import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/application/library_providers.dart';
import '../../library/domain/track.dart';
import '../domain/library_snapshot.dart';
import '../infrastructure/file_library_intelligence_store.dart';
import 'library_intelligence_controller.dart';
import 'library_intelligence_reducer.dart';
import 'library_intelligence_store.dart';

const int libraryIntelligenceTopN = 50;

final libraryIntelligenceStoreProvider = Provider<LibraryIntelligenceStore>((
  ref,
) {
  return FileLibraryIntelligenceStore();
});

final libraryIntelligenceSnapshotProvider = FutureProvider<LibrarySnapshot>((
  ref,
) async {
  final store = ref.watch(libraryIntelligenceStoreProvider);
  return store.load();
});

final libraryIntelligenceControllerProvider = Provider<LibraryIntelligenceController>((ref) {
  return LibraryIntelligenceController(
    store: ref.watch(libraryIntelligenceStoreProvider),
    reducer: const LibraryIntelligenceReducer(),
  );
});

final favoriteTrackKeysProvider = Provider<Set<String>>((ref) {
  final snapshot =
      ref.watch(libraryIntelligenceSnapshotProvider).valueOrNull ??
      const LibrarySnapshot.empty();
  return snapshot.tracks.values
      .where((item) => item.isFavorite)
      .map((item) => item.trackKey)
      .toSet();
});

final isTrackFavoriteByKeyProvider = Provider.family<bool, String>((ref, trackKey) {
  return ref.watch(favoriteTrackKeysProvider).contains(trackKey);
});

final favoriteTracksProvider = Provider<List<Track>>((ref) {
  final mapping = ref.watch(_libraryIntelligenceMappingProvider);
  return mapping.favorites;
});

final recentTracksProvider = Provider<List<Track>>((ref) {
  final mapping = ref.watch(_libraryIntelligenceMappingProvider);
  return mapping.recents;
});

final mostPlayedTracksProvider = Provider<List<Track>>((ref) {
  final mapping = ref.watch(_libraryIntelligenceMappingProvider);
  return mapping.mostPlayed;
});

final continueListeningTracksProvider = Provider<List<ContinueListeningItem>>((
  ref,
) {
  final mapping = ref.watch(_libraryIntelligenceMappingProvider);
  return mapping.continueListening;
});

final libraryIntelligenceStatsProvider = Provider<LibraryStatsSnapshot>((ref) {
  final mapping = ref.watch(_libraryIntelligenceMappingProvider);
  return mapping.stats;
});

final _libraryIntelligenceMappingProvider =
    Provider<LibraryIntelligenceMapping>((ref) {
      final tracks = ref.watch(tracksProvider).valueOrNull ?? const <Track>[];
      final snapshot =
          ref.watch(libraryIntelligenceSnapshotProvider).valueOrNull ??
          const LibrarySnapshot.empty();
      return mapLibraryIntelligence(
        snapshot: snapshot,
        tracks: tracks,
        topN: libraryIntelligenceTopN,
      );
    });

LibraryIntelligenceMapping mapLibraryIntelligence({
  required LibrarySnapshot snapshot,
  required List<Track> tracks,
  required int topN,
}) {
  final tracksByKey = <String, Track>{
    for (final track in tracks) _trackStableKey(track): track,
  };

  List<Track> mapTracks(Iterable<LibraryTrackSnapshot> items) {
    return items
        .map((item) => tracksByKey[item.trackKey])
        .whereType<Track>()
        .take(topN)
        .toList(growable: false);
  }

  final favorites = mapTracks(
    snapshot.tracks.values
        .where((item) => item.isFavorite)
        .toList(growable: false)
      ..sort((a, b) {
        final left = a.favoritedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.favoritedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      }),
  );

  final continueListening = snapshot.continueListening
      .map((item) {
        final track = tracksByKey[item.trackKey];
        if (track == null) return null;
        return ContinueListeningItem(
          track: track,
          resumePositionMs: item.resumePositionMs,
        );
      })
      .whereType<ContinueListeningItem>()
      .take(topN)
      .toList(growable: false);

  final visibleSnapshots = snapshot.tracks.values.where(
    (item) => tracksByKey.containsKey(item.trackKey),
  );
  final stats = LibraryStatsSnapshot(
    totalTracked: visibleSnapshots.length,
    favoriteTracks: visibleSnapshots.where((item) => item.isFavorite).length,
    completedTracks: visibleSnapshots.where((item) => item.isCompleted).length,
    totalPlayCount: visibleSnapshots.fold(
      0,
      (sum, item) => sum + item.playCount,
    ),
  );

  return LibraryIntelligenceMapping(
    favorites: favorites,
    recents: mapTracks(snapshot.recents),
    mostPlayed: mapTracks(snapshot.mostPlayed),
    continueListening: continueListening,
    stats: stats,
  );
}

String _trackStableKey(Track track) => stableTrackKey(track);

class ContinueListeningItem {
  const ContinueListeningItem({
    required this.track,
    required this.resumePositionMs,
  });

  final Track track;
  final int resumePositionMs;
}

class LibraryIntelligenceMapping {
  const LibraryIntelligenceMapping({
    required this.favorites,
    required this.recents,
    required this.mostPlayed,
    required this.continueListening,
    required this.stats,
  });

  final List<Track> favorites;
  final List<Track> recents;
  final List<Track> mostPlayed;
  final List<ContinueListeningItem> continueListening;
  final LibraryStatsSnapshot stats;
}
