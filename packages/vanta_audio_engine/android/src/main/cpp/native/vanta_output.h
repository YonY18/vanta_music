#pragma once

#include <string>

#include "miniaudio.h"

namespace vanta_audio_engine {
class VantaDecoder;

struct VantaOutputConfig {
  ma_format format = ma_format_unknown;
  ma_uint32 channels = 0;
  ma_uint32 sample_rate = 0;
};

struct VantaOutputBufferPolicy {
  ma_uint32 period_size_ms = 40;
  ma_uint32 periods = 4;
  ma_performance_profile performance_profile = ma_performance_profile_conservative;
};

inline VantaOutputBufferPolicy StableMusicOutputBufferPolicy() {
  return VantaOutputBufferPolicy{};
}

struct VantaOutputBackendPreference {
  const ma_backend* backends = nullptr;
  ma_uint32 backend_count = 0;
  const char* strategy_name = "default";
};

inline const ma_backend* AndroidOutputBackendOrder() {
  static constexpr ma_backend backends[] = {ma_backend_aaudio,
                                            ma_backend_opensl};
  return backends;
}

inline ma_uint32 AndroidOutputBackendOrderCount() { return 2; }

inline VantaOutputBackendPreference PreferredOutputBackendPreference() {
#if defined(__ANDROID__)
  return VantaOutputBackendPreference{AndroidOutputBackendOrder(),
                                      AndroidOutputBackendOrderCount(),
                                      "prefer_aaudio_fallback_opensl"};
#else
  return VantaOutputBackendPreference{nullptr, 0, "default"};
#endif
}

inline void ApplyOutputBufferPolicy(ma_device_config& device_config,
                                    const VantaOutputBufferPolicy& policy) {
  device_config.periodSizeInMilliseconds = policy.period_size_ms;
  device_config.periods = policy.periods;
  device_config.performanceProfile = policy.performance_profile;
}

inline const char* PerformanceProfileName(ma_performance_profile profile) {
  switch (profile) {
    case ma_performance_profile_low_latency:
      return "low_latency";
    case ma_performance_profile_conservative:
      return "conservative";
  }
  return "unknown";
}

inline const char* OutputBackendName(ma_backend backend) {
  switch (backend) {
    case ma_backend_aaudio:
      return "AAudio";
    case ma_backend_opensl:
      return "OpenSL|ES";
    default:
      return "unknown";
  }
}

inline std::string BackendPreferenceLogName(
    const VantaOutputBackendPreference& preference) {
  if (preference.backends == nullptr || preference.backend_count == 0) {
    return "default";
  }

  std::string names;
  for (ma_uint32 i = 0; i < preference.backend_count; ++i) {
    if (!names.empty()) {
      names += ",";
    }
    names += OutputBackendName(preference.backends[i]);
  }
  return names;
}

inline bool IsReusableOutputConfig(const VantaOutputConfig& current,
                                   const VantaOutputConfig& next) {
  return current.format == next.format && current.channels == next.channels &&
         current.sample_rate == next.sample_rate;
}

class VantaOutput {
 public:
  bool Open(const VantaDecoder& decoder, ma_device_data_proc callback, void* user_data);
  bool IsCompatibleWith(const VantaDecoder& decoder) const;
  void MarkReused();
  bool Start();
  bool Stop();
  bool SetVolume(float volume);
  void Close();
  bool IsReady() const;
  bool IsStarted() const;
  std::string LifecycleStatus() const;

 private:
  const char* BackendName() const;

  ma_device device_{};
  VantaOutputBufferPolicy buffer_policy_ = StableMusicOutputBufferPolicy();
  ma_format format_ = ma_format_unknown;
  ma_uint32 channels_ = 0;
  ma_uint32 sample_rate_ = 0;
  std::string lifecycle_status_ = "output=none backend=unknown";
  bool ready_ = false;
  bool started_ = false;
};
}  // namespace vanta_audio_engine
