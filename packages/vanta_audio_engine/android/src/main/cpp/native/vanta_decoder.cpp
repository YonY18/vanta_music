#include "vanta_decoder.h"

#include <algorithm>
#include <cstring>

namespace vanta_audio_engine {
bool VantaDecoder::SupportsLocalPath(const char *path) const {
  return VantaDecoderFactory::SupportsLocalPath(path);
}

bool VantaDecoder::OpenLocalPath(const char *path) {
  const VantaDecoderKind decoder_kind = VantaDecoderFactory::DetectLocalPath(path);
  if (decoder_kind == VantaDecoderKind::unsupported) {
    return false;
  }

  Close();

  if (decoder_kind == VantaDecoderKind::flac) {
    if (!flac_decoder_.OpenLocalPath(path)) {
      Close();
      return false;
    }
    active_decoder_ = VantaDecoderKind::flac;
    ready_ = true;
    sample_rate_ = flac_decoder_.SampleRate();
    channels_ = flac_decoder_.OutputChannels();
    total_frames_ = flac_decoder_.TotalFrames();
    return true;
  }

  if (decoder_kind == VantaDecoderKind::mp3) {
    if (!mp3_decoder_.OpenLocalPath(path)) {
      Close();
      return false;
    }
    active_decoder_ = VantaDecoderKind::mp3;
    ready_ = true;
    sample_rate_ = mp3_decoder_.SampleRate();
    channels_ = mp3_decoder_.OutputChannels();
    total_frames_ = mp3_decoder_.TotalFrames();
    return true;
  }

  ma_decoder_config decoder_config =
      ma_decoder_config_init(ma_format_f32, 0, 0);
  if (ma_decoder_init_file(path, &decoder_config, &decoder_) != MA_SUCCESS) {
    Close();
    return false;
  }

  active_decoder_ = VantaDecoderKind::wav;
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
  if (active_decoder_ == VantaDecoderKind::flac) {
    flac_decoder_.Close();
  } else if (active_decoder_ == VantaDecoderKind::mp3) {
    mp3_decoder_.Close();
  } else if (ready_) {
    ma_decoder_uninit(&decoder_);
  }
  ready_ = false;
  active_decoder_ = VantaDecoderKind::unsupported;
  total_frames_ = 0;
  sample_rate_ = 0;
  channels_ = 0;
}

bool VantaDecoder::Seek(uint64_t position_ms) {
  if (!ready_ || sample_rate_ == 0) {
    return false;
  }
  const uint64_t duration_ms = DurationMs() > 0 ? static_cast<uint64_t>(DurationMs()) : 0;
  const uint64_t clamped_position_ms =
      duration_ms > 0 ? std::min(position_ms, duration_ms) : position_ms;
  if (active_decoder_ == VantaDecoderKind::flac) {
    return flac_decoder_.Seek(clamped_position_ms);
  }
  if (active_decoder_ == VantaDecoderKind::mp3) {
    return mp3_decoder_.Seek(clamped_position_ms);
  }
  const ma_uint64 frame = (clamped_position_ms * sample_rate_) / 1000;
  return ma_decoder_seek_to_pcm_frame(&decoder_, frame) == MA_SUCCESS;
}

uint64_t VantaDecoder::PositionMs() const {
  if (!ready_ || sample_rate_ == 0) {
    return 0;
  }
  if (active_decoder_ == VantaDecoderKind::flac) {
    return flac_decoder_.PositionMs();
  }
  if (active_decoder_ == VantaDecoderKind::mp3) {
    return mp3_decoder_.PositionMs();
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

ma_uint64 VantaDecoder::ReadPcmFrames(void *output, ma_uint32 frame_count) {
  if (!ready_) {
    return 0;
  }
  if (active_decoder_ == VantaDecoderKind::flac) {
    return flac_decoder_.ReadPcmFrames(output, frame_count);
  }
  if (active_decoder_ == VantaDecoderKind::mp3) {
    return mp3_decoder_.ReadPcmFrames(output, frame_count);
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

bool VantaDecoder::IsReady() const { return ready_; }

ma_format VantaDecoder::OutputFormat() const {
  if (active_decoder_ == VantaDecoderKind::flac) {
    return flac_decoder_.OutputFormat();
  }
  if (active_decoder_ == VantaDecoderKind::mp3) {
    return mp3_decoder_.OutputFormat();
  }
  return decoder_.outputFormat;
}

ma_uint32 VantaDecoder::OutputChannels() const { return channels_; }

ma_uint32 VantaDecoder::SampleRate() const { return sample_rate_; }
} // namespace vanta_audio_engine
