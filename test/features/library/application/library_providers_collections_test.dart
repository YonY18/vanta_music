import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/application/library_providers.dart';
import 'package:vanta_music/features/library/domain/track.dart';

void main() {
  test('albumsProvider and artistsProvider derive from unified tracksProvider', () async {
    final tracks = [
      Track(
        id: '1',
        providerId: 'folder',
        title: 'Song 1',
        artist: 'Band A',
        album: 'Alpha',
        uri: Uri.file('/music/a.mp3'),
      ),
      Track(
        id: '2',
        providerId: 'local',
        title: 'Song 2',
        artist: 'Band A',
        album: 'Alpha',
        uri: Uri.parse('content://song/2'),
      ),
    ];

    final container = ProviderContainer(
      overrides: [tracksProvider.overrideWith((ref) async => tracks)],
    );
    addTearDown(container.dispose);

    await container.read(tracksProvider.future);

    final albums = container.read(albumsProvider);
    final artists = container.read(artistsProvider);

    expect(albums.length, 1);
    expect(albums.first.trackCount, 2);
    expect(artists.length, 1);
    expect(artists.first.trackCount, 2);
  });

  test('albumTracksProvider and artistTracksProvider expose playable subsets', () async {
    final tracks = [
      Track(
        id: '1',
        providerId: 'local',
        title: 'A',
        artist: 'Band A',
        artistId: '20',
        album: 'Alpha',
        albumId: '10',
        uri: Uri.parse('content://song/1'),
      ),
      Track(
        id: '2',
        providerId: 'local',
        title: 'B',
        artist: 'Band B',
        artistId: '21',
        album: 'Beta',
        albumId: '11',
        uri: Uri.parse('content://song/2'),
      ),
    ];

    final container = ProviderContainer(
      overrides: [tracksProvider.overrideWith((ref) async => tracks)],
    );
    addTearDown(container.dispose);

    await container.read(tracksProvider.future);

    final albumTracks = container.read(albumTracksProvider('10'));
    final artistTracks = container.read(artistTracksProvider('21'));

    expect(albumTracks.length, 1);
    expect(albumTracks.single.id, '1');
    expect(artistTracks.length, 1);
    expect(artistTracks.single.id, '2');
  });
}
