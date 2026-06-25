#include "vanta_decoder.h"

#include <algorithm>
#include <cctype>
#include <cstring>
#include <string>

namespace vanta_audio_engine {
bool VantaDecoder::SupportsLocalPath(const char *path) const {
  if (path == nullptr || path[0] == '\0') {
    return false;
  }
  std::string lower_path(path);
  std::transform(
      lower_path.begin(), lower_path.end(), lower_path.begin(),
      [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return (lower_path.size() >= 4 &&
          lower_path.substr(lower_path.size() - 4) == ".wav") ||
         (lower_path.size() >= 5 &&
          lower_path.substr(lower_path.size() - 5) == ".flac");
}

bool VantaDecoder::OpenLocalPath(const char *path) {
  if (!SupportsLocalPath(path)) {
    return false;
  }

  Close();

  std::string lower_path(path);
  std::transform(
      lower_path.begin(), lower_path.end(), lower_path.begin(),
      [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  if (lower_path.size() >= 5 &&
      lower_path.substr(lower_path.size() - 5) == ".flac") {
    if (!flac_decoder_.OpenLocalPath(path)) {
      Close();
      return false;
    }
    active_decoder_ = ActiveDecoder::flac;
    ready_ = true;
    sample_rate_ = flac_decoder_.SampleRate();
    channels_ = flac_decoder_.OutputChannels();
    total_frames_ = flac_decoder_.TotalFrames();
    return true;
  }

  ma_decoder_config decoder_config =
      ma_decoder_config_init(ma_format_f32, 0, 0);
  if (ma_decoder_init_file(path, &decoder_config, &decoder_) != MA_SUCCESS) {
    Close();
    return false;
  }

  active_decoder_ = ActiveDecoder::wav;
  ready_ = true;
  sample_rate_ = decoder_.outputSampleRate;
  channels_ = decoder_.outputChannels;
  if (ma_decoder_get_length_in_pcm_frames(&decoder_, &total_frames_) !=
      MA_SUCCESS) {
    total_frames_ = 0;
  }
  return true;
}

void VantaDecoder::Close() {
  if (active_decoder_ == ActiveDecoder::flac) {
    flac_decoder_.Close();
  } else if (ready_) {
    ma_decoder_uninit(&decoder_);
  }
  ready_ = false;
  active_decoder_ = ActiveDecoder::none;
  total_frames_ = 0;
  sample_rate_ = 0;
  channels_ = 0;
}

bool VantaDecoder::Seek(uint64_t position_ms) {
  if (!ready_ || sample_rate_ == 0) {
    return false;
  }
  if (active_decoder_ == ActiveDecoder::flac) {
    return flac_decoder_.Seek(position_ms);
  }
  const ma_uint64 frame = (position_ms * sample_rate_) / 1000;
  return ma_decoder_seek_to_pcm_frame(&decoder_, frame) == MA_SUCCESS;
}

uint64_t VantaDecoder::PositionMs() const {
  if (!ready_ || sample_rate_ == 0) {
    return 0;
  }
  if (active_decoder_ == ActiveDecoder::flac) {
    return flac_decoder_.PositionMs();
  }
  ma_uint64 cursor = 0;
  if (ma_decoder_get_cursor_in_pcm_frames(const_cast<ma_decoder *>(&decoder_),
                                          &cursor) != MA_SUCCESS) {
    return 0;
  }
  return (cursor * 1000) / sample_rate_;
}

int64_t VantaDecoder::DurationMs() const {
  if (!ready_ || sample_rate_ == 0 || total_frames_ == 0) {
    return -1;
  }
  return static_cast<int64_t>((total_frames_ * 1000) / sample_rate_);
}

void VantaDecoder::ReadPcmFrames(void *output, ma_uint32 frame_count) {
  if (!ready_) {
    return;
  }
  if (active_decoder_ == ActiveDecoder::flac) {
    flac_decoder_.ReadPcmFrames(output, frame_count);
    return;
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
}

bool VantaDecoder::IsReady() const { return ready_; }

ma_format VantaDecoder::OutputFormat() const {
  return active_decoder_ == ActiveDecoder::flac ? flac_decoder_.OutputFormat()
                                                : decoder_.outputFormat;
}

ma_uint32 VantaDecoder::OutputChannels() const { return channels_; }

ma_uint32 VantaDecoder::SampleRate() const { return sample_rate_; }
} // namespace vanta_audio_engine
