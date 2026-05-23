import '../../library_intelligence/application/library_intelligence_controller.dart';
import '../domain/track.dart';

List<bool> mapTrackFavoriteFlags({
  required List<Track> tracks,
  required Set<String> favoriteTrackKeys,
}) {
  return tracks
      .map((track) => favoriteTrackKeys.contains(stableTrackKey(track)))
      .toList(growable: false);
}
