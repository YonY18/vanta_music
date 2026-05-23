import '../../library/domain/track.dart';
import '../domain/library_event.dart';
import 'library_intelligence_reducer.dart';
import 'library_intelligence_store.dart';

typedef IntelligenceNow = DateTime Function();

class LibraryIntelligenceController {
  LibraryIntelligenceController({
    required LibraryIntelligenceStore store,
    required LibraryIntelligenceReducer reducer,
    IntelligenceNow? now,
  }) : _store = store,
       _reducer = reducer,
       _now = now ?? DateTime.now;

  final LibraryIntelligenceStore _store;
  final LibraryIntelligenceReducer _reducer;
  final IntelligenceNow _now;

  Future<bool> toggleFavorite({required String trackKey}) async {
    final snapshot = await _store.load();
    final current = snapshot.tracks[trackKey];
    final nextFavorite = !(current?.isFavorite ?? false);
    final updated = _reducer.reduce(snapshot, [
      LibraryEvent.favoriteToggled(
        trackKey: trackKey,
        isFavorite: nextFavorite,
        timestamp: _now(),
      ),
    ]);
    await _store.save(updated);
    return nextFavorite;
  }

  Future<bool> toggleFavoriteForTrack(Track track) {
    return toggleFavorite(trackKey: stableTrackKey(track));
  }
}

String stableTrackKey(Track track) => '${track.providerId}::${track.id}';
