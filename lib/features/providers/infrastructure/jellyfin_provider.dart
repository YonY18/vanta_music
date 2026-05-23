import '../../library/domain/album.dart';
import '../../library/domain/artist.dart';
import '../../library/domain/track.dart';
import '../domain/music_provider.dart';
import '../domain/stream_uri.dart';

class JellyfinProvider implements MusicProvider {
  @override
  String get id => 'jellyfin';

  @override
  String get name => 'Jellyfin';

  @override
  Future<List<Track>> getTracks() async => const [];

  @override
  Future<List<Album>> getAlbums() async => const [];

  @override
  Future<List<Artist>> getArtists() async => const [];

  @override
  Future<List<Track>> search(String query) async => const [];

  @override
  Future<StreamUri> resolveStream(Track track) =>
      throw UnimplementedError('Jellyfin todavía no forma parte del MVP.');
}
