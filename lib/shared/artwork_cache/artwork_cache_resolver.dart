import 'dart:typed_data';

import 'package:on_audio_query/on_audio_query.dart';

import '../../features/library/domain/track.dart';
import '../../features/premium_metadata/domain/metadata_models.dart';
import 'artwork_cache_diagnostics.dart';
import 'artwork_cache_key.dart';
import 'file_artwork_cache_store.dart';

abstract class ArtworkBytesSource {
  Future<Uint8List?> fetch({required int artworkId, required int sizePx});
}

abstract class EmbeddedArtworkBytesSource {
  Future<Uint8List?> fetch({required Uri uri, required int sizePx});
}

class OnAudioQueryArtworkBytesSource implements ArtworkBytesSource {
  OnAudioQueryArtworkBytesSource({OnAudioQuery? query})
    : _query = query ?? OnAudioQuery();

  final OnAudioQuery _query;

  @override
  Future<Uint8List?> fetch({required int artworkId, required int sizePx}) {
    return _query.queryArtwork(
      artworkId,
      ArtworkType.AUDIO,
      format: ArtworkFormat.JPEG,
      size: sizePx,
    );
  }
}

class ArtworkCacheResolver {
  ArtworkCacheResolver({
    required this.store,
    required this.source,
    required this.embeddedSource,
  });

  final ArtworkCacheStore store;
  final ArtworkBytesSource source;
  final EmbeddedArtworkBytesSource embeddedSource;
  final Set<String> _memoizedMisses = <String>{};

  Future<String?> resolvePath({
    required Track track,
    required int sizePx,
  }) async {
    return (await resolve(track: track, sizePx: sizePx)).path;
  }

  Future<ArtworkResolution> resolve({
    required Track track,
    required int sizePx,
  }) async {
    final artworkId = track.artworkId;

    final key = buildArtworkCacheKey(
      providerId: track.providerId,
      trackId: track.id,
      artworkId: artworkId,
      sizePx: sizePx,
      sourceUri: track.uri.toString(),
    );
    final rawKey = key.raw;

    if (_memoizedMisses.contains(rawKey)) {
      _debugLog(track, 'memoized miss');
      return ArtworkResolution(key: rawKey, resolvedAt: DateTime.now());
    }

    final cachedPath = await store.readPath(key);
    if (cachedPath != null) {
      _debugLog(track, 'cache hit path=$cachedPath');
      return ArtworkResolution(
        key: rawKey,
        path: cachedPath,
        resolvedAt: DateTime.now(),
      );
    }

    Uint8List? bytes;
    if (artworkId != null) {
      try {
        bytes = await source.fetch(artworkId: artworkId, sizePx: sizePx);
        _debugLog(
          track,
          bytes == null || bytes.isEmpty
              ? 'MediaStore miss artworkId=$artworkId'
              : 'MediaStore hit artworkId=$artworkId bytes=${bytes.length}',
        );
      } catch (error) {
        _debugLog(track, 'MediaStore error artworkId=$artworkId error=$error');
      }
    }

    if ((bytes == null || bytes.isEmpty) && track.uri.isScheme('file')) {
      try {
        bytes = await embeddedSource.fetch(uri: track.uri, sizePx: sizePx);
        _debugLog(
          track,
          bytes == null || bytes.isEmpty
              ? 'file fallback miss'
              : 'file fallback hit bytes=${bytes.length}',
        );
      } catch (error) {
        _debugLog(track, 'file fallback error error=$error');
      }
    }

    if (bytes == null || bytes.isEmpty) {
      _debugLog(track, 'final miss');
      _memoizedMisses.add(rawKey);
      return ArtworkResolution(key: rawKey, resolvedAt: DateTime.now());
    }

    await store.writeBytes(key, bytes);
    final writtenPath = await store.readPath(key);
    _debugLog(track, 'cache write path=$writtenPath');
    if (writtenPath == null) {
      _memoizedMisses.add(rawKey);
      return ArtworkResolution(key: rawKey, resolvedAt: DateTime.now());
    }
    return ArtworkResolution(
      key: rawKey,
      path: writtenPath,
      isFallback: artworkId == null,
      resolvedAt: DateTime.now(),
    );
  }

  void _debugLog(Track track, String message) {
    logArtworkCacheDiagnostic(
      '[ArtworkCache] $message | title="${track.title}" '
      'artworkId=${track.artworkId} uri=${track.uri}',
    );
  }
}
