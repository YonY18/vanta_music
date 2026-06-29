#define MA_IMPLEMENTATION
#include "vanta_engine.h"

#include "vanta_lifecycle_policy.h"

#include <jni.h>

#include <algorithm>
#include <chrono>
#include <cstring>

namespace vanta_audio_engine {
VantaEngine::VantaEngine() = default;

VantaEngine::~VantaEngine() { Dispose(); }

bool VantaEngine::Init() {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  initialized_ = true;
  return true;
}

bool VantaEngine::LoadLocalPath(const char *path) {
  if (path == nullptr || path[0] == '\0') {
    return false;
  }
  std::lock_guard<std::mutex> state_lock(state_mutex_);

  if (!initialized_ || !decoder_.SupportsLocalPath(path)) {
    last_load_error_ = VantaLoadError::unsupported_format;
    return false;
  }

  const bool had_output = output_.IsReady();
  if (had_output) {
    if (!output_.Stop()) {
      output_.Close();
    }
  }

  // Decoder ownership is mutated only after the device has been stopped or
  // closed. The render callback never takes state_mutex_ and only reads the
  // published decoder pointer while the device is allowed to invoke it.
  ClearRenderDecoder();
  StopDecoderThreadLocked();
  {
    std::lock_guard<std::mutex> decoder_lock(decoder_mutex_);
    decoder_.Close();
  }
  ResetRenderDiagnostics();
  {
    std::lock_guard<std::mutex> decoder_lock(decoder_mutex_);
    if (!decoder_.OpenLocalPath(path)) {
      output_.Close();
      decoder_.Close();
      last_load_error_ = VantaLoadError::decode_error;
      return false;
    }
  }
  if (!PreparePcmBufferLocked()) {
    output_.Close();
    std::lock_guard<std::mutex> decoder_lock(decoder_mutex_);
    decoder_.Close();
    last_load_error_ = VantaLoadError::decode_error;
    return false;
  }

  if (output_.IsReady()) {
    if (output_.IsCompatibleWith(decoder_)) {
      output_.MarkReused();
      FillInitialPcmBufferLocked();
      PublishRenderDecoder();
      StartDecoderThreadLocked();
      last_load_error_ = VantaLoadError::none;
      return true;
    }
    output_.Close();
  }

  if (!output_.Open(decoder_, VantaEngine::DataCallback, this)) {
    output_.Close();
    std::lock_guard<std::mutex> decoder_lock(decoder_mutex_);
    decoder_.Close();
    last_load_error_ = VantaLoadError::output_error;
    return false;
  }

  FillInitialPcmBufferLocked();
  PublishRenderDecoder();
  StartDecoderThreadLocked();
  last_load_error_ = VantaLoadError::none;
  return true;
}

bool VantaEngine::Play() {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  return IsPreparedLockedState() && output_.Start();
}

bool VantaEngine::Pause() {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  return IsPreparedLockedState() && output_.Stop();
}

bool VantaEngine::Stop() {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  if (!IsPreparedLockedState()) {
    return false;
  }
  ResetUnlocked();
  return true;
}

bool VantaEngine::Seek(uint64_t position_ms) {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  if (!IsPreparedLockedState()) {
    return false;
  }
  const bool restart_output = ShouldRestartOutputAfterSeek(output_.IsStarted());
  if (restart_output && !output_.Stop()) {
    return false;
  }
  ClearRenderDecoder();
  StopDecoderThreadLocked();
  const int64_t duration_ms = decoder_.DurationMs();
  const uint64_t clamped_position_ms =
      duration_ms > 0 ? std::min(position_ms, static_cast<uint64_t>(duration_ms))
                      : position_ms;
  bool seek_result = false;
  {
    std::lock_guard<std::mutex> decoder_lock(decoder_mutex_);
    seek_result = decoder_.Seek(clamped_position_ms);
  }
  render_position_ms_.store(seek_result ? clamped_position_ms
                                         : render_position_ms_.load());
  render_position_frames_.store((clamped_position_ms * decoder_.SampleRate()) / 1000);
  pcm_ring_buffer_.Clear();
  decoder_finished_.store(false);
  if (seek_result) {
    FillInitialPcmBufferLocked();
    StartDecoderThreadLocked();
  }
  PublishRenderDecoder();
  if (restart_output && !output_.Start()) {
    return false;
  }
  return seek_result;
}

bool VantaEngine::SetVolume(float volume) {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  return output_.SetVolume(volume);
}

uint64_t VantaEngine::PositionMs() const {
  return render_position_ms_.load();
}

int64_t VantaEngine::DurationMs() const {
  const uint64_t duration_ms = decoder_duration_ms_.load();
  return duration_ms == 0 ? -1 : static_cast<int64_t>(duration_ms);
}

const char *VantaEngine::LoadErrorCode() const {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  switch (last_load_error_) {
  case VantaLoadError::unsupported_format:
    return "unsupported_format";
  case VantaLoadError::decode_error:
    return "decode_error";
  case VantaLoadError::output_error:
    return "output_error";
  case VantaLoadError::none:
  default:
    return "decode_error";
  }
}

std::string VantaEngine::OutputLifecycleStatus() const {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  return output_.LifecycleStatus();
}

std::string VantaEngine::RenderDiagnostics() const {
  return FormatRenderDiagnostics(RenderDiagnosticsSnapshot());
}

ma_uint32 VantaEngine::TechnicalSampleRate() const {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  return decoder_.SampleRate();
}

ma_uint32 VantaEngine::TechnicalChannels() const {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  return decoder_.OutputChannels();
}

ma_uint32 VantaEngine::TechnicalBitDepth() const {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  return decoder_.SourceBitDepth();
}

ma_uint32 VantaEngine::TechnicalOutputSampleRate() const {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  return decoder_.SampleRate();
}

ma_uint32 VantaEngine::TechnicalOutputChannels() const {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  return decoder_.OutputChannels();
}

const char *VantaEngine::TechnicalPcmFormat() const {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  switch (decoder_.OutputFormat()) {
  case ma_format_f32:
    return "float32";
  case ma_format_s16:
    return "s16";
  case ma_format_s24:
    return "s24";
  case ma_format_s32:
    return "s32";
  default:
    return "unknown";
  }
}

const char *VantaEngine::TechnicalCodec() const {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  switch (decoder_.ActiveDecoderKind()) {
  case VantaDecoderKind::flac:
    return "FLAC";
  case VantaDecoderKind::mp3:
    return "MP3";
  case VantaDecoderKind::wav:
    return "WAV";
  default:
    return "unknown";
  }
}

const char *VantaEngine::TechnicalDecoderName() const {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  switch (decoder_.ActiveDecoderKind()) {
  case VantaDecoderKind::flac:
    return "dr_flac";
  case VantaDecoderKind::mp3:
    return "dr_mp3";
  case VantaDecoderKind::wav:
    return "miniaudio";
  default:
    return "unknown";
  }
}

void VantaEngine::Dispose() {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  ResetUnlocked();
  initialized_ = false;
}

void VantaEngine::DataCallback(ma_device *device, void *output,
                               const void *input, ma_uint32 frame_count) {
  auto *engine = static_cast<VantaEngine *>(device->pUserData);
  if (engine == nullptr) {
    std::memset(output, 0,
                frame_count *
                    ma_get_bytes_per_frame(device->playback.format,
                                           device->playback.channels));
    return;
  }

  engine->render_callbacks_.fetch_add(1);
  engine->audio_callback_alive_.store(true);
  engine->render_requested_frames_.fetch_add(frame_count);
  const bool render_ready = engine->render_ready_.load(std::memory_order_acquire);
  const auto bytes_per_frame = ma_get_bytes_per_frame(device->playback.format,
                                                        device->playback.channels);
  if (!render_ready) {
    engine->decoder_not_ready_underruns_.fetch_add(1);
    engine->render_zero_filled_frames_.fetch_add(frame_count);
    std::memset(output, 0, frame_count * bytes_per_frame);
    return;
  }

  const ma_uint64 frames_read = engine->pcm_ring_buffer_.ReadFrames(output, frame_count);
  engine->render_frames_read_.fetch_add(frames_read);
  const uint64_t position_frames =
      engine->render_position_frames_.fetch_add(frames_read) + frames_read;
  if (device->sampleRate > 0) {
    engine->render_position_ms_.store((position_frames * 1000) / device->sampleRate);
  }
  if (frames_read < frame_count) {
    engine->render_short_reads_.fetch_add(1);
    engine->ring_buffer_underruns_.fetch_add(1);
    engine->render_zero_filled_frames_.fetch_add(frame_count - frames_read);
    std::memset(static_cast<unsigned char *>(output) + frames_read * bytes_per_frame,
                0, (frame_count - frames_read) * bytes_per_frame);
  }
  (void)input;
}

void VantaEngine::ResetUnlocked() {
  output_.Close();
  ClearRenderDecoder();
  StopDecoderThreadLocked();
  {
    std::lock_guard<std::mutex> decoder_lock(decoder_mutex_);
    decoder_.Close();
  }
  pcm_ring_buffer_.Clear();
  ResetRenderDiagnostics();
}

bool VantaEngine::IsPreparedLockedState() const {
  return decoder_.IsReady() && output_.IsReady();
}

VantaRenderDiagnosticsSnapshot VantaEngine::RenderDiagnosticsSnapshot() const {
  const auto ring_fill_frames = pcm_ring_buffer_.BufferedFrames();
  const auto ring_capacity_frames = pcm_ring_buffer_.CapacityFrames();
  const auto sample_rate = decoder_thread_sample_rate_;
  return VantaRenderDiagnosticsSnapshot{
      render_callbacks_.load(),
      render_requested_frames_.load(),
      render_frames_read_.load(),
      render_short_reads_.load(),
      render_zero_filled_frames_.load(),
      decoder_not_ready_underruns_.load(),
      ring_buffer_underruns_.load(),
      ring_fill_frames,
      ring_capacity_frames,
      decoder_thread_alive_.load(),
      audio_callback_alive_.load(),
      sample_rate,
      decoder_thread_channels_,
      sample_rate == 0 ? 0 : (ring_fill_frames * 1000) / sample_rate,
      sample_rate == 0 ? 0 : (ring_capacity_frames * 1000) / sample_rate,
  };
}

void VantaEngine::ResetRenderDiagnostics() {
  render_position_ms_.store(0);
  render_callbacks_.store(0);
  render_requested_frames_.store(0);
  render_frames_read_.store(0);
  render_short_reads_.store(0);
  render_zero_filled_frames_.store(0);
  decoder_not_ready_underruns_.store(0);
  ring_buffer_underruns_.store(0);
  render_position_frames_.store(0);
  audio_callback_alive_.store(false);
}

void VantaEngine::ClearRenderDecoder() {
  render_decoder_.store(nullptr);
  render_ready_.store(false, std::memory_order_release);
  decoder_duration_ms_.store(0);
}

void VantaEngine::PublishRenderDecoder() {
  const int64_t duration_ms = decoder_.DurationMs();
  decoder_duration_ms_.store(duration_ms > 0 ? static_cast<uint64_t>(duration_ms)
                                               : 0);
  render_position_ms_.store(decoder_.PositionMs());
  render_position_frames_.store((decoder_.PositionMs() * decoder_.SampleRate()) / 1000);
  render_decoder_.store(&decoder_);
  render_ready_.store(true, std::memory_order_release);
}

bool VantaEngine::PreparePcmBufferLocked() {
  const ma_uint32 sample_rate = decoder_.SampleRate();
  pcm_buffer_policy_ = StableMusicPcmBufferPolicy();
  const ma_uint32 capacity_frames = FramesForMilliseconds(
      sample_rate, pcm_buffer_policy_.capacity_ms);
  decoder_finished_.store(false);
  return pcm_ring_buffer_.Reset(decoder_.OutputFormat(), decoder_.OutputChannels(),
                                 capacity_frames);
}

void VantaEngine::CaptureDecoderThreadMetadataLocked() {
  decoder_thread_sample_rate_ = decoder_.SampleRate();
  decoder_thread_channels_ = decoder_.OutputChannels();
  decoder_thread_chunk_frames_ = std::max<ma_uint32>(1, decoder_thread_sample_rate_ / 50);
  decoder_thread_bytes_per_frame_ = ma_get_bytes_per_frame(
      decoder_.OutputFormat(), decoder_.OutputChannels());
}

void VantaEngine::FillInitialPcmBufferLocked() {
  const ma_uint32 sample_rate = decoder_.SampleRate();
  const ma_uint32 target_frames = FramesForMilliseconds(
      sample_rate, pcm_buffer_policy_.initial_fill_ms);
  const ma_uint32 chunk_frames = std::max<ma_uint32>(1, sample_rate / 50);
  const auto bytes_per_frame =
      ma_get_bytes_per_frame(decoder_.OutputFormat(), decoder_.OutputChannels());
  std::vector<unsigned char> chunk(static_cast<size_t>(chunk_frames) * bytes_per_frame);
  while (pcm_ring_buffer_.BufferedFrames() < target_frames) {
    ma_uint64 frames_read = 0;
    {
      std::lock_guard<std::mutex> decoder_lock(decoder_mutex_);
      frames_read = decoder_.ReadPcmFrames(chunk.data(), chunk_frames);
    }
    if (frames_read == 0) {
      decoder_finished_.store(true);
      return;
    }
    pcm_ring_buffer_.WriteFrames(chunk.data(), static_cast<ma_uint32>(frames_read));
    if (frames_read < chunk_frames) {
      decoder_finished_.store(true);
      return;
    }
  }
}

void VantaEngine::StartDecoderThreadLocked() {
  if (decoder_thread_running_.load()) {
    return;
  }
  CaptureDecoderThreadMetadataLocked();
  decoder_thread_running_.store(true);
  decoder_thread_ = std::thread(&VantaEngine::DecoderThreadLoop, this);
}

void VantaEngine::StopDecoderThreadLocked() {
  decoder_thread_running_.store(false);
  if (decoder_thread_.joinable()) {
    decoder_thread_.join();
  }
  decoder_thread_alive_.store(false);
}

void VantaEngine::DecoderThreadLoop() {
  decoder_thread_alive_.store(true);
  const ma_uint32 chunk_frames = decoder_thread_chunk_frames_;
  const auto bytes_per_frame = decoder_thread_bytes_per_frame_;
  std::vector<unsigned char> chunk(static_cast<size_t>(chunk_frames) * bytes_per_frame);

  while (decoder_thread_running_.load()) {
    if (decoder_finished_.load() || pcm_ring_buffer_.AvailableWriteFrames() < chunk_frames) {
      std::this_thread::sleep_for(std::chrono::milliseconds(10));
      continue;
    }

    ma_uint64 frames_read = 0;
    {
      std::lock_guard<std::mutex> decoder_lock(decoder_mutex_);
      frames_read = decoder_.ReadPcmFrames(chunk.data(), chunk_frames);
    }
    if (frames_read == 0) {
      decoder_finished_.store(true);
      continue;
    }
    pcm_ring_buffer_.WriteFrames(chunk.data(), static_cast<ma_uint32>(frames_read));
    if (frames_read < chunk_frames) {
      decoder_finished_.store(true);
    }
  }
  decoder_thread_alive_.store(false);
}
} // namespace vanta_audio_engine

static vanta_audio_engine::VantaEngine engine;

extern "C" JNIEXPORT jboolean JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_initNative(JNIEnv *,
                                                                  jobject) {
  return engine.Init();
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_loadNative(
    JNIEnv *env, jobject, jstring path) {
  if (path == nullptr) {
    return false;
  }

  const char *native_path = env->GetStringUTFChars(path, nullptr);
  if (native_path == nullptr) {
    return false;
  }

  const bool loaded = engine.LoadLocalPath(native_path);
  env->ReleaseStringUTFChars(path, native_path);
  return loaded;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_loadErrorCodeNative(
    JNIEnv *env, jobject) {
  return env->NewStringUTF(engine.LoadErrorCode());
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_outputLifecycleStatusNative(
    JNIEnv *env, jobject) {
  const std::string status = engine.OutputLifecycleStatus();
  return env->NewStringUTF(status.c_str());
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_renderDiagnosticsNative(
    JNIEnv *env, jobject) {
  const std::string diagnostics = engine.RenderDiagnostics();
  return env->NewStringUTF(diagnostics.c_str());
}

extern "C" JNIEXPORT jint JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_technicalSampleRateNative(
    JNIEnv *, jobject) {
  return static_cast<jint>(engine.TechnicalSampleRate());
}

extern "C" JNIEXPORT jint JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_technicalChannelsNative(
    JNIEnv *, jobject) {
  return static_cast<jint>(engine.TechnicalChannels());
}

extern "C" JNIEXPORT jint JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_technicalBitDepthNative(
    JNIEnv *, jobject) {
  return static_cast<jint>(engine.TechnicalBitDepth());
}

extern "C" JNIEXPORT jint JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_technicalOutputSampleRateNative(
    JNIEnv *, jobject) {
  return static_cast<jint>(engine.TechnicalOutputSampleRate());
}

extern "C" JNIEXPORT jint JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_technicalOutputChannelsNative(
    JNIEnv *, jobject) {
  return static_cast<jint>(engine.TechnicalOutputChannels());
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_technicalPcmFormatNative(
    JNIEnv *env, jobject) {
  return env->NewStringUTF(engine.TechnicalPcmFormat());
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_technicalCodecNative(
    JNIEnv *env, jobject) {
  return env->NewStringUTF(engine.TechnicalCodec());
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_technicalDecoderNameNative(
    JNIEnv *env, jobject) {
  return env->NewStringUTF(engine.TechnicalDecoderName());
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_playNative(JNIEnv *,
                                                                  jobject) {
  return engine.Play();
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_pauseNative(JNIEnv *,
                                                                   jobject) {
  return engine.Pause();
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_stopNative(JNIEnv *,
                                                                  jobject) {
  return engine.Stop();
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_seekNative(
    JNIEnv *, jobject, jlong position_ms) {
  return engine.Seek(static_cast<uint64_t>(std::max<jlong>(0, position_ms)));
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_setVolumeNative(
    JNIEnv *, jobject, jfloat volume) {
  return engine.SetVolume(volume);
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_positionMsNative(
    JNIEnv *, jobject) {
  return static_cast<jlong>(engine.PositionMs());
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_durationMsNative(
    JNIEnv *, jobject) {
  return static_cast<jlong>(engine.DurationMs());
}

extern "C" JNIEXPORT void JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_disposeNative(JNIEnv *,
                                                                     jobject) {
  engine.Dispose();
}
