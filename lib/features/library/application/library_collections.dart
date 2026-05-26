import '../domain/album.dart';
import '../domain/artist.dart';
import '../domain/track.dart';
import '../../providers/domain/provider_identity.dart';

List<Track> filterLibraryNoiseTracks(List<Track> tracks) {
  return tracks
      .where((track) => !_isLikelyVoiceNote(track))
      .toList(growable: false);
}

List<Album> buildAlbumsFromTracks(List<Track> tracks) {
  final grouped = <String, _AlbumBucket>{};
  for (final track in tracks) {
    final albumTitle = _cleanAlbum(track.album);
    final artistName = _cleanArtist(track.artist);
    final providerId = collectionProviderId(track.providerId);
    final key = albumGroupKey(track);

    final current = grouped[key];
    if (current == null) {
      grouped[key] = _AlbumBucket(
        id: track.albumId?.trim().isNotEmpty == true ? track.albumId! : key,
        providerId: providerId,
        title: albumTitle,
        artist: artistName,
        artworkId: track.artworkId,
      )..trackCount = 1;
    } else {
      current.trackCount += 1;
      current.artworkId ??= track.artworkId;
    }
  }

  final albums =
      grouped.values
          .map(
            (bucket) => Album(
              id: bucket.id,
              providerId: bucket.providerId,
              title: bucket.title,
              artist: bucket.artist,
              trackCount: bucket.trackCount,
              artworkId: bucket.artworkId,
            ),
          )
          .toList(growable: false)
        ..sort((a, b) {
          final byTitle = a.title.toLowerCase().compareTo(
            b.title.toLowerCase(),
          );
          if (byTitle != 0) return byTitle;
          return a.providerId.compareTo(b.providerId);
        });
  return albums;
}

List<Artist> buildArtistsFromTracks(List<Track> tracks) {
  final grouped = <String, _ArtistBucket>{};
  for (final track in tracks) {
    final artistName = _cleanArtist(track.artist);
    final providerId = collectionProviderId(track.providerId);
    final key = artistGroupKey(track);
    final albumKey = _cleanAlbum(track.album).toLowerCase();

    final current = grouped[key];
    if (current == null) {
      grouped[key] =
          _ArtistBucket(
              id: track.artistId?.trim().isNotEmpty == true
                  ? track.artistId!
                  : key,
              providerId: providerId,
              name: artistName,
            )
            ..trackCount = 1
            ..albums.add(albumKey);
    } else {
      current.trackCount += 1;
      current.albums.add(albumKey);
    }
  }

  final artists =
      grouped.values
          .map(
            (bucket) => Artist(
              id: bucket.id,
              providerId: bucket.providerId,
              name: bucket.name,
              trackCount: bucket.trackCount,
              albumCount: bucket.albums.length,
            ),
          )
          .toList(growable: false)
        ..sort((a, b) {
          final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          if (byName != 0) return byName;
          return a.providerId.compareTo(b.providerId);
        });
  return artists;
}

String albumGroupKey(Track track) {
  final providerId = collectionProviderId(track.providerId);
  if (track.albumId?.trim().isNotEmpty == true) {
    if (providerId == localProviderId) return track.albumId!;
    return '$providerId|${track.albumId!}';
  }
  return '$providerId|name:${_cleanAlbum(track.album)}|artist:${_cleanArtist(track.artist)}'
      .toLowerCase();
}

String artistGroupKey(Track track) {
  final providerId = collectionProviderId(track.providerId);
  if (track.artistId?.trim().isNotEmpty == true) {
    if (providerId == localProviderId) return track.artistId!;
    return '$providerId|${track.artistId!}';
  }
  return '$providerId|name:${_cleanArtist(track.artist)}'.toLowerCase();
}

String collectionProviderId(String providerId) {
  return providerId.startsWith('$subsonicProviderPrefix:')
      ? providerId
      : localProviderId;
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
  final source =
      '${track.uri.toString()} ${track.title} ${track.album} ${track.artist}'
          .toLowerCase();
  final pathMatch =
      source.contains('/whatsapp/') &&
      (source.contains('voice notes') ||
          source.contains('ptt') ||
          source.contains('opus'));
  final titleMatch =
      source.contains('ptt-') || source.contains('whatsapp audio');
  return pathMatch || titleMatch;
}

class _AlbumBucket {
  _AlbumBucket({
    required this.id,
    required this.providerId,
    required this.title,
    required this.artist,
    required this.artworkId,
  });

  final String id;
  final String providerId;
  final String title;
  final String artist;
  int trackCount = 0;
  int? artworkId;
}

class _ArtistBucket {
  _ArtistBucket({
    required this.id,
    required this.providerId,
    required this.name,
  });

  final String id;
  final String providerId;
  final String name;
  int trackCount = 0;
  final Set<String> albums = <String>{};
}
