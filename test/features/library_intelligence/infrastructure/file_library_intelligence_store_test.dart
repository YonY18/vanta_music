import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vanta_music/features/library_intelligence/domain/library_snapshot.dart';
import 'package:vanta_music/features/library_intelligence/infrastructure/file_library_intelligence_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'library-intelligence-test',
    );
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

  test('saves and loads snapshot roundtrip', () async {
    final store = FileLibraryIntelligenceStore();
    final snapshot = LibrarySnapshot(
      schemaVersion: LibrarySnapshot.currentSchemaVersion,
      tracks: {
        'local::1': LibraryTrackSnapshot(
          trackKey: 'local::1',
          playCount: 3,
          lastPlayedAt: DateTime.utc(2026, 2, 1, 10),
          resumePositionMs: 120000,
          durationMs: 300000,
          isFavorite: true,
          favoritedAt: DateTime.utc(2026, 2, 1, 11),
          isCompleted: false,
          providerId: 'local',
          trackId: '1',
        ),
        'subsonic:server-a::subsonic:server-a:remote-1': LibraryTrackSnapshot(
          trackKey: 'subsonic:server-a::subsonic:server-a:remote-1',
          playCount: 5,
          lastPlayedAt: DateTime.utc(2026, 2, 2, 10),
          resumePositionMs: 64000,
          durationMs: 240000,
          isFavorite: false,
          favoritedAt: null,
          isCompleted: true,
          providerId: 'subsonic:server-a',
          trackId: 'subsonic:server-a:remote-1',
          serverId: 'server-a',
        ),
      },
      history: [
        PlaybackHistoryEntry(
          trackKey: 'subsonic:server-a::subsonic:server-a:remote-1',
          listenedAt: DateTime.utc(2026, 2, 2, 10, 4),
          listenedDurationMs: 64000,
          completed: true,
          providerId: 'subsonic:server-a',
          trackId: 'subsonic:server-a:remote-1',
          serverId: 'server-a',
        ),
      ],
    );

    await store.save(snapshot);
    final loaded = await store.load();

    expect(loaded.tracks['local::1']?.playCount, 3);
    expect(loaded.tracks['local::1']?.isFavorite, isTrue);
    expect(
      loaded
          .tracks['subsonic:server-a::subsonic:server-a:remote-1']
          ?.providerId,
      'subsonic:server-a',
    );
    expect(
      loaded.tracks['subsonic:server-a::subsonic:server-a:remote-1']?.serverId,
      'server-a',
    );
    expect(loaded.history.single.providerId, 'subsonic:server-a');
    expect(loaded.history.single.trackId, 'subsonic:server-a:remote-1');
  });

  test('returns empty snapshot for invalid json', () async {
    final store = FileLibraryIntelligenceStore();
    final file = File(p.join(tempDir.path, 'library_intelligence.json'));
    await file.parent.create(recursive: true);
    await file.writeAsString('{invalid json');

    final loaded = await store.load();

    expect(loaded, isNotNull);
    expect(loaded, const LibrarySnapshot.empty());
  });
}
