import '../domain/album.dart';
import '../domain/artist.dart';
import '../domain/track.dart';

List<Track> filterLibraryNoiseTracks(List<Track> tracks) {
  return tracks.where((track) => !_isLikelyVoiceNote(track)).toList(growable: false);
}

List<Album> buildAlbumsFromTracks(List<Track> tracks) {
  final grouped = <String, _AlbumBucket>{};
  for (final track in tracks) {
    final albumTitle = _cleanAlbum(track.album);
    final artistName = _cleanArtist(track.artist);
    final key = albumGroupKey(track);

    final current = grouped[key];
    if (current == null) {
      grouped[key] = _AlbumBucket(
        id: track.albumId?.trim().isNotEmpty == true ? track.albumId! : key,
        title: albumTitle,
        artist: artistName,
        artworkId: track.artworkId,
      )..trackCount = 1;
    } else {
      current.trackCount += 1;
      current.artworkId ??= track.artworkId;
    }
  }

  final albums = grouped.values
      .map(
        (bucket) => Album(
          id: bucket.id,
          title: bucket.title,
          artist: bucket.artist,
          trackCount: bucket.trackCount,
          artworkId: bucket.artworkId,
        ),
      )
      .toList(growable: false)
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return albums;
}

List<Artist> buildArtistsFromTracks(List<Track> tracks) {
  final grouped = <String, _ArtistBucket>{};
  for (final track in tracks) {
    final artistName = _cleanArtist(track.artist);
    final key = artistGroupKey(track);
    final albumKey = _cleanAlbum(track.album).toLowerCase();

    final current = grouped[key];
    if (current == null) {
      grouped[key] = _ArtistBucket(
        id: track.artistId?.trim().isNotEmpty == true ? track.artistId! : key,
        name: artistName,
      )
        ..trackCount = 1
        ..albums.add(albumKey);
    } else {
      current.trackCount += 1;
      current.albums.add(albumKey);
    }
  }

  final artists = grouped.values
      .map(
        (bucket) => Artist(
          id: bucket.id,
          name: bucket.name,
          trackCount: bucket.trackCount,
          albumCount: bucket.albums.length,
        ),
      )
      .toList(growable: false)
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return artists;
}

String albumGroupKey(Track track) {
  if (track.albumId?.trim().isNotEmpty == true) return track.albumId!;
  return 'name:${_cleanAlbum(track.album)}|artist:${_cleanArtist(track.artist)}'
      .toLowerCase();
}

String artistGroupKey(Track track) {
  if (track.artistId?.trim().isNotEmpty == true) return track.artistId!;
  return 'name:${_cleanArtist(track.artist)}'.toLowerCase();
}

String _cleanArtist(String value) {
  final text = value.trim();
  if (text.isEmpty || text == '<unknown>' || text.toLowerCase() == 'unknown') {
    return 'Desconocido';
  }
  return text;
}

String _cleanAlbum(String value) {
  final text = value.trim();
  if (text.isEmpty || text == '<unknown>' || text.toLowerCase() == 'unknown') {
    return 'Sin álbum';
  }
  return text;
}

bool _isLikelyVoiceNote(Track track) {
  final source = '${track.uri.toString()} ${track.title} ${track.album} ${track.artist}'.toLowerCase();
  final pathMatch = source.contains('/whatsapp/') &&
      (source.contains('voice notes') || source.contains('ptt') || source.contains('opus'));
  final titleMatch = source.contains('ptt-') || source.contains('whatsapp audio');
  return pathMatch || titleMatch;
}

class _AlbumBucket {
  _AlbumBucket({
    required this.id,
    required this.title,
    required this.artist,
    required this.artworkId,
  });

  final String id;
  final String title;
  final String artist;
  int trackCount = 0;
  int? artworkId;
}

class _ArtistBucket {
  _ArtistBucket({required this.id, required this.name});

  final String id;
  final String name;
  int trackCount = 0;
  final Set<String> albums = <String>{};
}
