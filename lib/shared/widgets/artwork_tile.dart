import 'package:flutter/material.dart';
import 'dart:io';
import 'package:on_audio_query/on_audio_query.dart';

import 'artwork_query_sizing.dart';

class ArtworkTile extends StatelessWidget {
  const ArtworkTile({
    super.key,
    required this.id,
    required this.type,
    this.size = 56,
    this.showPlaceholderOnly = false,
    this.cachedArtworkPath,
  });

  final int? id;
  final ArtworkType type;
  final double size;
  final bool showPlaceholderOnly;
  final String? cachedArtworkPath;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final querySize = resolveArtworkQuerySize(
      logicalSize: size,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    if (showPlaceholderOnly) return _placeholder(context, radius);

    final path = cachedArtworkPath;
    if (path != null && path.isNotEmpty) {
      return RepaintBoundary(
        child: ClipRRect(
          borderRadius: radius,
          child: Image.file(
            File(path),
            width: size,
            height: size,
            cacheWidth: querySize,
            cacheHeight: querySize,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) {
              if (id == null) return _placeholder(context, radius);
              return _queryArtwork(context, radius, querySize);
            },
          ),
        ),
      );
    }

    if (id == null) return _placeholder(context, radius);

    return _queryArtwork(context, radius, querySize);
  }

  Widget _queryArtwork(
    BuildContext context,
    BorderRadius radius,
    int querySize,
  ) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: QueryArtworkWidget(
          key: ValueKey<String>('artwork:${type.name}:$id:$querySize'),
          id: id!,
          type: type,
          artworkWidth: querySize.toDouble(),
          artworkHeight: querySize.toDouble(),
          artworkFit: BoxFit.cover,
          nullArtworkWidget: _placeholder(context, radius),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, BorderRadius radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
            Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: const Icon(Icons.music_note_rounded, color: Colors.white),
    );
  }
}
