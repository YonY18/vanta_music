import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/providers/domain/provider_identity.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_api_client.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_music_provider.dart';
import 'package:vanta_music/features/providers/infrastructure/subsonic_server_store.dart';

void main() {
  const server = SubsonicServerConfig(
    id: 'home',
    name: 'Home',
    baseUrl: 'https://music.example.test',
    username: 'alice',
  );

  test(
    'maps remote albums, artists, and songs with server-scoped ids',
    () async {
      final provider = SubsonicMusicProvider(
        server: server,
        client: _FakeSubsonicApiClient(
          artists: [
            SubsonicArtist(id: 'artist-1', name: 'Nina', albumCount: 2),
          ],
          albums: [
            SubsonicAlbum(
              id: 'album-1',
              title: 'Blue Room',
              artist: 'Nina',
              songCount: 9,
              coverArt: 'cover-1',
            ),
          ],
          songs: [
            SubsonicSong(
              id: 'song-1',
              title: 'Night Drive',
              artist: 'Nina',
              album: 'Blue Room',
              albumId: 'album-1',
              artistId: 'artist-1',
              durationSeconds: 245,
              coverArt: 'cover-1',
            ),
          ],
        ),
      );

      final artists = await provider.getArtists();
      final albums = await provider.getAlbums();
      final tracks = await provider.getTracks();

      expect(provider.id, subsonicProviderId('home'));
      expect(
        artists.single.id,
        remoteItemId(serverId: 'home', itemId: 'artist-1'),
      );
      expect(artists.single.providerId, subsonicProviderId('home'));
      expect(artists.single.albumCount, 2);
      expect(
        albums.single.id,
        remoteItemId(serverId: 'home', itemId: 'album-1'),
      );
      expect(albums.single.providerId, subsonicProviderId('home'));
      expect(albums.single.trackCount, 9);
      expect(
        tracks.single.id,
        remoteItemId(serverId: 'home', itemId: 'song-1'),
      );
      expect(tracks.single.providerId, subsonicProviderId('home'));
      expect(
        tracks.single.albumId,
        remoteItemId(serverId: 'home', itemId: 'album-1'),
      );
      expect(
        tracks.single.artistId,
        remoteItemId(serverId: 'home', itemId: 'artist-1'),
      );
      expect(tracks.single.duration, const Duration(seconds: 245));
      expect(tracks.single.uri.queryParameters['coverArtId'], 'cover-1');
    },
  );

  test(
    'search maps matching songs and resolveStream only returns stream URL',
    () async {
      final fakeClient = _FakeSubsonicApiClient(
        searchSongs: [
          SubsonicSong(
            id: 'song-2',
            title: 'Remote Only',
            artist: 'Mara',
            album: 'Clouds',
            durationSeconds: 180,
          ),
        ],
        configuredStreamUri: Uri.parse(
          'https://music.example.test/rest/stream.view?id=song-2&u=alice&s=salt&t=token',
        ),
      );
      final provider = SubsonicMusicProvider(
        server: server,
        client: fakeClient,
      );

      final results = await provider.search('remote');
      final stream = await provider.resolveStream(results.single);

      expect(results.single.title, 'Remote Only');
      expect(results.single.uri.scheme, 'subsonic');
      expect(results.single.uri.queryParameters['serverId'], 'home');
      expect(results.single.uri.queryParameters['id'], 'song-2');
      expect(stream.uri.path, '/rest/stream.view');
      expect(stream.uri.queryParameters['id'], 'song-2');
      expect(fakeClient.downloadRequests, 0);
    },
  );

  test('rejects stream resolution for a track from another provider', () async {
    final provider = SubsonicMusicProvider(
      server: server,
      client: _FakeSubsonicApiClient(),
    );

    await expectLater(
      provider.resolveStream(
        Track(
          id: 'local-1',
          providerId: localProviderId,
          title: 'Local',
          artist: 'Local Artist',
          album: 'Local Album',
          uri: Uri.file('/tmp/local.mp3'),
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}

class _FakeSubsonicApiClient implements SubsonicApiClientContract {
  _FakeSubsonicApiClient({
    this.artists = const [],
    this.albums = const [],
    this.songs = const [],
    this.searchSongs = const [],
    this.configuredStreamUri,
  });

  final List<SubsonicArtist> artists;
  final List<SubsonicAlbum> albums;
  final List<SubsonicSong> songs;
  final List<SubsonicSong> searchSongs;
  final Uri? configuredStreamUri;
  int downloadRequests = 0;

  @override
  Future<void> ping() async {}

  @override
  Future<List<SubsonicArtist>> getArtists() async => artists;

  @override
  Future<List<SubsonicAlbum>> getAlbumList2({
    String type = 'alphabeticalByName',
  }) async => albums;

  @override
  Future<SubsonicAlbumDetail> getAlbum(String id) async => SubsonicAlbumDetail(
    album: albums.firstWhere((album) => album.id == id),
    songs: songs.where((song) => song.albumId == id).toList(growable: false),
  );

  @override
  Future<SubsonicSong> getSong(String id) async =>
      songs.firstWhere((song) => song.id == id);

  @override
  Future<List<SubsonicSong>> search3(String query) async => searchSongs;

  @override
  Uri streamUri(String songId) =>
      configuredStreamUri ??
      Uri.parse('https://music.example.test/rest/stream.view?id=$songId');

  @override
  Uri getCoverArtUri(String coverArtId) => Uri.parse(
    'https://music.example.test/rest/getCoverArt.view?id=$coverArtId',
  );
}
