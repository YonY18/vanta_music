import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/domain/music_provider.dart';
import '../../providers/infrastructure/local_music_provider.dart';
import '../domain/album.dart';
import '../domain/artist.dart';
import '../domain/track.dart';
import '../../../shared/artwork_cache/artwork_cache_providers.dart';
import '../../../shared/artwork_cache/artwork_precache.dart';
import '../../library_intelligence/application/library_intelligence_providers.dart';
import '../../library_intelligence/domain/library_snapshot.dart';
import 'file_validation_cache.dart';
import 'folder_library_controller.dart';
import 'library_collections.dart';
import 'library_search.dart';
import 'library_track_merge.dart';
import 'media_permission_service.dart';

final mediaPermissionServiceProvider = Provider(
  (ref) => MediaPermissionService(),
);

final localMusicProvider = Provider<MusicProvider>(
  (ref) => LocalMusicProvider(),
);

final fileValidationCacheProvider = Provider<InMemoryFileValidationCache>(
  (ref) => InMemoryFileValidationCache(),
);

final mediaPermissionProvider = FutureProvider<MediaPermissionState>((
  ref,
) async {
  return ref.watch(mediaPermissionServiceProvider).requestAudioAccess();
});

final notificationPermissionProvider = FutureProvider<MediaPermissionState>((
  ref,
) async {
  return ref.watch(mediaPermissionServiceProvider).checkNotificationAccess();
});

final tracksProvider = FutureProvider<List<Track>>((ref) async {
  final folderTracks =
      ref.watch(folderLibraryControllerProvider).valueOrNull ?? const <Track>[];
  final permission = await ref.watch(mediaPermissionProvider.future);
  if (permission != MediaPermissionState.granted) {
    return folderTracks;
  }

  final mediaStoreTracks = await ref.watch(localMusicProvider).getTracks();
  final merged = await mergeAndCleanTracks([
    ...folderTracks,
    ...mediaStoreTracks,
  ], cache: ref.watch(fileValidationCacheProvider));
  return filterLibraryNoiseTracks(merged);
});

final filteredTracksProvider = Provider.family<List<Track>, String>((
  ref,
  query,
) {
  final tracks = ref.watch(tracksProvider).valueOrNull ?? const <Track>[];
  return filterTracksForQuery(tracks, query);
});

final albumsProvider = Provider<List<Album>>((ref) {
  final tracks = ref.watch(tracksProvider).valueOrNull ?? const <Track>[];
  return buildAlbumsFromTracks(tracks);
});

final artistsProvider = Provider<List<Artist>>((ref) {
  final tracks = ref.watch(tracksProvider).valueOrNull ?? const <Track>[];
  return buildArtistsFromTracks(tracks);
});

final albumTracksProvider = Provider.family<List<Track>, String>((
  ref,
  albumId,
) {
  final tracks = ref.watch(tracksProvider).valueOrNull ?? const <Track>[];
  return tracks
      .where((track) => albumGroupKey(track) == albumId)
      .toList(growable: false);
});

final artistTracksProvider = Provider.family<List<Track>, String>((
  ref,
  artistId,
) {
  final tracks = ref.watch(tracksProvider).valueOrNull ?? const <Track>[];
  return tracks
      .where((track) => artistGroupKey(track) == artistId)
      .toList(growable: false);
});

final intelligenceFavoriteTracksProvider = Provider<List<Track>>((ref) {
  return ref.watch(favoriteTracksProvider);
});

final intelligenceRecentTracksProvider = Provider<List<Track>>((ref) {
  return ref.watch(recentTracksProvider);
});

final intelligenceMostPlayedTracksProvider = Provider<List<Track>>((ref) {
  return ref.watch(mostPlayedTracksProvider);
});

final intelligenceContinueListeningProvider =
    Provider<List<ContinueListeningItem>>((ref) {
      return ref.watch(continueListeningTracksProvider);
    });

final intelligenceStatsProvider = Provider<LibraryStatsSnapshot>((ref) {
  return ref.watch(libraryIntelligenceStatsProvider);
});

final artworkCacheWarmupBootstrapProvider = Provider<void>((ref) {
  String? lastFingerprint;
  Timer? pendingWarmup;
  ref.onDispose(() => pendingWarmup?.cancel());

  ref.listen<AsyncValue<List<Track>>>(tracksProvider, (previous, next) {
    final tracks = next.valueOrNull;
    if (tracks == null || tracks.isEmpty) return;

    final selected = selectTracksForArtworkPrecache(tracks);
    if (selected.isEmpty) return;

    final fingerprint = selected
        .map(
          (track) =>
              '${track.providerId}|${track.id}|${track.artworkId ?? 'null'}|${track.uri}',
        )
        .join('||');
    if (lastFingerprint == fingerprint) return;

    lastFingerprint = fingerprint;
    pendingWarmup?.cancel();
    pendingWarmup = Timer(const Duration(milliseconds: 1200), () {
      unawaited(ref.read(artworkCacheWarmupServiceProvider).warmup(selected));
    });
  }, fireImmediately: true);
});
