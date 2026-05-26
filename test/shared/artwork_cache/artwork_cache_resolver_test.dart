import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/shared/artwork_cache/artwork_cache_diagnostics.dart';
import 'package:vanta_music/shared/artwork_cache/artwork_cache_key.dart';
import 'package:vanta_music/shared/artwork_cache/artwork_cache_resolver.dart';
import 'package:vanta_music/shared/artwork_cache/file_artwork_cache_store.dart';

void main() {
  final track = Track(
    id: '42',
    providerId: 'local',
    title: 'Song',
    artist: 'Artist',
    album: 'Album',
    uri: Uri.parse('file:///track.mp3'),
    artworkId: 9,
  );

  test('returns cached path without calling source', () async {
    final store = _FakeStore(readPathValue: '/tmp/cached.jpg');
    final source = _FakeSource(result: Uint8List.fromList([1, 2, 3]));
    final embedded = _FakeEmbeddedSource(result: Uint8List.fromList([4, 5]));
    final resolver = ArtworkCacheResolver(
      store: store,
      source: source,
      embeddedSource: embedded,
    );

    final path = await resolver.resolvePath(track: track, sizePx: 160);

    expect(path, '/tmp/cached.jpg');
    expect(source.calls, 0);
    expect(embedded.calls, 0);
  });

  test('fetches and writes when cache miss', () async {
    final store = _FakeStore(afterWritePath: '/tmp/new.jpg');
    final source = _FakeSource(result: Uint8List.fromList([9, 8, 7]));
    final resolver = ArtworkCacheResolver(
      store: store,
      source: source,
      embeddedSource: _FakeEmbeddedSource(result: null),
    );

    final path = await resolver.resolvePath(track: track, sizePx: 160);

    expect(path, '/tmp/new.jpg');
    expect(source.calls, 1);
    expect(store.writes, 1);
    expect(store.writtenBytes, [9, 8, 7]);
  });

  test('falls back to embedded artwork when track has no artworkId', () async {
    final noArtworkTrack = Track(
      id: '42',
      providerId: 'local',
      title: 'Song',
      artist: 'Artist',
      album: 'Album',
      uri: Uri.parse('file:///track.mp3'),
    );
    final store = _FakeStore(afterWritePath: '/tmp/embedded.jpg');
    final source = _FakeSource(result: Uint8List.fromList([9, 8, 7]));
    final embedded = _FakeEmbeddedSource(result: Uint8List.fromList([5, 6, 7]));
    final resolver = ArtworkCacheResolver(
      store: store,
      source: source,
      embeddedSource: embedded,
    );

    final path = await resolver.resolvePath(track: noArtworkTrack, sizePx: 160);

    expect(path, '/tmp/embedded.jpg');
    expect(source.calls, 0);
    expect(embedded.calls, 1);
    expect(store.writes, 1);
    expect(store.writtenBytes, [5, 6, 7]);
  });

  test('returns typed cached hit outcome without calling sources', () async {
    final store = _FakeStore(readPathValue: '/tmp/cached.jpg');
    final source = _FakeSource(result: Uint8List.fromList([1, 2, 3]));
    final embedded = _FakeEmbeddedSource(result: Uint8List.fromList([4, 5]));
    final resolver = ArtworkCacheResolver(
      store: store,
      source: source,
      embeddedSource: embedded,
    );

    final resolution = await resolver.resolve(track: track, sizePx: 160);

    expect(resolution.key, 'local|42|9|160');
    expect(resolution.path, '/tmp/cached.jpg');
    expect(resolution.hasArtwork, isTrue);
    expect(resolution.isFallback, isFalse);
    expect(source.calls, 0);
    expect(embedded.calls, 0);
  });

  test('memoizes final miss during resolver lifetime', () async {
    final store = _FakeStore();
    final source = _FakeSource(result: null);
    final embedded = _FakeEmbeddedSource(result: null);
    final resolver = ArtworkCacheResolver(
      store: store,
      source: source,
      embeddedSource: embedded,
    );

    final first = await resolver.resolve(track: track, sizePx: 160);
    final second = await resolver.resolve(track: track, sizePx: 160);

    expect(first.key, 'local|42|9|160');
    expect(first.hasArtwork, isFalse);
    expect(second.hasArtwork, isFalse);
    expect(source.calls, 1);
    expect(embedded.calls, 1);
    expect(store.writes, 0);
  });

  test(
    'fetches remote artwork asynchronously and writes sanitized cache key',
    () async {
      final remoteTrack = _remoteTrack(
        coverUri: Uri.parse(
          'https://music.example/rest/getCoverArt.view?id=cover-1&u=alice&s=salt&t=secret-token&c=vanta&f=json',
        ),
      );
      final store = _FakeStore(afterWritePath: '/tmp/remote.jpg');
      final remote = _DelayedRemoteSource(
        result: Uint8List.fromList([7, 7, 7]),
        delay: const Duration(milliseconds: 1),
      );
      final resolver = ArtworkCacheResolver(
        store: store,
        source: _FakeSource(result: null),
        embeddedSource: _FakeEmbeddedSource(result: null),
        remoteSource: remote,
      );

      final pending = resolver.resolve(track: remoteTrack, sizePx: 160);

      expect(store.writes, 0);
      final resolution = await pending;

      expect(resolution.path, '/tmp/remote.jpg');
      expect(remote.calls, 1);
      expect(remote.requestedUris.single.queryParameters['t'], 'secret-token');
      expect(store.writes, 1);
      expect(store.writtenBytes, [7, 7, 7]);
      expect(store.writtenKeys.single.raw, isNot(contains('secret-token')));
      expect(store.writtenKeys.single.raw, isNot(contains('alice')));
      expect(store.writtenKeys.single.raw, contains('subsonic:server-1'));
    },
  );

  test('reuses cached remote artwork without repeated network fetch', () async {
    final remoteTrack = _remoteTrack(
      coverUri: Uri.parse(
        'https://music.example/rest/getCoverArt.view?id=cover-1&t=secret-token',
      ),
    );
    final store = _FakeStore(afterWritePath: '/tmp/remote.jpg');
    final remote = _DelayedRemoteSource(result: Uint8List.fromList([1, 2]));
    final resolver = ArtworkCacheResolver(
      store: store,
      source: _FakeSource(result: null),
      embeddedSource: _FakeEmbeddedSource(result: null),
      remoteSource: remote,
    );

    final first = await resolver.resolvePath(track: remoteTrack, sizePx: 160);
    final second = await resolver.resolvePath(track: remoteTrack, sizePx: 160);

    expect(first, '/tmp/remote.jpg');
    expect(second, '/tmp/remote.jpg');
    expect(remote.calls, 1);
    expect(store.writes, 1);
  });

  test('sanitizes artwork diagnostics before logging auth-bearing urls', () {
    final sanitized = sanitizeArtworkDiagnosticMessage(
      'remote miss uri=https://music.example/rest/getCoverArt.view?id=cover-1&u=alice&s=salt&t=secret-token&password=hunter2&token=plain',
    );

    expect(sanitized, contains('music.example'));
    expect(sanitized, contains('id=cover-1'));
    expect(sanitized, isNot(contains('alice')));
    expect(sanitized, isNot(contains('salt')));
    expect(sanitized, isNot(contains('secret-token')));
    expect(sanitized, isNot(contains('hunter2')));
    expect(sanitized, isNot(contains('plain')));
  });
}

Track _remoteTrack({required Uri coverUri}) {
  return Track(
    id: 'subsonic:server-1:song-1',
    providerId: 'subsonic:server-1',
    title: 'Remote Song',
    artist: 'Remote Artist',
    album: 'Remote Album',
    uri: Uri(
      scheme: 'subsonic',
      host: 'track',
      queryParameters: <String, String>{
        'serverId': 'server-1',
        'id': 'song-1',
        'coverArtUri': coverUri.toString(),
      },
    ),
  );
}

class _FakeStore implements ArtworkCacheStore {
  _FakeStore({this.readPathValue, this.afterWritePath});

  final String? readPathValue;
  final String? afterWritePath;
  int writes = 0;
  List<int>? writtenBytes;
  final List<ArtworkCacheKey> writtenKeys = <ArtworkCacheKey>[];

  @override
  int get maxCacheSizeBytes => 1024;

  @override
  Future<String?> readPath(ArtworkCacheKey key) async {
    if (writes > 0) return afterWritePath;
    return readPathValue;
  }

  @override
  Future<void> writeBytes(ArtworkCacheKey key, Uint8List bytes) async {
    writes += 1;
    writtenKeys.add(key);
    writtenBytes = bytes;
  }
}

class _FakeSource implements ArtworkBytesSource {
  _FakeSource({required this.result});

  final Uint8List? result;
  int calls = 0;

  @override
  Future<Uint8List?> fetch({
    required int artworkId,
    required int sizePx,
  }) async {
    calls += 1;
    return result;
  }
}

class _FakeEmbeddedSource implements EmbeddedArtworkBytesSource {
  _FakeEmbeddedSource({required this.result});

  final Uint8List? result;
  int calls = 0;

  @override
  Future<Uint8List?> fetch({required Uri uri, required int sizePx}) async {
    calls += 1;
    return result;
  }
}

class _DelayedRemoteSource implements RemoteArtworkBytesSource {
  _DelayedRemoteSource({required this.result, this.delay = Duration.zero});

  final Uint8List? result;
  final Duration delay;
  final List<Uri> requestedUris = <Uri>[];

  int get calls => requestedUris.length;

  @override
  Future<Uint8List?> fetch({required Uri uri, required int sizePx}) async {
    requestedUris.add(uri);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return result;
  }
}
