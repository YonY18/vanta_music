#include <cassert>

#include "vanta_lifecycle_policy.h"

using vanta_audio_engine::ShouldRestartOutputAfterSeek;

int main() {
  assert(ShouldRestartOutputAfterSeek(true));
  assert(!ShouldRestartOutputAfterSeek(false));

  return 0;
}
