#include <cassert>

#include "vanta_decoder_factory.cpp"

using vanta_audio_engine::VantaDecoderFactory;
using vanta_audio_engine::VantaDecoderKind;

int main() {
  assert(VantaDecoderFactory::DetectLocalPath("/music/song.flac") ==
         VantaDecoderKind::flac);
  assert(VantaDecoderFactory::DetectLocalPath("/music/song.MP3") ==
         VantaDecoderKind::mp3);
  assert(VantaDecoderFactory::DetectLocalPath("/music/song.wav") ==
         VantaDecoderKind::wav);

  assert(VantaDecoderFactory::DetectLocalPath("/music/song.m4a") ==
         VantaDecoderKind::unsupported);
  assert(VantaDecoderFactory::DetectLocalPath("/music/song.aac") ==
         VantaDecoderKind::unsupported);
  assert(VantaDecoderFactory::DetectLocalPath("/music/song.alac") ==
         VantaDecoderKind::unsupported);
  assert(VantaDecoderFactory::DetectLocalPath("/music/song.opus") ==
         VantaDecoderKind::unsupported);
  assert(VantaDecoderFactory::DetectLocalPath("/music/song.ogg") ==
         VantaDecoderKind::unsupported);

  assert(VantaDecoderFactory::SupportsLocalPath("/music/song.mp3"));
  assert(!VantaDecoderFactory::SupportsLocalPath("/music/song.oga"));
  assert(!VantaDecoderFactory::SupportsLocalPath("/music/song.amr"));
  assert(!VantaDecoderFactory::SupportsLocalPath("/music/song.3gp"));

  return 0;
}
