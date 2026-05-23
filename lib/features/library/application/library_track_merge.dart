import 'dart:async';

import '../domain/track.dart';
import 'file_validation_cache.dart';

Future<List<Track>> mergeAndCleanTracks(
  List<Track> sources, {
  InMemoryFileValidationCache? cache,
}) async {
  final validationCache = cache ?? InMemoryFileValidationCache();
  final seen = <String>{};
  final result = <Track>[];
  final staleFileUris = <Uri>[];

  for (final track in sources) {
    if (!await _isPlayable(track, validationCache, staleFileUris)) continue;
    final key = _dedupeKey(track);
    if (seen.add(key)) {
      result.add(track);
    }
  }

  if (staleFileUris.isNotEmpty) {
    unawaited(validationCache.reconcileBatch(staleFileUris));
  }

  return List.unmodifiable(result);
}

String _dedupeKey(Track track) {
  final uri = track.uri.toString().trim().toLowerCase();
  if (uri.isNotEmpty) return uri;
  return '${track.providerId}:${track.id}'.toLowerCase();
}

Future<bool> _isPlayable(
  Track track,
  InMemoryFileValidationCache cache,
  List<Uri> staleFileUris,
) async {
  final uri = track.uri;
  if (uri.scheme == 'file') {
    final cached = cache.read(uri);
    if (cached != null) {
      staleFileUris.add(uri);
      return cached.state == ValidationState.valid;
    }
    final validated = await cache.validate(uri);
    return validated.state == ValidationState.valid;
  }
  return uri.scheme == 'content' || uri.scheme.startsWith('http');
}
