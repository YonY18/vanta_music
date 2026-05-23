import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/playlists/application/playlists_controller.dart';
import 'package:vanta_music/features/playlists/domain/playlist.dart';

void main() {
  test('appendTrackToPlaylist keeps track IDs unique', () {
    final track = Track(
      id: '1',
      providerId: 'local',
      title: 'Song',
      artist: 'Artist',
      album: 'Album',
      uri: Uri.file('/song.mp3'),
    );
    final playlist = Playlist(id: 'p1', name: 'Mix', tracks: [track]);

    final updated = appendTrackToPlaylist(playlist, track);

    expect(updated.tracks.length, 1);
    expect(updated.tracks.first.id, '1');
  });

  test('appendTrackToPlaylist appends new track and bumps updatedAt', () {
    final now = DateTime(2024, 1, 1);
    final originalTrack = Track(
      id: '1',
      providerId: 'local',
      title: 'Song 1',
      artist: 'Artist',
      album: 'Album',
      uri: Uri.file('/song1.mp3'),
    );
    final newTrack = Track(
      id: '2',
      providerId: 'local',
      title: 'Song 2',
      artist: 'Artist',
      album: 'Album',
      uri: Uri.file('/song2.mp3'),
    );
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
}
