class LibrarySnapshot {
  static const int currentSchemaVersion = 1;

  const LibrarySnapshot({
    required this.schemaVersion,
    required this.tracks,
    this.history = const [],
  });

  const LibrarySnapshot.empty()
    : schemaVersion = currentSchemaVersion,
      tracks = const {},
      history = const [];

  final int schemaVersion;
  final Map<String, LibraryTrackSnapshot> tracks;
  final List<PlaybackHistoryEntry> history;

  List<LibraryTrackSnapshot> get recents {
    final values = tracks.values.toList(growable: false);
    values.sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));
    return values;
  }

  List<LibraryTrackSnapshot> get mostPlayed {
    final values = tracks.values.toList(growable: false);
    values.sort((a, b) {
      final byPlays = b.playCount.compareTo(a.playCount);
      if (byPlays != 0) return byPlays;
      return b.lastPlayedAt.compareTo(a.lastPlayedAt);
    });
    return values;
  }

  List<LibraryTrackSnapshot> get continueListening =>
      tracks.values
          .where((item) => !item.isCompleted && item.resumePositionMs > 0)
          .toList(growable: false)
        ..sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));

  LibraryStatsSnapshot get stats {
    final values = tracks.values;
    final completed = values.where((item) => item.isCompleted).length;
    return LibraryStatsSnapshot(
      totalTracked: values.length,
      favoriteTracks: values.where((item) => item.isFavorite).length,
      completedTracks: completed,
      totalPlayCount: values.fold(0, (sum, item) => sum + item.playCount),
      songCount: values.length,
      albumCount: 0,
      artistCount: 0,
      totalDurationMs: values.fold(0, (sum, item) => sum + item.durationMs),
    );
  }

  LibrarySnapshot copyWith({
    int? schemaVersion,
    Map<String, LibraryTrackSnapshot>? tracks,
    List<PlaybackHistoryEntry>? history,
  }) {
    return LibrarySnapshot(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      tracks: tracks ?? this.tracks,
      history: history ?? this.history,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'tracks': tracks.map((key, value) => MapEntry(key, value.toJson())),
      'history': history.map((entry) => entry.toJson()).toList(growable: false),
    };
  }

  static LibrarySnapshot fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    final rawTracks = json['tracks'];
    if (schemaVersion is! int || rawTracks is! Map) {
      return const LibrarySnapshot.empty();
    }

    final tracks = <String, LibraryTrackSnapshot>{};
    for (final entry in rawTracks.entries) {
      final trackKey = entry.key.toString();
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      final parsed = LibraryTrackSnapshot.fromJson(value);
      if (parsed == null) continue;
      tracks[trackKey] = parsed;
    }

    final history = <PlaybackHistoryEntry>[];
    final rawHistory = json['history'];
    if (rawHistory is List) {
      for (final value in rawHistory) {
        if (value is! Map<String, dynamic>) continue;
        final parsed = PlaybackHistoryEntry.fromJson(value);
        if (parsed == null) continue;
        history.add(parsed);
      }
    }

    return LibrarySnapshot(
      schemaVersion: schemaVersion,
      tracks: Map.unmodifiable(tracks),
      history: List.unmodifiable(history),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LibrarySnapshot) return false;
    if (schemaVersion != other.schemaVersion) return false;
    if (tracks.length != other.tracks.length) return false;
    if (history.length != other.history.length) return false;
    for (final entry in tracks.entries) {
      if (other.tracks[entry.key] != entry.value) return false;
    }
    for (var index = 0; index < history.length; index += 1) {
      if (other.history[index] != history[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    Object.hashAll(tracks.entries),
    Object.hashAll(history),
  );
}

class LibrarySourceIdentity {
  const LibrarySourceIdentity({
    required this.providerId,
    required this.trackId,
    this.serverId,
  });

  final String providerId;
  final String trackId;
  final String? serverId;
}

LibrarySourceIdentity? parseLibrarySourceIdentity(String trackKey) {
  final separatorIndex = trackKey.indexOf('::');
  if (separatorIndex <= 0 || separatorIndex >= trackKey.length - 2) {
    return null;
  }

  final providerId = trackKey.substring(0, separatorIndex);
  final trackId = trackKey.substring(separatorIndex + 2);
  if (providerId.isEmpty || trackId.isEmpty) return null;

  const remotePrefix = 'subsonic:';
  final serverId = providerId.startsWith(remotePrefix)
      ? providerId.substring(remotePrefix.length)
      : null;

  return LibrarySourceIdentity(
    providerId: providerId,
    trackId: trackId,
    serverId: serverId == null || serverId.isEmpty ? null : serverId,
  );
}

class PlaybackHistoryEntry {
  const PlaybackHistoryEntry({
    required this.trackKey,
    required this.listenedAt,
    required this.listenedDurationMs,
    required this.completed,
    this.providerId,
    this.trackId,
    this.serverId,
  });

  final String trackKey;
  final DateTime listenedAt;
  final int listenedDurationMs;
  final bool completed;
  final String? providerId;
  final String? trackId;
  final String? serverId;

  Map<String, dynamic> toJson() {
    return {
      'trackKey': trackKey,
      'listenedAt': listenedAt.toIso8601String(),
      'listenedDurationMs': listenedDurationMs,
      'completed': completed,
      'providerId': providerId,
      'trackId': trackId,
      'serverId': serverId,
    };
  }

  static PlaybackHistoryEntry? fromJson(Map<String, dynamic> json) {
    final trackKey = json['trackKey']?.toString();
    final listenedAt = DateTime.tryParse((json['listenedAt'] ?? '').toString());
    final listenedDurationMs = json['listenedDurationMs'];
    final completed = json['completed'];
    if (trackKey == null ||
        trackKey.isEmpty ||
        listenedAt == null ||
        listenedDurationMs is! int ||
        completed is! bool) {
      return null;
    }

    return PlaybackHistoryEntry(
      trackKey: trackKey,
      listenedAt: listenedAt,
      listenedDurationMs: listenedDurationMs,
      completed: completed,
      providerId: json['providerId']?.toString(),
      trackId: json['trackId']?.toString(),
      serverId: json['serverId']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PlaybackHistoryEntry &&
        other.trackKey == trackKey &&
        other.listenedAt == listenedAt &&
        other.listenedDurationMs == listenedDurationMs &&
        other.completed == completed &&
        other.providerId == providerId &&
        other.trackId == trackId &&
        other.serverId == serverId;
  }

  @override
  int get hashCode => Object.hash(
    trackKey,
    listenedAt,
    listenedDurationMs,
    completed,
    providerId,
    trackId,
    serverId,
  );
}

class LibraryTrackSnapshot {
  const LibraryTrackSnapshot({
    required this.trackKey,
    required this.playCount,
    required this.lastPlayedAt,
    required this.resumePositionMs,
    required this.durationMs,
    required this.isFavorite,
    required this.favoritedAt,
    required this.isCompleted,
    this.providerId,
    this.trackId,
    this.serverId,
  });

  final String trackKey;
  final int playCount;
  final DateTime lastPlayedAt;
  final int resumePositionMs;
  final int durationMs;
  final bool isFavorite;
  final DateTime? favoritedAt;
  final bool isCompleted;
  final String? providerId;
  final String? trackId;
  final String? serverId;

  static const Object _keepFavoritedAt = Object();

  LibraryTrackSnapshot copyWith({
    int? playCount,
    DateTime? lastPlayedAt,
    int? resumePositionMs,
    int? durationMs,
    bool? isFavorite,
    Object? favoritedAt = _keepFavoritedAt,
    bool? isCompleted,
    Object? providerId = _keepFavoritedAt,
    Object? trackId = _keepFavoritedAt,
    Object? serverId = _keepFavoritedAt,
  }) {
    return LibraryTrackSnapshot(
      trackKey: trackKey,
      playCount: playCount ?? this.playCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      resumePositionMs: resumePositionMs ?? this.resumePositionMs,
      durationMs: durationMs ?? this.durationMs,
      isFavorite: isFavorite ?? this.isFavorite,
      favoritedAt: identical(favoritedAt, _keepFavoritedAt)
          ? this.favoritedAt
          : favoritedAt as DateTime?,
      isCompleted: isCompleted ?? this.isCompleted,
      providerId: identical(providerId, _keepFavoritedAt)
          ? this.providerId
          : providerId as String?,
      trackId: identical(trackId, _keepFavoritedAt)
          ? this.trackId
          : trackId as String?,
      serverId: identical(serverId, _keepFavoritedAt)
          ? this.serverId
          : serverId as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trackKey': trackKey,
      'playCount': playCount,
      'lastPlayedAt': lastPlayedAt.toIso8601String(),
      'resumePositionMs': resumePositionMs,
      'durationMs': durationMs,
      'isFavorite': isFavorite,
      'favoritedAt': favoritedAt?.toIso8601String(),
      'isCompleted': isCompleted,
      'providerId': providerId,
      'trackId': trackId,
      'serverId': serverId,
    };
  }

  static LibraryTrackSnapshot? fromJson(Map<String, dynamic> json) {
    final trackKey = json['trackKey']?.toString();
    final playCount = json['playCount'];
    final lastPlayedAt = DateTime.tryParse(
      (json['lastPlayedAt'] ?? '').toString(),
    );
    final resumePositionMs = json['resumePositionMs'];
    final durationMs = json['durationMs'];
    final isFavorite = json['isFavorite'];
    final isCompleted = json['isCompleted'];
    if (trackKey == null ||
        trackKey.isEmpty ||
        playCount is! int ||
        lastPlayedAt == null ||
        resumePositionMs is! int ||
        durationMs is! int ||
        isFavorite is! bool ||
        isCompleted is! bool) {
      return null;
    }

    return LibraryTrackSnapshot(
      trackKey: trackKey,
      playCount: playCount,
      lastPlayedAt: lastPlayedAt,
      resumePositionMs: resumePositionMs,
      durationMs: durationMs,
      isFavorite: isFavorite,
      favoritedAt: DateTime.tryParse((json['favoritedAt'] ?? '').toString()),
      isCompleted: isCompleted,
      providerId: json['providerId']?.toString(),
      trackId: json['trackId']?.toString(),
      serverId: json['serverId']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LibraryTrackSnapshot &&
        other.trackKey == trackKey &&
        other.playCount == playCount &&
        other.lastPlayedAt == lastPlayedAt &&
        other.resumePositionMs == resumePositionMs &&
        other.durationMs == durationMs &&
        other.isFavorite == isFavorite &&
        other.favoritedAt == favoritedAt &&
        other.isCompleted == isCompleted &&
        other.providerId == providerId &&
        other.trackId == trackId &&
        other.serverId == serverId;
  }

  @override
  int get hashCode => Object.hash(
    trackKey,
    playCount,
    lastPlayedAt,
    resumePositionMs,
    durationMs,
    isFavorite,
    favoritedAt,
    isCompleted,
    providerId,
    trackId,
    serverId,
  );
}

class LibraryStatsSnapshot {
  const LibraryStatsSnapshot({
    required this.totalTracked,
    required this.favoriteTracks,
    required this.completedTracks,
    required this.totalPlayCount,
    this.songCount = 0,
    this.albumCount = 0,
    this.artistCount = 0,
    this.totalDurationMs = 0,
  });

  final int totalTracked;
  final int favoriteTracks;
  final int completedTracks;
  final int totalPlayCount;
  final int songCount;
  final int albumCount;
  final int artistCount;
  final int totalDurationMs;
}
