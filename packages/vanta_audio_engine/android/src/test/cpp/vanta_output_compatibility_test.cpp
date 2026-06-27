#include <cassert>
#include <string>

#include "vanta_output.h"
#include "vanta_pcm_buffer_policy.h"
#include "vanta_render_callback_policy.h"

using vanta_audio_engine::ApplyOutputBufferPolicy;
using vanta_audio_engine::AndroidOutputBackendOrder;
using vanta_audio_engine::AndroidOutputBackendOrderCount;
using vanta_audio_engine::BackendPreferenceLogName;
using vanta_audio_engine::PerformanceProfileName;
using vanta_audio_engine::PreferredOutputBackendPreference;
using vanta_audio_engine::IsReusableOutputConfig;
using vanta_audio_engine::StableMusicOutputBufferPolicy;
using vanta_audio_engine::ClampPcmBufferMs;
using vanta_audio_engine::FramesForMilliseconds;
using vanta_audio_engine::StableMusicPcmBufferPolicy;
using vanta_audio_engine::VantaRenderCallbackPolicy;
using vanta_audio_engine::VantaOutputConfig;

int main() {
  const VantaOutputConfig output{ma_format_s16, 2, 48000};

  assert(IsReusableOutputConfig(output,
                                VantaOutputConfig{ma_format_s16, 2, 48000}));
  assert(!IsReusableOutputConfig(output,
                                 VantaOutputConfig{ma_format_s16, 2, 44100}));
  assert(!IsReusableOutputConfig(output,
                                 VantaOutputConfig{ma_format_s16, 1, 48000}));
  assert(!IsReusableOutputConfig(output,
                                  VantaOutputConfig{ma_format_f32, 2, 48000}));

  const auto policy = StableMusicOutputBufferPolicy();
  assert(policy.period_size_ms == 40);
  assert(policy.periods == 4);
  assert(policy.performance_profile == ma_performance_profile_conservative);
  assert(PerformanceProfileName(policy.performance_profile) ==
         std::string("conservative"));

  ma_device_config device_config{};
  ApplyOutputBufferPolicy(device_config, policy);
  assert(device_config.periodSizeInMilliseconds == 40);
  assert(device_config.periodSizeInFrames == 0);
  assert(device_config.periods == 4);
  assert(device_config.performanceProfile == ma_performance_profile_conservative);

  assert(ClampPcmBufferMs(100) == 250);
  assert(ClampPcmBufferMs(750) == 750);
  assert(ClampPcmBufferMs(1200) == 1000);
  const auto pcm_policy = StableMusicPcmBufferPolicy();
  assert(pcm_policy.capacity_ms == 750);
  assert(pcm_policy.initial_fill_ms == 500);
  assert(FramesForMilliseconds(48000, pcm_policy.capacity_ms) == 36000);
  assert(StableMusicPcmBufferPolicy(100).capacity_ms == 250);
  assert(StableMusicPcmBufferPolicy(1200).capacity_ms == 1000);

  static_assert(VantaRenderCallbackPolicy::reads_predecoded_ring_buffer);
  static_assert(!VantaRenderCallbackPolicy::allows_decoder_reads);
  static_assert(!VantaRenderCallbackPolicy::allows_locks);
  static_assert(!VantaRenderCallbackPolicy::allows_allocations);
  static_assert(!VantaRenderCallbackPolicy::allows_logging);
  static_assert(!VantaRenderCallbackPolicy::allows_channel_callbacks);

  const auto* android_backend_order = AndroidOutputBackendOrder();
  assert(AndroidOutputBackendOrderCount() == 2);
  assert(android_backend_order[0] == ma_backend_aaudio);
  assert(android_backend_order[1] == ma_backend_opensl);
  assert(BackendPreferenceLogName({android_backend_order, 2, "test"}) ==
         std::string("AAudio,OpenSL|ES"));

  const auto backend_preference = PreferredOutputBackendPreference();
#if defined(__ANDROID__)
  assert(backend_preference.backends == android_backend_order);
  assert(backend_preference.backend_count == 2);
  assert(std::string(backend_preference.strategy_name) ==
         "prefer_aaudio_fallback_opensl");
#else
  assert(backend_preference.backends == nullptr);
  assert(backend_preference.backend_count == 0);
  assert(std::string(backend_preference.strategy_name) == "default");
#endif

  return 0;
}
