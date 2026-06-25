import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/player/domain/audio_settings.dart';
import 'package:vanta_music/features/player/domain/vanta_audio_engine.dart';
import 'package:vanta_music/features/player/infrastructure/vanta_audio_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test(
      'keeps downloaded Subsonic files on the current engine after resolution',
      () async {
        final item = MediaItem(
          id: 'subsonic://track?serverId=server-a&id=remote-1',
          title: 'Remote track',
          extras: const {
            'trackId': 'subsonic:server-a:remote-1',
            'providerId': 'subsonic:server-a',
            'canonicalUri': 'subsonic://track?serverId=server-a&id=remote-1',
          },
        );
        final registry = _FakeStreamResolverRegistry({
          'subsonic:server-a::subsonic:server-a:remote-1': Uri.parse(
            'file:///downloads/remote-1.flac',
          ),
        });

        final resolved = await VantaAudioHandler.resolveQueueItemsSafely([
          item,
        ], registry);

        expect(
          resolved.uris.single,
          Uri.parse('file:///downloads/remote-1.flac'),
        );
        expect(
          VantaAudioHandler.isOriginalLocalFileForNative(
            resolved.queueItems.single,
          ),
          isFalse,
        );
      },
    );

    test('allows native attempts only for original local file queue items', () {
      final local = VantaAudioHandler.mediaItemFromTrack(
        _track('local-1', 'file:///queue/local.wav'),
      );
      final staleRemote = MediaItem(
        id: 'file:///downloads/remote-1.flac',
        title: 'Remote track',
        extras: const {
          'trackId': 'remote-1',
          'providerId': 'local',
          'canonicalUri': 'subsonic://track?serverId=server-a&id=remote-1',
        },
      );

      expect(VantaAudioHandler.isOriginalLocalFileForNative(local), isTrue);
      expect(
        VantaAudioHandler.isOriginalLocalFileForNative(staleRemote),
        isFalse,
      );
    });

    test('allows native attempts for original local content queue items', () {
      const localContent = MediaItem(
        id: 'content://media/external/audio/media/local.wav',
        title: 'Local content',
        extras: {'providerId': 'local'},
      );
      const remoteContent = MediaItem(
        id: 'content://media/external/audio/media/remote.wav',
        title: 'Remote content',
        extras: {
          'providerId': 'subsonic:server-a',
          'canonicalUri': 'subsonic://track?serverId=server-a&id=remote-1',
        },
      );

      expect(
        VantaAudioHandler.isOriginalLocalSourceForNative(localContent),
        isTrue,
      );
      expect(
        VantaAudioHandler.isOriginalLocalSourceForNative(remoteContent),
        isFalse,
      );
    });

    test(
      'passes eligible content WAV sources to the native fallback seam',
      () async {
        final native = _RecordingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );
        const item = MediaItem(
          id: 'content://media/external/audio/media/1',
          title: 'Local content',
          extras: {
            'providerId': 'local',
            'contentMimeType': 'audio/wav',
            'contentDisplayName': 'private-title.wav',
          },
        );

        await handler.tryNativeEngineOrFallbackForTesting(
          Uri.parse(item.id),
          originalItem: item,
          title: item.title,
        );

        expect(native.loadedSources.single.uri, Uri.parse(item.id));
        expect(native.loadedSources.single.contentMimeType, 'audio/wav');
        expect(
          native.loadedSources.single.contentDisplayName,
          'private-title.wav',
        );
      },
    );

    test('keeps non-WAV content sources on the current engine', () async {
      final native = _RecordingNativeEngine();
      final handler = VantaAudioHandler(nativeEngine: native);
      addTearDown(handler.dispose);
      await handler.applyAudioSettings(
        const AudioSettings(
          audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
        ),
      );
      const item = MediaItem(
        id: 'content://media/external/audio/media/1',
        title: 'Local content',
        extras: {'providerId': 'local', 'contentMimeType': 'audio/flac'},
      );

      await handler.tryNativeEngineOrFallbackForTesting(
        Uri.parse(item.id),
        originalItem: item,
        title: item.title,
      );

      expect(native.loadedSources, isEmpty);
    });

    test(
      'does not crash when native engine fails at the handler fallback seam',
      () async {
        final native = _ThrowingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );
        final item = VantaAudioHandler.mediaItemFromTrack(
          _track('local-1', 'file:///queue/local.wav'),
        );

        await handler.tryNativeEngineOrFallbackForTesting(
          Uri.parse('file:///queue/local.wav'),
          originalItem: item,
          title: item.title,
        );

        expect(native.initCalls, 1);
        expect(native.loadCalls, 1);
        expect(native.stopCalls, 1);
      },
    );

    test('releases attempted native engine when handler stops', () async {
      final native = _RecordingNativeEngine();
      final handler = VantaAudioHandler(nativeEngine: native);
      addTearDown(handler.dispose);
      await handler.applyAudioSettings(
        const AudioSettings(
          audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
        ),
      );
      final item = VantaAudioHandler.mediaItemFromTrack(
        _track('local-1', 'file:///queue/local.wav'),
      );

      await handler.tryNativeEngineOrFallbackForTesting(
        Uri.parse('file:///queue/local.wav'),
        originalItem: item,
        title: item.title,
      );
      await handler.stop();

      expect(native.stopCalls, 1);
    });

    test(
      'skips one failed remote item while preserving playable queue order',
      () async {
        final local = VantaAudioHandler.mediaItemFromTrack(
          _track('local-1', 'file:///queue/local.mp3'),
        );
        final failed = VantaAudioHandler.mediaItemFromTrack(
          _track(
            'subsonic:server-a:remote-fail',
            'subsonic://track?serverId=server-a&id=remote-fail',
            providerId: 'subsonic:server-a',
          ),
        );
        final remote = VantaAudioHandler.mediaItemFromTrack(
          _track(
            'subsonic:server-a:remote-ok',
            'subsonic://track?serverId=server-a&id=remote-ok',
            providerId: 'subsonic:server-a',
          ),
        );
        final registry = _PartiallyFailingStreamResolverRegistry(
          resolved: {
            'subsonic:server-a::subsonic:server-a:remote-ok': Uri.parse(
              'https://music.example/rest/stream.view?id=remote-ok&t=fresh-token',
            ),
          },
          failures: {
            'subsonic:server-a::subsonic:server-a:remote-fail':
                RemoteTrackResolveException.retryable(
                  item: failed,
                  message: 'Subsonic request timed out.',
                ),
          },
        );

        final result = await VantaAudioHandler.resolveQueueItemsSafely([
          local,
          failed,
          remote,
        ], registry);

        expect(result.queueItems.map((item) => item.id), [local.id, remote.id]);
        expect(result.uris, [
          Uri.parse('file:///queue/local.mp3'),
          Uri.parse(
            'https://music.example/rest/stream.view?id=remote-ok&t=fresh-token',
          ),
        ]);
        expect(result.failures, hasLength(1));
        expect(result.failures.single.item.id, failed.id);
        expect(result.failures.single.retryable, isTrue);
      },
    );

    test('stores audio settings without adding playback processing', () async {
      final handler = VantaAudioHandler();
      addTearDown(handler.dispose);

      const settings = AudioSettings(crossfade: true, replayGain: true);
      await handler.applyAudioSettings(settings);

      expect(handler.audioSettings, settings);
    });
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

class _PartiallyFailingStreamResolverRegistry
    implements StreamResolverRegistry {
  _PartiallyFailingStreamResolverRegistry({
    required this.resolved,
    required this.failures,
  });

  final Map<String, Uri> resolved;
  final Map<String, Exception> failures;

  @override
  Future<Uri> resolve(MediaItem item) async {
    final key = VantaAudioHandler.normalizeTrackKey(item)!;
    final failure = failures[key];
    if (failure != null) throw failure;
    return resolved[key] ?? Uri.parse(item.id);
  }
}

class _ThrowingNativeEngine implements VantaAudioEngine {
  int initCalls = 0;
  int loadCalls = 0;
  int stopCalls = 0;

  @override
  Stream<VantaPlaybackState> get playbackState => const Stream.empty();

  @override
  Stream<Duration> get position => const Stream.empty();

  @override
  Stream<Duration?> get duration => const Stream.empty();

  @override
  Future<void> init() async {
    initCalls++;
  }

  @override
  Future<void> load(VantaAudioSource source) async {
    loadCalls++;
    throw const VantaAudioEngineException(
      'native-not-ready',
      'Native engine is not ready for playback yet.',
    );
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {}
}

class _RecordingNativeEngine implements VantaAudioEngine {
  final loadedSources = <VantaAudioSource>[];
  int stopCalls = 0;

  @override
  Stream<VantaPlaybackState> get playbackState => const Stream.empty();

  @override
  Stream<Duration> get position => const Stream.empty();

  @override
  Stream<Duration?> get duration => const Stream.empty();

  @override
  Future<void> init() async {}

  @override
  Future<void> load(VantaAudioSource source) async {
    loadedSources.add(source);
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {}
}
