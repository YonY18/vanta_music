import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/domain/track.dart';
import '../domain/playlist.dart';
import '../infrastructure/local_playlist_store.dart';

final localPlaylistStoreProvider = Provider((ref) => LocalPlaylistStore());

final playlistsControllerProvider =
    AsyncNotifierProvider<PlaylistsController, List<Playlist>>(
      PlaylistsController.new,
    );

class PlaylistsController extends AsyncNotifier<List<Playlist>> {
  @override
  Future<List<Playlist>> build() async {
    return ref.read(localPlaylistStoreProvider).getPlaylists();
  }

  Future<void> createPlaylist(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return;

    final current = [...(state.valueOrNull ?? const <Playlist>[])];
    final playlist = Playlist(
      id: _newId(),
      name: normalized,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final updated = [...current, playlist];
    await _save(updated);
  }

  Future<void> addTrackToPlaylist({
    required String playlistId,
    required Track track,
  }) async {
    final current = [...(state.valueOrNull ?? const <Playlist>[])];
    final updated = current
        .map(
          (playlist) => playlist.id == playlistId
              ? appendTrackToPlaylist(playlist, track)
              : playlist,
        )
        .toList(growable: false);
    await _save(updated);
  }

  Future<void> _save(List<Playlist> playlists) async {
    await ref.read(localPlaylistStoreProvider).savePlaylists(playlists);
    state = AsyncValue.data(playlists);
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}

Playlist appendTrackToPlaylist(
  Playlist playlist,
  Track track, {
  DateTime Function() now = DateTime.now,
}) {
  final alreadyExists = playlist.tracks.any((item) => item.id == track.id);
  if (alreadyExists) return playlist;

  return Playlist(
    id: playlist.id,
    name: playlist.name,
    description: playlist.description,
    tracks: [...playlist.tracks, track],
    createdAt: playlist.createdAt,
    updatedAt: now(),
  );
}
