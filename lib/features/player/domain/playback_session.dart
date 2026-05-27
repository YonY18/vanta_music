import 'package:audio_service/audio_service.dart';

import '../../providers/domain/provider_identity.dart';

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
    final safeQueue = <({int originalIndex, Map<String, dynamic> json})>[];
    for (var i = 0; i < queue.length; i++) {
      final json = _mediaItemToJson(queue[i]);
      if (json != null) safeQueue.add((originalIndex: i, json: json));
    }
    final safeCurrentIndex = safeQueue.indexWhere(
      (entry) => entry.originalIndex == currentIndex,
    );

    return {
      'queue': safeQueue.map((entry) => entry.json).toList(growable: false),
      'currentIndex': safeCurrentIndex < 0 ? 0 : safeCurrentIndex,
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

  static Map<String, dynamic>? _mediaItemToJson(MediaItem item) {
    final safeId = _safeMediaId(item);
    if (safeId == null) return null;
    return {
      'id': safeId,
      'title': item.title,
      'artist': item.artist,
      'album': item.album,
      'durationMs': item.duration?.inMilliseconds,
      'extras': _safeExtras(item.extras, safeId),
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

  static String? _safeMediaId(MediaItem item) {
    final canonicalUri = item.extras?['canonicalUri']?.toString();
    if (_isRemoteProvider(item.extras)) {
      if (canonicalUri?.isNotEmpty == true &&
          !_isAuthBearingUriString(canonicalUri!)) {
        return canonicalUri;
      }
      if (_isAuthBearingUriString(item.id) ||
          _isAuthBearingUriString(canonicalUri ?? '')) {
        return _syntheticCanonicalUri(item.extras);
      }
    }
    return item.id;
  }

  static String? _syntheticCanonicalUri(Map<String, dynamic>? extras) {
    final providerId = extras?['providerId']?.toString();
    final trackId = extras?['trackId']?.toString();
    if (providerId == null || trackId == null) return null;
    if (!providerId.startsWith('$subsonicProviderPrefix:')) return null;

    final serverId = providerId.substring('$subsonicProviderPrefix:'.length);
    final providerScopedPrefix = '$providerId:';
    final itemId = trackId.startsWith(providerScopedPrefix)
        ? trackId.substring(providerScopedPrefix.length)
        : trackId;
    if (serverId.isEmpty || itemId.isEmpty) return null;

    return Uri(
      scheme: 'subsonic',
      host: 'track',
      queryParameters: {'serverId': serverId, 'id': itemId},
    ).toString();
  }

  static Map<String, dynamic>? _safeExtras(
    Map<String, dynamic>? extras,
    String safeId,
  ) {
    if (extras == null) return null;
    final safe = <String, dynamic>{};
    for (final entry in extras.entries) {
      if (_isSensitiveExtraKey(entry.key)) continue;
      final value = entry.value;
      if (value is Uri && _isAuthBearingUri(value)) continue;
      if (value is String && _isAuthBearingUriString(value)) continue;
      safe[entry.key] = value;
    }
    if (_isRemoteProvider(extras)) {
      safe['canonicalUri'] = safeId;
    }
    return safe;
  }

  static bool _isRemoteProvider(Map<String, dynamic>? extras) {
    final providerId = extras?['providerId']?.toString() ?? '';
    return providerId.isNotEmpty && providerId != 'local';
  }

  static bool _isSensitiveExtraKey(String key) {
    final normalized = key.toLowerCase();
    return normalized.contains('stream') ||
        normalized.contains('token') ||
        normalized.contains('password');
  }

  static bool _isAuthBearingUriString(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && _isAuthBearingUri(uri);
  }

  static bool _isAuthBearingUri(Uri uri) {
    final keys = uri.queryParameters.keys.map((key) => key.toLowerCase());
    return uri.scheme.startsWith('http') &&
        (keys.contains('t') ||
            keys.contains('s') ||
            keys.contains('u') ||
            keys.contains('token') ||
            keys.contains('password'));
  }
}
