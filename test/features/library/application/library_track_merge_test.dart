import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/application/file_validation_cache.dart';
import 'package:vanta_music/features/library/application/library_track_merge.dart';
import 'package:vanta_music/features/library/domain/track.dart';

void main() {
  test('dedupes same uri from folder and media store', () async {
    final file = File('${Directory.systemTemp.path}/song_merge_test.mp3')
      ..writeAsStringSync('x');
    final uri = file.uri;
    final tracks = [
      Track(
        id: 'a',
        providerId: 'folder',
        title: 'Song',
        artist: 'A',
        album: 'X',
        uri: uri,
      ),
      Track(
        id: 'b',
        providerId: 'local',
        title: 'Song',
        artist: 'A',
        album: 'X',
        uri: uri,
      ),
    ];

    final cache = InMemoryFileValidationCache();
    await cache.validate(uri);
    final merged = await mergeAndCleanTracks(tracks, cache: cache);

    expect(merged.length, 1);
  });

  test('filters stale missing file track', () async {
    final tempDir = await Directory.systemTemp.createTemp('vanta-test');
    final existing = File('${tempDir.path}/ok.mp3')..writeAsStringSync('x');
    final missing = Uri.file('${tempDir.path}/missing.mp3');

    final cache = InMemoryFileValidationCache();
    await cache.validate(existing.uri);
    final merged = await mergeAndCleanTracks([
      Track(
        id: '1',
        providerId: 'folder',
        title: 'Ok',
        artist: 'A',
        album: 'X',
        uri: existing.uri,
      ),
      Track(
        id: '2',
        providerId: 'folder',
        title: 'Missing',
        artist: 'A',
        album: 'X',
        uri: missing,
      ),
    ], cache: cache);

    expect(merged.length, 1);
    expect(merged.single.id, '1');
  });
}
