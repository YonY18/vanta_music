import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library_intelligence/domain/library_event.dart';
import 'package:vanta_music/features/library_intelligence/domain/library_snapshot.dart';

void main() {
  group('LibrarySnapshot history JSON', () {
    test('decodes old snapshots without history using safe defaults', () {
      final snapshot = LibrarySnapshot.fromJson({
        'schemaVersion': 1,
        'tracks': {
          'local::legacy': {
            'trackKey': 'local::legacy',
            'playCount': 2,
            'lastPlayedAt': '2026-01-01T10:00:00.000Z',
            'resumePositionMs': 45000,
            'durationMs': 180000,
            'isFavorite': false,
            'isCompleted': false,
          },
        },
      });

      expect(snapshot.history, isEmpty);
      expect(snapshot.tracks['local::legacy']?.playCount, 2);
    });

    test(
      'writes and reads playback history listened duration and completion',
      () {
        final entry = PlaybackHistoryEntry(
          trackKey: 'local::song',
          listenedAt: DateTime.utc(2026, 1, 2, 12),
          listenedDurationMs: 123000,
          completed: true,
        );
        final snapshot = LibrarySnapshot(
          schemaVersion: 1,
          tracks: const {},
          history: [entry],
        );

        final json = snapshot.toJson();
        final historyJson =
            (json['history'] as List).single as Map<String, dynamic>;

        expect(historyJson['listenedDurationMs'], 123000);
        expect(historyJson['completed'], true);
        expect(LibrarySnapshot.fromJson(json).history, [entry]);
      },
    );
  });

  group('LibraryEvent history fields', () {
    test('serializes completion listened duration for history reducers', () {
      final event = LibraryEvent.playbackCompleted(
        trackKey: 'local::song',
        timestamp: DateTime.utc(2026, 1, 2, 12),
        listenedDurationMs: 123000,
        durationMs: 180000,
      );

      expect(event.listenedDurationMs, 123000);
      expect(event.completed, true);
      expect(LibraryEvent.fromJson(event.toJson())?.listenedDurationMs, 123000);
    });
  });
}
