import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library_intelligence/application/library_intelligence_reducer.dart';
import 'package:vanta_music/features/library_intelligence/domain/library_event.dart';
import 'package:vanta_music/features/library_intelligence/domain/library_snapshot.dart';

void main() {
  test('orders recents by last played and most played by play count', () {
    final reducer = const LibraryIntelligenceReducer();
    final snapshot = reducer.reduce(const LibrarySnapshot.empty(), [
      LibraryEvent.playStarted(
        trackKey: 'local::a',
        timestamp: DateTime.utc(2026, 1, 1, 10),
      ),
      LibraryEvent.playStarted(
        trackKey: 'local::b',
        timestamp: DateTime.utc(2026, 1, 1, 11),
      ),
      LibraryEvent.playStarted(
        trackKey: 'local::b',
        timestamp: DateTime.utc(2026, 1, 1, 12),
      ),
    ]);

    expect(snapshot.recents.first.trackKey, 'local::b');
    expect(snapshot.mostPlayed.first.trackKey, 'local::b');
    expect(snapshot.mostPlayed.first.playCount, 2);
  });

  test('removes continue listening item after completion', () {
    final reducer = const LibraryIntelligenceReducer();
    final snapshot = reducer.reduce(const LibrarySnapshot.empty(), [
      LibraryEvent.progressUpdated(
        trackKey: 'local::c',
        positionMs: 45000,
        durationMs: 180000,
        timestamp: DateTime.utc(2026, 1, 1, 10),
      ),
      LibraryEvent.playbackCompleted(
        trackKey: 'local::c',
        timestamp: DateTime.utc(2026, 1, 1, 10, 3),
      ),
    ]);

    expect(snapshot.continueListening, isEmpty);
    expect(snapshot.stats.completedTracks, 1);
  });

  test(
    'records bounded playback history for progress and completion events',
    () {
      final reducer = const LibraryIntelligenceReducer();
      final events = List.generate(
        LibraryIntelligenceReducer.historyLimit + 2,
        (index) => LibraryEvent.playbackCompleted(
          trackKey: 'local::$index',
          timestamp: DateTime.utc(2026, 1, 1, 10).add(Duration(minutes: index)),
          listenedDurationMs: 60000 + index,
          durationMs: 180000,
        ),
      );

      final snapshot = reducer.reduce(const LibrarySnapshot.empty(), events);

      expect(
        snapshot.history,
        hasLength(LibraryIntelligenceReducer.historyLimit),
      );
      expect(snapshot.history.first.trackKey, 'local::${events.length - 1}');
      expect(
        snapshot.history.first.listenedDurationMs,
        60000 + events.length - 1,
      );
      expect(snapshot.history.first.completed, true);
    },
  );

  test(
    'preserves remote source identity without colliding with local tracks',
    () {
      final reducer = const LibraryIntelligenceReducer();
      final snapshot = reducer.reduce(const LibrarySnapshot.empty(), [
        LibraryEvent.playStarted(
          trackKey: 'local::shared-id',
          timestamp: DateTime.utc(2026, 1, 1, 10),
        ),
        LibraryEvent.progressUpdated(
          trackKey: 'subsonic:server-a::subsonic:server-a:shared-id',
          positionMs: 45000,
          durationMs: 180000,
          timestamp: DateTime.utc(2026, 1, 1, 11),
        ),
        LibraryEvent.playbackCompleted(
          trackKey: 'subsonic:server-a::subsonic:server-a:shared-id',
          timestamp: DateTime.utc(2026, 1, 1, 11, 3),
          listenedDurationMs: 45000,
          durationMs: 180000,
        ),
      ]);

      final local = snapshot.tracks['local::shared-id'];
      final remote =
          snapshot.tracks['subsonic:server-a::subsonic:server-a:shared-id'];

      expect(snapshot.tracks.length, 2);
      expect(local, isNotNull);
      expect(local!.providerId, 'local');
      expect(local.trackId, 'shared-id');
      expect(local.serverId, isNull);
      expect(remote, isNotNull);
      expect(remote!.providerId, 'subsonic:server-a');
      expect(remote.trackId, 'subsonic:server-a:shared-id');
      expect(remote.serverId, 'server-a');
      expect(snapshot.history.single.providerId, 'subsonic:server-a');
      expect(snapshot.history.single.serverId, 'server-a');
      expect(snapshot.history.single.trackId, 'subsonic:server-a:shared-id');
    },
  );
}
