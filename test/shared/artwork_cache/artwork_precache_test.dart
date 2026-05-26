import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/shared/artwork_cache/artwork_cache_key.dart';
import 'package:vanta_music/shared/artwork_cache/artwork_cache_resolver.dart';
import 'package:vanta_music/shared/artwork_cache/artwork_precache.dart';
import 'package:vanta_music/shared/artwork_cache/file_artwork_cache_store.dart';

void main() {
  group('selectTracksForArtworkPrecache', () {
    test('keeps library order, skips unsupported, and applies bound', () {
      final tracks = [
        _track('1', artworkId: 10, uri: Uri.parse('content://song/1')),
        _track('2', artworkId: null, uri: Uri.parse('content://song/2')),
        _track('3', artworkId: null, uri: Uri.file('/music/3.mp3')),
        _track('4', artworkId: 44, uri: Uri.parse('content://song/4')),
      ];

      final selected = selectTracksForArtworkPrecache(tracks, maxCount: 2);

      expect(selected.map((track) => track.id).toList(), ['1', '3']);
    });

    test('includes remote Subsonic cover art while preserving bounded order', () {
      final tracks = [
        _track(
          'local-unsupported',
          artworkId: null,
          uri: Uri.parse('content://song/1'),
        ),
        _remoteTrack('remote-1', coverArtId: 'cover-1'),
        _remoteTrack(
          'remote-2',
          coverArtUri:
              'https://music.example/rest/getCoverArt.view?id=cover-2&t=secret-token',
        ),
        _track(
          'local-file',
          artworkId: null,
          uri: Uri.file('/music/local.mp3'),
        ),
      ];

      final selected = selectTracksForArtworkPrecache(tracks, maxCount: 2);

      expect(selected.map((track) => track.id).toList(), [
        'subsonic:server-1:remote-1',
        'subsonic:server-1:remote-2',
      ]);
    });
  });

  group('ArtworkCacheWarmupService', () {
    test('warms selected tracks only and applies maxCount', () async {
      final resolver = _TrackingResolver();
      final service = ArtworkCacheWarmupService(resolver: resolver);
      final tracks = [
        _track('1', artworkId: 1, uri: Uri.parse('content://song/1')),
        _track('2', artworkId: null, uri: Uri.parse('content://song/2')),
        _track('3', artworkId: null, uri: Uri.file('/music/3.mp3')),
      ];

      await service.warmup(tracks, maxCount: 1);

      expect(resolver.calledTrackIds, ['1']);
    });

    test('swallows resolver failures', () async {
      final resolver = _TrackingResolver(failTrackIds: {'1'});
      final service = ArtworkCacheWarmupService(resolver: resolver);

      await service.warmup([
        _track('1', artworkId: 1, uri: Uri.parse('content://song/1')),
        _track('2', artworkId: 2, uri: Uri.parse('content://song/2')),
      ]);

      expect(resolver.calledTrackIds, ['1', '2']);
    });

    test('respects maxConcurrency', () async {
      final resolver = _TrackingResolver(
        delay: const Duration(milliseconds: 15),
      );
      final service = ArtworkCacheWarmupService(resolver: resolver);

      await service.warmup([
        _track('1', artworkId: 1, uri: Uri.parse('content://song/1')),
        _track('2', artworkId: 2, uri: Uri.parse('content://song/2')),
        _track('3', artworkId: 3, uri: Uri.parse('content://song/3')),
      ], maxConcurrency: 2);

      expect(resolver.maxConcurrentCalls, lessThanOrEqualTo(2));
    });
  });
}

Track _remoteTrack(String id, {String? coverArtId, String? coverArtUri}) {
  final queryParameters = <String, String>{'serverId': 'server-1', 'id': id};
  if (coverArtId != null) queryParameters['coverArtId'] = coverArtId;
  if (coverArtUri != null) queryParameters['coverArtUri'] = coverArtUri;

  return Track(
    id: 'subsonic:server-1:$id',
    providerId: 'subsonic:server-1',
    title: 'Remote Song $id',
    artist: 'Remote Artist',
    album: 'Remote Album',
    uri: Uri(
      scheme: 'subsonic',
      host: 'track',
      queryParameters: queryParameters,
    ),
  );
}

Track _track(String id, {required int? artworkId, required Uri uri}) {
  return Track(
    id: id,
    providerId: 'local',
    title: 'Song $id',
    artist: 'Artist',
    album: 'Album',
    uri: uri,
    artworkId: artworkId,
  );
}

class _TrackingResolver extends ArtworkCacheResolver {
  _TrackingResolver({this.failTrackIds = const <String>{}, this.delay})
    : super(
        store: _NoopStore(),
        source: _NoopSource(),
        embeddedSource: _NoopEmbeddedSource(),
      );

  final Set<String> failTrackIds;
  final Duration? delay;
  final List<String> calledTrackIds = <String>[];
  int _activeCalls = 0;
  int maxConcurrentCalls = 0;

  @override
  Future<String?> resolvePath({
    required Track track,
    required int sizePx,
  }) async {
    calledTrackIds.add(track.id);
    _activeCalls += 1;
    if (_activeCalls > maxConcurrentCalls) {
      maxConcurrentCalls = _activeCalls;
    }
    try {
      if (delay != null) await Future<void>.delayed(delay!);
      if (failTrackIds.contains(track.id)) {
        throw StateError('failed to resolve ${track.id}');
      }
      return '/tmp/${track.id}.jpg';
    } finally {
      _activeCalls -= 1;
    }
  }
}

class _NoopStore implements ArtworkCacheStore {
  @override
  int get maxCacheSizeBytes => 1024;

  @override
  Future<String?> readPath(ArtworkCacheKey key) async => null;

  @override
  Future<void> writeBytes(ArtworkCacheKey key, Uint8List bytes) async {}
}

class _NoopSource implements ArtworkBytesSource {
  @override
  Future<Uint8List?> fetch({
    required int artworkId,
    required int sizePx,
  }) async {
    return null;
  }
}

class _NoopEmbeddedSource implements EmbeddedArtworkBytesSource {
  @override
  Future<Uint8List?> fetch({required Uri uri, required int sizePx}) async {
    return null;
  }
}
