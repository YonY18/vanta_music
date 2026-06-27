#pragma once

#include <algorithm>
#include <cstdint>

#include "miniaudio.h"

namespace vanta_audio_engine {
struct VantaPcmBufferPolicy {
  ma_uint32 capacity_ms = 750;
  ma_uint32 initial_fill_ms = 500;
};

// Internal PCM buffer policy guardrails for native playback experiments. The
// production path currently uses StableMusicPcmBufferPolicy() with its default;
// no Dart/Kotlin/runtime setting exposes this knob yet.
inline ma_uint32 ClampPcmBufferMs(ma_uint32 value_ms) {
  return std::clamp<ma_uint32>(value_ms, 250, 1000);
}

inline VantaPcmBufferPolicy StableMusicPcmBufferPolicy(
    ma_uint32 requested_capacity_ms = 750) {
  const ma_uint32 capacity_ms = ClampPcmBufferMs(requested_capacity_ms);
  return VantaPcmBufferPolicy{
      capacity_ms,
      std::min<ma_uint32>(capacity_ms, 500),
  };
}

inline ma_uint32 FramesForMilliseconds(ma_uint32 sample_rate,
                                       ma_uint32 milliseconds) {
  return (sample_rate * milliseconds) / 1000;
}
}  // namespace vanta_audio_engine
