import '../domain/library_event.dart';
import '../domain/library_snapshot.dart';

class LibraryIntelligenceReducer {
  const LibraryIntelligenceReducer();

  static const int continueListeningMinPositionMs = 15000;

  LibrarySnapshot reduce(LibrarySnapshot previous, List<LibraryEvent> events) {
    final tracks = Map<String, LibraryTrackSnapshot>.from(previous.tracks);

    for (final event in events) {
      final current = tracks[event.trackKey] ??
          LibraryTrackSnapshot(
            trackKey: event.trackKey,
            playCount: 0,
            lastPlayedAt: event.timestamp,
            resumePositionMs: 0,
            durationMs: 0,
            isFavorite: false,
            favoritedAt: null,
            isCompleted: false,
          );

      switch (event.type) {
        case LibraryEventType.playStarted:
          tracks[event.trackKey] = current.copyWith(
            playCount: current.playCount + 1,
            lastPlayedAt: event.timestamp,
          );
        case LibraryEventType.progressUpdated:
          final positionMs = event.positionMs ?? 0;
          final durationMs = event.durationMs ?? current.durationMs;
          tracks[event.trackKey] = current.copyWith(
            lastPlayedAt: event.timestamp,
            durationMs: durationMs,
            resumePositionMs: positionMs >= continueListeningMinPositionMs ? positionMs : 0,
            isCompleted: false,
          );
        case LibraryEventType.playbackCompleted:
          tracks[event.trackKey] = current.copyWith(
            lastPlayedAt: event.timestamp,
            resumePositionMs: 0,
            isCompleted: true,
          );
        case LibraryEventType.favoriteToggled:
          tracks[event.trackKey] = current.copyWith(
            isFavorite: event.isFavorite ?? false,
            favoritedAt: (event.isFavorite ?? false) ? event.timestamp : null,
            lastPlayedAt: event.timestamp,
          );
      }
    }

    return previous.copyWith(tracks: Map.unmodifiable(tracks));
  }
}
