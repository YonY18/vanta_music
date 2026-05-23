import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/library/presentation/library_track_favorites.dart';

void main() {
  test('maps tracks to favorite flags using stable keys', () {
    final tracks = [
      Track(
        id: '1',
        providerId: 'local',
        title: 'Song 1',
        artist: 'Artist',
        album: 'Album',
        uri: Uri.parse('content://song/1'),
      ),
      Track(
        id: '2',
        providerId: 'local',
        title: 'Song 2',
        artist: 'Artist',
        album: 'Album',
        uri: Uri.parse('content://song/2'),
      ),
    ];

    final flags = mapTrackFavoriteFlags(
      tracks: tracks,
      favoriteTrackKeys: {'local::2'},
    );

    expect(flags, [false, true]);
  });

  test('returns empty flags for empty tracks list', () {
    final flags = mapTrackFavoriteFlags(
      tracks: const [],
      favoriteTrackKeys: {'local::2'},
    );

    expect(flags, isEmpty);
  });
}
