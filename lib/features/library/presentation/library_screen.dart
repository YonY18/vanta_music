import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../shared/widgets/artwork_tile.dart';
import '../../../shared/widgets/artwork_query_sizing.dart';
import '../../../shared/artwork_cache/artwork_cache_providers.dart';
import '../../player/application/player_controller.dart';
import '../../player/presentation/mini_player.dart';
import '../application/folder_library_controller.dart';
import '../application/library_providers.dart';
import '../application/media_permission_service.dart';
import '../application/permission_ux.dart';
import '../../library_intelligence/application/library_intelligence_controller.dart';
import '../../library_intelligence/application/library_intelligence_providers.dart';
import '../domain/album.dart';
import '../domain/artist.dart';
import '../domain/track.dart';
import '../../playlists/application/playlists_controller.dart';
import 'library_intelligence_sections.dart';
import 'library_list_layout.dart';
import 'library_track_actions.dart';
import 'library_track_favorites.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vanta Music'),
          actions: [
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
            IconButton(
              tooltip: 'Buscar',
              onPressed: () => showSearch(
                context: context,
                delegate: _TrackSearchDelegate(ref),
              ),
              icon: const Icon(Icons.search_rounded),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Inicio'),
              Tab(text: 'Canciones'),
              Tab(text: 'Álbumes'),
              Tab(text: 'Artistas'),
              Tab(text: 'Playlists'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _HomeTab(),
            _SongsTab(),
            _AlbumsTab(),
            _ArtistsTab(),
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Re-escaneando biblioteca local...')),
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
                          'Activá notificaciones para controles más estables en Android 13/14.',
                      ctaLabel: notificationCta!.label,
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
        'Sin permiso para leer música. Aceptá el permiso y reintentá.',
      MediaPermissionState.permanentlyDenied =>
        'Permiso denegado permanentemente. Habilitalo en Ajustes del sistema.',
      MediaPermissionState.restricted =>
        'Acceso restringido por el sistema. Revisá controles parentales o políticas del dispositivo.',
      _ =>
        'No encontré música local. Copiá canciones al dispositivo o abrí una carpeta.',
    };
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    if (intelligenceSections.isEmpty) {
      return const _EmptyState(
        message: 'Todavía no hay actividad para mostrar en Inicio.',
      );
    }

    return _ArtworkDeferredOnScroll(
      builder: (deferArtwork) => CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          for (final sectionEntry in intelligenceSections.asMap().entries) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  sectionEntry.value.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
        return ListTile(
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
        return ListTile(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _CollectionTracksScreen(
                title: artist.name,
                subtitle: '${artist.trackCount} canciones',
                tracksProvider: artistTracksProvider(artist.id),
              ),
            ),
          ),
          leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
          title: Text(
            artist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('${artist.trackCount} canciones'),
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
                  return FilledButton.icon(
                    onPressed: () => _createPlaylist(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Crear playlist'),
                  );
                }

                final playlist = items[index - 1];
                return ListTile(
                  leading: const Icon(Icons.playlist_play_rounded),
                  title: Text(playlist.name),
                  subtitle: Text('${playlist.tracks.length} canciones'),
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

class _TrackTile extends ConsumerWidget {
  const _TrackTile({
    required this.track,
    required this.onTap,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onAddToPlaylist,
    required this.onOpenActions,
    this.deferArtwork = false,
  });

  final Track track;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onOpenActions;
  final bool deferArtwork;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final querySize = resolveArtworkQuerySize(
      logicalSize: 56,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    final cachedArtworkPath = deferArtwork
        ? null
        : ref
              .watch(
                trackArtworkPathProvider(
                  TrackArtworkRequest(track: track, sizePx: querySize),
                ),
              )
              .valueOrNull;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        onLongPress: onOpenActions,
        leading: ArtworkTile(
          id: track.artworkId,
          type: ArtworkType.AUDIO,
          showPlaceholderOnly: deferArtwork,
          cachedArtworkPath: cachedArtworkPath,
        ),
        title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${track.artist} • ${track.album}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: isFavorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
          onPressed: onToggleFavorite,
          icon: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, this.ctaLabel, this.onCta});

  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onCta, child: Text(ctaLabel!)),
            ],
          ],
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            const SizedBox(width: 12),
            TextButton(onPressed: onCta, child: Text(ctaLabel)),
          ],
        ),
      ),
    );
  }
}

class _TrackSearchDelegate extends SearchDelegate<void> {
  _TrackSearchDelegate(this.ref);

  final WidgetRef ref;

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
    final results = ref.watch(filteredTracksProvider(query));
    final favoriteTrackKeys = ref.watch(favoriteTrackKeysProvider);
    final favoriteFlags = mapTrackFavoriteFlags(
      tracks: results,
      favoriteTrackKeys: favoriteTrackKeys,
    );

    return _ArtworkDeferredOnScroll(
      builder: (deferArtwork) => ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) => _TrackTile(
          track: results[index],
          deferArtwork: deferArtwork,
          onTap: () {
            ref.read(playerControllerProvider).playTracks(results, index);
            close(context, null);
            context.push('/now-playing');
          },
          isFavorite: favoriteFlags[index],
          onToggleFavorite: () async {
            await ref
                .read(libraryIntelligenceControllerProvider)
                .toggleFavoriteForTrack(results[index]);
            ref.invalidate(libraryIntelligenceSnapshotProvider);
          },
          onAddToPlaylist: () => _showAddToPlaylistSheet(
            context: context,
            ref: ref,
            track: results[index],
          ),
          onOpenActions: () => showTrackQuickActionsSheet(
            context: context,
            isFavorite: favoriteFlags[index],
            onToggleFavorite: () async {
              await ref
                  .read(libraryIntelligenceControllerProvider)
                  .toggleFavoriteForTrack(results[index]);
              ref.invalidate(libraryIntelligenceSnapshotProvider);
            },
            onAddToPlaylist: () => _showAddToPlaylistSheet(
              context: context,
              ref: ref,
              track: results[index],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddToPlaylistSheet({
    required BuildContext context,
    required WidgetRef ref,
    required Track track,
  }) => showAddToPlaylistSheet(context: context, ref: ref, track: track);
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
    builder: (context) => ListView.builder(
      shrinkWrap: true,
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return ListTile(
          title: Text(playlist.name),
          subtitle: Text('${playlist.tracks.length} canciones'),
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
  );
}

Future<void> showTrackQuickActionsSheet({
  required BuildContext context,
  required bool isFavorite,
  required Future<void> Function() onToggleFavorite,
  required Future<void> Function() onAddToPlaylist,
}) async {
  final actions = buildTrackQuickActions(isFavorite: isFavorite);

  await showModalBottomSheet<void>(
    context: context,
    builder: (context) => ListView.builder(
      shrinkWrap: true,
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return ListTile(
          leading: Icon(action.icon),
          title: Text(action.label),
          onTap: () async {
            Navigator.of(context).pop();
            if (action.type == TrackQuickActionType.toggleFavorite) {
              await onToggleFavorite();
              return;
            }
            await onAddToPlaylist();
          },
        );
      },
    ),
  );
}
