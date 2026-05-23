import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/presentation/library_track_actions.dart';

void main() {
  group('track quick actions', () {
    test('builds favorite-off actions with add-to-playlist fallback', () {
      final actions = buildTrackQuickActions(isFavorite: false);

      expect(actions, hasLength(2));
      expect(actions.first.type, TrackQuickActionType.toggleFavorite);
      expect(actions.first.label, 'Agregar a favoritos');
      expect(actions.first.icon, Icons.favorite_border_rounded);
      expect(actions.last.type, TrackQuickActionType.addToPlaylist);
      expect(actions.last.label, 'Agregar a playlist');
      expect(actions.last.icon, Icons.playlist_add_rounded);
    });

    test('builds favorite-on actions with proper remove label', () {
      final actions = buildTrackQuickActions(isFavorite: true);

      expect(actions, hasLength(2));
      expect(actions.first.type, TrackQuickActionType.toggleFavorite);
      expect(actions.first.label, 'Quitar de favoritos');
      expect(actions.first.icon, Icons.favorite_rounded);
    });
  });
}
