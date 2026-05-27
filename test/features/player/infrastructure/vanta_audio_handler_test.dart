import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/player/infrastructure/vanta_audio_handler.dart';

void main() {
  group('VantaAudioHandler queue helpers', () {
    test(
      'removes a queued item by media id while preserving the remaining order',
      () {
        final queue = [_item('a'), _item('b'), _item('c')];

        final result = VantaAudioHandler.removeQueueItems(queue, 'b');

        expect(result.map((item) => item.id), ['a', 'c']);
      },
    );

    test('ignores remove commands for unknown media ids', () {
      final queue = [_item('a'), _item('b')];

      final result = VantaAudioHandler.removeQueueItems(queue, 'missing');

      expect(result.map((item) => item.id), ['a', 'b']);
    });

    test('inserts play-next after the current queue index', () {
      final queue = [_item('a'), _item('b'), _item('c')];
      final next = _item('next');

      final result = VantaAudioHandler.insertPlayNext(
        queue,
        next,
        currentIndex: 1,
      );

      expect(result.map((item) => item.id), ['a', 'b', 'next', 'c']);
    });

    test('adds new items to the end of the queue', () {
      final queue = [_item('a')];

      final result = VantaAudioHandler.appendToQueueEnd(queue, _item('end'));

      expect(result.map((item) => item.id), ['a', 'end']);
    });

    test('converts tracks to queue media items with provider extras', () {
      final result = VantaAudioHandler.mediaItemFromTrack(
        _track('42', 'file:///queue/song.mp3'),
      );

      expect(result.id, 'file:///queue/song.mp3');
      expect(result.title, 'Track 42');
      expect(result.extras, containsPair('trackId', '42'));
      expect(result.extras, containsPair('providerId', 'local'));
    });

    test(
      'resolves remote queue items at playback time while keeping canonical media ids',
      () async {
        final local = VantaAudioHandler.mediaItemFromTrack(
          _track('local-1', 'file:///queue/local.mp3'),
        );
        final remote = VantaAudioHandler.mediaItemFromTrack(
          _track(
            'subsonic:server-a:remote-1',
            'subsonic://track?serverId=server-a&id=remote-1',
            providerId: 'subsonic:server-a',
          ),
        );
        final registry = _FakeStreamResolverRegistry({
          'subsonic:server-a::subsonic:server-a:remote-1': Uri.parse(
            'https://music.example/rest/stream.view?id=remote-1&t=secret-token',
          ),
        });

        final sources = await VantaAudioHandler.resolveQueueItemUris([
          local,
          remote,
        ], registry);

        expect(sources, [
          Uri.parse('file:///queue/local.mp3'),
          Uri.parse(
            'https://music.example/rest/stream.view?id=remote-1&t=secret-token',
          ),
        ]);
        expect(remote.id, 'subsonic://track?serverId=server-a&id=remote-1');
        expect(registry.requests, [
          'subsonic:server-a::subsonic:server-a:remote-1',
        ]);
      },
    );

    for (final providerId in [null, '', 'local']) {
      test(
        'routes Subsonic item with ${providerId ?? 'missing'} providerId through resolver',
        () async {
          final item = MediaItem(
            id: 'subsonic://track?serverId=server-a&id=remote-1',
            title: 'Remote track',
            extras: providerId == null ? null : {'providerId': providerId},
          );
          final registry = _FailClosedStreamResolverRegistry();

          await expectLater(
            VantaAudioHandler.resolveQueueItemUris([item], registry),
            throwsA(isA<StateError>()),
          );

          expect(registry.requests, [item.id]);
        },
      );
    }

    test(
      'routes Subsonic canonicalUri through resolver even when media id is local',
      () async {
        final item = MediaItem(
          id: 'file:///queue/stale-local.mp3',
          title: 'Remote track',
          extras: const {
            'providerId': 'local',
            'canonicalUri': 'subsonic://track?serverId=server-a&id=remote-1',
          },
        );
        final registry = _FailClosedStreamResolverRegistry();

        await expectLater(
          VantaAudioHandler.resolveQueueItemUris([item], registry),
          throwsA(isA<StateError>()),
        );

        expect(registry.requests, [item.id]);
      },
    );
  });
}

MediaItem _item(String id) => MediaItem(id: id, title: 'Track $id');

Track _track(String id, String uri, {String providerId = 'local'}) {
  return Track(
    id: id,
    providerId: providerId,
    title: 'Track $id',
    artist: 'Artist',
    album: 'Album',
    uri: Uri.parse(uri),
    duration: const Duration(minutes: 3),
  );
}

class _FakeStreamResolverRegistry implements StreamResolverRegistry {
  _FakeStreamResolverRegistry(this._resolved);

  final Map<String, Uri> _resolved;
  final List<String> requests = [];

  @override
  Future<Uri> resolve(MediaItem item) async {
    final key = VantaAudioHandler.normalizeTrackKey(item)!;
    requests.add(key);
    return _resolved[key] ?? Uri.parse(item.id);
  }
}

class _FailClosedStreamResolverRegistry implements StreamResolverRegistry {
  final List<String> requests = [];

  @override
  Future<Uri> resolve(MediaItem item) async {
    requests.add(item.id);
    throw StateError('resolver required');
  }
}
