import '../../library/domain/album.dart';
import '../../library/domain/artist.dart';
import '../../library/domain/track.dart';
import 'stream_uri.dart';

abstract class MusicProvider {
  String get id;
  String get name;

  Future<List<Track>> search(String query);
  Future<List<Track>> getTracks();
  Future<StreamUri> resolveStream(Track track);

  Future<List<Album>> getAlbums() async => const [];
  Future<List<Artist>> getArtists() async => const [];
}
