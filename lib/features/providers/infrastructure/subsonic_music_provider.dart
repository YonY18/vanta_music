import '../../library/domain/album.dart';
import '../../library/domain/artist.dart';
import '../../library/domain/track.dart';
import '../domain/music_provider.dart';
import '../domain/provider_identity.dart';
import '../domain/stream_uri.dart';
import 'subsonic_api_client.dart';
import 'subsonic_server_store.dart';

class SubsonicMusicProvider implements MusicProvider {
  const SubsonicMusicProvider({required this.server, required this.client});

  final SubsonicServerConfig server;
  final SubsonicApiClientContract client;

  @override
  String get id => subsonicProviderId(server.id);

  @override
  String get name => server.name;

  @override
  Future<List<Artist>> getArtists() async {
    final artists = await client.getArtists();
    return artists
        .map(
          (artist) => Artist(
            id: remoteItemId(serverId: server.id, itemId: artist.id),
            providerId: id,
            name: artist.name,
            trackCount: 0,
            albumCount: artist.albumCount,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<Album>> getAlbums() async {
    final albums = await client.getAlbumList2();
    return albums.map(_mapAlbum).toList(growable: false);
  }

  @override
  Future<List<Track>> getTracks() async {
    final albums = await client.getAlbumList2();
    final tracks = <Track>[];
    for (final album in albums) {
      final detail = await client.getAlbum(album.id);
      tracks.addAll(detail.songs.map(_mapSong));
    }
    return tracks;
  }

  @override
  Future<List<Track>> search(String query) async {
    final songs = await client.search3(query);
    return songs.map(_mapSong).toList(growable: false);
  }

  @override
  Future<StreamUri> resolveStream(Track track) async {
    if (track.providerId != id) {
      throw ArgumentError.value(
        track.providerId,
        'track.providerId',
        'does not belong to this Subsonic provider',
      );
    }
    final songId = _rawSongId(track);
    return StreamUri(client.streamUri(songId));
  }

  Uri coverArtUri(String coverArtId) => client.getCoverArtUri(coverArtId);

  Album _mapAlbum(SubsonicAlbum album) => Album(
    id: remoteItemId(serverId: server.id, itemId: album.id),
    providerId: id,
    title: album.title,
    artist: album.artist,
    trackCount: album.songCount ?? 0,
  );

  Track _mapSong(SubsonicSong song) => Track(
    id: remoteItemId(serverId: server.id, itemId: song.id),
    providerId: id,
    title: song.title,
    artist: song.artist,
    album: song.album,
    uri: Uri(
      scheme: 'subsonic',
      host: 'track',
      queryParameters: <String, String>{
        'serverId': server.id,
        'id': song.id,
        if (song.coverArt != null && song.coverArt!.isNotEmpty)
          'coverArtId': song.coverArt!,
      },
    ),
    albumId: song.albumId == null
        ? null
        : remoteItemId(serverId: server.id, itemId: song.albumId!),
    artistId: song.artistId == null
        ? null
        : remoteItemId(serverId: server.id, itemId: song.artistId!),
    duration: song.durationSeconds == null
        ? null
        : Duration(seconds: song.durationSeconds!),
  );

  String _rawSongId(Track track) {
    final uriId = track.uri.queryParameters['id'];
    if (track.uri.scheme == 'subsonic' && uriId != null && uriId.isNotEmpty) {
      return uriId;
    }
    final prefix = '$subsonicProviderPrefix:${server.id}:';
    if (track.id.startsWith(prefix)) return track.id.substring(prefix.length);
    throw ArgumentError.value(
      track.id,
      'track.id',
      'is not a server-scoped Subsonic track id',
    );
  }
}
