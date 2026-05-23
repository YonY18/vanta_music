import '../domain/track.dart';

List<Track> filterTracksForQuery(List<Track> tracks, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return tracks;
  }

  return tracks.where((track) {
    return track.title.toLowerCase().contains(normalized) ||
        track.artist.toLowerCase().contains(normalized) ||
        track.album.toLowerCase().contains(normalized);
  }).toList(growable: false);
}
