import 'package:on_audio_query/on_audio_query.dart';

import '../../library/domain/album.dart';
import '../../library/domain/artist.dart';
import '../../library/domain/track.dart';
import '../domain/music_provider.dart';
import '../domain/stream_uri.dart';

class LocalMusicProvider implements MusicProvider {
  LocalMusicProvider({OnAudioQuery? audioQuery})
    : _audioQuery = audioQuery ?? OnAudioQuery();

  final OnAudioQuery _audioQuery;

  @override
  String get id => 'local';

  @override
  String get name => 'Este dispositivo';

  @override
  Future<List<Track>> getTracks() async {
    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    return songs.where(_isSupported).map(_toTrack).toList(growable: false);
  }

  @override
  Future<List<Track>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return getTracks();

    final tracks = await getTracks();
    return tracks
        .where((track) {
          return track.title.toLowerCase().contains(normalized) ||
              track.artist.toLowerCase().contains(normalized) ||
              track.album.toLowerCase().contains(normalized);
        })
        .toList(growable: false);
  }

  @override
  Future<List<Album>> getAlbums() async {
    final albums = await _audioQuery.queryAlbums(
      sortType: AlbumSortType.ALBUM,
      orderType: OrderType.ASC_OR_SMALLER,
      ignoreCase: true,
    );

    return albums
        .map((album) {
          return Album(
            id: album.id.toString(),
            title: _clean(album.album),
            artist: _clean(album.artist),
            trackCount: album.numOfSongs,
            artworkId: album.id,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<Artist>> getArtists() async {
    final artists = await _audioQuery.queryArtists(
      sortType: ArtistSortType.ARTIST,
      orderType: OrderType.ASC_OR_SMALLER,
      ignoreCase: true,
    );

    return artists
        .map((artist) {
          return Artist(
            id: artist.id.toString(),
            name: _clean(artist.artist),
            trackCount: artist.numberOfTracks ?? 0,
            albumCount: artist.numberOfAlbums,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<StreamUri> resolveStream(Track track) async => StreamUri(track.uri);

  Track _toTrack(SongModel song) {
    final rawUri = song.uri?.trim().isNotEmpty == true ? song.uri! : song.data;
    final uri = rawUri.startsWith('content://') || rawUri.startsWith('file://')
        ? Uri.parse(rawUri)
        : Uri.file(rawUri);

    return Track(
      id: song.id.toString(),
      providerId: id,
      title: _clean(song.title),
      artist: _clean(song.artist),
      album: _clean(song.album),
      uri: uri,
      albumId: song.albumId?.toString(),
      artistId: song.artistId?.toString(),
      duration: song.duration == null
          ? null
          : Duration(milliseconds: song.duration!),
      artworkId: song.id,
    );
  }

  bool _isSupported(SongModel song) {
    final data = song.data.toLowerCase();
    return data.endsWith('.mp3') ||
        data.endsWith('.flac') ||
        data.endsWith('.ogg') ||
        data.endsWith('.m4a');
  }

  String _clean(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty || text == '<unknown>') {
      return 'Desconocido';
    }
    return text;
  }
}
