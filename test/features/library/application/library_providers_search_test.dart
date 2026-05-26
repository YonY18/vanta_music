import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/application/library_providers.dart';
import 'package:vanta_music/features/library/domain/album.dart';
import 'package:vanta_music/features/library/domain/artist.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/providers/domain/music_provider.dart';
import 'package:vanta_music/features/providers/domain/stream_uri.dart';

void main() {
  test(
    'filteredTracksProvider recomputes by query over prepared tracks',
    () async {
      final tracks = [
        Track(
          id: '1',
          providerId: 'local',
          title: 'Night Train',
          artist: 'Vanta',
          album: 'Noir',
          uri: Uri.parse('file:///music/1.mp3'),
        ),
        Track(
          id: '2',
          providerId: 'local',
          title: 'Morning Sun',
          artist: 'Aurora',
          album: 'Dawn',
          uri: Uri.parse('file:///music/2.mp3'),
        ),
      ];

      final container = ProviderContainer(
        overrides: [tracksProvider.overrideWith((ref) async => tracks)],
      );
      addTearDown(container.dispose);

      await container.read(tracksProvider.future);

      final all = container.read(filteredTracksProvider(''));
      final filtered = container.read(filteredTracksProvider('vanta'));

      expect(all.length, 2);
      expect(filtered.length, 1);
      expect(filtered.single.id, '1');
    },
  );

  test('file validation cache invalidates entries explicitly', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cache = container.read(fileValidationCacheProvider);

    final uri = Uri.parse('file:///music/cache.mp3');
    await cache.validate(uri);
    expect(cache.read(uri), isNotNull);

    cache.invalidateAll();
    expect(cache.read(uri), isNull);
  });

  test(
    'remote tracks load from a dedicated provider without joining local search',
    () async {
      final localTrack = _track(
        id: 'local-1',
        providerId: 'local',
        title: 'Remote Dreams',
        uri: Uri.parse('file:///music/local.mp3'),
      );
      final remoteTrack = _track(
        id: 'subsonic:server-a:remote-1',
        providerId: 'subsonic:server-a',
        title: 'Remote Dreams',
        uri: Uri.parse('subsonic://track?serverId=server-a&id=remote-1'),
      );
      final container = ProviderContainer(
        overrides: [
          tracksProvider.overrideWith((ref) async => [localTrack]),
          activeRemoteMusicProvider.overrideWithValue(
            _FakeMusicProvider([remoteTrack]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(tracksProvider.future);
      final remoteTracks = await container.read(
        remoteLibraryTracksProvider.future,
      );

      expect(
        container
            .read(filteredTracksProvider('remote'))
            .map((track) => track.id),
        ['local-1'],
      );
      expect(remoteTracks.map((track) => track.id), [
        'subsonic:server-a:remote-1',
      ]);
      expect(
        container
            .read(filteredRemoteTracksProvider('remote'))
            .map((track) => track.id),
        ['subsonic:server-a:remote-1'],
      );
    },
  );
}

Track _track({
  required String id,
  required String providerId,
  required String title,
  required Uri uri,
}) {
  return Track(
    id: id,
    providerId: providerId,
    title: title,
    artist: 'Artist',
    album: 'Album',
    uri: uri,
  );
}

class _FakeMusicProvider implements MusicProvider {
  const _FakeMusicProvider(this.tracks);

  final List<Track> tracks;

  @override
  String get id => 'subsonic:server-a';

  @override
  String get name => 'Navidrome';

  @override
  Future<List<Track>> getTracks() async => tracks;

  @override
  Future<List<Album>> getAlbums() async => const [];

  @override
  Future<List<Artist>> getArtists() async => const [];

  @override
  Future<List<Track>> search(String query) async => tracks
      .where((track) => track.title.toLowerCase().contains(query.toLowerCase()))
      .toList(growable: false);

  @override
  Future<StreamUri> resolveStream(Track track) async => StreamUri(track.uri);
}
