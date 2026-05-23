import 'package:flutter/material.dart';

enum TrackQuickActionType { toggleFavorite, addToPlaylist }

class TrackQuickAction {
  const TrackQuickAction({
    required this.type,
    required this.label,
    required this.icon,
  });

  final TrackQuickActionType type;
  final String label;
  final IconData icon;
}

List<TrackQuickAction> buildTrackQuickActions({required bool isFavorite}) {
  return [
    TrackQuickAction(
      type: TrackQuickActionType.toggleFavorite,
      label: isFavorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
      icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
    ),
    const TrackQuickAction(
      type: TrackQuickActionType.addToPlaylist,
      label: 'Agregar a playlist',
      icon: Icons.playlist_add_rounded,
    ),
  ];
}
