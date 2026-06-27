import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/player/domain/audio_settings.dart';
import 'package:vanta_music/features/player/domain/playback_session.dart';
import 'package:vanta_music/features/player/domain/vanta_audio_engine.dart';
import 'package:vanta_music/features/player/application/playback_session_store.dart';
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
      'passes local content sources without Dart metadata to the native fallback seam',
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
          extras: {'providerId': 'local'},
        );

        await handler.tryNativeEngineOrFallbackForTesting(
          Uri.parse(item.id),
          originalItem: item,
          title: item.title,
        );

        expect(native.loadedSources.single.uri, Uri.parse(item.id));
        expect(native.loadedSources.single.contentMimeType, isNull);
        expect(native.loadedSources.single.contentDisplayName, isNull);
      },
    );

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

    test(
      'passes eligible content FLAC sources to the native fallback seam',
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
            'contentMimeType': 'audio/flac',
            'contentDisplayName': 'private-title.flac',
          },
        );

        await handler.tryNativeEngineOrFallbackForTesting(
          Uri.parse(item.id),
          originalItem: item,
          title: item.title,
        );

        expect(native.loadedSources.single.uri, Uri.parse(item.id));
        expect(native.loadedSources.single.contentMimeType, 'audio/flac');
        expect(
          native.loadedSources.single.contentDisplayName,
          'private-title.flac',
        );
      },
    );

    test('keeps unsupported content sources on the current engine', () async {
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
        extras: {'providerId': 'local', 'contentMimeType': 'audio/mpeg'},
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
      'routes play pause and seek commands to active native engine',
      () async {
        final native = _RecordingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );
        final item = VantaAudioHandler.mediaItemFromTrack(
          _track('local-1', 'file:///queue/local.flac'),
        );

        await handler.tryNativeEngineOrFallbackForTesting(
          Uri.parse('file:///queue/local.flac'),
          originalItem: item,
          title: item.title,
        );
        await handler.play();
        await handler.pause();
        await handler.seek(const Duration(seconds: 30));

        expect(native.playCalls, 1);
        expect(native.pauseCalls, 1);
        expect(native.seekPositions, [const Duration(seconds: 30)]);
      },
    );

    test(
      'native play activates the shared app audio session without self-pausing',
      () async {
        final native = _RecordingNativeEngine();
        final audioSession = _RecordingPlaybackFocusSession();
        final handler = VantaAudioHandler(
          nativeEngine: native,
          audioSession: audioSession,
        );
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );
        final item = VantaAudioHandler.mediaItemFromTrack(
          _track('local-1', 'file:///queue/local.flac'),
        );

        await handler.tryNativeEngineOrFallbackForTesting(
          Uri.parse('file:///queue/local.flac'),
          originalItem: item,
          title: item.title,
        );
        await handler.play();

        expect(audioSession.activations, [true]);
        expect(native.playCalls, 1);
        expect(native.pauseCalls, 0);
        expect(handler.playbackState.value.playing, isTrue);
      },
    );

    test(
      'immediate native audio interruption pauses native and deactivates app audio focus',
      () async {
        final native = _RecordingNativeEngine();
        final audioSession = _RecordingPlaybackFocusSession();
        final handler = VantaAudioHandler(
          nativeEngine: native,
          audioSession: audioSession,
        );
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );
        final item = VantaAudioHandler.mediaItemFromTrack(
          _track('local-1', 'file:///queue/local.flac'),
        );

        await handler.tryNativeEngineOrFallbackForTesting(
          Uri.parse('file:///queue/local.flac'),
          originalItem: item,
          title: item.title,
        );
        await handler.play();
        audioSession.emitInterruption(
          AudioInterruptionEvent(true, AudioInterruptionType.pause),
        );
        await _waitUntil(() => native.pauseCalls == 1);

        expect(native.pauseCalls, 1);
        expect(audioSession.activations, [true, false]);
        expect(handler.playbackState.value.playing, isFalse);
      },
    );

    test(
      'immediate unknown native audio interruption pauses native and deactivates app audio focus',
      () async {
        final native = _RecordingNativeEngine();
        final audioSession = _RecordingPlaybackFocusSession();
        final handler = VantaAudioHandler(
          nativeEngine: native,
          audioSession: audioSession,
        );
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );
        final item = VantaAudioHandler.mediaItemFromTrack(
          _track('local-1', 'file:///queue/local.flac'),
        );

        await handler.tryNativeEngineOrFallbackForTesting(
          Uri.parse('file:///queue/local.flac'),
          originalItem: item,
          title: item.title,
        );
        await handler.play();
        audioSession.emitInterruption(
          AudioInterruptionEvent(true, AudioInterruptionType.unknown),
        );
        await _waitUntil(() => native.pauseCalls == 1);

        expect(native.pauseCalls, 1);
        expect(audioSession.activations, [true, false]);
        expect(handler.playbackState.value.playing, isFalse);
      },
    );

    test(
      'current-engine playback ignores native interruption bridge',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final audioSession = _RecordingPlaybackFocusSession();
        final handler = VantaAudioHandler(audioSession: audioSession);
        addTearDown(handler.dispose);

        await handler.playMediaItem(_item('file:///queue/current.mp3'));
        audioSession.emitInterruption(
          AudioInterruptionEvent(true, AudioInterruptionType.pause),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(audioSession.activations, isEmpty);
        expect(platform.player.playCalls, 1);
        expect(platform.player.events, ['load', 'play']);
      },
    );

    test(
      'native duck interruption lowers volume and restores without resume',
      () async {
        final native = _RecordingNativeEngine();
        final audioSession = _RecordingPlaybackFocusSession();
        final handler = VantaAudioHandler(
          nativeEngine: native,
          audioSession: audioSession,
        );
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );
        final item = VantaAudioHandler.mediaItemFromTrack(
          _track('local-1', 'file:///queue/local.flac'),
        );

        await handler.tryNativeEngineOrFallbackForTesting(
          Uri.parse('file:///queue/local.flac'),
          originalItem: item,
          title: item.title,
        );
        await handler.play();
        audioSession.emitInterruption(
          AudioInterruptionEvent(true, AudioInterruptionType.duck),
        );
        await _waitUntil(() => native.volumes.contains(0.2));
        audioSession.emitInterruption(
          AudioInterruptionEvent(false, AudioInterruptionType.duck),
        );
        await _waitUntil(() => native.volumes.contains(1.0));

        expect(native.volumes, [0.2, 1.0]);
        expect(native.playCalls, 1);
        expect(native.pauseCalls, 0);
        expect(handler.playbackState.value.playing, isTrue);
      },
    );

    test(
      'becoming noisy event pauses native playback without resume',
      () async {
        final native = _RecordingNativeEngine();
        final audioSession = _RecordingPlaybackFocusSession();
        final handler = VantaAudioHandler(
          nativeEngine: native,
          audioSession: audioSession,
        );
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );
        final item = VantaAudioHandler.mediaItemFromTrack(
          _track('local-1', 'file:///queue/local.flac'),
        );

        await handler.tryNativeEngineOrFallbackForTesting(
          Uri.parse('file:///queue/local.flac'),
          originalItem: item,
          title: item.title,
        );
        await handler.play();
        audioSession.emitBecomingNoisy();
        await _waitUntil(() => native.pauseCalls == 1);

        expect(native.pauseCalls, 1);
        expect(native.playCalls, 1);
        expect(audioSession.activations, [true, false]);
        expect(handler.playbackState.value.playing, isFalse);
      },
    );

    test('explicit native pause deactivates app audio focus', () async {
      final native = _RecordingNativeEngine();
      final audioSession = _RecordingPlaybackFocusSession();
      final handler = VantaAudioHandler(
        nativeEngine: native,
        audioSession: audioSession,
      );
      addTearDown(handler.dispose);
      await handler.applyAudioSettings(
        const AudioSettings(
          audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
        ),
      );
      final item = VantaAudioHandler.mediaItemFromTrack(
        _track('local-1', 'file:///queue/local.flac'),
      );

      await handler.tryNativeEngineOrFallbackForTesting(
        Uri.parse('file:///queue/local.flac'),
        originalItem: item,
        title: item.title,
      );
      await handler.play();
      await handler.pause();

      expect(audioSession.activations, [true, false]);
      expect(native.pauseCalls, 1);
      expect(handler.playbackState.value.playing, isFalse);
    });

    test(
      'current-engine remote playback does not use native focus session',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final audioSession = _RecordingPlaybackFocusSession();
        final handler = VantaAudioHandler(
          audioSession: audioSession,
          streamResolverRegistry: _FakeStreamResolverRegistry({
            'subsonic:server-a::subsonic:server-a:remote-1': Uri.parse(
              'https://music.example/rest/stream.view?id=remote-1&t=secret',
            ),
          }),
        );
        addTearDown(handler.dispose);

        await handler.playTracks([
          _track(
            'subsonic:server-a:remote-1',
            'subsonic://track?serverId=server-a&id=remote-1',
            providerId: 'subsonic:server-a',
          ),
        ]);

        expect(audioSession.activations, isEmpty);
        expect(platform.player.playCalls, 1);
      },
    );

    test(
      'does not pause active native playback for app lifecycle backgrounding',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final native = _StreamingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );

        await handler.setQueueAndPlay([
          _track('local-1', 'file:///queue/local-1.flac'),
          _track('local-2', 'file:///queue/local-2.flac'),
        ]);

        handler.didChangeAppLifecycleState(AppLifecycleState.paused);
        native.emitPlaying();
        native.emitCompleted();

        expect(native.pauseCalls, 0);
        expect(handler.playbackState.value.playing, isTrue);
        await expectLater(
          handler.mediaItem.where(
            (item) => item?.id == 'file:///queue/local-2.flac',
          ),
          emits(isNotNull),
        );
        await _waitUntil(() => native.playCalls == 2);
        expect(platform.player.events, isEmpty);
      },
    );

    test('explicit pause while backgrounded pauses native playback', () async {
      final native = _StreamingNativeEngine();
      final handler = VantaAudioHandler(nativeEngine: native);
      addTearDown(handler.dispose);
      await handler.applyAudioSettings(
        const AudioSettings(
          audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
        ),
      );

      await handler.setQueueAndPlay([
        _track('local-1', 'file:///queue/local-1.flac'),
      ]);

      handler.didChangeAppLifecycleState(AppLifecycleState.paused);
      await handler.pause();

      expect(native.pauseCalls, 1);
      expect(handler.playbackState.value.playing, isFalse);
    });

    test(
      'resumed lifecycle preserves explicit native pause behavior',
      () async {
        final native = _StreamingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );

        await handler.setQueueAndPlay([
          _track('local-1', 'file:///queue/local-1.flac'),
        ]);

        handler.didChangeAppLifecycleState(AppLifecycleState.paused);
        handler.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await handler.pause();

        expect(native.pauseCalls, 1);
        expect(handler.playbackState.value.playing, isFalse);
      },
    );

    test(
      'native play broadcasts foreground-eligible audio service state',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final native = _StreamingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );

        await handler.setQueueAndPlay([
          _track('local-1', 'file:///queue/local.flac'),
        ]);

        final state = handler.playbackState.value;
        expect(handler.mediaItem.value?.id, 'file:///queue/local.flac');
        expect(state.playing, isTrue);
        expect(state.processingState, AudioProcessingState.ready);
        expect(state.queueIndex, 0);
        expect(state.controls, contains(MediaControl.pause));
        expect(state.systemActions, contains(MediaAction.pause));
        expect(state.systemActions, contains(MediaAction.play));
      },
    );

    test(
      'stale current-engine events cannot mark native playback as paused',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final native = _StreamingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);

        await handler.setQueueAndPlay([
          _track('local-1', 'content://media/external/audio/media/1'),
        ]);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );
        await handler.play();

        platform.player.emitPausedEvent();
        platform.player.emitCompleted();
        await Future<void>.delayed(Duration.zero);

        expect(native.playCalls, greaterThanOrEqualTo(1));
        expect(native.pauseCalls, 0);
        expect(handler.isNativeEngineActiveForTesting, isTrue);
        expect(handler.playbackState.value.playing, isTrue);
        expect(
          handler.playbackState.value.processingState,
          AudioProcessingState.ready,
        );
      },
    );

    test('native completion advances to the next native queue item', () async {
      final platform = _FakeJustAudioPlatform();
      final originalPlatform = JustAudioPlatform.instance;
      JustAudioPlatform.instance = platform;
      addTearDown(() => JustAudioPlatform.instance = originalPlatform);
      final native = _StreamingNativeEngine();
      final handler = VantaAudioHandler(nativeEngine: native);
      addTearDown(handler.dispose);
      await handler.applyAudioSettings(
        const AudioSettings(
          audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
        ),
      );

      await handler.setQueueAndPlay([
        _track('local-1', 'file:///queue/local-1.flac'),
        _track('local-2', 'file:///queue/local-2.flac'),
      ]);
      native.emitPlaying();
      native.emitCompleted();

      await expectLater(
        handler.mediaItem.where(
          (item) => item?.id == 'file:///queue/local-2.flac',
        ),
        emits(isNotNull),
      );
      expect(native.loadedSources.map((source) => source.uri.toString()), [
        'file:///queue/local-1.flac',
        'file:///queue/local-2.flac',
      ]);
      await _waitUntil(() => native.playCalls == 2);
      expect(native.playCalls, 2);
      expect(platform.player.loadCalls, 0);
      expect(platform.player.seekIndexes, isEmpty);
    });

    test('native-ready initial item does not prepare just_audio', () async {
      final platform = _FakeJustAudioPlatform();
      final originalPlatform = JustAudioPlatform.instance;
      JustAudioPlatform.instance = platform;
      addTearDown(() => JustAudioPlatform.instance = originalPlatform);
      final native = _StreamingNativeEngine();
      final handler = VantaAudioHandler(nativeEngine: native);
      addTearDown(handler.dispose);
      await handler.applyAudioSettings(
        const AudioSettings(
          audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
        ),
      );

      await handler.setQueueAndPlay([
        _track('local-1', 'file:///queue/local-1.flac'),
      ]);

      expect(
        native.loadedSources.single.uri.toString(),
        'file:///queue/local-1.flac',
      );
      expect(native.playCalls, 1);
      expect(platform.player.loadCalls, 0);
      expect(platform.player.playCalls, 0);
    });

    test(
      'native play failure prepares current engine before fallback play',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final native = _PlayThrowingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );

        await handler.setQueueAndPlay([
          _track('local-1', 'file:///queue/local-1.flac'),
        ]);

        expect(
          native.loadedSources.single.uri.toString(),
          'file:///queue/local-1.flac',
        );
        expect(native.playCalls, 1);
        expect(handler.isNativeEngineActiveForTesting, isFalse);
        expect(platform.player.events, ['load', 'play']);
      },
    );

    test(
      'native pause failure releases native without current engine fallback',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final native = _PauseThrowingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );

        await handler.setQueueAndPlay([
          _track('local-1', 'file:///queue/local-1.flac'),
        ]);

        expect(handler.isNativeEngineActiveForTesting, isTrue);
        expect(platform.player.events, isEmpty);

        await handler.pause();

        expect(
          native.loadedSources.single.uri.toString(),
          'file:///queue/local-1.flac',
        );
        expect(native.playCalls, 1);
        expect(native.pauseCalls, 1);
        expect(native.stopCalls, 1);
        expect(handler.isNativeEngineActiveForTesting, isFalse);
        expect(platform.player.events, isEmpty);
      },
    );

    test(
      'native seek failure prepares current engine before fallback seek',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final native = _SeekThrowingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );

        await handler.setQueueAndPlay([
          _track('local-1', 'file:///queue/local-1.flac'),
        ]);

        expect(handler.isNativeEngineActiveForTesting, isTrue);
        expect(platform.player.events, isEmpty);

        await handler.seek(const Duration(seconds: 42));

        expect(
          native.loadedSources.single.uri.toString(),
          'file:///queue/local-1.flac',
        );
        expect(native.seekPositions, [const Duration(seconds: 42)]);
        expect(native.stopCalls, 1);
        expect(handler.isNativeEngineActiveForTesting, isFalse);
        expect(platform.player.events, ['load', 'seek']);
      },
    );

    test(
      'native load failure falls back and prepares current engine',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final native = _ThrowingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );

        await handler.setQueueAndPlay([
          _track('local-1', 'file:///queue/local-1.flac'),
        ]);

        expect(native.loadCalls, 1);
        expect(handler.isNativeEngineActiveForTesting, isFalse);
        expect(platform.player.loadCalls, 1);
        expect(platform.player.playCalls, 1);
      },
    );

    test(
      'native-ready restored item does not prepare just_audio at startup',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final item = VantaAudioHandler.mediaItemFromTrack(
          _track('local-1', 'file:///queue/local-1.flac'),
        );
        final native = _RecordingNativeEngine();
        final handler = VantaAudioHandler(
          sessionStore: _MemoryPlaybackSessionStore(
            PlaybackSession(
              queue: [item],
              currentIndex: 0,
              position: const Duration(seconds: 12),
            ),
          ),
          nativeEngine: native,
        );
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );

        await handler.restoreSessionIfAvailable();

        expect(handler.mediaItem.value?.id, item.id);
        expect(native.loadedSources.single.uri.toString(), item.id);
        expect(native.seekPositions, [const Duration(seconds: 12)]);
        expect(handler.isNativeEngineActiveForTesting, isTrue);
        expect(platform.player.loadCalls, 0);
      },
    );

    test(
      'play promotes existing current-engine content item after native is enabled',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final native = _RecordingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);

        await handler.setQueueAndPlay([
          _track('local-1', 'content://media/external/audio/media/1'),
        ]);
        await handler.pause();
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );

        await handler.play();

        expect(
          native.loadedSources.single.uri.toString(),
          'content://media/external/audio/media/1',
        );
        expect(native.playCalls, 1);
        expect(handler.isNativeEngineActiveForTesting, isTrue);
      },
    );

    test(
      'applying native mode re-evaluates an existing current-engine item',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final native = _RecordingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);

        await handler.setQueueAndPlay([
          _track('local-1', 'content://media/external/audio/media/1'),
        ]);
        await handler.pause();

        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );

        expect(
          native.loadedSources.single.uri.toString(),
          'content://media/external/audio/media/1',
        );
        expect(handler.isNativeEngineActiveForTesting, isTrue);
        expect(native.playCalls, 0);
      },
    );

    test(
      'applying native mode keeps remote http Subsonic current item on current engine',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final native = _RecordingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);

        await handler.setQueueAndPlay([
          _track(
            'remote-1',
            'https://music.example/rest/stream.view?id=remote-1',
            providerId: 'subsonic:server-a',
          ),
        ]);
        await handler.pause();

        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );

        expect(handler.mediaItem.value?.id, contains('remote-1'));
        expect(native.loadedSources, isEmpty);
        expect(handler.isNativeEngineActiveForTesting, isFalse);
        expect(platform.player.loadCalls, 1);
      },
    );

    test(
      'play promotes restored current-engine content item after native is enabled',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final item = VantaAudioHandler.mediaItemFromTrack(
          _track('local-1', 'content://media/external/audio/media/1'),
        );
        final native = _RecordingNativeEngine();
        final handler = VantaAudioHandler(
          sessionStore: _MemoryPlaybackSessionStore(
            PlaybackSession(
              queue: [item],
              currentIndex: 0,
              position: Duration.zero,
            ),
          ),
          nativeEngine: native,
        );
        addTearDown(handler.dispose);

        await handler.restoreSessionIfAvailable();
        expect(handler.mediaItem.value?.id, item.id);
        expect(platform.player.loadCalls, 1);
        expect(native.loadedSources, isEmpty);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );

        await handler.play();

        expect(native.loadedSources.single.uri.toString(), item.id);
        expect(native.playCalls, 1);
        expect(handler.isNativeEngineActiveForTesting, isTrue);
      },
    );

    test('route decision diagnostics include mode and redacted source', () async {
      final item = VantaAudioHandler.mediaItemFromTrack(
        _track('private', 'file:///private/secret/local.flac'),
      );
      final handler = VantaAudioHandler(nativeEngine: _RecordingNativeEngine());
      addTearDown(handler.dispose);
      final logs = <String>[];

      await runZoned(
        () => handler.tryNativeEngineOrFallbackForTesting(
          Uri.parse(item.id),
          originalItem: item,
          title: item.title,
        ),
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => logs.add(line),
        ),
      );

      expect(
        logs,
        contains(
          contains(
            'route-decision mode=androidDefault owner=current-engine reason=native-engine-not-selected source=file://local',
          ),
        ),
      );
      expect(logs.join('\n'), isNot(contains('/private/secret/local.flac')));
    });

    test(
      'native restore load failure falls back and prepares current engine',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final item = VantaAudioHandler.mediaItemFromTrack(
          _track('local-1', 'file:///queue/local-1.flac'),
        );
        final native = _ThrowingNativeEngine();
        final handler = VantaAudioHandler(
          sessionStore: _MemoryPlaybackSessionStore(
            PlaybackSession(
              queue: [item],
              currentIndex: 0,
              position: const Duration(seconds: 12),
            ),
          ),
          nativeEngine: native,
        );
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );

        await handler.restoreSessionIfAvailable();

        expect(native.loadCalls, 1);
        expect(handler.isNativeEngineActiveForTesting, isFalse);
        expect(platform.player.loadCalls, 1);
      },
    );

    test('stop while native-owned does not stop current engine', () async {
      final platform = _FakeJustAudioPlatform();
      final originalPlatform = JustAudioPlatform.instance;
      JustAudioPlatform.instance = platform;
      addTearDown(() => JustAudioPlatform.instance = originalPlatform);
      final native = _RecordingNativeEngine();
      final handler = VantaAudioHandler(nativeEngine: native);
      addTearDown(handler.dispose);
      await handler.applyAudioSettings(
        const AudioSettings(
          audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
        ),
      );

      await handler.setQueueAndPlay([
        _track('local-1', 'file:///queue/local-1.flac'),
      ]);
      await handler.pause();
      await handler.stop();

      expect(native.stopCalls, 1);
      expect(platform.player.events, isEmpty);
    });

    test(
      'native error log includes code without sensitive source data',
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
          _track('private', 'file:///private/secret/local.flac'),
        );
        final logs = <String>[];

        await runZoned(
          () => handler.tryNativeEngineOrFallbackForTesting(
            Uri.parse(item.id),
            originalItem: item,
            title: item.title,
          ),
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, line) => logs.add(line),
          ),
        );

        expect(logs, contains(contains('native-error code=native_not_ready')));
        expect(logs.join('\n'), isNot(contains('/private/secret/local.flac')));
      },
    );

    test(
      'native completion to unsupported next item clears native and routes current engine',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final native = _StreamingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );

        await handler.setQueueAndPlay([
          _track('local-1', 'file:///queue/local-1.flac'),
          _track('local-2', 'file:///queue/local-2.mp3'),
        ]);
        native.emitPlaying();
        native.emitCompleted();

        await expectLater(
          handler.playbackState.where((state) => state.queueIndex == 1),
          emits(anything),
        );
        expect(handler.isNativeEngineActiveForTesting, isFalse);
        expect(native.loadedSources.map((source) => source.uri.toString()), [
          'file:///queue/local-1.flac',
        ]);
        expect(native.stopCalls, greaterThanOrEqualTo(1));
        await _waitUntil(() => platform.player.loadCalls == 1);
        expect(platform.player.loadCalls, 1);
        await _waitUntil(() => platform.player.playCalls == 1);
        expect(platform.player.playCalls, 1);
      },
    );

    test(
      'native completion at end of queue exposes completed playback state',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final native = _StreamingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );

        await handler.setQueueAndPlay([
          _track('local-1', 'file:///queue/local-1.flac'),
          _track('local-2', 'file:///queue/local-2.flac'),
        ]);
        native.emitDuration(const Duration(minutes: 3));
        native.emitPlaying();
        native.emitCompleted();
        await _waitUntil(() => native.playCalls == 2);
        expect(native.loadedSources.map((source) => source.uri.toString()), [
          'file:///queue/local-1.flac',
          'file:///queue/local-2.flac',
        ]);
        expect(native.stopCalls, 0);
        native.emitDuration(const Duration(minutes: 3));
        native.emitPlaying();
        native.emitCompleted();

        await _waitUntil(
          () =>
              handler.playbackState.value.processingState ==
              AudioProcessingState.completed,
        );
        final state = handler.playbackState.value;
        expect(state.processingState, AudioProcessingState.completed);
        expect(state.playing, isFalse);
        expect(state.queueIndex, 1);
        expect(state.updatePosition, const Duration(minutes: 3));
        await _waitUntil(() => native.stopCalls == 1);
        expect(native.stopCalls, 1);
        expect(handler.isNativeEngineActiveForTesting, isFalse);
      },
    );

    test(
      'duplicate stale native completed events do not advance more than once',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final native = _StreamingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );

        await handler.setQueueAndPlay([
          _track('local-1', 'file:///queue/local-1.flac'),
          _track('local-2', 'file:///queue/local-2.flac'),
          _track('local-3', 'file:///queue/local-3.flac'),
        ]);
        native.emitPlaying();
        native.emitCompleted();
        await _waitUntil(() => native.playCalls == 2);

        native.emitCompleted();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(handler.mediaItem.value?.id, 'file:///queue/local-2.flac');
        expect(handler.playbackState.value.queueIndex, 1);
        expect(native.playCalls, 2);
        expect(platform.player.seekIndexes, isEmpty);
      },
    );

    test(
      'current engine completion behavior stays on current engine',
      () async {
        final platform = _FakeJustAudioPlatform();
        final originalPlatform = JustAudioPlatform.instance;
        JustAudioPlatform.instance = platform;
        addTearDown(() => JustAudioPlatform.instance = originalPlatform);
        final native = _StreamingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);

        await handler.setQueueAndPlay([
          _track('local-1', 'file:///queue/local-1.mp3'),
        ]);
        platform.player.emitCompleted();

        expect(native.loadedSources, isEmpty);
        expect(platform.player.loadCalls, 1);
        expect(platform.player.playCalls, 1);
        expect(handler.isNativeEngineActiveForTesting, isFalse);
      },
    );

    test(
      'deactivates stale native engine before unsupported source fallback',
      () async {
        for (final fallbackItem in [
          VantaAudioHandler.mediaItemFromTrack(
            _track('local-mp3', 'file:///queue/local.mp3'),
          ),
          VantaAudioHandler.mediaItemFromTrack(
            _track(
              'remote-1',
              'subsonic://track?serverId=server-a&id=remote-1',
              providerId: 'subsonic:server-a',
            ),
          ),
        ]) {
          final native = _RecordingNativeEngine();
          final handler = VantaAudioHandler(nativeEngine: native);
          addTearDown(handler.dispose);
          await handler.applyAudioSettings(
            const AudioSettings(
              audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
            ),
          );
          final nativeItem = VantaAudioHandler.mediaItemFromTrack(
            _track('local-flac', 'file:///queue/local.flac'),
          );

          await handler.tryNativeEngineOrFallbackForTesting(
            Uri.parse(nativeItem.id),
            originalItem: nativeItem,
            title: nativeItem.title,
          );
          await handler.tryNativeEngineOrFallbackForTesting(
            Uri.parse(fallbackItem.id),
            originalItem: fallbackItem,
            title: fallbackItem.title,
          );

          expect(native.loadedSources.map((source) => source.uri), [
            Uri.parse(nativeItem.id),
          ]);
          expect(handler.isNativeEngineActiveForTesting, isFalse);
          expect(native.stopCalls, 1);
          expect(native.playCalls, 0);
        }
      },
    );

    test('preserves paused native state when seeking', () async {
      final native = _RecordingNativeEngine();
      final handler = VantaAudioHandler(nativeEngine: native);
      addTearDown(handler.dispose);
      await handler.applyAudioSettings(
        const AudioSettings(
          audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
        ),
      );
      final item = VantaAudioHandler.mediaItemFromTrack(
        _track('local-1', 'file:///queue/local.flac'),
      );

      await handler.tryNativeEngineOrFallbackForTesting(
        Uri.parse(item.id),
        originalItem: item,
        title: item.title,
      );
      await handler.play();
      await handler.pause();
      await handler.seek(const Duration(seconds: 45));

      expect(native.seekPositions, [const Duration(seconds: 45)]);
      expect(handler.playbackState.value.playing, isFalse);
      expect(
        handler.playbackState.value.updatePosition,
        const Duration(seconds: 45),
      );
    });

    test(
      'forwards native position and duration streams while native owns playback',
      () async {
        final native = _StreamingNativeEngine();
        final handler = VantaAudioHandler(nativeEngine: native);
        addTearDown(handler.dispose);
        await handler.applyAudioSettings(
          const AudioSettings(
            audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
          ),
        );
        final item = VantaAudioHandler.mediaItemFromTrack(
          _track('local-1', 'file:///queue/local.flac'),
        );

        await handler.tryNativeEngineOrFallbackForTesting(
          Uri.parse(item.id),
          originalItem: item,
          title: item.title,
        );

        final durationEvent = expectLater(
          handler.durationStream,
          emits(const Duration(minutes: 3)),
        );
        final positionEvent = expectLater(
          handler.positionStream.where(
            (position) => position == const Duration(seconds: 42),
          ),
          emits(const Duration(seconds: 42)),
        );
        native.emitDuration(const Duration(minutes: 3));
        native.emitPosition(const Duration(seconds: 42));

        await durationEvent;
        await positionEvent;
      },
    );

    test('clamps native seeks to known native duration', () async {
      final native = _StreamingNativeEngine();
      final handler = VantaAudioHandler(nativeEngine: native);
      addTearDown(handler.dispose);
      await handler.applyAudioSettings(
        const AudioSettings(
          audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
        ),
      );
      final item = VantaAudioHandler.mediaItemFromTrack(
        _track('local-1', 'file:///queue/local.flac'),
      );

      await handler.tryNativeEngineOrFallbackForTesting(
        Uri.parse(item.id),
        originalItem: item,
        title: item.title,
      );
      native.emitDuration(const Duration(minutes: 3));
      await Future<void>.delayed(Duration.zero);

      await handler.seek(const Duration(minutes: 5));
      await handler.seek(const Duration(milliseconds: -1));

      expect(native.seekPositions, [const Duration(minutes: 3), Duration.zero]);
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

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
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

class _MemoryPlaybackSessionStore implements PlaybackSessionStore {
  _MemoryPlaybackSessionStore(this.session);

  PlaybackSession? session;
  bool cleared = false;

  @override
  Future<void> save(PlaybackSession session) async {
    this.session = session;
  }

  @override
  Future<PlaybackSession?> load() async => session;

  @override
  Future<void> clear() async {
    cleared = true;
    session = null;
  }
}

class _RecordingPlaybackFocusSession implements PlaybackFocusSession {
  _RecordingPlaybackFocusSession();

  final activations = <bool>[];
  final _interruptions = StreamController<AudioInterruptionEvent>.broadcast();
  final _becomingNoisy = StreamController<void>.broadcast();

  @override
  Stream<AudioInterruptionEvent> get interruptionEvents =>
      _interruptions.stream;

  @override
  Stream<void> get becomingNoisyEvents => _becomingNoisy.stream;

  @override
  Future<bool> setActive(bool active) async {
    activations.add(active);
    return true;
  }

  void emitInterruption(AudioInterruptionEvent event) {
    _interruptions.add(event);
  }

  void emitBecomingNoisy() {
    _becomingNoisy.add(null);
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
      'native_not_ready',
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
  final seekPositions = <Duration>[];
  final volumes = <double>[];
  int playCalls = 0;
  int pauseCalls = 0;
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
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
  }

  @override
  Future<void> dispose() async {}
}

class _StreamingNativeEngine extends _RecordingNativeEngine {
  final _playbackState = StreamController<VantaPlaybackState>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();

  @override
  Stream<VantaPlaybackState> get playbackState => _playbackState.stream;

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration?> get duration => _duration.stream;

  void emitPlaying() {
    _playbackState.add(
      const VantaPlaybackState(status: VantaPlaybackStatus.playing),
    );
  }

  void emitCompleted() {
    _playbackState.add(
      const VantaPlaybackState(status: VantaPlaybackStatus.completed),
    );
  }

  void emitPosition(Duration position) {
    _position.add(position);
  }

  void emitDuration(Duration? duration) {
    _duration.add(duration);
  }

  @override
  Future<void> dispose() async {
    await _playbackState.close();
    await _position.close();
    await _duration.close();
  }
}

class _PlayThrowingNativeEngine extends _StreamingNativeEngine {
  @override
  Future<void> play() async {
    playCalls++;
    throw const VantaAudioEngineException(
      'native_play_failed',
      'Native play failed after load.',
    );
  }
}

class _PauseThrowingNativeEngine extends _StreamingNativeEngine {
  @override
  Future<void> pause() async {
    pauseCalls++;
    throw const VantaAudioEngineException(
      'native_pause_failed',
      'Native pause failed after load.',
    );
  }
}

class _SeekThrowingNativeEngine extends _StreamingNativeEngine {
  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
    throw const VantaAudioEngineException(
      'native_seek_failed',
      'Native seek failed after load.',
    );
  }
}

class _FakeJustAudioPlatform extends JustAudioPlatform {
  final _FakeAudioPlayerPlatform player = _FakeAudioPlayerPlatform('fake');

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async => player;

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async => DisposePlayerResponse();

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async => DisposeAllPlayersResponse();
}

class _FakeAudioPlayerPlatform extends AudioPlayerPlatform {
  _FakeAudioPlayerPlatform(super.id);

  final _events = StreamController<PlaybackEventMessage>.broadcast();
  final seekIndexes = <int>[];
  final events = <String>[];
  int? currentIndex = 0;
  int loadCalls = 0;
  int playCalls = 0;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    events.add('load');
    loadCalls++;
    currentIndex = request.initialIndex ?? 0;
    _emit(ProcessingStateMessage.ready);
    return LoadResponse(duration: const Duration(minutes: 3));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    events.add('play');
    playCalls++;
    _emit(ProcessingStateMessage.ready);
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    events.add('pause');
    return PauseResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    events.add('seek');
    currentIndex = request.index ?? currentIndex;
    if (request.index != null) seekIndexes.add(request.index!);
    _emit(ProcessingStateMessage.ready);
    return SeekResponse();
  }

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    await _events.close();
    return DisposeResponse();
  }

  void emitCompleted() => _emit(ProcessingStateMessage.completed);

  void emitPausedEvent() => _emit(ProcessingStateMessage.ready);

  void _emit(ProcessingStateMessage state) {
    _events.add(
      PlaybackEventMessage(
        processingState: state,
        updateTime: DateTime.now(),
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        duration: const Duration(minutes: 3),
        icyMetadata: null,
        currentIndex: currentIndex,
        androidAudioSessionId: null,
      ),
    );
  }
}
