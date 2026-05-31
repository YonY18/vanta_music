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

  test(
    'writes fresh remote snapshots using server and provider scope',
    () async {
      final snapshotStore = InMemoryRemoteLibrarySnapshotStore();
      final provider = SubsonicMusicProvider(
        server: server,
        client: _FakeSubsonicApiClient(
          albums: [
            const SubsonicAlbum(
              id: 'album-1',
              title: 'Blue Room',
              artist: 'Nina',
            ),
          ],
          songs: [
            const SubsonicSong(
              id: 'song-1',
              title: 'Night Drive',
              artist: 'Nina',
              album: 'Blue Room',
              albumId: 'album-1',
            ),
          ],
        ),
        snapshotStore: snapshotStore,
        clock: () => DateTime.utc(2026, 5, 30, 21, 0),
      );

      final snapshot = await provider.loadTrackSnapshot();

      expect(snapshot.serverId, 'home');
      expect(snapshot.providerId, subsonicProviderId('home'));
      expect(snapshot.isStale, isFalse);
      expect(snapshot.isPartial, isFalse);
      expect(snapshot.lastSyncAt, DateTime.utc(2026, 5, 30, 21, 0));
      expect(
        snapshot.tracks.single.id,
        remoteItemId(serverId: 'home', itemId: 'song-1'),
      );

      final cached = await snapshotStore.read(
        serverId: 'home',
        providerId: subsonicProviderId('home'),
      );
      expect(
        cached?.tracks.single.id,
        remoteItemId(serverId: 'home', itemId: 'song-1'),
      );
    },
  );

  test('bounds remote hydration to the configured album window', () async {
    final client = _FakeSubsonicApiClient(
      albums: const [
        SubsonicAlbum(id: 'album-1', title: 'One', artist: 'Nina'),
        SubsonicAlbum(id: 'album-2', title: 'Two', artist: 'Nina'),
        SubsonicAlbum(id: 'album-3', title: 'Three', artist: 'Nina'),
      ],
      songs: const [
        SubsonicSong(
          id: 'song-1',
          title: 'Track 1',
          artist: 'Nina',
          album: 'One',
          albumId: 'album-1',
        ),
        SubsonicSong(
          id: 'song-2',
          title: 'Track 2',
          artist: 'Nina',
          album: 'Two',
          albumId: 'album-2',
        ),
        SubsonicSong(
          id: 'song-3',
          title: 'Track 3',
          artist: 'Nina',
          album: 'Three',
          albumId: 'album-3',
        ),
      ],
    );
    final provider = SubsonicMusicProvider(
      server: server,
      client: client,
      remoteAlbumHydrationLimit: 2,
    );

    final snapshot = await provider.loadTrackSnapshot();

    expect(client.lastAlbumListSize, 2);
    expect(client.albumDetailRequests, ['album-1', 'album-2']);
    expect(snapshot.isPartial, isTrue);
    expect(snapshot.tracks.map((track) => track.title), ['Track 1', 'Track 2']);
  });

  test(
    'returns stale cached tracks for the active server only when unavailable',
    () async {
      final snapshotStore = InMemoryRemoteLibrarySnapshotStore(
        snapshots: [
          RemoteLibrarySnapshot(
            serverId: 'home',
            providerId: subsonicProviderId('home'),
            tracks: [
              Track(
                id: remoteItemId(serverId: 'home', itemId: 'song-1'),
                providerId: subsonicProviderId('home'),
                title: 'Cached Home Song',
                artist: 'Nina',
                album: 'Blue Room',
                uri: Uri.parse('subsonic://track?serverId=home&id=song-1'),
              ),
            ],
            lastSyncAt: DateTime.utc(2026, 5, 29, 18, 30),
            isStale: false,
          ),
          RemoteLibrarySnapshot(
            serverId: 'work',
            providerId: subsonicProviderId('work'),
            tracks: [
              Track(
                id: remoteItemId(serverId: 'work', itemId: 'song-9'),
                providerId: subsonicProviderId('work'),
                title: 'Wrong Server Song',
                artist: 'Mara',
                album: 'Clouds',
                uri: Uri.parse('subsonic://track?serverId=work&id=song-9'),
              ),
            ],
            lastSyncAt: DateTime.utc(2026, 5, 28, 12, 0),
            isStale: false,
          ),
        ],
      );
      final provider = SubsonicMusicProvider(
        server: server,
        client: _FakeSubsonicApiClient(
          unavailableError: const SubsonicUnavailableFailure('Server is down'),
        ),
        snapshotStore: snapshotStore,
      );

      final snapshot = await provider.loadTrackSnapshot();

      expect(snapshot.isStale, isTrue);
      expect(snapshot.failure, isA<SubsonicUnavailableFailure>());
      expect(snapshot.lastSyncAt, DateTime.utc(2026, 5, 29, 18, 30));
      expect(snapshot.tracks.single.title, 'Cached Home Song');
    },
  );
}

class _FakeSubsonicApiClient implements SubsonicApiClientContract {
  _FakeSubsonicApiClient({
    this.artists = const [],
    this.albums = const [],
    this.songs = const [],
    this.searchSongs = const [],
    this.configuredStreamUri,
    this.unavailableError,
  });

  final List<SubsonicArtist> artists;
  final List<SubsonicAlbum> albums;
  final List<SubsonicSong> songs;
  final List<SubsonicSong> searchSongs;
  final Uri? configuredStreamUri;
  final Object? unavailableError;
  int downloadRequests = 0;
  int? lastAlbumListSize;
  final List<String> albumDetailRequests = <String>[];

  @override
  Future<void> ping() async {}

  @override
  Future<List<SubsonicArtist>> getArtists() async => artists;

  @override
  Future<List<SubsonicAlbum>> getAlbumList2({
    String type = 'alphabeticalByName',
    int? size,
    int? offset,
  }) async {
    if (unavailableError != null) throw unavailableError!;
    lastAlbumListSize = size;
    final start = offset ?? 0;
    final bounded = albums.skip(start);
    if (size == null) return bounded.toList(growable: false);
    return bounded.take(size).toList(growable: false);
  }

  @override
  Future<SubsonicAlbumDetail> getAlbum(String id) async {
    albumDetailRequests.add(id);
    return SubsonicAlbumDetail(
      album: albums.firstWhere((album) => album.id == id),
      songs: songs.where((song) => song.albumId == id).toList(growable: false),
    );
  }

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
