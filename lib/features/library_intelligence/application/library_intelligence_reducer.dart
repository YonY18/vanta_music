import '../domain/library_event.dart';
import '../domain/library_snapshot.dart';

class LibraryIntelligenceReducer {
  const LibraryIntelligenceReducer();

  static const int continueListeningMinPositionMs = 15000;
  static const int historyLimit = 100;

  LibrarySnapshot reduce(LibrarySnapshot previous, List<LibraryEvent> events) {
    final tracks = Map<String, LibraryTrackSnapshot>.from(previous.tracks);
    final history = List<PlaybackHistoryEntry>.from(previous.history);

    for (final event in events) {
      final identity = parseLibrarySourceIdentity(event.trackKey);
      final providerId = identity?.providerId;
      final trackId = identity?.trackId;
      final serverId = identity?.serverId;
      final current =
          tracks[event.trackKey] ??
          LibraryTrackSnapshot(
            trackKey: event.trackKey,
            playCount: 0,
            lastPlayedAt: event.timestamp,
            resumePositionMs: 0,
            durationMs: 0,
            isFavorite: false,
            favoritedAt: null,
            isCompleted: false,
            providerId: identity?.providerId,
            trackId: identity?.trackId,
            serverId: identity?.serverId,
          );

      switch (event.type) {
        case LibraryEventType.playStarted:
          tracks[event.trackKey] = current.copyWith(
            playCount: current.playCount + 1,
            lastPlayedAt: event.timestamp,
            providerId: current.providerId ?? providerId,
            trackId: current.trackId ?? trackId,
            serverId: current.serverId ?? serverId,
          );
        case LibraryEventType.progressUpdated:
          final positionMs = event.positionMs ?? 0;
          final durationMs = event.durationMs ?? current.durationMs;
          tracks[event.trackKey] = current.copyWith(
            lastPlayedAt: event.timestamp,
            durationMs: durationMs,
            resumePositionMs: positionMs >= continueListeningMinPositionMs
                ? positionMs
                : 0,
            isCompleted: false,
            providerId: current.providerId ?? providerId,
            trackId: current.trackId ?? trackId,
            serverId: current.serverId ?? serverId,
          );
        case LibraryEventType.playbackCompleted:
          final listenedDurationMs =
              event.listenedDurationMs ?? current.resumePositionMs;
          final durationMs = event.durationMs ?? current.durationMs;
          tracks[event.trackKey] = current.copyWith(
            lastPlayedAt: event.timestamp,
            durationMs: durationMs,
            resumePositionMs: 0,
            isCompleted: true,
            providerId: current.providerId ?? providerId,
            trackId: current.trackId ?? trackId,
            serverId: current.serverId ?? serverId,
          );
          history.insert(
            0,
            PlaybackHistoryEntry(
              trackKey: event.trackKey,
              listenedAt: event.timestamp,
              listenedDurationMs: listenedDurationMs,
              completed: event.completed ?? true,
              providerId: current.providerId ?? providerId,
              trackId: current.trackId ?? trackId,
              serverId: current.serverId ?? serverId,
            ),
          );
        case LibraryEventType.favoriteToggled:
          tracks[event.trackKey] = current.copyWith(
            isFavorite: event.isFavorite ?? false,
            favoritedAt: (event.isFavorite ?? false) ? event.timestamp : null,
            lastPlayedAt: event.timestamp,
            providerId: current.providerId ?? providerId,
            trackId: current.trackId ?? trackId,
            serverId: current.serverId ?? serverId,
          );
      }
    }

    return previous.copyWith(
      tracks: Map.unmodifiable(tracks),
      history: List.unmodifiable(history.take(historyLimit)),
    );
  }
}
