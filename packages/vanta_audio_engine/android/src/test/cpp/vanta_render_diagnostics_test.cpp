#include <cassert>
#include <string>

#include "vanta_render_diagnostics.h"

using vanta_audio_engine::FormatRenderDiagnostics;
using vanta_audio_engine::HasRenderAnomaly;
using vanta_audio_engine::ProducedFrames;
using vanta_audio_engine::VantaRenderDiagnosticsSnapshot;

int main() {
  const VantaRenderDiagnosticsSnapshot clean{10, 4800, 4800, 0, 0, 0, 0, 24000, 24000, true, true, 48000, 2, 500, 500};
  assert(ProducedFrames(clean) == 4800);
  assert(!HasRenderAnomaly(clean));

  const VantaRenderDiagnosticsSnapshot underrun{12, 5760, 5520, 2, 240, 1, 1, 0, 24000, true, true, 48000, 2, 0, 500};
  assert(ProducedFrames(underrun) == 5520);
  assert(HasRenderAnomaly(underrun));

  const std::string formatted = FormatRenderDiagnostics(underrun);
  assert(formatted.find("callbacks=12") != std::string::npos);
  assert(formatted.find("requested_frames=5760") != std::string::npos);
  assert(formatted.find("frames_read=5520") != std::string::npos);
  assert(formatted.find("frames_produced=5520") != std::string::npos);
  assert(formatted.find("short_reads=2") != std::string::npos);
  assert(formatted.find("zero_filled_frames=240") != std::string::npos);
  assert(formatted.find("decoder_not_ready_underruns=1") != std::string::npos);
  assert(formatted.find("ring_buffer_underruns=1") != std::string::npos);
  assert(formatted.find("ring_buffer_fill_frames=0") != std::string::npos);
  assert(formatted.find("ring_buffer_capacity_frames=24000") != std::string::npos);
  assert(formatted.find("ring_buffer_fill_ms=0") != std::string::npos);
  assert(formatted.find("ring_buffer_capacity_ms=500") != std::string::npos);
  assert(formatted.find("decoder_thread_alive=1") != std::string::npos);
  assert(formatted.find("audio_callback_alive=1") != std::string::npos);
  assert(formatted.find("sample_rate=48000") != std::string::npos);
  assert(formatted.find("channels=2") != std::string::npos);

  return 0;
}
