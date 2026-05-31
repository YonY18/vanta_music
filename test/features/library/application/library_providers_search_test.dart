import 'dart:async';

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

  test(
    'debounces remote search requests before calling the provider',
    () async {
      final calls = <String>[];
      final container = ProviderContainer(
        overrides: [
          remoteSearchDebounceDurationProvider.overrideWithValue(
            const Duration(milliseconds: 30),
          ),
          remoteTrackSearchProvider.overrideWithValue((query) async {
            calls.add(query);
            return [
              _track(
                id: query,
                providerId: 'subsonic:server-a',
                title: query,
                uri: Uri.parse('subsonic://track?serverId=server-a&id=$query'),
              ),
            ];
          }),
        ],
      );
      addTearDown(container.dispose);

      final listener = container.listen(
        remoteSearchStateProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(listener.close);

      container.read(remoteSearchStateProvider.notifier).setQuery('first');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      container.read(remoteSearchStateProvider.notifier).setQuery('second');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(calls, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(calls, ['second']);
      expect(
        container.read(remoteSearchStateProvider).tracks.single.id,
        'second',
      );
    },
  );

  test(
    'ignores stale remote search results after a newer query wins',
    () async {
      final oldCompleter = Completer<List<Track>>();
      final newCompleter = Completer<List<Track>>();
      final calls = <String>[];
      final container = ProviderContainer(
        overrides: [
          remoteSearchDebounceDurationProvider.overrideWithValue(Duration.zero),
          remoteTrackSearchProvider.overrideWithValue((query) {
            calls.add(query);
            if (query == 'old') return oldCompleter.future;
            return newCompleter.future;
          }),
        ],
      );
      addTearDown(container.dispose);

      final listener = container.listen(
        remoteSearchStateProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(listener.close);

      container.read(remoteSearchStateProvider.notifier).setQuery('old');
      await Future<void>.delayed(Duration.zero);
      container.read(remoteSearchStateProvider.notifier).setQuery('new');
      await Future<void>.delayed(Duration.zero);

      oldCompleter.complete([
        _track(
          id: 'old-result',
          providerId: 'subsonic:server-a',
          title: 'Old Result',
          uri: Uri.parse('subsonic://track?serverId=server-a&id=old-result'),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(calls, ['old', 'new']);
      expect(container.read(remoteSearchStateProvider).isLoading, true);
      expect(container.read(remoteSearchStateProvider).tracks, isEmpty);

      newCompleter.complete([
        _track(
          id: 'new-result',
          providerId: 'subsonic:server-a',
          title: 'New Result',
          uri: Uri.parse('subsonic://track?serverId=server-a&id=new-result'),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(remoteSearchStateProvider).tracks.single.id,
        'new-result',
      );
      expect(container.read(remoteSearchStateProvider).query, 'new');
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
