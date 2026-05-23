import 'dart:math' as math;

int resolveArtworkQuerySize({
  required double logicalSize,
  required double devicePixelRatio,
  int maxPhysicalPixels = 160,
}) {
  final requested = (logicalSize * devicePixelRatio).round();
  final minSize = logicalSize.floor();
  return math.max(minSize, math.min(requested, maxPhysicalPixels));
}
