#pragma once

#include <cstdint>
#include <sstream>
#include <string>

namespace vanta_audio_engine {
struct VantaRenderDiagnosticsSnapshot {
  uint64_t callbacks = 0;
  uint64_t requested_frames = 0;
  uint64_t frames_read = 0;
  uint64_t short_reads = 0;
  uint64_t zero_filled_frames = 0;
  uint64_t decoder_not_ready_underruns = 0;
  uint64_t ring_buffer_underruns = 0;
  uint64_t ring_buffer_fill_frames = 0;
  uint64_t ring_buffer_capacity_frames = 0;
  bool decoder_thread_alive = false;
  bool audio_callback_alive = false;
  uint64_t sample_rate = 0;
  uint64_t channels = 0;
  uint64_t ring_buffer_fill_ms = 0;
  uint64_t ring_buffer_capacity_ms = 0;
};

inline uint64_t ProducedFrames(const VantaRenderDiagnosticsSnapshot &snapshot) {
  return snapshot.requested_frames >= snapshot.zero_filled_frames
             ? snapshot.requested_frames - snapshot.zero_filled_frames
             : 0;
}

inline std::string FormatRenderDiagnostics(
    const VantaRenderDiagnosticsSnapshot &snapshot) {
  std::ostringstream stream;
  stream << "callbacks=" << snapshot.callbacks
         << " requested_frames=" << snapshot.requested_frames
         << " frames_read=" << snapshot.frames_read
         << " frames_produced=" << ProducedFrames(snapshot)
          << " short_reads=" << snapshot.short_reads
          << " zero_filled_frames=" << snapshot.zero_filled_frames
          << " decoder_not_ready_underruns="
          << snapshot.decoder_not_ready_underruns
          << " ring_buffer_underruns=" << snapshot.ring_buffer_underruns
          << " ring_buffer_fill_frames=" << snapshot.ring_buffer_fill_frames
          << " ring_buffer_capacity_frames=" << snapshot.ring_buffer_capacity_frames
          << " ring_buffer_fill_ms=" << snapshot.ring_buffer_fill_ms
          << " ring_buffer_capacity_ms=" << snapshot.ring_buffer_capacity_ms
          << " decoder_thread_alive=" << (snapshot.decoder_thread_alive ? 1 : 0)
          << " audio_callback_alive=" << (snapshot.audio_callback_alive ? 1 : 0)
          << " sample_rate=" << snapshot.sample_rate
          << " channels=" << snapshot.channels;
  return stream.str();
}

inline bool HasRenderAnomaly(const VantaRenderDiagnosticsSnapshot &snapshot) {
  return snapshot.short_reads > 0 || snapshot.zero_filled_frames > 0 ||
         snapshot.decoder_not_ready_underruns > 0 ||
         snapshot.ring_buffer_underruns > 0;
}
} // namespace vanta_audio_engine
