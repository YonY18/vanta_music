#pragma once

#include <cstdint>

#include "miniaudio.h"

namespace vanta_audio_engine {
class VantaFlacDecoder {
public:
  bool OpenLocalPath(const char *path);
  void Close();
  bool Seek(uint64_t position_ms);
  uint64_t PositionMs() const;
  int64_t DurationMs() const;
  void ReadPcmFrames(void *output, ma_uint32 frame_count);

  bool IsReady() const;
  ma_format OutputFormat() const;
  ma_uint32 OutputChannels() const;
  ma_uint32 SampleRate() const;
  ma_uint64 TotalFrames() const;

private:
  ma_decoder decoder_{};
  bool ready_ = false;
  ma_uint64 total_frames_ = 0;
  ma_uint32 sample_rate_ = 0;
  ma_uint32 channels_ = 0;
};
} // namespace vanta_audio_engine
