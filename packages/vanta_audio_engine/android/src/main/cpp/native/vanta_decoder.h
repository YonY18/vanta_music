#pragma once

#include <cstdint>

#include "miniaudio.h"
#include "vanta_decoder_factory.h"
#include "vanta_flac_decoder.h"
#include "vanta_mp3_decoder.h"

namespace vanta_audio_engine {
class VantaDecoder {
public:
  bool SupportsLocalPath(const char *path) const;
  bool OpenLocalPath(const char *path);
  void Close();
  bool Seek(uint64_t position_ms);
  uint64_t PositionMs() const;
  int64_t DurationMs() const;
  ma_uint64 ReadPcmFrames(void *output, ma_uint32 frame_count);

  bool IsReady() const;
  ma_format OutputFormat() const;
  ma_uint32 OutputChannels() const;
  ma_uint32 SampleRate() const;
  ma_uint32 SourceBitDepth() const;
  VantaDecoderKind ActiveDecoderKind() const;

private:
  ma_decoder decoder_{};
  VantaFlacDecoder flac_decoder_{};
  VantaMp3Decoder mp3_decoder_{};
  VantaDecoderKind active_decoder_ = VantaDecoderKind::unsupported;
  bool ready_ = false;
  ma_uint64 total_frames_ = 0;
  ma_uint32 sample_rate_ = 0;
  ma_uint32 channels_ = 0;
  ma_uint32 source_bit_depth_ = 0;
};
} // namespace vanta_audio_engine
