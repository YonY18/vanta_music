import 'package:flutter/foundation.dart';

const bool artworkCacheDiagnosticsEnabled = false;

void logArtworkCacheDiagnostic(String message) {
  if (!kDebugMode || !artworkCacheDiagnosticsEnabled) return;
  debugPrint(message);
}
