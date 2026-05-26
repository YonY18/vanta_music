import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/application/library_collections.dart';
import 'package:vanta_music/features/library/domain/album.dart';
import 'package:vanta_music/features/library/domain/artist.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/providers/domain/provider_identity.dart';

void main() {
  test('filters WhatsApp voice notes but keeps regular music files', () {
    final tracks = [
      Track(
        id: '1',
        providerId: 'local',
        title: 'PTT-20260522-WA0001',
        artist: 'Desconocido',
        album: 'Desconocido',
        uri: Uri.file(
          '/storage/emulated/0/WhatsApp/Media/WhatsApp Voice Notes/PTT-20260522-WA0001.opus',
        ),
      ),
      Track(
        id: '2',
        providerId: 'local',
        title: 'My Song',
        artist: 'Band',
        album: 'Album',
        uri: Uri.file('/storage/emulated/0/Music/Band/my_song.mp3'),
      ),
    ];

    final filtered = filterLibraryNoiseTracks(tracks);
    expect(filtered.length, 1);
    expect(filtered.single.id, '2');
  });

  test(
    'buildAlbumsFromTracks groups with fallback values when missing metadata',
    () {
      final tracks = [
        Track(
          id: '1',
          providerId: 'folder',
          title: 'a',
          artist: '',
          album: '',
          uri: Uri.file('/music/folder/one.mp3'),
        ),
        Track(
          id: '2',
          providerId: 'local',
          title: 'b',
          artist: 'Artist A',
          album: 'Album A',
          albumId: '10',
          artworkId: 11,
          uri: Uri.parse('content://media/external/audio/media/2'),
        ),
        Track(
          id: '3',
          providerId: 'local',
          title: 'c',
          artist: 'Artist A',
          album: 'Album A',
          albumId: '10',
          artworkId: 12,
          uri: Uri.parse('content://media/external/audio/media/3'),
        ),
      ];

      final albums = buildAlbumsFromTracks(tracks);
      expect(albums.length, 2);
      expect(albums.first.id, '10');
      expect(albums.first.trackCount, 2);
      expect(albums.first.artist, 'Artist A');
      expect(albums.last.title, 'Sin álbum');
      expect(albums.last.artist, 'Desconocido');
    },
  );

  test('buildArtistsFromTracks counts tracks and unique albums', () {
    final tracks = [
      Track(
        id: '1',
        providerId: 'local',
        title: 'a',
        artist: 'Artist A',
        album: 'One',
        uri: Uri.parse('content://1'),
      ),
      Track(
        id: '2',
        providerId: 'local',
        title: 'b',
        artist: 'Artist A',
        album: 'Two',
        uri: Uri.parse('content://2'),
      ),
      Track(
        id: '3',
        providerId: 'folder',
        title: 'c',
        artist: '',
        album: '',
        uri: Uri.file('/music/x.mp3'),
      ),
    ];

    final artists = buildArtistsFromTracks(tracks);
    expect(artists.length, 2);
    expect(artists.first.name, 'Artist A');
    expect(artists.first.trackCount, 2);
    expect(artists.first.albumCount, 2);
    expect(artists.last.name, 'Desconocido');
  });

  test('album and artist default to local provider identity', () {
    const album = Album(
      id: '10',
      title: 'Album A',
      artist: 'Artist A',
      trackCount: 2,
    );
    const artist = Artist(id: '20', name: 'Artist A', trackCount: 2);

    expect(album.providerId, localProviderId);
    expect(artist.providerId, localProviderId);
  });

  test('collection grouping keeps remote and local ids separate', () {
    final tracks = [
      Track(
        id: 'local-track',
        providerId: localProviderId,
        title: 'Local',
        artist: 'Artist A',
        album: 'Album A',
        albumId: '10',
        artistId: '20',
        uri: Uri.file('/music/local.mp3'),
      ),
      Track(
        id: remoteItemId(serverId: 'home', itemId: 'local-track'),
        providerId: subsonicProviderId('home'),
        title: 'Remote',
        artist: 'Artist A',
        album: 'Album A',
        albumId: '10',
        artistId: '20',
        uri: Uri.parse('subsonic://home/song/local-track'),
      ),
    ];

    final albums = buildAlbumsFromTracks(tracks);
    final artists = buildArtistsFromTracks(tracks);

    expect(albums.map((album) => album.providerId), [
      localProviderId,
      'subsonic:home',
    ]);
    expect(albums.map((album) => album.id), ['10', '10']);
    expect(artists.map((artist) => artist.providerId), [
      localProviderId,
      'subsonic:home',
    ]);
    expect(artists.map((artist) => artist.id), ['20', '20']);
  });
}
