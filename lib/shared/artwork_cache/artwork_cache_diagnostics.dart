import 'package:flutter/foundation.dart';

const bool artworkCacheDiagnosticsEnabled = false;

const Set<String> _sensitiveArtworkQueryKeys = <String>{
  'u',
  's',
  't',
  'password',
  'token',
};

String sanitizeArtworkDiagnosticMessage(String message) {
  return message.replaceAllMapped(
    RegExp(r'([?&](?:u|s|t|password|token)=)([^&#\s]+)', caseSensitive: false),
    (match) => '${match.group(1)}<redacted>',
  );
}

Uri sanitizeArtworkUri(Uri uri) {
  if (uri.queryParameters.isEmpty) return uri;
  final sanitized = <String, String>{};
  for (final entry in uri.queryParameters.entries) {
    if (_sensitiveArtworkQueryKeys.contains(entry.key.toLowerCase())) {
      continue;
    }
    sanitized[entry.key] = entry.value;
  }
  return uri.replace(queryParameters: sanitized.isEmpty ? null : sanitized);
}

void logArtworkCacheDiagnostic(String message) {
  if (!kDebugMode || !artworkCacheDiagnosticsEnabled) return;
  debugPrint(sanitizeArtworkDiagnosticMessage(message));
}
