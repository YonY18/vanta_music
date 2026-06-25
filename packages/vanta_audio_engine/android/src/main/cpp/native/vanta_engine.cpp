#define MA_IMPLEMENTATION
#include "vanta_engine.h"

#include <jni.h>

#include <algorithm>
#include <cstring>

namespace vanta_audio_engine {
VantaEngine::VantaEngine() = default;

VantaEngine::~VantaEngine() { Dispose(); }

bool VantaEngine::Init() {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  initialized_ = true;
  return true;
}

bool VantaEngine::LoadLocalPath(const char* path) {
  if (path == nullptr || path[0] == '\0') {
    return false;
  }
  std::lock_guard<std::mutex> state_lock(state_mutex_);

  if (!initialized_ || !decoder_.SupportsLocalPath(path)) {
    return false;
  }

  ResetUnlocked();

  std::lock_guard<std::mutex> decoder_lock(decoder_mutex_);
  if (!decoder_.OpenLocalPath(path) ||
      !output_.Open(decoder_, VantaEngine::DataCallback, this)) {
    output_.Close();
    decoder_.Close();
    return false;
  }

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
  output_.Stop();
  std::lock_guard<std::mutex> decoder_lock(decoder_mutex_);
  return decoder_.Seek(0);
}

bool VantaEngine::Seek(uint64_t position_ms) {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  if (!IsPreparedLockedState()) {
    return false;
  }
  std::lock_guard<std::mutex> decoder_lock(decoder_mutex_);
  return decoder_.Seek(position_ms);
}

bool VantaEngine::SetVolume(float volume) {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  return output_.SetVolume(volume);
}

uint64_t VantaEngine::PositionMs() const {
  std::lock_guard<std::mutex> decoder_lock(decoder_mutex_);
  return decoder_.PositionMs();
}

int64_t VantaEngine::DurationMs() const {
  std::lock_guard<std::mutex> decoder_lock(decoder_mutex_);
  return decoder_.DurationMs();
}

void VantaEngine::Dispose() {
  std::lock_guard<std::mutex> state_lock(state_mutex_);
  ResetUnlocked();
  initialized_ = false;
}

void VantaEngine::DataCallback(ma_device* device, void* output, const void* input,
                               ma_uint32 frame_count) {
  auto* engine = static_cast<VantaEngine*>(device->pUserData);
  if (engine == nullptr) {
    std::memset(output, 0, frame_count * ma_get_bytes_per_frame(device->playback.format,
                                                                device->playback.channels));
    return;
  }

  std::lock_guard<std::mutex> decoder_lock(engine->decoder_mutex_);
  if (!engine->decoder_.IsReady()) {
    std::memset(output, 0, frame_count * ma_get_bytes_per_frame(device->playback.format,
                                                                device->playback.channels));
    return;
  }

  engine->decoder_.ReadPcmFrames(output, frame_count);
  (void)input;
}

void VantaEngine::ResetUnlocked() {
  output_.Close();
  std::lock_guard<std::mutex> decoder_lock(decoder_mutex_);
  decoder_.Close();
}

bool VantaEngine::IsPreparedLockedState() const {
  std::lock_guard<std::mutex> decoder_lock(decoder_mutex_);
  return decoder_.IsReady() && output_.IsReady();
}
}  // namespace vanta_audio_engine

static vanta_audio_engine::VantaEngine engine;

extern "C" JNIEXPORT jboolean JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_initNative(JNIEnv*, jobject) {
  return engine.Init();
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_loadNative(
    JNIEnv* env,
    jobject,
    jstring path) {
  if (path == nullptr) {
    return false;
  }

  const char* native_path = env->GetStringUTFChars(path, nullptr);
  if (native_path == nullptr) {
    return false;
  }

  const bool loaded = engine.LoadLocalPath(native_path);
  env->ReleaseStringUTFChars(path, native_path);
  return loaded;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_playNative(JNIEnv*, jobject) {
  return engine.Play();
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_pauseNative(JNIEnv*, jobject) {
  return engine.Pause();
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_stopNative(JNIEnv*, jobject) {
  return engine.Stop();
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_seekNative(JNIEnv*, jobject,
                                                                  jlong position_ms) {
  return engine.Seek(static_cast<uint64_t>(std::max<jlong>(0, position_ms)));
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_setVolumeNative(JNIEnv*, jobject,
                                                                       jfloat volume) {
  return engine.SetVolume(volume);
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_positionMsNative(JNIEnv*, jobject) {
  return static_cast<jlong>(engine.PositionMs());
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_durationMsNative(JNIEnv*, jobject) {
  return static_cast<jlong>(engine.DurationMs());
}

extern "C" JNIEXPORT void JNICALL
Java_com_vantamusic_audioengine_VantaAudioEnginePlugin_disposeNative(JNIEnv*, jobject) {
  engine.Dispose();
}
