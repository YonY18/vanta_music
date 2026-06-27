#include "vanta_flac_decoder.h"

#include <algorithm>
#include <cstring>

namespace vanta_audio_engine {
bool VantaFlacDecoder::OpenLocalPath(const char *path) {
  if (path == nullptr || path[0] == '\0') {
    return false;
  }

  Close();

  ma_decoder_config decoder_config =
      ma_decoder_config_init(ma_format_f32, 0, 0);
  if (ma_decoder_init_file(path, &decoder_config, &decoder_) != MA_SUCCESS) {
    Close();
    return false;
  }

  ready_ = true;
  sample_rate_ = decoder_.outputSampleRate;
  channels_ = decoder_.outputChannels;
  if (ma_decoder_get_length_in_pcm_frames(&decoder_, &total_frames_) !=
      MA_SUCCESS) {
    total_frames_ = 0;
  }
  return true;
}

void VantaFlacDecoder::Close() {
  if (ready_) {
    ma_decoder_uninit(&decoder_);
    ready_ = false;
  }
  total_frames_ = 0;
  sample_rate_ = 0;
  channels_ = 0;
}

bool VantaFlacDecoder::Seek(uint64_t position_ms) {
  if (!ready_ || sample_rate_ == 0) {
    return false;
  }
  const uint64_t duration_ms = DurationMs() > 0 ? static_cast<uint64_t>(DurationMs()) : 0;
  const uint64_t clamped_position_ms =
      duration_ms > 0 ? std::min(position_ms, duration_ms) : position_ms;
  const ma_uint64 frame = (clamped_position_ms * sample_rate_) / 1000;
  return ma_decoder_seek_to_pcm_frame(&decoder_, frame) == MA_SUCCESS;
}

uint64_t VantaFlacDecoder::PositionMs() const {
  if (!ready_ || sample_rate_ == 0) {
    return 0;
  }
  ma_uint64 cursor = 0;
  if (ma_decoder_get_cursor_in_pcm_frames(const_cast<ma_decoder *>(&decoder_),
                                          &cursor) != MA_SUCCESS) {
    return 0;
  }
  return (cursor * 1000) / sample_rate_;
}

int64_t VantaFlacDecoder::DurationMs() const {
  if (!ready_ || sample_rate_ == 0 || total_frames_ == 0) {
    return -1;
  }
  return static_cast<int64_t>((total_frames_ * 1000) / sample_rate_);
}

ma_uint64 VantaFlacDecoder::ReadPcmFrames(void *output, ma_uint32 frame_count) {
  if (!ready_) {
    return 0;
  }
  ma_uint64 frames_read = 0;
  ma_decoder_read_pcm_frames(&decoder_, output, frame_count, &frames_read);
  if (frames_read < frame_count) {
    const auto bytes_per_frame =
        ma_get_bytes_per_frame(OutputFormat(), OutputChannels());
    std::memset(static_cast<unsigned char *>(output) +
                    (frames_read * bytes_per_frame),
                0, (frame_count - frames_read) * bytes_per_frame);
  }
  return frames_read;
}

bool VantaFlacDecoder::IsReady() const { return ready_; }

ma_format VantaFlacDecoder::OutputFormat() const {
  return decoder_.outputFormat;
}

ma_uint32 VantaFlacDecoder::OutputChannels() const { return channels_; }

ma_uint32 VantaFlacDecoder::SampleRate() const { return sample_rate_; }

ma_uint64 VantaFlacDecoder::TotalFrames() const { return total_frames_; }
} // namespace vanta_audio_engine
