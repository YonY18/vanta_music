import 'package:audio_service/audio_service.dart';

import '../../../shared/artwork_cache/artwork_cache_providers.dart';
import '../../library/domain/track.dart';

TrackArtworkRequest? trackArtworkRequestFromMediaItem({
  required MediaItem item,
  required int sizePx,
}) {
  final providerId = item.extras?['providerId']?.toString();
  final trackIdFromExtras = item.extras?['trackId']?.toString();
  final trackId = _asTrackIdFromUri(trackIdFromExtras, item.id);
  final artworkId = _asArtworkId(item.extras?['artworkId']);

  if (providerId == null || providerId.isEmpty || trackId == null) {
    return null;
  }

  final uri = _safeUri(item.id);
  if (uri == null) return null;

  final track = Track(
    id: trackId,
    providerId: providerId,
    title: item.title,
    artist: item.artist ?? 'Desconocido',
    album: item.album ?? 'Álbum desconocido',
    uri: uri,
    duration: item.duration,
    artworkId: artworkId,
  );

  return TrackArtworkRequest(track: track, sizePx: sizePx);
}

String? _asTrackIdFromUri(String? trackIdFromExtras, String itemId) {
  if (trackIdFromExtras != null && trackIdFromExtras.isNotEmpty) return trackIdFromExtras;
  return itemId.isEmpty ? null : itemId;
}

int? _asArtworkId(Object? artworkId) {
  if (artworkId is int) return artworkId;
  if (artworkId is String) return int.tryParse(artworkId);
  return null;
}

Uri? _safeUri(String value) {
  if (value.isEmpty) return null;
  return Uri.tryParse(value);
}
