import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/application/library_providers.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/library_intelligence/application/library_intelligence_providers.dart';
import 'package:vanta_music/features/library_intelligence/domain/library_snapshot.dart';

void main() {
  test(
    'maps favorites/recents/most played/continue from snapshot using unified tracks',
    () {
      final tracks = [
        Track(
          id: 'a',
          providerId: 'local',
          title: 'A',
          artist: 'Artist',
          album: 'Album',
          uri: Uri.parse('content://song/a'),
        ),
        Track(
          id: 'b',
          providerId: 'local',
          title: 'B',
          artist: 'Artist',
          album: 'Album',
          uri: Uri.parse('content://song/b'),
        ),
        Track(
          id: 'c',
          providerId: 'folder',
          title: 'C',
          artist: 'Artist',
          album: 'Album',
          uri: Uri.file('/music/c.mp3'),
        ),
      ];

      final snapshot = LibrarySnapshot(
        schemaVersion: 1,
        tracks: {
          'local::a': LibraryTrackSnapshot(
            trackKey: 'local::a',
            playCount: 1,
            lastPlayedAt: DateTime.utc(2026, 1, 1, 10),
            resumePositionMs: 0,
            durationMs: 200000,
            isFavorite: true,
            favoritedAt: DateTime.utc(2026, 1, 1, 10),
            isCompleted: false,
          ),
          'local::b': LibraryTrackSnapshot(
            trackKey: 'local::b',
            playCount: 9,
            lastPlayedAt: DateTime.utc(2026, 1, 1, 12),
            resumePositionMs: 61000,
            durationMs: 180000,
            isFavorite: false,
            favoritedAt: null,
            isCompleted: false,
          ),
          'folder::c': LibraryTrackSnapshot(
            trackKey: 'folder::c',
            playCount: 9,
            lastPlayedAt: DateTime.utc(2026, 1, 1, 11),
            resumePositionMs: 32000,
            durationMs: 190000,
            isFavorite: true,
            favoritedAt: DateTime.utc(2026, 1, 1, 11),
            isCompleted: false,
          ),
          'local::ghost': LibraryTrackSnapshot(
            trackKey: 'local::ghost',
            playCount: 100,
            lastPlayedAt: DateTime.utc(2026, 1, 1, 13),
            resumePositionMs: 45000,
            durationMs: 200000,
            isFavorite: true,
            favoritedAt: DateTime.utc(2026, 1, 1, 13),
            isCompleted: false,
          ),
        },
      );

      final mapping = mapLibraryIntelligence(
        snapshot: snapshot,
        tracks: tracks,
        topN: 50,
      );

      expect(mapping.favorites.map((track) => track.id), ['c', 'a']);
      expect(mapping.recents.map((track) => track.id), ['b', 'c', 'a']);
      expect(mapping.mostPlayed.map((track) => track.id), ['b', 'c', 'a']);
      expect(mapping.continueListening.map((item) => item.track.id), [
        'b',
        'c',
      ]);
      expect(mapping.continueListening.first.resumePositionMs, 61000);
    },
  );

  test(
    'bounds top listened and history lists while filtering ghost tracks',
    () {
      final tracks = List.generate(
        4,
        (index) => Track(
          id: '$index',
          providerId: 'local',
          title: 'Track $index',
          artist: index.isEven ? 'Even Artist' : 'Odd Artist',
          album: index < 2 ? 'First Album' : 'Second Album',
          uri: Uri.parse('content://song/$index'),
          duration: Duration(seconds: 100 + index),
        ),
      );
      final snapshot = LibrarySnapshot(
        schemaVersion: 1,
        tracks: {
          for (final track in tracks)
            'local::${track.id}': LibraryTrackSnapshot(
              trackKey: 'local::${track.id}',
              playCount: int.parse(track.id) + 1,
              lastPlayedAt: DateTime.utc(2026, 1, 1, 10 + int.parse(track.id)),
              resumePositionMs: 0,
              durationMs: track.duration!.inMilliseconds,
              isFavorite: false,
              favoritedAt: null,
              isCompleted: true,
            ),
        },
        history: [
          PlaybackHistoryEntry(
            trackKey: 'local::3',
            listenedAt: DateTime.utc(2026, 1, 1, 13),
            listenedDurationMs: 103000,
            completed: true,
          ),
          PlaybackHistoryEntry(
            trackKey: 'local::ghost',
            listenedAt: DateTime.utc(2026, 1, 1, 14),
            listenedDurationMs: 999000,
            completed: true,
          ),
          PlaybackHistoryEntry(
            trackKey: 'local::2',
            listenedAt: DateTime.utc(2026, 1, 1, 12),
            listenedDurationMs: 102000,
            completed: false,
          ),
        ],
      );

      final mapping = mapLibraryIntelligence(
        snapshot: snapshot,
        tracks: tracks,
        topN: 2,
      );

      expect(mapping.topListened.map((track) => track.id), ['3', '2']);
      expect(mapping.history.map((item) => item.track.id), ['3', '2']);
      expect(mapping.stats.songCount, 4);
      expect(mapping.stats.albumCount, 2);
      expect(mapping.stats.artistCount, 2);
      expect(mapping.stats.totalDurationMs, 406000);
    },
  );

  test(
    'provider bridge composes derived lists and filters stats to existing tracks',
    () async {
      final snapshot = LibrarySnapshot(
        schemaVersion: 1,
        tracks: {
          'local::x': LibraryTrackSnapshot(
            trackKey: 'local::x',
            playCount: 3,
            lastPlayedAt: DateTime.utc(2026, 1, 1, 8),
            resumePositionMs: 0,
            durationMs: 120000,
            isFavorite: true,
            favoritedAt: DateTime.utc(2026, 1, 1, 8),
            isCompleted: true,
          ),
          'local::ghost': LibraryTrackSnapshot(
            trackKey: 'local::ghost',
            playCount: 10,
            lastPlayedAt: DateTime.utc(2026, 1, 1, 9),
            resumePositionMs: 0,
            durationMs: 120000,
            isFavorite: true,
            favoritedAt: DateTime.utc(2026, 1, 1, 9),
            isCompleted: false,
          ),
        },
      );

      final container = ProviderContainer(
        overrides: [
          tracksProvider.overrideWith(
            (ref) async => [
              Track(
                id: 'x',
                providerId: 'local',
                title: 'X',
                artist: 'Artist',
                album: 'Album',
                uri: Uri.parse('content://song/x'),
              ),
            ],
          ),
          libraryIntelligenceSnapshotProvider.overrideWith(
            (ref) async => snapshot,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(tracksProvider.future);
      await container.read(libraryIntelligenceSnapshotProvider.future);

      final favorites = container.read(favoriteTracksProvider);
      final stats = container.read(libraryIntelligenceStatsProvider);

      expect(favorites.map((track) => track.id), ['x']);
      expect(stats.totalTracked, 1);
      expect(stats.favoriteTracks, 1);
      expect(stats.completedTracks, 1);
      expect(stats.totalPlayCount, 3);
    },
  );
}
