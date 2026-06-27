#pragma once

namespace vanta_audio_engine {

inline bool ShouldRestartOutputAfterSeek(bool output_started) {
  return output_started;
}

} // namespace vanta_audio_engine
