import 'package:flutter/material.dart';
import 'dart:io';
import 'package:on_audio_query/on_audio_query.dart';

import '../../app/theme.dart';
import 'artwork_query_sizing.dart';

class ArtworkTile extends StatelessWidget {
  const ArtworkTile({
    super.key,
    required this.id,
    required this.type,
    this.size = 56,
    this.showPlaceholderOnly = false,
    this.cachedArtworkPath,
    this.placeholderDominantColor,
    this.placeholderAccentColor,
  });

  final int? id;
  final ArtworkType type;
  final double size;
  final bool showPlaceholderOnly;
  final String? cachedArtworkPath;
  final Color? placeholderDominantColor;
  final Color? placeholderAccentColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    final querySize = resolveArtworkQuerySize(
      logicalSize: size,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    if (showPlaceholderOnly) return _frame(_placeholder(context, radius));

    final path = cachedArtworkPath;
    if (path != null && path.isNotEmpty) {
      return _frame(
        RepaintBoundary(
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
        ),
      );
    }

    if (id == null) return _frame(_placeholder(context, radius));

    return _frame(_queryArtwork(context, radius, querySize));
  }

  Widget _frame(Widget child) {
    return SizedBox.square(dimension: size, child: child);
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
        border: Border.all(color: VantaColors.border, width: 0.6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            placeholderAccentColor?.withValues(alpha: 0.62) ??
                VantaColors.violet.withValues(alpha: 0.62),
            VantaColors.surfaceHigh,
            placeholderDominantColor?.withValues(alpha: 0.62) ??
                VantaColors.surfaceElevated,
          ],
        ),
      ),
      child: const Icon(Icons.music_note_rounded, color: VantaColors.text),
    );
  }
}
