#pragma once

namespace vanta_audio_engine {

enum class VantaDecoderKind { unsupported, wav, flac, mp3 };

class VantaDecoderFactory {
 public:
  static VantaDecoderKind DetectLocalPath(const char* path);
  static bool SupportsLocalPath(const char* path);
};

}  // namespace vanta_audio_engine
