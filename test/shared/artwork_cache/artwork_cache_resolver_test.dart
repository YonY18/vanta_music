import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/domain/track.dart';
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
}

class _FakeStore implements ArtworkCacheStore {
  _FakeStore({this.readPathValue, this.afterWritePath});

  final String? readPathValue;
  final String? afterWritePath;
  int writes = 0;
  List<int>? writtenBytes;

  @override
  Future<String?> readPath(ArtworkCacheKey key) async {
    if (writes > 0) return afterWritePath;
    return readPathValue;
  }

  @override
  Future<void> writeBytes(ArtworkCacheKey key, Uint8List bytes) async {
    writes += 1;
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
