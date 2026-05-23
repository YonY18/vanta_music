import '../../library/domain/album.dart';
import '../../library/domain/artist.dart';
import '../../library/domain/track.dart';
import '../domain/music_provider.dart';
import '../domain/stream_uri.dart';

class YoutubeMusicExperimentalProvider implements MusicProvider {
  @override
  String get id => 'youtube_music_experimental';

  @override
  String get name => 'YouTube Music Experimental';

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
      throw UnimplementedError('No se usan APIs no oficiales en el MVP.');
}
