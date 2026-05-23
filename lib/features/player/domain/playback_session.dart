import 'package:audio_service/audio_service.dart';

class PlaybackSession {
  const PlaybackSession({
    required this.queue,
    required this.currentIndex,
    required this.position,
    this.savedAt,
  });

  final List<MediaItem> queue;
  final int currentIndex;
  final Duration position;
  final DateTime? savedAt;

  Map<String, dynamic> toJson() {
    return {
      'queue': queue.map(_mediaItemToJson).toList(growable: false),
      'currentIndex': currentIndex,
      'positionMs': position.inMilliseconds,
      'savedAt': (savedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  static PlaybackSession? fromJson(Map<String, dynamic> json) {
    final rawQueue = json['queue'];
    final index = json['currentIndex'];
    final positionMs = json['positionMs'];
    if (rawQueue is! List || index is! int || positionMs is! int) return null;

    final queue = rawQueue
        .whereType<Map<String, dynamic>>()
        .map(_mediaItemFromJson)
        .whereType<MediaItem>()
        .toList(growable: false);
    if (queue.isEmpty || index < 0 || index >= queue.length) return null;

    return PlaybackSession(
      queue: queue,
      currentIndex: index,
      position: Duration(milliseconds: positionMs),
      savedAt: DateTime.tryParse((json['savedAt'] ?? '').toString()),
    );
  }

  static Map<String, dynamic> _mediaItemToJson(MediaItem item) {
    return {
      'id': item.id,
      'title': item.title,
      'artist': item.artist,
      'album': item.album,
      'durationMs': item.duration?.inMilliseconds,
      'extras': item.extras,
    };
  }

  static MediaItem? _mediaItemFromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final title = json['title']?.toString();
    if (id == null || id.isEmpty || title == null || title.isEmpty) return null;
    final durationMs = json['durationMs'];

    return MediaItem(
      id: id,
      title: title,
      artist: json['artist']?.toString(),
      album: json['album']?.toString(),
      duration: durationMs is int ? Duration(milliseconds: durationMs) : null,
      extras: json['extras'] is Map
          ? Map<String, dynamic>.from(json['extras'] as Map)
          : null,
    );
  }
}
