#pragma once

#include <cstdint>
#include <mutex>

#include "vanta_decoder.h"
#include "vanta_output.h"

namespace vanta_audio_engine {
class VantaEngine {
 public:
  VantaEngine();
  ~VantaEngine();

  VantaEngine(const VantaEngine&) = delete;
  VantaEngine& operator=(const VantaEngine&) = delete;

  bool Init();
  bool LoadLocalPath(const char* path);
  bool Play();
  bool Pause();
  bool Stop();
  bool Seek(uint64_t position_ms);
  bool SetVolume(float volume);
  uint64_t PositionMs() const;
  int64_t DurationMs() const;
  void Dispose();

 private:
  static void DataCallback(ma_device* device, void* output, const void* input,
                           ma_uint32 frame_count);
  void ResetUnlocked();
  bool IsPreparedLockedState() const;

  VantaDecoder decoder_{};
  VantaOutput output_{};
  mutable std::mutex state_mutex_{};
  mutable std::mutex decoder_mutex_{};
  bool initialized_ = false;
};
}  // namespace vanta_audio_engine
