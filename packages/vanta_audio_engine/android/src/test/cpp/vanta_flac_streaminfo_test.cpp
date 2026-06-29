#include "vanta_flac_streaminfo.h"

#include <cassert>
#include <cstdint>

namespace {
constexpr size_t kHeaderSize = 42;

void WriteStreamInfoFields(uint8_t *stream_info, uint32_t sample_rate,
                            uint32_t channels, uint32_t bits_per_sample) {
  const uint32_t encoded_channels = channels - 1;
  const uint32_t encoded_bits_per_sample = bits_per_sample - 1;
  stream_info[10] = static_cast<uint8_t>((sample_rate >> 12) & 0xFF);
  stream_info[11] = static_cast<uint8_t>((sample_rate >> 4) & 0xFF);
  stream_info[12] = static_cast<uint8_t>(((sample_rate & 0x0F) << 4) |
                                         ((encoded_channels & 0x07) << 1) |
                                         ((encoded_bits_per_sample >> 4) & 0x01));
  stream_info[13] = static_cast<uint8_t>((encoded_bits_per_sample & 0x0F) << 4);
}

void WriteBlockSize(uint8_t *header, uint32_t block_size) {
  header[5] = static_cast<uint8_t>((block_size >> 16) & 0xFF);
  header[6] = static_cast<uint8_t>((block_size >> 8) & 0xFF);
  header[7] = static_cast<uint8_t>(block_size & 0xFF);
}

void ResetValidHeader(uint8_t *header) {
  for (size_t index = 0; index < kHeaderSize; ++index) {
    header[index] = 0;
  }
  header[0] = 'f';
  header[1] = 'L';
  header[2] = 'a';
  header[3] = 'C';
  header[4] = 0x00;
  WriteBlockSize(header, 34);
  WriteStreamInfoFields(header + 8, 48000, 2, 24);
}
} // namespace

int main() {
  uint8_t header[kHeaderSize]{};
  ResetValidHeader(header);

  vanta_audio_engine::VantaFlacStreamInfo info{};
  assert(vanta_audio_engine::ParseNativeFlacStreamInfo(header, sizeof(header),
                                                       &info));
  assert(info.sample_rate == 48000);
  assert(info.channels == 2);
  assert(info.bits_per_sample == 24);

  header[0] = 'I';
  assert(!vanta_audio_engine::ParseNativeFlacStreamInfo(header, sizeof(header),
                                                        &info));

  ResetValidHeader(header);
  assert(!vanta_audio_engine::ParseNativeFlacStreamInfo(header, 41, &info));

  ResetValidHeader(header);
  WriteBlockSize(header, 33);
  assert(!vanta_audio_engine::ParseNativeFlacStreamInfo(header, sizeof(header),
                                                        &info));

  ResetValidHeader(header);
  WriteBlockSize(header, 35);
  assert(!vanta_audio_engine::ParseNativeFlacStreamInfo(header, sizeof(header),
                                                        &info));

  ResetValidHeader(header);
  WriteStreamInfoFields(header + 8, 0, 2, 24);
  assert(!vanta_audio_engine::ParseNativeFlacStreamInfo(header, sizeof(header),
                                                        &info));

  ResetValidHeader(header);
  WriteStreamInfoFields(header + 8, 48000, 2, 1);
  assert(!vanta_audio_engine::ParseNativeFlacStreamInfo(header, sizeof(header),
                                                        &info));

  ResetValidHeader(header);
  WriteStreamInfoFields(header + 8, 48000, 2, 3);
  assert(!vanta_audio_engine::ParseNativeFlacStreamInfo(header, sizeof(header),
                                                        &info));

  ResetValidHeader(header);
  WriteStreamInfoFields(header + 8, 48000, 8, 32);
  assert(vanta_audio_engine::ParseNativeFlacStreamInfo(header, sizeof(header),
                                                       &info));
  assert(info.channels == 8);
  assert(info.bits_per_sample == 32);
  return 0;
}
