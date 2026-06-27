#pragma once

#include <algorithm>
#include <atomic>
#include <cstdint>
#include <cstring>
#include <vector>

#include "miniaudio.h"

namespace vanta_audio_engine {
inline ma_uint32 VantaBytesPerSample(ma_format format) {
  switch (format) {
  case ma_format_u8:
    return 1;
  case ma_format_s16:
    return 2;
  case ma_format_s24:
    return 3;
  case ma_format_s32:
  case ma_format_f32:
    return 4;
  default:
    return 0;
  }
}

class VantaPcmRingBuffer {
public:
  bool Reset(ma_format format, ma_uint32 channels, ma_uint32 capacity_frames) {
    const ma_uint32 bytes_per_frame = VantaBytesPerSample(format) * channels;
    if (bytes_per_frame == 0 || capacity_frames == 0) {
      return false;
    }
    bytes_per_frame_ = bytes_per_frame;
    capacity_frames_ = capacity_frames;
    buffer_.assign(static_cast<size_t>(capacity_frames_) * bytes_per_frame_, 0);
    read_frame_.store(0, std::memory_order_relaxed);
    write_frame_.store(0, std::memory_order_relaxed);
    return true;
  }

  void Clear() {
    read_frame_.store(0, std::memory_order_relaxed);
    write_frame_.store(0, std::memory_order_relaxed);
    std::fill(buffer_.begin(), buffer_.end(), 0);
  }

  ma_uint32 CapacityFrames() const {
    return capacity_frames_;
  }

  ma_uint32 BufferedFrames() const {
    const auto write = write_frame_.load(std::memory_order_acquire);
    const auto read = read_frame_.load(std::memory_order_acquire);
    return static_cast<ma_uint32>(std::min<ma_uint64>(write - read, capacity_frames_));
  }

  ma_uint32 AvailableWriteFrames() const {
    return capacity_frames_ - BufferedFrames();
  }

  ma_uint32 WriteFrames(const void *input, ma_uint32 frame_count) {
    if (input == nullptr || frame_count == 0) {
      return 0;
    }
    const auto read = read_frame_.load(std::memory_order_acquire);
    const auto write = write_frame_.load(std::memory_order_relaxed);
    const auto buffered = write - read;
    const ma_uint32 frames_to_write =
        std::min<ma_uint32>(frame_count, capacity_frames_ - static_cast<ma_uint32>(buffered));
    const auto *source = static_cast<const unsigned char *>(input);
    for (ma_uint32 i = 0; i < frames_to_write; ++i) {
      const ma_uint32 write_index = static_cast<ma_uint32>((write + i) % capacity_frames_);
      std::memcpy(&buffer_[static_cast<size_t>(write_index) * bytes_per_frame_],
                  source + static_cast<size_t>(i) * bytes_per_frame_,
                  bytes_per_frame_);
    }
    write_frame_.store(write + frames_to_write, std::memory_order_release);
    return frames_to_write;
  }

  ma_uint32 ReadFrames(void *output, ma_uint32 frame_count) {
    if (output == nullptr || frame_count == 0) {
      return 0;
    }
    const auto write = write_frame_.load(std::memory_order_acquire);
    const auto read = read_frame_.load(std::memory_order_relaxed);
    const auto buffered = write - read;
    const ma_uint32 frames_to_read =
        std::min<ma_uint32>(frame_count, static_cast<ma_uint32>(buffered));
    auto *destination = static_cast<unsigned char *>(output);
    for (ma_uint32 i = 0; i < frames_to_read; ++i) {
      const ma_uint32 source_frame = static_cast<ma_uint32>((read + i) % capacity_frames_);
      std::memcpy(destination + static_cast<size_t>(i) * bytes_per_frame_,
                  &buffer_[static_cast<size_t>(source_frame) * bytes_per_frame_],
                  bytes_per_frame_);
    }
    read_frame_.store(read + frames_to_read, std::memory_order_release);
    return frames_to_read;
  }

private:
  std::vector<unsigned char> buffer_{};
  ma_uint32 bytes_per_frame_ = 0;
  ma_uint32 capacity_frames_ = 0;
  std::atomic<ma_uint64> read_frame_{0};
  std::atomic<ma_uint64> write_frame_{0};
};
} // namespace vanta_audio_engine
