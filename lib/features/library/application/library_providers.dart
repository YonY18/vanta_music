import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/application/subsonic_providers.dart';
import '../../providers/domain/music_provider.dart';
import '../../providers/infrastructure/local_music_provider.dart';
import '../../providers/infrastructure/subsonic_music_provider.dart';
import '../../premium_metadata/application/premium_metadata_providers.dart';
import '../../premium_metadata/domain/metadata_models.dart';
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

export '../../providers/application/subsonic_providers.dart';

final mediaPermissionServiceProvider = Provider(
  (ref) => MediaPermissionService(),
);

final localMusicProvider = Provider<MusicProvider>(
  (ref) => LocalMusicProvider(),
);

final activeRemoteMusicProvider = Provider<MusicProvider?>((ref) => null);

final savedSubsonicMusicProvider = FutureProvider<MusicProvider?>((ref) async {
  final store = await ref.watch(subsonicServerStoreProvider.future);
  final activeServerId = await store.readActiveServer();
  if (activeServerId == null) return null;

  final servers = await store.loadServers();
  final server = servers
      .where((server) => server.id == activeServerId)
      .firstOrNull;
  if (server == null) return null;

  final password = await store.readPassword(activeServerId);
  if (password == null || password.isEmpty) return null;

  return SubsonicMusicProvider(
    server: server,
    client: ref.watch(subsonicApiClientFactoryProvider)(
      server: server,
      password: password,
    ),
  );
});

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

final remoteLibraryTracksProvider = FutureProvider<List<Track>>((ref) async {
  final provider =
      ref.watch(activeRemoteMusicProvider) ??
      await ref.watch(savedSubsonicMusicProvider.future);
  if (provider == null) return const <Track>[];
  return provider.getTracks();
});

final remoteLibrarySourceLabelProvider = Provider<String>((ref) {
  return ref.watch(activeRemoteMusicProvider)?.name ??
      ref.watch(savedSubsonicMusicProvider).valueOrNull?.name ??
      'Remote library';
});

final filteredRemoteTracksProvider = Provider.family<List<Track>, String>((
  ref,
  query,
) {
  final tracks =
      ref.watch(remoteLibraryTracksProvider).valueOrNull ?? const <Track>[];
  return filterTracksForQuery(tracks, query);
});

final remoteSearchTracksProvider = FutureProvider.family<List<Track>, String>((
  ref,
  query,
) async {
  final provider = ref.watch(activeRemoteMusicProvider);
  final normalized = query.trim();
  final remoteProvider =
      provider ?? await ref.watch(savedSubsonicMusicProvider.future);
  if (remoteProvider == null || normalized.isEmpty) return const <Track>[];
  return remoteProvider.search(normalized);
});

final libraryTrackDisplayMetadataProvider =
    FutureProvider.family<ResolvedTrackMetadata, Track>((ref, track) {
      return ref.watch(resolvedTrackMetadataProvider(track).future);
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
