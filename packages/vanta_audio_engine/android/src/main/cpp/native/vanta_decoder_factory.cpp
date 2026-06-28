#include "vanta_decoder_factory.h"

#include <algorithm>
#include <cctype>
#include <string>

namespace vanta_audio_engine {

VantaDecoderKind VantaDecoderFactory::DetectLocalPath(const char* path) {
  if (path == nullptr || path[0] == '\0') {
    return VantaDecoderKind::unsupported;
  }

  std::string lower_path(path);
  std::transform(
      lower_path.begin(), lower_path.end(), lower_path.begin(),
      [](unsigned char c) { return static_cast<char>(std::tolower(c)); });

  if (lower_path.size() >= 5 &&
      lower_path.substr(lower_path.size() - 5) == ".flac") {
    return VantaDecoderKind::flac;
  }
  if (lower_path.size() >= 4 &&
      lower_path.substr(lower_path.size() - 4) == ".mp3") {
    return VantaDecoderKind::mp3;
  }
  if (lower_path.size() >= 4 &&
      lower_path.substr(lower_path.size() - 4) == ".wav") {
    return VantaDecoderKind::wav;
  }

  return VantaDecoderKind::unsupported;
}

bool VantaDecoderFactory::SupportsLocalPath(const char* path) {
  return DetectLocalPath(path) != VantaDecoderKind::unsupported;
}

}  // namespace vanta_audio_engine
