import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/artwork_cache/artwork_cache_providers.dart';
import '../../../shared/widgets/artwork_query_sizing.dart';
import '../application/media_item_artwork_request.dart';
import '../application/player_controller.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(mediaItemProvider).valueOrNull;
    if (item == null) return const SizedBox.shrink();

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => context.push('/now-playing'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: _MiniPlayerArtwork(item: item),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.artist ?? 'Desconocido',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const _MiniPlayerPlayPauseButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlayerArtwork extends ConsumerWidget {
  const _MiniPlayerArtwork({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = resolveArtworkQuerySize(
      logicalSize: 48,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    final request = trackArtworkRequestFromMediaItem(item: item, sizePx: size);
    final path = request == null
        ? null
        : ref.watch(trackArtworkPathProvider(request)).valueOrNull;

    if (path == null) {
      return const Icon(Icons.music_note_rounded);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.music_note_rounded),
      ),
    );
  }
}

class _MiniPlayerPlayPauseButton extends ConsumerWidget {
  const _MiniPlayerPlayPauseButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing =
        ref.watch(playbackStateProvider.select((value) => value.valueOrNull?.playing ?? false));
    final controller = ref.read(playerControllerProvider);

    return IconButton(
      onPressed: playing ? controller.pause : controller.play,
      icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
    );
  }
}
