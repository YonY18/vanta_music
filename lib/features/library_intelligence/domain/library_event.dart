enum LibraryEventType { playStarted, progressUpdated, playbackCompleted, favoriteToggled }

class LibraryEvent {
  const LibraryEvent._({
    required this.type,
    required this.trackKey,
    required this.timestamp,
    this.positionMs,
    this.durationMs,
    this.isFavorite,
  });

  factory LibraryEvent.playStarted({
    required String trackKey,
    required DateTime timestamp,
  }) =>
      LibraryEvent._(
        type: LibraryEventType.playStarted,
        trackKey: trackKey,
        timestamp: timestamp,
      );

  factory LibraryEvent.progressUpdated({
    required String trackKey,
    required int positionMs,
    required int durationMs,
    required DateTime timestamp,
  }) =>
      LibraryEvent._(
        type: LibraryEventType.progressUpdated,
        trackKey: trackKey,
        positionMs: positionMs,
        durationMs: durationMs,
        timestamp: timestamp,
      );

  factory LibraryEvent.playbackCompleted({
    required String trackKey,
    required DateTime timestamp,
  }) =>
      LibraryEvent._(
        type: LibraryEventType.playbackCompleted,
        trackKey: trackKey,
        timestamp: timestamp,
      );

  factory LibraryEvent.favoriteToggled({
    required String trackKey,
    required bool isFavorite,
    required DateTime timestamp,
  }) =>
      LibraryEvent._(
        type: LibraryEventType.favoriteToggled,
        trackKey: trackKey,
        isFavorite: isFavorite,
        timestamp: timestamp,
      );

  final LibraryEventType type;
  final String trackKey;
  final DateTime timestamp;
  final int? positionMs;
  final int? durationMs;
  final bool? isFavorite;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'trackKey': trackKey,
      'timestamp': timestamp.toIso8601String(),
      'positionMs': positionMs,
      'durationMs': durationMs,
      'isFavorite': isFavorite,
    };
  }

  static LibraryEvent? fromJson(Map<String, dynamic> json) {
    final typeRaw = json['type']?.toString();
    LibraryEventType? type;
    for (final candidate in LibraryEventType.values) {
      if (candidate.name == typeRaw) {
        type = candidate;
        break;
      }
    }
    final trackKey = json['trackKey']?.toString();
    final timestamp = DateTime.tryParse((json['timestamp'] ?? '').toString());
    if (type == null || trackKey == null || trackKey.isEmpty || timestamp == null) {
      return null;
    }

    switch (type) {
      case LibraryEventType.playStarted:
        return LibraryEvent.playStarted(trackKey: trackKey, timestamp: timestamp);
      case LibraryEventType.progressUpdated:
        final positionMs = json['positionMs'];
        final durationMs = json['durationMs'];
        if (positionMs is! int || durationMs is! int) return null;
        return LibraryEvent.progressUpdated(
          trackKey: trackKey,
          positionMs: positionMs,
          durationMs: durationMs,
          timestamp: timestamp,
        );
      case LibraryEventType.playbackCompleted:
        return LibraryEvent.playbackCompleted(trackKey: trackKey, timestamp: timestamp);
      case LibraryEventType.favoriteToggled:
        final isFavorite = json['isFavorite'];
        if (isFavorite is! bool) return null;
        return LibraryEvent.favoriteToggled(
          trackKey: trackKey,
          isFavorite: isFavorite,
          timestamp: timestamp,
        );
    }
  }
}
