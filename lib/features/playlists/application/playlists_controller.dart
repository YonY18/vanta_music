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

  Future<void> renamePlaylistById({
    required String playlistId,
    required String name,
  }) async {
    final current = [...(state.valueOrNull ?? const <Playlist>[])];
    final updated = current
        .map(
          (playlist) => playlist.id == playlistId
              ? renamePlaylist(playlist, name)
              : playlist,
        )
        .toList(growable: false);
    await _save(updated);
  }

  Future<void> deletePlaylistById(String playlistId) async {
    final current = [...(state.valueOrNull ?? const <Playlist>[])];
    await _save(deletePlaylist(current, playlistId));
  }

  Future<void> removeTrackFromPlaylistById({
    required String playlistId,
    required String trackId,
  }) async {
    final current = [...(state.valueOrNull ?? const <Playlist>[])];
    final updated = current
        .map(
          (playlist) => playlist.id == playlistId
              ? removeTrackFromPlaylist(playlist, trackId)
              : playlist,
        )
        .toList(growable: false);
    await _save(updated);
  }

  Future<void> reorderTrackInPlaylist({
    required String playlistId,
    required int fromIndex,
    required int toIndex,
  }) async {
    final current = [...(state.valueOrNull ?? const <Playlist>[])];
    final updated = current
        .map(
          (playlist) => playlist.id == playlistId
              ? reorderPlaylistTrack(
                  playlist,
                  fromIndex: fromIndex,
                  toIndex: toIndex,
                )
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

  return playlist.copyWith(
    tracks: [...playlist.tracks, track],
    updatedAt: now(),
  );
}

Playlist renamePlaylist(
  Playlist playlist,
  String name, {
  DateTime Function() now = DateTime.now,
}) {
  final normalized = name.trim();
  if (normalized.isEmpty || normalized == playlist.name) return playlist;

  return playlist.copyWith(name: normalized, updatedAt: now());
}

List<Playlist> deletePlaylist(List<Playlist> playlists, String playlistId) {
  return playlists
      .where((playlist) => playlist.id != playlistId)
      .toList(growable: false);
}

Playlist removeTrackFromPlaylist(
  Playlist playlist,
  String trackId, {
  DateTime Function() now = DateTime.now,
}) {
  final tracks = playlist.tracks
      .where((track) => track.id != trackId)
      .toList(growable: false);
  if (tracks.length == playlist.tracks.length) return playlist;

  return playlist.copyWith(tracks: tracks, updatedAt: now());
}

Playlist reorderPlaylistTrack(
  Playlist playlist, {
  required int fromIndex,
  required int toIndex,
  DateTime Function() now = DateTime.now,
}) {
  final tracks = [...playlist.tracks];
  if (fromIndex < 0 ||
      fromIndex >= tracks.length ||
      toIndex < 0 ||
      toIndex >= tracks.length ||
      fromIndex == toIndex) {
    return playlist;
  }

  final track = tracks.removeAt(fromIndex);
  tracks.insert(toIndex, track);
  return playlist.copyWith(tracks: tracks, updatedAt: now());
}
