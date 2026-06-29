#pragma once

#include <cstdint>
#include <atomic>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "vanta_decoder.h"
#include "vanta_output.h"
#include "vanta_pcm_buffer_policy.h"
#include "vanta_pcm_ring_buffer.h"
#include "vanta_render_callback_policy.h"
#include "vanta_render_diagnostics.h"

namespace vanta_audio_engine {
enum class VantaLoadError {
  none,
  unsupported_format,
  decode_error,
  output_error
};

class VantaEngine {
public:
  VantaEngine();
  ~VantaEngine();

  VantaEngine(const VantaEngine &) = delete;
  VantaEngine &operator=(const VantaEngine &) = delete;

  bool Init();
  bool LoadLocalPath(const char *path);
  bool Play();
  bool Pause();
  bool Stop();
  bool Seek(uint64_t position_ms);
  bool SetVolume(float volume);
  uint64_t PositionMs() const;
  int64_t DurationMs() const;
  const char *LoadErrorCode() const;
  std::string OutputLifecycleStatus() const;
  std::string RenderDiagnostics() const;
  ma_uint32 TechnicalSampleRate() const;
  ma_uint32 TechnicalChannels() const;
  ma_uint32 TechnicalBitDepth() const;
  ma_uint32 TechnicalOutputSampleRate() const;
  ma_uint32 TechnicalOutputChannels() const;
  const char *TechnicalPcmFormat() const;
  const char *TechnicalCodec() const;
  const char *TechnicalDecoderName() const;
  void Dispose();

private:
  // Real-time render callback. Keep aligned with VantaRenderCallbackPolicy:
  // no locks, decoder reads, allocations, logging, file I/O, or channel calls.
  static void DataCallback(ma_device *device, void *output, const void *input,
                           ma_uint32 frame_count);
  void ResetUnlocked();
  bool IsPreparedLockedState() const;
  VantaRenderDiagnosticsSnapshot RenderDiagnosticsSnapshot() const;
  void ResetRenderDiagnostics();
  void ClearRenderDecoder();
  void PublishRenderDecoder();
  bool PreparePcmBufferLocked();
  void CaptureDecoderThreadMetadataLocked();
  void FillInitialPcmBufferLocked();
  void StartDecoderThreadLocked();
  void StopDecoderThreadLocked();
  void DecoderThreadLoop();

  VantaDecoder decoder_{};
  VantaOutput output_{};
  mutable std::mutex state_mutex_{};
  std::mutex decoder_mutex_{};
  VantaPcmRingBuffer pcm_ring_buffer_{};
  std::thread decoder_thread_{};
  bool initialized_ = false;
  VantaLoadError last_load_error_ = VantaLoadError::none;
  std::atomic<VantaDecoder *> render_decoder_{nullptr};
  std::atomic_bool render_ready_{false};
  std::atomic<uint64_t> decoder_duration_ms_{0};
  std::atomic<uint64_t> render_position_ms_{0};
  std::atomic<uint64_t> render_callbacks_{0};
  std::atomic<uint64_t> render_requested_frames_{0};
  std::atomic<uint64_t> render_frames_read_{0};
  std::atomic<uint64_t> render_short_reads_{0};
  std::atomic<uint64_t> render_zero_filled_frames_{0};
  std::atomic<uint64_t> decoder_not_ready_underruns_{0};
  std::atomic<uint64_t> ring_buffer_underruns_{0};
  std::atomic<uint64_t> render_position_frames_{0};
  std::atomic_bool decoder_thread_running_{false};
  std::atomic_bool decoder_thread_alive_{false};
  std::atomic_bool decoder_finished_{false};
  std::atomic_bool audio_callback_alive_{false};
  VantaPcmBufferPolicy pcm_buffer_policy_ = StableMusicPcmBufferPolicy();
  ma_uint32 decoder_thread_sample_rate_ = 0;
  ma_uint32 decoder_thread_channels_ = 0;
  ma_uint32 decoder_thread_chunk_frames_ = 0;
  ma_uint32 decoder_thread_bytes_per_frame_ = 0;
};
} // namespace vanta_audio_engine
