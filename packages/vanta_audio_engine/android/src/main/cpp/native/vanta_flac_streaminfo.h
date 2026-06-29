#pragma once

#include <cstddef>
#include <cstdint>

namespace vanta_audio_engine {

struct VantaFlacStreamInfo {
  uint32_t sample_rate = 0;
  uint32_t channels = 0;
  uint32_t bits_per_sample = 0;
};

inline bool ParseNativeFlacStreamInfo(const uint8_t *data, size_t size,
                                      VantaFlacStreamInfo *info) {
  if (data == nullptr || info == nullptr || size < 42) {
    return false;
  }
  if (data[0] != 'f' || data[1] != 'L' || data[2] != 'a' || data[3] != 'C') {
    return false;
  }

  const uint8_t metadata_block_type = data[4] & 0x7F;
  const uint32_t metadata_block_size =
      (static_cast<uint32_t>(data[5]) << 16) |
      (static_cast<uint32_t>(data[6]) << 8) | static_cast<uint32_t>(data[7]);
  if (metadata_block_type != 0 || metadata_block_size != 34 ||
      size < 8 + metadata_block_size) {
    return false;
  }

  const uint8_t *stream_info = data + 8;
  const uint32_t sample_rate =
      (static_cast<uint32_t>(stream_info[10]) << 12) |
      (static_cast<uint32_t>(stream_info[11]) << 4) |
      ((static_cast<uint32_t>(stream_info[12]) & 0xF0) >> 4);
  const uint32_t channels =
      ((static_cast<uint32_t>(stream_info[12]) & 0x0E) >> 1) + 1;
  const uint32_t bits_per_sample =
      (((static_cast<uint32_t>(stream_info[12]) & 0x01) << 4) |
       ((static_cast<uint32_t>(stream_info[13]) & 0xF0) >> 4)) +
      1;

  if (sample_rate == 0 || channels == 0 || bits_per_sample < 4 ||
      bits_per_sample > 32) {
    return false;
  }

  info->sample_rate = sample_rate;
  info->channels = channels;
  info->bits_per_sample = bits_per_sample;
  return true;
}

} // namespace vanta_audio_engine
