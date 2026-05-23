import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/artwork_cache/artwork_cache_providers.dart';
import '../../../shared/utils/duration_format.dart';
import '../../../shared/widgets/artwork_query_sizing.dart';
import '../application/media_item_artwork_request.dart';
import '../application/player_controller.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(mediaItemProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        actions: item == null
            ? null
            : [
                IconButton(
                  tooltip: 'Track info',
                  onPressed: () => _showTrackInfoSheet(context, item),
                  icon: const Icon(Icons.info_outline_rounded),
                ),
              ],
      ),
      body: item == null
          ? const Center(child: Text('Todavía no hay nada reproduciéndose.'))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  _NowPlayingArtwork(item: item),
                  const SizedBox(height: 32),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                   Text(
                     item.artist ?? 'Desconocido',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                  ),
                   const SizedBox(height: 24),
                   const _NowPlayingPositionSection(),
                   const SizedBox(height: 24),
                   const _NowPlayingControls(),
                   const Spacer(),
                 ],
               ),
            ),
    );
  }
}

class _NowPlayingArtwork extends ConsumerWidget {
  const _NowPlayingArtwork({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = resolveArtworkQuerySize(
      logicalSize: MediaQuery.sizeOf(context).width - 48,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    final request = trackArtworkRequestFromMediaItem(item: item, sizePx: size);
    final path = request == null
        ? null
        : ref.watch(trackArtworkPathProvider(request)).valueOrNull;

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondaryContainer,
              const Color(0xFF111118),
            ],
          ),
        ),
        child: path == null
            ? const Icon(
                Icons.album_rounded,
                size: 96,
                color: Colors.white,
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.album_rounded,
                    size: 96,
                    color: Colors.white,
                  ),
                ),
              ),
      ),
    );
  }
}

void _showTrackInfoSheet(BuildContext context, MediaItem item) {
  final duration = item.duration == null ? '—' : formatDuration(item.duration!);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Track info', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _InfoRow(label: 'Título', value: item.title),
            _InfoRow(label: 'Artista', value: item.artist ?? 'Desconocido'),
            _InfoRow(label: 'Álbum', value: item.album ?? 'Desconocido'),
            _InfoRow(label: 'Duración', value: duration),
            _InfoRow(label: 'URI', value: item.id),
          ],
        ),
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingPositionSection extends ConsumerWidget {
  const _NowPlayingPositionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(mediaItemProvider).valueOrNull;
    final position =
        ref.watch(playbackPositionProvider).valueOrNull ?? Duration.zero;
    final duration =
        ref.watch(playbackDurationProvider).valueOrNull ??
        item?.duration ??
        Duration.zero;

    return Column(
      children: [
        Slider(
          value: position.inMilliseconds
              .clamp(0, duration.inMilliseconds)
              .toDouble(),
          max: duration.inMilliseconds <= 0
              ? 1
              : duration.inMilliseconds.toDouble(),
          onChanged: (value) => ref
              .read(playerControllerProvider)
              .seek(Duration(milliseconds: value.round())),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatDuration(position)),
            Text(formatDuration(duration)),
          ],
        ),
      ],
    );
  }
}

class _NowPlayingControls extends ConsumerWidget {
  const _NowPlayingControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing =
        ref.watch(playbackStateProvider.select((value) => value.valueOrNull?.playing ?? false));
    final controller = ref.read(playerControllerProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          iconSize: 32,
          onPressed: controller.previous,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        const SizedBox(width: 20),
        IconButton.filled(
          iconSize: 48,
          onPressed: playing ? controller.pause : controller.play,
          icon: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          ),
        ),
        const SizedBox(width: 20),
        IconButton.filledTonal(
          iconSize: 32,
          onPressed: controller.next,
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}
