#pragma once

namespace vanta_audio_engine {

// Host-testable contract for the miniaudio render callback. The callback must
// stay real-time safe: it may read already-decoded PCM from the preallocated
// SPSC ring buffer and update atomics, but it must not decode, take locks,
// allocate, log, or call back into Kotlin/Dart.
struct VantaRenderCallbackPolicy {
  static constexpr bool reads_predecoded_ring_buffer = true;
  static constexpr bool allows_decoder_reads = false;
  static constexpr bool allows_locks = false;
  static constexpr bool allows_allocations = false;
  static constexpr bool allows_logging = false;
  static constexpr bool allows_channel_callbacks = false;
};

static_assert(VantaRenderCallbackPolicy::reads_predecoded_ring_buffer,
              "Native render callback must read from the PCM ring buffer");
static_assert(!VantaRenderCallbackPolicy::allows_decoder_reads,
              "Native render callback must not decode or perform file I/O");
static_assert(!VantaRenderCallbackPolicy::allows_locks,
              "Native render callback must not take locks");
static_assert(!VantaRenderCallbackPolicy::allows_allocations,
              "Native render callback must not allocate");
static_assert(!VantaRenderCallbackPolicy::allows_logging,
              "Native render callback must not log");
static_assert(!VantaRenderCallbackPolicy::allows_channel_callbacks,
              "Native render callback must not call Kotlin/Dart channels");

}  // namespace vanta_audio_engine
