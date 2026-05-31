import 'dart:typed_data';

import 'package:on_audio_query/on_audio_query.dart';
import 'package:http/http.dart' as http;

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

abstract class RemoteArtworkBytesSource {
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

class HttpRemoteArtworkBytesSource implements RemoteArtworkBytesSource {
  HttpRemoteArtworkBytesSource({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<Uint8List?> fetch({required Uri uri, required int sizePx}) async {
    if (!uri.isScheme('http') && !uri.isScheme('https')) return null;

    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    return response.bodyBytes.isEmpty ? null : response.bodyBytes;
  }
}

class ArtworkCacheResolver {
  ArtworkCacheResolver({
    required this.store,
    required this.source,
    required this.embeddedSource,
    this.remoteSource,
  });

  final ArtworkCacheStore store;
  final ArtworkBytesSource source;
  final EmbeddedArtworkBytesSource embeddedSource;
  final RemoteArtworkBytesSource? remoteSource;
  final Set<String> _memoizedMisses = <String>{};
  final Map<String, Future<ArtworkResolution>> _inFlight =
      <String, Future<ArtworkResolution>>{};

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

    final remoteArtworkUri = remoteArtworkUriForTrack(track);
    final key = buildArtworkCacheKey(
      providerId: track.providerId,
      trackId: track.id,
      artworkId: artworkId,
      sizePx: sizePx,
      serverId: remoteArtworkUri?.queryParameters['serverId'],
      coverArtId: remoteArtworkUri?.queryParameters['id'],
      sourceUri: _cacheSourceUri(
        track: track,
        remoteArtworkUri: remoteArtworkUri,
      ),
    );
    final rawKey = key.raw;

    if (_memoizedMisses.contains(rawKey)) {
      _debugLog(track, 'memoized miss');
      return ArtworkResolution(
        key: rawKey,
        isFallback: true,
        resolvedAt: DateTime.now(),
      );
    }

    final pending = _inFlight[rawKey];
    if (pending != null) return pending;

    final future = _resolveInternal(
      track: track,
      sizePx: sizePx,
      key: key,
      rawKey: rawKey,
      artworkId: artworkId,
      remoteArtworkUri: remoteArtworkUri,
    );
    _inFlight[rawKey] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(rawKey);
    }
  }

  Future<ArtworkResolution> _resolveInternal({
    required Track track,
    required int sizePx,
    required ArtworkCacheKey key,
    required String rawKey,
    required int? artworkId,
    required Uri? remoteArtworkUri,
  }) async {
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

    if ((bytes == null || bytes.isEmpty) &&
        remoteArtworkUri != null &&
        remoteSource != null) {
      try {
        bytes = await remoteSource!.fetch(
          uri: remoteArtworkUri,
          sizePx: sizePx,
        );
        _debugLog(
          track,
          bytes == null || bytes.isEmpty
              ? 'remote miss uri=$remoteArtworkUri'
              : 'remote hit uri=$remoteArtworkUri bytes=${bytes.length}',
        );
      } catch (error) {
        _debugLog(track, 'remote error uri=$remoteArtworkUri error=$error');
      }
    }

    if (bytes == null || bytes.isEmpty) {
      _debugLog(track, 'final miss');
      _memoizedMisses.add(rawKey);
      return ArtworkResolution(
        key: rawKey,
        isFallback: true,
        resolvedAt: DateTime.now(),
      );
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

Uri? remoteArtworkUriForTrack(Track track) {
  if (!track.uri.isScheme('subsonic')) return null;

  final explicitUri = track.uri.queryParameters['coverArtUri'];
  if (explicitUri != null && explicitUri.isNotEmpty) {
    return Uri.tryParse(explicitUri);
  }

  final coverArtId = track.uri.queryParameters['coverArtId'];
  if (coverArtId == null || coverArtId.isEmpty) return null;

  return Uri(
    scheme: 'subsonic',
    host: 'cover-art',
    queryParameters: <String, String>{
      if (track.uri.queryParameters['serverId'] != null)
        'serverId': track.uri.queryParameters['serverId']!,
      'id': coverArtId,
    },
  );
}

bool hasRemoteArtwork(Track track) => remoteArtworkUriForTrack(track) != null;

String _cacheSourceUri({required Track track, required Uri? remoteArtworkUri}) {
  if (remoteArtworkUri == null) return track.uri.toString();

  final coverArtId = remoteArtworkUri.queryParameters['id'];
  if (coverArtId != null && coverArtId.isNotEmpty) {
    return 'remote-cover:${track.providerId}:$coverArtId';
  }

  return sanitizeArtworkUri(remoteArtworkUri).toString();
}
