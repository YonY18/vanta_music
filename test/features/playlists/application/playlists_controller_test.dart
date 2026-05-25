import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/playlists/application/playlists_controller.dart';
import 'package:vanta_music/features/playlists/domain/playlist.dart';

void main() {
  Track track(String id) {
    return Track(
      id: id,
      providerId: 'local',
      title: 'Song $id',
      artist: 'Artist',
      album: 'Album',
      uri: Uri.file('/song$id.mp3'),
    );
  }

  test('appendTrackToPlaylist keeps track IDs unique', () {
    final firstTrack = track('1');
    final playlist = Playlist(id: 'p1', name: 'Mix', tracks: [firstTrack]);

    final updated = appendTrackToPlaylist(playlist, firstTrack);

    expect(updated.tracks.length, 1);
    expect(updated.tracks.first.id, '1');
  });

  test('appendTrackToPlaylist appends new track and bumps updatedAt', () {
    final now = DateTime(2024, 1, 1);
    final originalTrack = track('1');
    final newTrack = track('2');
    final playlist = Playlist(
      id: 'p1',
      name: 'Mix',
      tracks: [originalTrack],
      updatedAt: now,
    );

    final updated = appendTrackToPlaylist(
      playlist,
      newTrack,
      now: () => DateTime(2024, 1, 2),
    );

    expect(updated.tracks.length, 2);
    expect(updated.tracks.last.id, '2');
    expect(updated.updatedAt, DateTime(2024, 1, 2));
  });

  test('renamePlaylist trims names and bumps updatedAt', () {
    final playlist = Playlist(
      id: 'p1',
      name: 'Road',
      updatedAt: DateTime(2024, 1, 1),
    );

    final updated = renamePlaylist(
      playlist,
      '  Night Drive  ',
      now: () => DateTime(2024, 1, 2),
    );

    expect(updated.name, 'Night Drive');
    expect(updated.updatedAt, DateTime(2024, 1, 2));
  });

  test('renamePlaylist ignores empty names', () {
    final playlist = Playlist(id: 'p1', name: 'Road');

    final updated = renamePlaylist(playlist, '   ');

    expect(updated.name, 'Road');
  });

  test('deletePlaylist removes only the matching playlist', () {
    final playlists = [
      Playlist(id: 'p1', name: 'One'),
      Playlist(id: 'p2', name: 'Two'),
    ];

    final updated = deletePlaylist(playlists, 'p1');

    expect(updated.map((playlist) => playlist.id), ['p2']);
  });

  test(
    'removeTrackFromPlaylist removes only the matching track and bumps updatedAt',
    () {
      final playlist = Playlist(
        id: 'p1',
        name: 'Mix',
        tracks: [track('1'), track('2'), track('3')],
        updatedAt: DateTime(2024, 1, 1),
      );

      final updated = removeTrackFromPlaylist(
        playlist,
        '2',
        now: () => DateTime(2024, 1, 2),
      );

      expect(updated.tracks.map((track) => track.id), ['1', '3']);
      expect(updated.updatedAt, DateTime(2024, 1, 2));
    },
  );

  test('reorderPlaylistTrack moves a track to the first position', () {
    final playlist = Playlist(
      id: 'p1',
      name: 'Mix',
      tracks: [track('1'), track('2'), track('3')],
    );

    final updated = reorderPlaylistTrack(
      playlist,
      fromIndex: 2,
      toIndex: 0,
      now: () => DateTime(2024, 1, 2),
    );

    expect(updated.tracks.map((track) => track.id), ['3', '1', '2']);
    expect(updated.updatedAt, DateTime(2024, 1, 2));
  });

  test('reorderPlaylistTrack moves a track to the last position', () {
    final playlist = Playlist(
      id: 'p1',
      name: 'Mix',
      tracks: [track('1'), track('2'), track('3')],
    );

    final updated = reorderPlaylistTrack(playlist, fromIndex: 0, toIndex: 2);

    expect(updated.tracks.map((track) => track.id), ['2', '3', '1']);
  });

  test('reorderPlaylistTrack ignores out-of-range indexes', () {
    final playlist = Playlist(
      id: 'p1',
      name: 'Mix',
      tracks: [track('1'), track('2')],
    );

    final updated = reorderPlaylistTrack(playlist, fromIndex: -1, toIndex: 1);

    expect(updated.tracks.map((track) => track.id), ['1', '2']);
  });
}
