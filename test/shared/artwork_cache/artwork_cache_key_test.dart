import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/shared/artwork_cache/artwork_cache_key.dart';

void main() {
  test('builds stable key including provider track artwork and size', () {
    final key = buildArtworkCacheKey(
      providerId: 'local',
      trackId: '42',
      artworkId: 9,
      sizePx: 160,
    );

    expect(key.raw, 'local|42|9|160');
  });

  test('filename is filesystem-safe and stable', () {
    final key = buildArtworkCacheKey(
      providerId: 'folder/provider',
      trackId: 'track:1',
      artworkId: 9,
      sizePx: 160,
    );

    final fileNameA = artworkCacheFileName(key);
    final fileNameB = artworkCacheFileName(key);
    expect(fileNameA, fileNameB);
    expect(fileNameA, endsWith('.jpg'));
    expect(fileNameA, matches(RegExp(r'^[a-zA-Z0-9._-]+$')));
    expect(fileNameA.length, lessThanOrEqualTo(64));
  });

  test('different size produces a different cache filename', () {
    final base = buildArtworkCacheKey(
      providerId: 'local',
      trackId: '42',
      artworkId: 9,
      sizePx: 56,
    );
    final bigger = buildArtworkCacheKey(
      providerId: 'local',
      trackId: '42',
      artworkId: 9,
      sizePx: 160,
    );

    expect(artworkCacheFileName(base), isNot(artworkCacheFileName(bigger)));
  });

  test('builds fallback key when artworkId is missing for file tracks', () {
    final key = buildArtworkCacheKey(
      providerId: 'folder',
      trackId: 'folder:/music/song.mp3',
      artworkId: null,
      sizePx: 160,
      sourceUri: 'file:///music/song.mp3',
    );

    expect(
      key.raw,
      'folder|folder:/music/song.mp3|src:file:///music/song.mp3|160',
    );
  });

  test('filename remains short for long file track URIs', () {
    final key = buildArtworkCacheKey(
      providerId: 'folder',
      trackId:
          'folder:/storage/emulated/0/Music/Musicas/${'very-long-' * 30}.flac',
      artworkId: null,
      sizePx: 160,
      sourceUri:
          'file:///storage/emulated/0/Music/Musicas/${'very-long-' * 30}.flac',
    );

    final fileName = artworkCacheFileName(key);

    expect(fileName, startsWith('artwork_'));
    expect(fileName, endsWith('.jpg'));
    expect(fileName.length, lessThanOrEqualTo(64));
  });

  test(
    'builds server-scoped remote artwork key from server and cover art ids',
    () {
      final key = buildArtworkCacheKey(
        providerId: 'subsonic:server-a',
        trackId: 'song-1',
        artworkId: null,
        sizePx: 160,
        serverId: 'server-a',
        coverArtId: 'cover-42',
      );

      expect(key.raw, 'subsonic|server-a|cover-42|160');
    },
  );
}
