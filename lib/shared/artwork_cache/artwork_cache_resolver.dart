import 'dart:typed_data';

import 'package:on_audio_query/on_audio_query.dart';

import '../../features/library/domain/track.dart';
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
  const ArtworkCacheResolver({
    required this.store,
    required this.source,
    required this.embeddedSource,
  });

  final ArtworkCacheStore store;
  final ArtworkBytesSource source;
  final EmbeddedArtworkBytesSource embeddedSource;

  Future<String?> resolvePath({
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

    final cachedPath = await store.readPath(key);
    if (cachedPath != null) {
      _debugLog(track, 'cache hit path=$cachedPath');
      return cachedPath;
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
      return null;
    }

    await store.writeBytes(key, bytes);
    final writtenPath = await store.readPath(key);
    _debugLog(track, 'cache write path=$writtenPath');
    return writtenPath;
  }

  void _debugLog(Track track, String message) {
    logArtworkCacheDiagnostic(
      '[ArtworkCache] $message | title="${track.title}" '
      'artworkId=${track.artworkId} uri=${track.uri}',
    );
  }
}
