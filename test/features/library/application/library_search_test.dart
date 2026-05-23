import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/application/library_search.dart';
import 'package:vanta_music/features/library/domain/track.dart';

void main() {
  final tracks = [
    Track(
      id: '1',
      providerId: 'local',
      title: 'Neon Skyline',
      artist: 'Vanta',
      album: 'Night Drive',
      uri: Uri.parse('file:///music/1.mp3'),
    ),
    Track(
      id: '2',
      providerId: 'local',
      title: 'Morning Glow',
      artist: 'Aurora',
      album: 'Daybreak',
      uri: Uri.parse('file:///music/2.mp3'),
    ),
  ];

  test('returns full list when query is empty/whitespace', () {
    final results = filterTracksForQuery(tracks, '   ');

    expect(results.length, 2);
    expect(results.first.id, '1');
    expect(results.last.id, '2');
  });

  test('matches query across title/artist/album with normalization', () {
    final byTitle = filterTracksForQuery(tracks, ' skyline ');
    final byArtist = filterTracksForQuery(tracks, 'aUrOrA');
    final byAlbum = filterTracksForQuery(tracks, 'night');

    expect(byTitle.length, 1);
    expect(byTitle.single.id, '1');

    expect(byArtist.length, 1);
    expect(byArtist.single.id, '2');

    expect(byAlbum.length, 1);
    expect(byAlbum.single.id, '1');
  });
}
