import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vanta_music/features/playlists/infrastructure/local_playlist_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('playlist-store-test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationSupportDirectory') {
            return tempDir.path;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'loads backward-compatible playlist json without optional fields',
    () async {
      final store = LocalPlaylistStore();
      final file = File(p.join(tempDir.path, 'playlists.json'));
      await file.writeAsString('''
[
  {
    "id": "p1",
    "name": "Road",
    "tracks": [
      {
        "id": "t1",
        "providerId": "local",
        "title": "Song",
        "artist": "Artist",
        "album": "Album",
        "uri": "/song.mp3"
      }
    ]
  }
]
''');

      final playlists = await store.getPlaylists();

      expect(playlists.map((playlist) => playlist.id), ['p1']);
      expect(playlists.single.name, 'Road');
      expect(playlists.single.tracks.map((track) => track.id), ['t1']);
    },
  );

  test('returns an empty list for malformed playlist json', () async {
    final store = LocalPlaylistStore();
    final file = File(p.join(tempDir.path, 'playlists.json'));
    await file.writeAsString('{invalid json');

    final playlists = await store.getPlaylists();

    expect(playlists, isEmpty);
  });

  test(
    'skips malformed playlists and tracks while keeping valid entries',
    () async {
      final store = LocalPlaylistStore();
      final file = File(p.join(tempDir.path, 'playlists.json'));
      await file.writeAsString('''
[
  {"id": "", "name": "Broken"},
  {
    "id": "p1",
    "name": "Road",
    "tracks": [
      {"id": "broken", "providerId": "local"},
      {
        "id": "t1",
        "providerId": "local",
        "title": "Song",
        "artist": "Artist",
        "album": "Album",
        "uri": "/song.mp3"
      }
    ]
  }
]
''');

      final playlists = await store.getPlaylists();

      expect(playlists.map((playlist) => playlist.id), ['p1']);
      expect(playlists.single.tracks.map((track) => track.id), ['t1']);
    },
  );
}
