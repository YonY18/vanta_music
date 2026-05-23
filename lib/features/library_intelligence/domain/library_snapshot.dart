class LibrarySnapshot {
  static const int currentSchemaVersion = 1;

  const LibrarySnapshot({
    required this.schemaVersion,
    required this.tracks,
  });

  const LibrarySnapshot.empty()
      : schemaVersion = currentSchemaVersion,
        tracks = const {};

  final int schemaVersion;
  final Map<String, LibraryTrackSnapshot> tracks;

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
      tracks.values.where((item) => !item.isCompleted && item.resumePositionMs > 0).toList(growable: false)
        ..sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));

  LibraryStatsSnapshot get stats {
    final values = tracks.values;
    final completed = values.where((item) => item.isCompleted).length;
    return LibraryStatsSnapshot(
      totalTracked: values.length,
      favoriteTracks: values.where((item) => item.isFavorite).length,
      completedTracks: completed,
      totalPlayCount: values.fold(0, (sum, item) => sum + item.playCount),
    );
  }

  LibrarySnapshot copyWith({
    int? schemaVersion,
    Map<String, LibraryTrackSnapshot>? tracks,
  }) {
    return LibrarySnapshot(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      tracks: tracks ?? this.tracks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'tracks': tracks.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  static LibrarySnapshot fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    final rawTracks = json['tracks'];
    if (schemaVersion is! int || rawTracks is! Map) return const LibrarySnapshot.empty();

    final tracks = <String, LibraryTrackSnapshot>{};
    for (final entry in rawTracks.entries) {
      final trackKey = entry.key.toString();
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      final parsed = LibraryTrackSnapshot.fromJson(value);
      if (parsed == null) continue;
      tracks[trackKey] = parsed;
    }

    return LibrarySnapshot(schemaVersion: schemaVersion, tracks: Map.unmodifiable(tracks));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LibrarySnapshot) return false;
    if (schemaVersion != other.schemaVersion) return false;
    if (tracks.length != other.tracks.length) return false;
    for (final entry in tracks.entries) {
      if (other.tracks[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(schemaVersion, Object.hashAll(tracks.entries));
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
  });

  final String trackKey;
  final int playCount;
  final DateTime lastPlayedAt;
  final int resumePositionMs;
  final int durationMs;
  final bool isFavorite;
  final DateTime? favoritedAt;
  final bool isCompleted;

  static const Object _keepFavoritedAt = Object();

  LibraryTrackSnapshot copyWith({
    int? playCount,
    DateTime? lastPlayedAt,
    int? resumePositionMs,
    int? durationMs,
    bool? isFavorite,
    Object? favoritedAt = _keepFavoritedAt,
    bool? isCompleted,
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
    };
  }

  static LibraryTrackSnapshot? fromJson(Map<String, dynamic> json) {
    final trackKey = json['trackKey']?.toString();
    final playCount = json['playCount'];
    final lastPlayedAt = DateTime.tryParse((json['lastPlayedAt'] ?? '').toString());
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
        other.isCompleted == isCompleted;
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
      );
}

class LibraryStatsSnapshot {
  const LibraryStatsSnapshot({
    required this.totalTracked,
    required this.favoriteTracks,
    required this.completedTracks,
    required this.totalPlayCount,
  });

  final int totalTracked;
  final int favoriteTracks;
  final int completedTracks;
  final int totalPlayCount;
}
