import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/artwork_tile.dart';
import '../../../shared/widgets/artwork_query_sizing.dart';
import '../../../shared/artwork_cache/artwork_cache_providers.dart';
import '../../downloads/presentation/download_track_actions.dart';
import '../../player/application/player_controller.dart';
import '../../player/presentation/mini_player.dart';
import '../application/folder_library_controller.dart';
import '../application/library_providers.dart';
import '../application/media_permission_service.dart';
import '../application/permission_ux.dart';
import '../../providers/infrastructure/subsonic_api_client.dart';
import '../../providers/infrastructure/subsonic_music_provider.dart';
import '../../providers/infrastructure/subsonic_server_store.dart';
import '../../library_intelligence/application/library_intelligence_providers.dart';
import '../../library_intelligence/domain/library_snapshot.dart';
import '../domain/track.dart';
import '../../playlists/application/playlists_controller.dart';
import '../../playlists/domain/playlist.dart';
import 'library_intelligence_sections.dart';
import 'library_track_actions.dart';
import 'library_track_favorites.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const _VantaAppTitle(),
          actions: [
            IconButton(
              tooltip: 'Audio settings',
              onPressed: () => context.push('/audio-settings'),
              icon: const Icon(Icons.tune_rounded),
            ),
            IconButton(
              tooltip: 'Downloads',
              onPressed: () => context.push('/downloads'),
              icon: const Icon(Icons.download_rounded),
            ),
            IconButton(
              tooltip: 'Abrir carpeta',
              onPressed: () => _pickFolder(context, ref),
              icon: const Icon(Icons.folder_open_rounded),
            ),
            IconButton(
              tooltip: 'Re-escanear biblioteca',
              onPressed: () => _refreshLibrary(context, ref),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Inicio'),
              Tab(text: 'Library'),
              Tab(text: 'Remote'),
              Tab(text: 'Playlists'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _HomeTab(),
            _LibraryTab(),
            _RemoteLibraryTab(),
            _PlaylistsTab(),
          ],
        ),
        bottomNavigationBar: const MiniPlayer(),
      ),
    );
  }

  Future<void> _pickFolder(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(folderLibraryControllerProvider.notifier)
        .pickAndScanFolder();
    ref.read(fileValidationCacheProvider).invalidateAll();
    ref.invalidate(tracksProvider);

    final result = ref.read(folderLibraryControllerProvider);
    final count = result.valueOrNull?.length;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          count == null
              ? 'No pude abrir esa carpeta.'
              : 'Carpeta escaneada: $count canciones encontradas.',
        ),
      ),
    );
  }

  void _refreshLibrary(BuildContext context, WidgetRef ref) {
    ref.read(folderLibraryControllerProvider.notifier).rescan();
    ref.read(fileValidationCacheProvider).invalidateAll();
    ref.invalidate(mediaPermissionProvider);
    ref.invalidate(tracksProvider);
    ref.invalidate(albumsProvider);
    ref.invalidate(artistsProvider);
    ref.invalidate(remoteLibraryUiStateProvider);
    ref.invalidate(remoteLibraryTracksProvider);
    ref.invalidate(remoteSearchStateProvider);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Actualizando biblioteca...')));
  }
}

class _VantaAppTitle extends StatelessWidget {
  const _VantaAppTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Vanta Music'),
        SizedBox(height: 2),
        Text(
          'Dark. Minimal. Fast.',
          style: TextStyle(
            color: VantaColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

class _SongsTab extends ConsumerWidget {
  const _SongsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(artworkCacheWarmupBootstrapProvider);
    final permission = ref.watch(mediaPermissionProvider).valueOrNull;
    final notificationPermission = ref
        .watch(notificationPermissionProvider)
        .valueOrNull;
    final tracks = ref.watch(tracksProvider);
    return tracks.when(
      data: (items) {
        if (items.isEmpty) {
          final audioCta = resolveAudioPermissionCta(permission);
          return _EmptyState(
            message: _emptyMessage(permission),
            ctaLabel: audioCta?.label,
            onCta: audioCta == null
                ? null
                : () => _handlePermissionCta(context, ref, audioCta),
          );
        }

        final notificationCta = notificationPermission == null
            ? null
            : resolveNotificationPermissionCta(
                notificationPermission: notificationPermission,
                hasTracks: items.isNotEmpty,
              );

        final hasNotificationBanner = notificationCta != null;
        final favoriteTrackKeys = ref.watch(favoriteTrackKeysProvider);
        final allSongsFavoriteFlags = mapTrackFavoriteFlags(
          tracks: items,
          favoriteTrackKeys: favoriteTrackKeys,
        );

        return _ArtworkDeferredOnScroll(
          builder: (deferArtwork) => CustomScrollView(
            slivers: [
              if (hasNotificationBanner)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: _PermissionBanner(
                      message:
                          'Activá notificaciones para mantener controles estables en Android 13 o superior.',
                      ctaLabel: notificationCta.label,
                      onCta: () =>
                          _handlePermissionCta(context, ref, notificationCta),
                    ),
                  ),
                ),
              if (!hasNotificationBanner)
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final track = items[index];
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      index == items.length - 1 ? 104 : 8,
                    ),
                    child: _TrackTile(
                      track: track,
                      deferArtwork: deferArtwork,
                      onTap: () => ref
                          .read(playerControllerProvider)
                          .playTracks(items, index),
                      isFavorite: allSongsFavoriteFlags[index],
                      onToggleFavorite: () async {
                        await ref
                            .read(libraryIntelligenceControllerProvider)
                            .toggleFavoriteForTrack(track);
                        ref.invalidate(libraryIntelligenceSnapshotProvider);
                      },
                      onAddToPlaylist: () => showAddToPlaylistSheet(
                        context: context,
                        ref: ref,
                        track: track,
                      ),
                      onOpenActions: () => showTrackQuickActionsSheet(
                        context: context,
                        isFavorite: allSongsFavoriteFlags[index],
                        onToggleFavorite: () async {
                          await ref
                              .read(libraryIntelligenceControllerProvider)
                              .toggleFavoriteForTrack(track);
                          ref.invalidate(libraryIntelligenceSnapshotProvider);
                        },
                        onAddToPlaylist: () => showAddToPlaylistSheet(
                          context: context,
                          ref: ref,
                          track: track,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
      error: (error, stack) =>
          _EmptyState(message: 'No pude leer la biblioteca: $error'),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _handlePermissionCta(
    BuildContext context,
    WidgetRef ref,
    PermissionCta cta,
  ) async {
    final permissionService = ref.read(mediaPermissionServiceProvider);

    if (cta.type == PermissionCtaType.openSettings) {
      await permissionService.openSettings();
    } else if (cta.type == PermissionCtaType.requestAudio) {
      ref.invalidate(mediaPermissionProvider);
    } else {
      await permissionService.requestNotificationAccess();
      ref.invalidate(notificationPermissionProvider);
    }

    ref.invalidate(tracksProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Actualizando permisos...')));
    }
  }

  String _emptyMessage(MediaPermissionState? permission) {
    return switch (permission) {
      MediaPermissionState.denied =>
        'Vanta necesita permiso para leer tu música local. Permitilo para armar la biblioteca.',
      MediaPermissionState.permanentlyDenied =>
        'El permiso de música quedó bloqueado. Abrí Ajustes y habilitalo manualmente.',
      MediaPermissionState.restricted =>
        'Acceso restringido por el sistema. Revisá controles parentales o políticas del dispositivo.',
      _ =>
        'No encontré música local todavía. Copiá canciones al dispositivo o abrí una carpeta.',
    };
  }
}

class _LibraryTab extends ConsumerWidget {
  const _LibraryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Library',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: VantaColors.text,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 14),
                _LibrarySearchBar(
                  onTap: () => showSearch(
                    context: context,
                    delegate: _TrackSearchDelegate(),
                  ),
                ),
                const SizedBox(height: 18),
                const _LibrarySegmentTabs(),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [_SongsTab(), _AlbumsTab(), _ArtistsTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibrarySearchBar extends StatelessWidget {
  const _LibrarySearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: VantaColors.surfaceElevated,
            border: Border.all(color: VantaColors.border, width: 0.7),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Row(
            children: [
              Icon(Icons.search_rounded, color: VantaColors.muted, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search artists, albums, tracks',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: VantaColors.muted, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibrarySegmentTabs extends StatelessWidget {
  const _LibrarySegmentTabs();

  @override
  Widget build(BuildContext context) {
    return const TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        Tab(text: 'Tracks'),
        Tab(text: 'Albums'),
        Tab(text: 'Artists'),
      ],
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(intelligenceStatsProvider);
    final intelligenceSections = buildVisibleIntelligenceSections(
      continueListening: ref
          .watch(intelligenceContinueListeningProvider)
          .map((item) => item.track)
          .toList(growable: false),
      recents: ref.watch(intelligenceRecentTracksProvider),
      mostPlayed: ref.watch(intelligenceMostPlayedTracksProvider),
      favorites: ref.watch(intelligenceFavoriteTracksProvider),
    );
    final favoriteTrackKeys = ref.watch(favoriteTrackKeysProvider);
    final sectionFavoriteFlags = {
      for (final entry in intelligenceSections.asMap().entries)
        entry.key: mapTrackFavoriteFlags(
          tracks: entry.value.tracks,
          favoriteTrackKeys: favoriteTrackKeys,
        ),
    };

    return _ArtworkDeferredOnScroll(
      builder: (deferArtwork) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: _LibraryStatsCards(stats: stats),
            ),
          ),
          if (intelligenceSections.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: _SmartLibraryEmptyStates(),
              ),
            ),
          SliverToBoxAdapter(
            child: _HomeMockHeader(
              tracks: intelligenceSections.isEmpty
                  ? const []
                  : intelligenceSections.first.tracks,
              deferArtwork: deferArtwork,
              onPlayTrack: (index) {
                final tracks = intelligenceSections.first.tracks;
                ref.read(playerControllerProvider).playTracks(tracks, index);
              },
            ),
          ),
          for (final sectionEntry in intelligenceSections.asMap().entries) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _SectionTitle(title: sectionEntry.value.title),
              ),
            ),
            SliverList.builder(
              itemCount: sectionEntry.value.tracks.length,
              itemBuilder: (context, index) {
                final track = sectionEntry.value.tracks[index];
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    index == sectionEntry.value.tracks.length - 1 ? 16 : 8,
                  ),
                  child: _TrackTile(
                    track: track,
                    deferArtwork: deferArtwork,
                    onTap: () => ref
                        .read(playerControllerProvider)
                        .playTracks(sectionEntry.value.tracks, index),
                    isFavorite: sectionFavoriteFlags[sectionEntry.key]![index],
                    onToggleFavorite: () async {
                      await ref
                          .read(libraryIntelligenceControllerProvider)
                          .toggleFavoriteForTrack(track);
                      ref.invalidate(libraryIntelligenceSnapshotProvider);
                    },
                    onAddToPlaylist: () => showAddToPlaylistSheet(
                      context: context,
                      ref: ref,
                      track: track,
                    ),
                    onOpenActions: () => showTrackQuickActionsSheet(
                      context: context,
                      isFavorite:
                          sectionFavoriteFlags[sectionEntry.key]![index],
                      onToggleFavorite: () async {
                        await ref
                            .read(libraryIntelligenceControllerProvider)
                            .toggleFavoriteForTrack(track);
                        ref.invalidate(libraryIntelligenceSnapshotProvider);
                      },
                      onAddToPlaylist: () => showAddToPlaylistSheet(
                        context: context,
                        ref: ref,
                        track: track,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
  }
}

class _LibraryStatsCards extends StatelessWidget {
  const _LibraryStatsCards({required this.stats});

  final LibraryStatsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value) => Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Library stats'),
        const SizedBox(height: 12),
        Row(
          children: [
            stat('Songs', _plural(stats.songCount, 'song')),
            stat('Albums', _plural(stats.albumCount, 'album')),
          ],
        ),
        Row(
          children: [
            stat('Artists', _plural(stats.artistCount, 'artist')),
            stat('Duration', _formatDuration(stats.totalDurationMs)),
          ],
        ),
      ],
    );
  }
}

String _plural(int count, String singular) {
  final suffix = count == 1 ? singular : '${singular}s';
  return '$count $suffix';
}

String _formatDuration(int totalDurationMs) {
  final minutes = Duration(milliseconds: totalDurationMs).inMinutes;
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (remainingMinutes == 0) return '${hours}h';
  return '${hours}h ${remainingMinutes}m';
}

class _SmartLibraryEmptyStates extends StatelessWidget {
  const _SmartLibraryEmptyStates();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _InfoCard(
          icon: Icons.auto_awesome_rounded,
          title: 'Smart library warming up',
          message:
              'Play local tracks to unlock recent, favorite, and most-played sections.',
        ),
        SizedBox(height: 8),
        _InfoCard(
          icon: Icons.cloud_sync_outlined,
          title: 'Cloud sync coming soon',
          message:
              'Premium sync and AI library tools are planned, but local playback works today.',
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: VantaColors.violet.withValues(alpha: 0.14),
              ),
              child: Icon(icon, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: VantaColors.muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeMockHeader extends StatelessWidget {
  const _HomeMockHeader({
    required this.tracks,
    required this.deferArtwork,
    required this.onPlayTrack,
  });

  final List<Track> tracks;
  final bool deferArtwork;
  final ValueChanged<int> onPlayTrack;

  @override
  Widget build(BuildContext context) {
    final heroTrack = tracks.isEmpty ? null : tracks.first;
    final recentTracks = tracks.length <= 1
        ? const <Track>[]
        : tracks.skip(1).take(3).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NowPlayingPreview(
            track: heroTrack,
            deferArtwork: deferArtwork,
            onTap: heroTrack == null ? null : () => onPlayTrack(0),
          ),
          const SizedBox(height: 28),
          const _SectionTitle(title: 'Recently added'),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var index = 0; index < 3; index++) ...[
                Expanded(
                  child: _RecentArtworkCard(
                    track: index < recentTracks.length
                        ? recentTracks[index]
                        : null,
                    deferArtwork: deferArtwork,
                    onTap: index < recentTracks.length
                        ? () => onPlayTrack(index + 1)
                        : null,
                  ),
                ),
                if (index != 2) const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 22),
          for (var index = 0; index < 3; index++) ...[
            _HomePreviewRow(
              track: index < tracks.length ? tracks[index] : null,
              onTap: index < tracks.length ? () => onPlayTrack(index) : null,
            ),
            if (index != 2) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _NowPlayingPreview extends StatelessWidget {
  const _NowPlayingPreview({
    required this.track,
    required this.deferArtwork,
    required this.onTap,
  });

  final Track? track;
  final bool deferArtwork;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: VantaColors.surfaceElevated,
        border: Border.all(color: VantaColors.border, width: 0.7),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              track == null
                  ? const _DiscPlaceholder(size: 96)
                  : ArtworkTile(
                      id: track!.artworkId,
                      type: ArtworkType.AUDIO,
                      size: 96,
                      showPlaceholderOnly: deferArtwork,
                    ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Now Playing',
                      style: TextStyle(
                        color: VantaColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      track?.title ?? 'Nothing playing yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VantaColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track?.artist ?? 'Start your local library',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VantaColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentArtworkCard extends StatelessWidget {
  const _RecentArtworkCard({
    required this.track,
    required this.deferArtwork,
    required this.onTap,
  });

  final Track? track;
  final bool deferArtwork;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Center(
            child: track == null
                ? const Icon(Icons.album_rounded, color: VantaColors.muted)
                : ArtworkTile(
                    id: track!.artworkId,
                    type: ArtworkType.AUDIO,
                    size: 72,
                    showPlaceholderOnly: deferArtwork,
                  ),
          ),
        ),
      ),
    );
  }
}

class _HomePreviewRow extends StatelessWidget {
  const _HomePreviewRow({required this.track, required this.onTap});

  final Track? track;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VantaColors.surfaceHigh.withValues(alpha: 0.72),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: VantaColors.border,
          ),
          child: const Icon(Icons.music_note_rounded, size: 18),
        ),
        title: Text(
          track?.title ?? 'Local track preview',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          track?.artist ?? 'Waiting for library activity',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _DiscPlaceholder extends StatelessWidget {
  const _DiscPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: VantaColors.surfaceHigh,
        border: Border.all(
          color: VantaColors.violet.withValues(alpha: 0.68),
          width: 1.4,
        ),
      ),
      child: Center(
        child: Container(
          width: size * 0.24,
          height: size * 0.24,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: VantaColors.text,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: VantaColors.text,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(albumsProvider);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
      itemCount: albums.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final album = albums[index];
        return Card(
          child: ListTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _CollectionTracksScreen(
                  title: album.title,
                  subtitle: album.artist,
                  tracksProvider: albumTracksProvider(album.id),
                ),
              ),
            ),
            leading: ArtworkTile(id: album.artworkId, type: ArtworkType.ALBUM),
            title: Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${album.artist} • ${album.trackCount} canciones'),
          ),
        );
      },
    );
  }
}

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(artistsProvider);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
      itemCount: artists.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final artist = artists[index];
        return Card(
          child: ListTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _CollectionTracksScreen(
                  title: artist.name,
                  subtitle: '${artist.trackCount} canciones',
                  tracksProvider: artistTracksProvider(artist.id),
                ),
              ),
            ),
            leading: const CircleAvatar(
              backgroundColor: VantaColors.surfaceHigh,
              child: Icon(Icons.person_rounded),
            ),
            title: Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${artist.trackCount} canciones'),
          ),
        );
      },
    );
  }
}

class _CollectionTracksScreen extends ConsumerWidget {
  const _CollectionTracksScreen({
    required this.title,
    required this.subtitle,
    required this.tracksProvider,
  });

  final String title;
  final String subtitle;
  final ProviderListenable<List<Track>> tracksProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(artworkCacheWarmupBootstrapProvider);
    final tracks = ref.watch(tracksProvider);
    final favoriteTrackKeys = ref.watch(favoriteTrackKeysProvider);
    final favoriteFlags = mapTrackFavoriteFlags(
      tracks: tracks,
      favoriteTrackKeys: favoriteTrackKeys,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
      ),
      body: _ArtworkDeferredOnScroll(
        builder: (deferArtwork) => ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
          itemCount: tracks.length,
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsets.only(
              bottom: index == tracks.length - 1 ? 0 : 8,
            ),
            child: _TrackTile(
              track: tracks[index],
              deferArtwork: deferArtwork,
              onTap: () =>
                  ref.read(playerControllerProvider).playTracks(tracks, index),
              isFavorite: favoriteFlags[index],
              onToggleFavorite: () async {
                await ref
                    .read(libraryIntelligenceControllerProvider)
                    .toggleFavoriteForTrack(tracks[index]);
                ref.invalidate(libraryIntelligenceSnapshotProvider);
              },
              onAddToPlaylist: () => showAddToPlaylistSheet(
                context: context,
                ref: ref,
                track: tracks[index],
              ),
              onOpenActions: () => showTrackQuickActionsSheet(
                context: context,
                isFavorite: favoriteFlags[index],
                onToggleFavorite: () async {
                  await ref
                      .read(libraryIntelligenceControllerProvider)
                      .toggleFavoriteForTrack(tracks[index]);
                  ref.invalidate(libraryIntelligenceSnapshotProvider);
                },
                onAddToPlaylist: () => showAddToPlaylistSheet(
                  context: context,
                  ref: ref,
                  track: tracks[index],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RemoteLibraryTab extends ConsumerWidget {
  const _RemoteLibraryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remoteState = ref.watch(remoteLibraryUiStateProvider);
    final sourceLabel = ref.watch(remoteLibrarySourceLabelProvider);

    return remoteState.when(
      data: (state) {
        final items = state.tracks;
        if (items.isEmpty) {
          if (state.failure != null) {
            return _RemoteLibraryFailureState(
              state: state,
              onRetry: () => _retryRemoteLibrary(ref),
            );
          }
          return _EmptyState(
            icon: Icons.cloud_queue_rounded,
            message:
                'Connect a Subsonic server to browse remote music separately from your local library.',
            ctaLabel: 'Connect to Subsonic',
            onCta: () => _showSubsonicConnectSheet(context, ref),
          );
        }

        final favoriteTrackKeys = ref.watch(favoriteTrackKeysProvider);
        final favoriteFlags = mapTrackFavoriteFlags(
          tracks: items,
          favoriteTrackKeys: favoriteTrackKeys,
        );

        return _ArtworkDeferredOnScroll(
          builder: (deferArtwork) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remote library',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: VantaColors.text,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sourceLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: VantaColors.muted,
                        ),
                      ),
                      if (state.isPartial ||
                          state.isUsingCache ||
                          state.failure != null) ...[
                        const SizedBox(height: 12),
                        _RemoteLibraryStatusBanner(
                          state: state,
                          onRetry: () => _retryRemoteLibrary(ref),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    index == items.length - 1 ? 104 : 8,
                  ),
                  child: _TrackTile(
                    track: items[index],
                    deferArtwork: deferArtwork,
                    trailing: DownloadTrackActionButton(track: items[index]),
                    onTap: () => ref
                        .read(playerControllerProvider)
                        .playTracks(items, index),
                    isFavorite: favoriteFlags[index],
                    onToggleFavorite: () async {
                      await ref
                          .read(libraryIntelligenceControllerProvider)
                          .toggleFavoriteForTrack(items[index]);
                      ref.invalidate(libraryIntelligenceSnapshotProvider);
                    },
                    onAddToPlaylist: () => showAddToPlaylistSheet(
                      context: context,
                      ref: ref,
                      track: items[index],
                    ),
                    onOpenActions: () => showTrackQuickActionsSheet(
                      context: context,
                      isFavorite: favoriteFlags[index],
                      onToggleFavorite: () async {
                        await ref
                            .read(libraryIntelligenceControllerProvider)
                            .toggleFavoriteForTrack(items[index]);
                        ref.invalidate(libraryIntelligenceSnapshotProvider);
                      },
                      onAddToPlaylist: () => showAddToPlaylistSheet(
                        context: context,
                        ref: ref,
                        track: items[index],
                      ),
                      onOpenDownloads: () => showDownloadTrackActionsSheet(
                        context: context,
                        track: items[index],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      error: (error, stack) => _RemoteLibraryFailureState(
        state: RemoteLibraryUiState(
          failure: error,
          failureKind: RemoteLibraryFailureKind.unknown,
          canRetry: true,
        ),
        onRetry: () => _retryRemoteLibrary(ref),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  void _retryRemoteLibrary(WidgetRef ref) {
    ref.invalidate(remoteLibraryUiStateProvider);
    ref.invalidate(remoteLibraryTracksProvider);
  }

  void _showSubsonicConnectSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SubsonicConnectSheet(),
    );
  }
}

class _RemoteLibraryFailureState extends StatelessWidget {
  const _RemoteLibraryFailureState({
    required this.state,
    required this.onRetry,
  });

  final RemoteLibraryUiState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _EmptyState(
      icon: Icons.cloud_off_rounded,
      message: _remoteFailureMessage(state),
      ctaLabel: state.canRetry ? 'Retry' : null,
      onCta: state.canRetry ? onRetry : null,
    );
  }
}

class _RemoteLibraryStatusBanner extends StatelessWidget {
  const _RemoteLibraryStatusBanner({
    required this.state,
    required this.onRetry,
  });

  final RemoteLibraryUiState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final partialMessage = state.isPartial
        ? 'Showing a fast remote preview from up to '
              '${SubsonicMusicProvider.defaultRemoteAlbumHydrationLimit} albums. '
              'Use search for the full server catalog.'
        : null;
    final timestamp = state.lastSyncAt == null
        ? null
        : 'Last sync: ${_formatRemoteSyncTimestamp(state.lastSyncAt!)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VantaColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VantaColors.border, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (partialMessage != null) ...[
            Text(partialMessage, style: Theme.of(context).textTheme.bodyMedium),
            if (state.isUsingCache || state.failure != null)
              const SizedBox(height: 8),
          ],
          if (state.isUsingCache || state.failure != null)
            Text(
              _remoteFailureMessage(state),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (timestamp != null &&
              (partialMessage != null ||
                  state.isUsingCache ||
                  state.failure != null)) ...[
            const SizedBox(height: 4),
            Text(
              timestamp,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: VantaColors.muted),
            ),
          ],
          if (state.canRetry) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}

class _SubsonicConnectSheet extends ConsumerStatefulWidget {
  const _SubsonicConnectSheet();

  @override
  ConsumerState<_SubsonicConnectSheet> createState() =>
      _SubsonicConnectSheetState();
}

class _SubsonicConnectSheetState extends ConsumerState<_SubsonicConnectSheet> {
  final _nameController = TextEditingController(text: 'Navidrome');
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isConnecting = false;
  String? _status;
  bool _isError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHeader(
                title: 'Connect to Subsonic',
                subtitle:
                    'Works with Navidrome and Subsonic-compatible servers.',
              ),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Server name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'https://music.example.com',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                onSubmitted: (_) => _connect(),
              ),
              if (_status != null) ...[
                const SizedBox(height: 14),
                Text(
                  _status!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _isError ? Colors.redAccent : VantaColors.muted,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _isConnecting ? null : _connect,
                icon: _isConnecting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_done_rounded),
                label: Text(
                  _isConnecting ? 'Connecting...' : 'Connect to Subsonic',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connect() async {
    final name = _nameController.text.trim();
    final baseUrl = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty ||
        baseUrl.isEmpty ||
        username.isEmpty ||
        password.isEmpty) {
      setState(() {
        _status = 'Complete server name, URL, username, and password.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _status = 'Testing Subsonic connection...';
      _isError = false;
    });

    try {
      final config = SubsonicServerConfig(
        id: _serverId(baseUrl, username),
        name: name,
        baseUrl: baseUrl,
        username: username,
      );
      final client = ref.read(subsonicApiClientFactoryProvider)(
        server: config,
        password: password,
      );
      await client.ping();

      final store = await ref.read(subsonicServerStoreProvider.future);
      await store.saveServer(config, password: password);
      await store.selectActiveServer(config.normalized().id);
      ref.invalidate(savedSubsonicMusicProvider);
      ref.invalidate(remoteLibraryTracksProvider);

      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _status = 'Connected. Loading remote library...';
        _isError = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subsonic server connected.')),
      );
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _status = 'Connection failed: ${_safeSubsonicError(error)}';
        _isError = true;
      });
    }
  }
}

String _serverId(String baseUrl, String username) {
  final uri = Uri.parse(baseUrl.trim());
  final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme.toLowerCase();
  final host = uri.host.isEmpty ? 'server' : uri.host.toLowerCase();
  final port = uri.hasPort ? uri.port.toString() : '';
  final path = uri.path.replaceAll(RegExp(r'/+$'), '').toLowerCase();
  final raw = [
    scheme,
    host,
    if (port.isNotEmpty) port,
    if (path.isNotEmpty) path,
    username.trim().toLowerCase(),
  ].join('-');
  final safe = raw.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return safe.replaceAll(RegExp(r'^-+|-+$'), '');
}

String _safeSubsonicError(Object error) {
  if (error is SubsonicFailure) return error.message;
  if (error is ArgumentError) {
    return error.message?.toString() ?? 'Invalid server settings.';
  }
  return 'Unable to connect to the server.';
}

String _remoteFailureMessage(RemoteLibraryUiState state) {
  if (state.isUsingCache) {
    return switch (state.failureKind) {
      RemoteLibraryFailureKind.timeout =>
        'Connection timed out. Showing cached music.',
      RemoteLibraryFailureKind.tls =>
        'Secure connection failed. Showing cached music.',
      RemoteLibraryFailureKind.auth =>
        'Authentication failed. Showing cached music.',
      RemoteLibraryFailureKind.forbidden =>
        'Access denied. Showing cached music.',
      RemoteLibraryFailureKind.notFound =>
        'Remote library endpoint missing. Showing cached music.',
      RemoteLibraryFailureKind.malformed =>
        'Server response was invalid. Showing cached music.',
      _ => 'Server unavailable. Showing cached music.',
    };
  }

  return switch (state.failureKind) {
    RemoteLibraryFailureKind.timeout => 'Connection timed out.',
    RemoteLibraryFailureKind.tls => 'Secure connection failed.',
    RemoteLibraryFailureKind.auth => 'Authentication failed.',
    RemoteLibraryFailureKind.forbidden => 'Access denied.',
    RemoteLibraryFailureKind.notFound => 'Remote library endpoint missing.',
    RemoteLibraryFailureKind.malformed => 'Server response was invalid.',
    RemoteLibraryFailureKind.unavailable => 'Server unavailable.',
    _ => 'Unable to load the remote library.',
  };
}

String _formatRemoteSyncTimestamp(DateTime timestamp) {
  final utc = timestamp.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  final hour = utc.hour.toString().padLeft(2, '0');
  final minute = utc.minute.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day $hour:$minute UTC';
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsControllerProvider);
    return playlists.when(
      data: (items) => items.isEmpty
          ? _EmptyState(
              message: 'Todavía no tenés playlists locales.',
              ctaLabel: 'Crear playlist',
              onCta: () => _createPlaylist(context, ref),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _PlaylistCreateCard(
                    onTap: () => _createPlaylist(context, ref),
                  );
                }

                final playlist = items[index - 1];
                return Card(
                  child: ListTile(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _PlaylistDetailScreen(
                          playlistId: playlist.id,
                          initialName: playlist.name,
                        ),
                      ),
                    ),
                    leading: const Icon(Icons.playlist_play_rounded),
                    title: Text(playlist.name),
                    subtitle: Text(_plural(playlist.tracks.length, 'song')),
                  ),
                );
              },
            ),
      error: (error, stack) =>
          _EmptyState(message: 'No pude cargar playlists: $error'),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ej: Camino al trabajo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty) return;
    await ref.read(playlistsControllerProvider.notifier).createPlaylist(name);
  }
}

class _PlaylistDetailScreen extends ConsumerWidget {
  const _PlaylistDetailScreen({
    required this.playlistId,
    required this.initialName,
  });

  final String playlistId;
  final String initialName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsControllerProvider);
    final playlist = _findPlaylist(playlists.valueOrNull, playlistId);

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(title: Text(initialName)),
        body: const _EmptyState(message: 'No pude cargar esta playlist.'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _plural(playlist.tracks.length, 'song'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: playlist.tracks.isEmpty
          ? const _EmptyState(
              message: 'Esta playlist todavía no tiene canciones.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
              itemCount: playlist.tracks.length,
              itemBuilder: (context, index) {
                final track = playlist.tracks[index];
                return Card(
                  child: ListTile(
                    onTap: () => ref
                        .read(playerControllerProvider)
                        .playTracks(playlist.tracks, index),
                    leading: const Icon(Icons.music_note_rounded),
                    title: Text(track.title),
                    subtitle: Text('${track.artist} • ${track.album}'),
                  ),
                );
              },
            ),
    );
  }
}

Playlist? _findPlaylist(List<Playlist>? playlists, String playlistId) {
  if (playlists == null) return null;
  for (final playlist in playlists) {
    if (playlist.id == playlistId) return playlist;
  }
  return null;
}

class _TrackTile extends ConsumerWidget {
  const _TrackTile({
    required this.track,
    required this.onTap,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onAddToPlaylist,
    required this.onOpenActions,
    this.trailing,
    this.deferArtwork = false,
    this.sourceLabel,
  });

  final Track track;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onOpenActions;
  final Widget? trailing;
  final bool deferArtwork;
  final String? sourceLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayMetadata = ref
        .watch(libraryTrackDisplayMetadataProvider(track))
        .valueOrNull;
    final querySize = resolveArtworkQuerySize(
      logicalSize: 56,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    final artworkPath = deferArtwork
        ? const AsyncData<String?>(null)
        : ref.watch(
            trackArtworkPathProvider(
              TrackArtworkRequest(track: track, sizePx: querySize),
            ),
          );
    final cachedArtworkPath = artworkPath.valueOrNull;
    final showPlaceholderOnly = deferArtwork || artworkPath.isLoading;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        onLongPress: onOpenActions,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ArtworkTile(
                id: track.artworkId,
                type: ArtworkType.AUDIO,
                showPlaceholderOnly: showPlaceholderOnly,
                cachedArtworkPath: cachedArtworkPath,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayMetadata?.title ?? track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${displayMetadata?.artist ?? track.artist} • ${displayMetadata?.album ?? track.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: VantaColors.muted),
                    ),
                    if (sourceLabel != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Source: $sourceLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: VantaColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[trailing!],
              IconButton(
                tooltip: isFavorite
                    ? 'Quitar de favoritos'
                    : 'Agregar a favoritos',
                onPressed: onToggleFavorite,
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite ? VantaColors.violet : VantaColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    this.ctaLabel,
    this.onCta,
    this.icon = Icons.library_music_rounded,
  });

  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: VantaColors.violet.withValues(alpha: 0.14),
                      border: Border.all(
                        color: VantaColors.violet.withValues(alpha: 0.38),
                      ),
                    ),
                    child: Icon(icon, color: VantaColors.text, size: 30),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: VantaColors.text,
                      height: 1.35,
                    ),
                  ),
                  if (ctaLabel != null && onCta != null) ...[
                    const SizedBox(height: 18),
                    FilledButton(onPressed: onCta, child: Text(ctaLabel!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({
    required this.message,
    required this.ctaLabel,
    required this.onCta,
  });

  final String message;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VantaColors.violet.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VantaColors.violet.withValues(alpha: 0.18),
              ),
              child: const Icon(Icons.notifications_active_outlined, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: VantaColors.text,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onCta, child: Text(ctaLabel)),
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: VantaColors.text,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: VantaColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _SheetActionTile extends StatelessWidget {
  const _SheetActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: VantaColors.surfaceHigh,
            ),
            child: Icon(icon, size: 20),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: subtitle == null
              ? null
              : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _PlaylistCreateCard extends StatelessWidget {
  const _PlaylistCreateCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VantaColors.violet.withValues(alpha: 0.16),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: VantaColors.violet.withValues(alpha: 0.18),
          ),
          child: const Icon(Icons.add_rounded),
        ),
        title: const Text(
          'Crear playlist',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('Organizá tu biblioteca local'),
      ),
    );
  }
}

class _TrackSearchDelegate extends SearchDelegate<void> {
  _TrackSearchDelegate();

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context);

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        onPressed: () => query = '',
        icon: const Icon(Icons.clear_rounded),
      ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back_rounded),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    if (query.trim().isEmpty) {
      return const _EmptyState(
        icon: Icons.search_rounded,
        message: 'Buscá canciones por título, artista o álbum.',
      );
    }
    return _SearchResultsView(
      query: query,
      onTrackSelected: (context, ref, tracks, index) {
        ref.read(playerControllerProvider).playTracks(tracks, index);
        close(context, null);
        context.push('/now-playing');
      },
    );
  }
}

class _SearchResultsView extends ConsumerStatefulWidget {
  const _SearchResultsView({
    required this.query,
    required this.onTrackSelected,
  });

  final String query;
  final void Function(BuildContext, WidgetRef, List<Track>, int)
  onTrackSelected;

  @override
  ConsumerState<_SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends ConsumerState<_SearchResultsView> {
  @override
  void initState() {
    super.initState();
    _scheduleRemoteSearch(widget.query);
  }

  @override
  void didUpdateWidget(covariant _SearchResultsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _scheduleRemoteSearch(widget.query);
    }
  }

  void _scheduleRemoteSearch(String query) {
    Future<void>.microtask(() {
      if (!mounted) return;
      ref.read(remoteSearchStateProvider.notifier).setQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final localResults = ref.watch(filteredTracksProvider(widget.query));
    final remoteState = ref.watch(remoteSearchStateProvider);
    final favoriteTrackKeys = ref.watch(favoriteTrackKeysProvider);
    final localFavoriteFlags = mapTrackFavoriteFlags(
      tracks: localResults,
      favoriteTrackKeys: favoriteTrackKeys,
    );
    final remoteFavoriteFlags = mapTrackFavoriteFlags(
      tracks: remoteState.tracks,
      favoriteTrackKeys: favoriteTrackKeys,
    );

    return _ArtworkDeferredOnScroll(
      builder: (deferArtwork) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        children: [
          const _SectionTitle(title: 'Local library'),
          const SizedBox(height: 12),
          if (localResults.isEmpty)
            const _SearchStatusCard(
              message: 'No encontré canciones locales con esa búsqueda.',
            )
          else
            for (var index = 0; index < localResults.length; index += 1)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == localResults.length - 1 ? 0 : 8,
                ),
                child: _TrackTile(
                  track: localResults[index],
                  deferArtwork: deferArtwork,
                  sourceLabel: 'Local library',
                  onTap: () =>
                      widget.onTrackSelected(context, ref, localResults, index),
                  isFavorite: localFavoriteFlags[index],
                  onToggleFavorite: () async {
                    await ref
                        .read(libraryIntelligenceControllerProvider)
                        .toggleFavoriteForTrack(localResults[index]);
                    ref.invalidate(libraryIntelligenceSnapshotProvider);
                  },
                  onAddToPlaylist: () => showAddToPlaylistSheet(
                    context: context,
                    ref: ref,
                    track: localResults[index],
                  ),
                  onOpenActions: () => showTrackQuickActionsSheet(
                    context: context,
                    isFavorite: localFavoriteFlags[index],
                    onToggleFavorite: () async {
                      await ref
                          .read(libraryIntelligenceControllerProvider)
                          .toggleFavoriteForTrack(localResults[index]);
                      ref.invalidate(libraryIntelligenceSnapshotProvider);
                    },
                    onAddToPlaylist: () => showAddToPlaylistSheet(
                      context: context,
                      ref: ref,
                      track: localResults[index],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 20),
          const _SectionTitle(title: 'Remote library'),
          const SizedBox(height: 12),
          if (remoteState.isLoading)
            _SearchStatusCard(
              message: 'Searching ${remoteState.sourceLabel}...',
            )
          else if (remoteState.failure != null)
            const _SearchStatusCard(
              message: 'Remote search is unavailable right now.',
            )
          else if (remoteState.hasSearched && remoteState.tracks.isEmpty)
            _SearchStatusCard(
              message: 'No remote matches in ${remoteState.sourceLabel}.',
            )
          else
            for (var index = 0; index < remoteState.tracks.length; index += 1)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == remoteState.tracks.length - 1 ? 0 : 8,
                ),
                child: _TrackTile(
                  track: remoteState.tracks[index],
                  deferArtwork: deferArtwork,
                  sourceLabel: remoteState.sourceLabel,
                  trailing: DownloadTrackActionButton(
                    track: remoteState.tracks[index],
                  ),
                  onTap: () => widget.onTrackSelected(
                    context,
                    ref,
                    remoteState.tracks,
                    index,
                  ),
                  isFavorite: remoteFavoriteFlags[index],
                  onToggleFavorite: () async {
                    await ref
                        .read(libraryIntelligenceControllerProvider)
                        .toggleFavoriteForTrack(remoteState.tracks[index]);
                    ref.invalidate(libraryIntelligenceSnapshotProvider);
                  },
                  onAddToPlaylist: () => showAddToPlaylistSheet(
                    context: context,
                    ref: ref,
                    track: remoteState.tracks[index],
                  ),
                  onOpenActions: () => showTrackQuickActionsSheet(
                    context: context,
                    isFavorite: remoteFavoriteFlags[index],
                    onToggleFavorite: () async {
                      await ref
                          .read(libraryIntelligenceControllerProvider)
                          .toggleFavoriteForTrack(remoteState.tracks[index]);
                      ref.invalidate(libraryIntelligenceSnapshotProvider);
                    },
                    onAddToPlaylist: () => showAddToPlaylistSheet(
                      context: context,
                      ref: ref,
                      track: remoteState.tracks[index],
                    ),
                    onOpenDownloads: () => showDownloadTrackActionsSheet(
                      context: context,
                      track: remoteState.tracks[index],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _SearchStatusCard extends StatelessWidget {
  const _SearchStatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

class _ArtworkDeferredOnScroll extends StatefulWidget {
  const _ArtworkDeferredOnScroll({required this.builder});

  final Widget Function(bool deferArtwork) builder;

  @override
  State<_ArtworkDeferredOnScroll> createState() =>
      _ArtworkDeferredOnScrollState();
}

class _ArtworkDeferredOnScrollState extends State<_ArtworkDeferredOnScroll> {
  @override
  Widget build(BuildContext context) {
    // Keep artwork stable while scrolling. The previous scroll-aware placeholder
    // swap reduced artwork work but caused broad list rebuilds and felt janky on
    // real devices. Stability wins here; artwork sizing/repaint isolation still
    // protects the hot path.
    return widget.builder(false);
  }
}

Future<void> showAddToPlaylistSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Track track,
}) async {
  final playlists =
      ref.read(playlistsControllerProvider).valueOrNull ?? const [];

  if (playlists.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Primero creá una playlist en su pestaña.')),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: playlists.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _SheetHeader(
              title: 'Agregar a playlist',
              subtitle: 'Elegí una lista local para guardar esta canción.',
            );
          }

          final playlist = playlists[index - 1];
          return _SheetActionTile(
            icon: Icons.playlist_play_rounded,
            title: playlist.name,
            subtitle: '${playlist.tracks.length} canciones',
            onTap: () async {
              await ref
                  .read(playlistsControllerProvider.notifier)
                  .addTrackToPlaylist(playlistId: playlist.id, track: track);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Agregada a ${playlist.name}.')),
                );
              }
            },
          );
        },
      ),
    ),
  );
}

Future<void> showTrackQuickActionsSheet({
  required BuildContext context,
  required bool isFavorite,
  required Future<void> Function() onToggleFavorite,
  required Future<void> Function() onAddToPlaylist,
  Future<void> Function()? onOpenDownloads,
}) async {
  final actions = buildTrackQuickActions(
    isFavorite: isFavorite,
    includeDownloadAction: onOpenDownloads != null,
  );

  await showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: actions.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _SheetHeader(
              title: 'Acciones rápidas',
              subtitle: 'Opciones livianas para tu biblioteca local.',
            );
          }

          final action = actions[index - 1];
          return _SheetActionTile(
            icon: action.icon,
            title: action.label,
            onTap: () async {
              Navigator.of(context).pop();
              if (action.type == TrackQuickActionType.toggleFavorite) {
                await onToggleFavorite();
                return;
              }
              if (action.type == TrackQuickActionType.download) {
                await onOpenDownloads?.call();
                return;
              }
              await onAddToPlaylist();
            },
          );
        },
      ),
    ),
  );
}
