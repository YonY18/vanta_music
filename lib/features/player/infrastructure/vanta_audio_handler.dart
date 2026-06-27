import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

import '../../library_intelligence/application/library_intelligence_sink.dart';
import '../../library/application/file_validation_cache.dart';
import '../../library/domain/track.dart';
import '../../providers/infrastructure/subsonic_api_client.dart';
import '../application/player_controller.dart';
import '../application/playback_session_store.dart';
import '../application/audio_engine_selection.dart';
import '../domain/audio_settings.dart';
import '../domain/playback_session.dart';
import '../domain/vanta_audio_engine.dart';

abstract interface class PlaybackFocusSession {
  Stream<AudioInterruptionEvent> get interruptionEvents;
  Stream<void> get becomingNoisyEvents;

  Future<bool> setActive(bool active);
}

class AudioSessionPlaybackFocus implements PlaybackFocusSession {
  const AudioSessionPlaybackFocus(this._session);

  final AudioSession _session;

  @override
  Stream<AudioInterruptionEvent> get interruptionEvents =>
      _session.interruptionEventStream;

  @override
  Stream<void> get becomingNoisyEvents => _session.becomingNoisyEventStream;

  @override
  Future<bool> setActive(bool active) => _session.setActive(active);
}

class NoopPlaybackFocusSession implements PlaybackFocusSession {
  const NoopPlaybackFocusSession();

  @override
  Stream<AudioInterruptionEvent> get interruptionEvents => const Stream.empty();

  @override
  Stream<void> get becomingNoisyEvents => const Stream.empty();

  @override
  Future<bool> setActive(bool active) async => true;
}

class VantaAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler, WidgetsBindingObserver
    implements PlayerAudioControl {
  VantaAudioHandler({
    this._sessionStore,
    InMemoryFileValidationCache? validationCache,
    this._intelligenceSink,
    StreamResolverRegistry? streamResolverRegistry,
    this._nativeEngine,
    this.audioSession = const NoopPlaybackFocusSession(),
    this._engineSelection = const VantaAudioEngineSelection(),
  }) : _validationCache = validationCache ?? InMemoryFileValidationCache(),
       _streamResolverRegistry =
           streamResolverRegistry ?? const LocalStreamResolverRegistry() {
    _eventSub = _player.playbackEventStream.listen(_broadcastState);
    _indexSub = _player.currentIndexStream.listen((index) {
      final items = queue.value;
      if (_currentEngineHasFullQueue &&
          index != null &&
          index >= 0 &&
          index < items.length) {
        _queueIndex = index;
        mediaItem.add(items[index]);
      }
      _broadcastState(_player.playbackEvent);
    });
    _playerPositionSub = _player.positionStream.listen((position) {
      if (!_nativeEngineActive) _positionController.add(position);
    });
    _playerDurationSub = _player.durationStream.listen((duration) {
      if (!_nativeEngineActive) _durationController.add(duration);
    });
    _audioInterruptionSub = audioSession.interruptionEvents.listen(
      _handleAudioInterruption,
      onError: (Object error) {
        _logAudioEngine(
          'audio-session-interruption-error error=${_safeError(error)}',
        );
      },
    );
    _becomingNoisySub = audioSession.becomingNoisyEvents.listen(
      (_) => _handleBecomingNoisy(),
      onError: (Object error) {
        _logAudioEngine('audio-session-noisy-error error=${_safeError(error)}');
      },
    );
    WidgetsBinding.instance.addObserver(this);
  }

  final AudioPlayer _player = AudioPlayer();
  final PlaybackSessionStore? _sessionStore;
  final InMemoryFileValidationCache _validationCache;
  final LibraryIntelligenceSink? _intelligenceSink;
  final StreamResolverRegistry _streamResolverRegistry;
  final VantaAudioEngine? _nativeEngine;
  final PlaybackFocusSession audioSession;
  final VantaAudioEngineSelection _engineSelection;
  late final StreamSubscription<PlaybackEvent> _eventSub;
  late final StreamSubscription<int?> _indexSub;
  late final StreamSubscription<AudioInterruptionEvent> _audioInterruptionSub;
  late final StreamSubscription<void> _becomingNoisySub;
  StreamSubscription<VantaPlaybackState>? _nativeStateSub;
  StreamSubscription<Duration>? _nativePositionSub;
  StreamSubscription<Duration?>? _nativeDurationSub;
  late final StreamSubscription<Duration> _playerPositionSub;
  late final StreamSubscription<Duration?> _playerDurationSub;
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();

  Timer? _persistDebounce;
  bool _restoring = false;
  bool _nativeEngineAttempted = false;
  bool _nativeEngineActive = false;
  bool _nativeEnginePlaying = false;
  bool _handlingNativeCompletion = false;
  bool _nativeCompletionArmed = false;
  bool _nativeDucked = false;
  bool _currentEngineHasFullQueue = false;
  bool _skipNativePromotionForNextPlay = false;
  Duration _nativePosition = Duration.zero;
  Duration? _nativeDuration;
  int? _queueIndex;
  String? _lastCompletedTrackKey;
  RemoteTrackFailure? _lastRemoteFailure;
  AudioSettings _audioSettings = AudioSettings.defaults;

  AudioSettings get audioSettings => _audioSettings;

  bool get isNativeEngineActiveForTesting => _nativeEngineActive;

  Future<void> restoreSessionIfAvailable() async {
    final store = _sessionStore;
    if (store == null) return;

    final session = await store.load();
    if (session == null) return;

    final safe = _safeSession(session);
    if (safe == null) {
      await store.clear();
      return;
    }

    _restoring = true;
    queue.add(safe.queue);
    mediaItem.add(safe.queue[safe.currentIndex]);
    _queueIndex = safe.currentIndex;
    final restoredNative = await _tryNativeRestore(safe);
    if (restoredNative) {
      _restoring = false;
      _currentEngineHasFullQueue = false;
      _logAudioEngine('owner=native-engine action=playback-route');
      _broadcastNativeState(playing: false, positionOverride: _nativePosition);
      if (safe.pendingReconcileUris.isNotEmpty) {
        unawaited(_validationCache.reconcileBatch(safe.pendingReconcileUris));
      }
      return;
    }

    await _player.setAudioSources(
      await _audioSourcesFor(safe.queue),
      initialIndex: safe.currentIndex,
      initialPosition: safe.position,
    );
    _currentEngineHasFullQueue = true;
    _restoring = false;
    _broadcastState(_player.playbackEvent);

    if (safe.pendingReconcileUris.isNotEmpty) {
      unawaited(_validationCache.reconcileBatch(safe.pendingReconcileUris));
    }
  }

  @override
  Stream<Duration> get positionStream => _positionController.stream;
  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  Future<void> applyAudioSettings(AudioSettings settings) async {
    final previousEngineType = _audioSettings.audioEngineType;
    _audioSettings = settings;
    _logAudioEngine('selected=${settings.audioEngineType.name}');
    if (previousEngineType != VantaAudioEngineType.vantaNativeExperimental &&
        settings.audioEngineType ==
            VantaAudioEngineType.vantaNativeExperimental) {
      await _promoteCurrentItemAfterNativeModeEnabled();
    }
  }

  Future<void> _promoteCurrentItemAfterNativeModeEnabled() async {
    if (_nativeEngineActive || queue.value.isEmpty) return;
    _skipNativePromotionForNextPlay = false;
    final shouldResume = _player.playing;
    final promoted = await _tryPromoteCurrentItemToNativeForPlay();
    if (promoted && shouldResume) await play();
  }

  Future<void> setQueueAndPlay(
    List<Track> tracks, {
    int initialIndex = 0,
  }) async {
    if (tracks.isEmpty) return;

    final items = tracks.map(mediaItemFromTrack).toList(growable: false);
    final resolved = await resolveQueueItemsSafely(
      items,
      _streamResolverRegistry,
    );
    _updateRemoteFailure(resolved.failures);
    if (resolved.queueItems.isEmpty) {
      if (resolved.failures.isNotEmpty) {
        mediaItem.add(resolved.failures.first.item);
        _broadcastState(_player.playbackEvent);
      }
      return;
    }

    final safeInitialIndex = initialIndex.clamp(
      0,
      resolved.queueItems.length - 1,
    );
    queue.add(resolved.queueItems);
    mediaItem.add(resolved.queueItems[safeInitialIndex]);
    _queueIndex = safeInitialIndex;

    final nativeReady = await _tryNativeEngineOrFallback(
      resolved.uris[safeInitialIndex],
      originalItem: resolved.queueItems[safeInitialIndex],
      title: resolved.queueItems[safeInitialIndex].title,
    );
    if (nativeReady) {
      _currentEngineHasFullQueue = false;
      _logAudioEngine('owner=native-engine action=playback-route');
      await play();
      _scheduleSessionPersist();
      return;
    }

    await _player.setAudioSources(
      [
        for (var index = 0; index < resolved.queueItems.length; index++)
          AudioSource.uri(
            resolved.uris[index],
            tag: resolved.queueItems[index],
          ),
      ],
      initialIndex: safeInitialIndex,
      initialPosition: Duration.zero,
    );
    _currentEngineHasFullQueue = true;
    _skipNativePromotionForNextPlay = true;
    _logAudioEngine('owner=current-engine action=playback-route');
    await play();
    _scheduleSessionPersist();
  }

  @override
  Future<void> playTracks(List<Track> tracks, {int initialIndex = 0}) =>
      setQueueAndPlay(tracks, initialIndex: initialIndex);

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    final resolved = await resolveQueueItemsSafely([
      mediaItem,
    ], _streamResolverRegistry);
    _updateRemoteFailure(resolved.failures);
    if (resolved.queueItems.isEmpty) {
      this.mediaItem.add(mediaItem);
      _broadcastState(_player.playbackEvent);
      return;
    }

    queue.add(resolved.queueItems);
    this.mediaItem.add(resolved.queueItems.single);
    _queueIndex = 0;
    final nativeReady = await _tryNativeEngineOrFallback(
      resolved.uris.single,
      originalItem: resolved.queueItems.single,
      title: resolved.queueItems.single.title,
    );
    if (nativeReady) {
      _currentEngineHasFullQueue = false;
      _logAudioEngine('owner=native-engine action=playback-route');
      await play();
      _scheduleSessionPersist();
      return;
    }
    await _player.setAudioSource(
      AudioSource.uri(resolved.uris.single, tag: resolved.queueItems.single),
    );
    _currentEngineHasFullQueue = false;
    _skipNativePromotionForNextPlay = true;
    _logAudioEngine('owner=current-engine action=playback-route');
    await play();
    _scheduleSessionPersist();
  }

  @override
  Future<void> play() async {
    if (!_nativeEngineActive) {
      await _tryPromoteCurrentItemToNativeForPlay();
    }
    _emitPlayStarted();
    if (_nativeEngineActive) {
      try {
        final focusGranted = await audioSession.setActive(true);
        if (!focusGranted) {
          _nativeEnginePlaying = false;
          _broadcastNativeState(playing: false);
          _logAudioEngine('fallback=none reason=audio-session-denied');
          return;
        }
        await _nativeEngine?.play();
        _nativeEnginePlaying = true;
        _broadcastNativeState(playing: true);
        _logAudioEngine('play native-engine');
        return;
      } catch (error) {
        await _releaseNativeEngineAfterAttempt();
        _logAudioEngine(
          'fallback=current-engine reason=native-play-error native-error code=${_nativeErrorCode(error)} error=${_safeError(error)}',
        );
        final prepared = await _prepareCurrentEngineForCurrentItem();
        if (!prepared) {
          _logAudioEngine('fallback=none reason=current-item-unavailable');
          return;
        }
      }
    }
    _logAudioEngine('play current-engine');
    return _player.play();
  }

  @override
  Future<void> pause() => _pause(_NativePauseOrigin.externalCommand);

  Future<void> _pause(_NativePauseOrigin origin) async {
    _emitProgress();
    if (_nativeEngineActive) {
      try {
        await _setNativeDucked(false);
        await _nativeEngine?.pause();
        await audioSession.setActive(false);
        _nativeEnginePlaying = false;
        _nativeCompletionArmed = false;
        _broadcastNativeState(playing: false);
        _logAudioEngine('pause native-engine reason=${origin.logValue}');
        return;
      } catch (error) {
        await _releaseNativeEngineAfterAttempt();
        _logAudioEngine(
          'fallback=none reason=native-pause-error pause-origin=${origin.logValue} action=native-released error=${_safeError(error)}',
        );
        return;
      }
    }
    _logAudioEngine('pause current-engine reason=${origin.logValue}');
    return _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    final targetPosition = _clampSeekPosition(position);
    if (_nativeEngineActive) {
      try {
        await _nativeEngine?.seek(targetPosition);
        _nativePosition = targetPosition;
        _positionController.add(targetPosition);
        _broadcastNativeState(
          playing: _nativeEnginePlaying,
          positionOverride: targetPosition,
        );
        _emitProgress(positionOverride: targetPosition);
        return;
      } catch (error) {
        await _releaseNativeEngineAfterAttempt();
        _logAudioEngine(
          'fallback=current-engine reason=native-seek-error native-error code=${_nativeErrorCode(error)} error=${_safeError(error)}',
        );
        final prepared = await _prepareCurrentEngineForCurrentItem();
        if (!prepared) {
          _logAudioEngine('fallback=none reason=current-item-unavailable');
          return;
        }
      }
    }
    await _player.seek(targetPosition);
    _emitProgress(positionOverride: targetPosition);
  }

  @override
  Future<void> skipToQueueItem(int index) => _skipToIndex(index);

  @override
  Future<void> removeQueueItemById(String mediaItemId) async {
    final items = queue.value;
    final index = items.indexWhere((item) => item.id == mediaItemId);
    if (index < 0) return;

    queue.add(removeQueueItems(items, mediaItemId));
    if (_currentEngineHasFullQueue) {
      await _player.removeAudioSourceAt(index);
    }
    _scheduleSessionPersist();
  }

  @override
  Future<void> playNext(Track track) async {
    final item = mediaItemFromTrack(track);
    final items = queue.value;
    final currentIndex = _currentQueueIndex;
    final insertIndex = _playNextIndex(items.length, currentIndex);

    queue.add(insertPlayNext(items, item, currentIndex: currentIndex));
    if (_currentEngineHasFullQueue) {
      await _player.insertAudioSource(insertIndex, await _audioSourceFor(item));
    }
    _scheduleSessionPersist();
  }

  @override
  Future<void> addToQueueEnd(Track track) async {
    final item = mediaItemFromTrack(track);
    queue.add(appendToQueueEnd(queue.value, item));
    if (_currentEngineHasFullQueue) {
      await _player.addAudioSource(await _audioSourceFor(item));
    }
    _scheduleSessionPersist();
  }

  @override
  Future<void> retryFailedTrack() async {
    final failure = _lastRemoteFailure;
    if (failure == null || !failure.retryable) return;

    final resolved = await resolveQueueItemsSafely([
      failure.item,
    ], _streamResolverRegistry);
    _updateRemoteFailure(resolved.failures);
    if (resolved.queueItems.isEmpty) return;

    if (queue.value.isEmpty) {
      queue.add(resolved.queueItems);
      mediaItem.add(resolved.queueItems.single);
      await _player.setAudioSource(
        AudioSource.uri(resolved.uris.single, tag: resolved.queueItems.single),
      );
    } else {
      final currentIndex = _currentQueueIndex;
      final insertIndex = _playNextIndex(queue.value.length, currentIndex);
      queue.add(
        insertPlayNext(
          queue.value,
          resolved.queueItems.single,
          currentIndex: currentIndex,
        ),
      );
      await _player.insertAudioSource(
        insertIndex,
        AudioSource.uri(resolved.uris.single, tag: resolved.queueItems.single),
      );
      await _player.seek(Duration.zero, index: insertIndex);
      mediaItem.add(resolved.queueItems.single);
    }

    _lastRemoteFailure = null;
    await play();
    _broadcastState(_player.playbackEvent);
    _scheduleSessionPersist();
  }

  @override
  Future<void> skipToNext() {
    final index = _currentQueueIndex;
    if (index == null) return Future<void>.value();
    return _skipToIndex(index + 1);
  }

  @override
  Future<void> skipToPrevious() {
    final index = _currentQueueIndex;
    if (index == null) return Future<void>.value();
    return _skipToIndex(index - 1);
  }

  @override
  Future<void> stop() async {
    if (_nativeEngineActive) {
      _logAudioEngine('stop native-engine');
      await _releaseNativeEngineAfterAttempt();
      await _sessionStore?.clear();
      return super.stop();
    }

    _logAudioEngine('stop current-engine');
    await _player.stop();
    await _releaseNativeEngineAfterAttempt();
    await _sessionStore?.clear();
    return super.stop();
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _eventSub.cancel();
    await _indexSub.cancel();
    await _audioInterruptionSub.cancel();
    await _becomingNoisySub.cancel();
    await _playerPositionSub.cancel();
    await _playerDurationSub.cancel();
    await _nativeStateSub?.cancel();
    await _nativePositionSub?.cancel();
    await _nativeDurationSub?.cancel();
    _persistDebounce?.cancel();
    await _intelligenceSink?.dispose();
    await _disposeNativeEngineAfterAttempt();
    await _player.dispose();
    await _positionController.close();
    await _durationController.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState _) {
    // Lifecycle transitions are app visibility changes, not playback intent.
    // Explicit media/user pauses still arrive through pause() and release native
    // playback through the normal path, even while backgrounded or locked.
  }

  static String? normalizeTrackKey(MediaItem item) {
    final trackId = item.extras?['trackId']?.toString();
    final providerId = item.extras?['providerId']?.toString();
    if (trackId != null &&
        trackId.isNotEmpty &&
        providerId != null &&
        providerId.isNotEmpty) {
      return '$providerId::$trackId';
    }

    return item.id.isEmpty ? null : item.id;
  }

  static MediaItem mediaItemFromTrack(Track track) {
    return MediaItem(
      id: track.uri.toString(),
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
      extras: {
        'trackId': track.id,
        'providerId': track.providerId,
        'canonicalUri': track.uri.toString(),
        'artworkId': track.artworkId,
      },
    );
  }

  static Future<List<Uri>> resolveQueueItemUris(
    List<MediaItem> items,
    StreamResolverRegistry registry,
  ) async {
    final resolved = await resolveQueueItemsSafely(items, registry);
    if (resolved.failures.isNotEmpty) {
      throw StateError(resolved.failures.first.message);
    }
    return resolved.uris;
  }

  static Future<ResolvedQueueItems> resolveQueueItemsSafely(
    List<MediaItem> items,
    StreamResolverRegistry registry,
  ) async {
    final queueItems = <MediaItem>[];
    final uris = <Uri>[];
    final failures = <RemoteTrackFailure>[];

    for (final item in items) {
      final providerId = item.extras?['providerId']?.toString();
      if (!_isSubsonicQueueItem(item) &&
          (providerId == null || providerId.isEmpty || providerId == 'local')) {
        queueItems.add(item);
        uris.add(Uri.parse(item.id));
        continue;
      }

      try {
        final uri = await registry.resolve(item);
        queueItems.add(item);
        uris.add(uri);
      } on RemoteTrackResolveException catch (error) {
        failures.add(error.failure);
      } on StateError catch (error) {
        failures.add(
          RemoteTrackFailure.nonRetryable(
            item: item,
            message: error.message.toString(),
          ),
        );
      }
    }

    return ResolvedQueueItems(
      queueItems: List<MediaItem>.unmodifiable(queueItems),
      uris: List<Uri>.unmodifiable(uris),
      failures: List<RemoteTrackFailure>.unmodifiable(failures),
    );
  }

  static bool _isSubsonicQueueItem(MediaItem item) {
    final id = Uri.tryParse(item.id);
    if (id != null && id.isScheme('subsonic')) return true;

    final canonicalUri = item.extras?['canonicalUri']?.toString();
    if (canonicalUri == null || canonicalUri.isEmpty) return false;
    return Uri.tryParse(canonicalUri)?.isScheme('subsonic') ?? false;
  }

  static bool isOriginalLocalFileForNative(MediaItem item) {
    return isOriginalLocalSourceForNative(item);
  }

  static bool isOriginalLocalSourceForNative(MediaItem item) {
    final providerId = item.extras?['providerId']?.toString();
    if (providerId != null && providerId.isNotEmpty && providerId != 'local') {
      return false;
    }
    if (_isSubsonicQueueItem(item)) return false;

    final originalUri = Uri.tryParse(item.id);
    if (originalUri == null) return false;
    if (originalUri.isScheme('file')) {
      return originalUri.toFilePath().isNotEmpty;
    }
    return originalUri.isScheme('content');
  }

  static List<MediaItem> removeQueueItems(
    List<MediaItem> items,
    String mediaItemId,
  ) {
    return items
        .where((item) => item.id != mediaItemId)
        .toList(growable: false);
  }

  static List<MediaItem> insertPlayNext(
    List<MediaItem> items,
    MediaItem item, {
    required int? currentIndex,
  }) {
    final updated = List<MediaItem>.of(items);
    updated.insert(_playNextIndex(items.length, currentIndex), item);
    return List.unmodifiable(updated);
  }

  static List<MediaItem> appendToQueueEnd(
    List<MediaItem> items,
    MediaItem item,
  ) {
    return List.unmodifiable([...items, item]);
  }

  static int _playNextIndex(int queueLength, int? currentIndex) {
    if (queueLength <= 0) return 0;
    if (currentIndex == null || currentIndex < 0) return queueLength;
    return (currentIndex + 1).clamp(0, queueLength);
  }

  void _broadcastState(PlaybackEvent event) {
    if (_nativeEngineActive) return;

    final playing = _player.playing;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.play,
          MediaAction.pause,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _mapProcessingState(_player.processingState),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentQueueIndex ?? event.currentIndex,
        errorCode: _lastRemoteFailure == null
            ? null
            : (_lastRemoteFailure!.retryable
                  ? retryablePlaybackErrorCode
                  : nonRetryablePlaybackErrorCode),
        errorMessage: _lastRemoteFailure?.message,
      ),
    );
    if (!_restoring) {
      _emitCompletedIfNeeded();
      _scheduleSessionPersist();
    }
  }

  void _broadcastNativeState({
    required bool playing,
    Duration? positionOverride,
    AudioProcessingState processingState = AudioProcessingState.ready,
  }) {
    final effectivePosition = positionOverride ?? _nativePosition;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.play,
          MediaAction.pause,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processingState,
        playing: playing,
        updatePosition: effectivePosition,
        bufferedPosition: effectivePosition,
        speed: 1,
        queueIndex: _currentQueueIndex,
      ),
    );
  }

  void _emitPlayStarted() {
    final sink = _intelligenceSink;
    final item = mediaItem.value;
    if (sink == null || item == null) return;
    final trackKey = normalizeTrackKey(item);
    if (trackKey == null || trackKey.isEmpty) return;
    _lastCompletedTrackKey = null;
    sink.recordPlayStarted(trackKey: trackKey);
  }

  void _emitProgress({Duration? positionOverride}) {
    final sink = _intelligenceSink;
    final item = mediaItem.value;
    if (sink == null || item == null) return;
    final trackKey = normalizeTrackKey(item);
    if (trackKey == null || trackKey.isEmpty) return;

    final position =
        (positionOverride ??
                (_nativeEngineActive ? _nativePosition : _player.position))
            .inMilliseconds;
    final duration =
        ((_nativeEngineActive ? _nativeDuration : _player.duration) ??
                item.duration)
            ?.inMilliseconds ??
        0;
    if (position <= 0 || duration <= 0) return;

    sink.recordProgress(
      trackKey: trackKey,
      positionMs: position,
      durationMs: duration,
    );
  }

  void _emitCompletedIfNeeded() {
    if (_player.processingState != ProcessingState.completed) return;
    if (_nativeEngineActive) return;
    final sink = _intelligenceSink;
    final item = mediaItem.value;
    if (sink == null || item == null) return;
    final trackKey = normalizeTrackKey(item);
    if (trackKey == null ||
        trackKey.isEmpty ||
        trackKey == _lastCompletedTrackKey) {
      return;
    }
    sink.recordPlaybackCompleted(trackKey: trackKey);
    _lastCompletedTrackKey = trackKey;
  }

  void _scheduleSessionPersist() {
    final store = _sessionStore;
    if (store == null) return;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 350), () async {
      final currentQueue = queue.value;
      final index = _currentQueueIndex;
      if (currentQueue.isEmpty || index == null || index < 0) return;

      await store.save(
        PlaybackSession(
          queue: currentQueue,
          currentIndex: index,
          position: _nativeEngineActive ? _nativePosition : _player.position,
        ),
      );
    });
  }

  Future<List<AudioSource>> _audioSourcesFor(List<MediaItem> items) async {
    final uris = await resolveQueueItemUris(items, _streamResolverRegistry);
    return [
      for (var index = 0; index < items.length; index++)
        AudioSource.uri(uris[index], tag: items[index]),
    ];
  }

  Future<AudioSource> _audioSourceFor(MediaItem item) async {
    final uri = (await resolveQueueItemUris([
      item,
    ], _streamResolverRegistry)).single;
    return AudioSource.uri(uri, tag: item);
  }

  Future<bool> _prepareCurrentEngineForCurrentItem() async {
    final index = _currentQueueIndex;
    final items = queue.value;
    if (index == null || index < 0 || index >= items.length) return false;

    final item = items[index];
    _queueIndex = index;
    mediaItem.add(item);
    await _player.setAudioSource(await _audioSourceFor(item));
    _currentEngineHasFullQueue = false;
    _logAudioEngine('owner=current-engine action=fallback-prepare');
    return true;
  }

  int? get _currentQueueIndex => _queueIndex ?? _player.currentIndex;

  Future<bool> _tryNativeRestore(_SafeSessionResult safe) async {
    final item = safe.queue[safe.currentIndex];
    Uri uri;
    try {
      uri = (await resolveQueueItemUris([
        item,
      ], _streamResolverRegistry)).single;
    } catch (_) {
      return false;
    }

    final nativeReady = await _tryNativeEngineOrFallback(
      uri,
      originalItem: item,
      title: item.title,
    );
    if (!nativeReady) return false;

    if (safe.position > Duration.zero) {
      try {
        await _nativeEngine?.seek(safe.position);
        _nativePosition = safe.position;
        _positionController.add(safe.position);
      } catch (error) {
        await _releaseNativeEngineAfterAttempt();
        _logAudioEngine(
          'fallback=current-engine reason=native-restore-seek-error native-error code=${_nativeErrorCode(error)} error=${_safeError(error)}',
        );
        return false;
      }
    }
    return true;
  }

  Duration _clampSeekPosition(Duration position) {
    final nonNegative = position.isNegative ? Duration.zero : position;
    final duration = _nativeEngineActive ? _nativeDuration : _player.duration;
    if (duration == null || duration <= Duration.zero) return nonNegative;
    return nonNegative > duration ? duration : nonNegative;
  }

  _SafeSessionResult? _safeSession(PlaybackSession session) {
    final pendingReconcileUris = <Uri>[];
    final cleanedQueue = session.queue
        .where((item) {
          final uri = Uri.tryParse(item.id);
          if (uri == null) return false;
          if (uri.scheme == 'file') {
            final cached = _validationCache.read(uri);
            if (cached != null) {
              pendingReconcileUris.add(uri);
              return cached.state == ValidationState.valid;
            }
            pendingReconcileUris.add(uri);
          }
          return true;
        })
        .toList(growable: false);

    if (cleanedQueue.isEmpty) return null;
    final maxIndex = cleanedQueue.length - 1;
    final index = session.currentIndex > maxIndex
        ? maxIndex
        : session.currentIndex;

    return _SafeSessionResult(
      queue: cleanedQueue,
      currentIndex: index,
      position: session.position,
      savedAt: session.savedAt,
      pendingReconcileUris: pendingReconcileUris,
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    return switch (state) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
  }

  void _updateRemoteFailure(List<RemoteTrackFailure> failures) {
    _lastRemoteFailure = failures.isEmpty ? null : failures.first;
  }

  Future<bool> tryNativeEngineOrFallbackForTesting(
    Uri uri, {
    required MediaItem originalItem,
    required String title,
  }) =>
      _tryNativeEngineOrFallback(uri, originalItem: originalItem, title: title);

  Future<bool> _tryNativeEngineOrFallback(
    Uri uri, {
    required MediaItem originalItem,
    required String title,
    bool allowNativeOutputReuse = false,
  }) async {
    final canReuseExistingNativeOutput =
        allowNativeOutputReuse && _nativeEngineAttempted && _nativeEngineActive;
    final source = VantaAudioSource(
      uri: uri,
      title: title,
      contentMimeType: originalItem.extras?['contentMimeType']?.toString(),
      contentDisplayName: originalItem.extras?['contentDisplayName']
          ?.toString(),
    );

    if (!isOriginalLocalSourceForNative(originalItem)) {
      await _releaseNativeEngineAfterAttempt();
      _logRouteDecision(
        source: source,
        owner: 'current-engine',
        reason: 'non-local-original-source',
      );
      _logAudioEngine(
        'fallback=current-engine reason=non-local-original-source source=${_safeSourceLabel(uri)}',
      );
      return false;
    }

    if (!_engineSelection.shouldAttemptNative(
      settings: _audioSettings,
      source: source,
    )) {
      await _releaseNativeEngineAfterAttempt();
      _logRouteDecision(
        source: source,
        owner: 'current-engine',
        reason: _engineSelection.fallbackReason(source),
      );
      _logAudioEngine(
        'fallback=current-engine reason=${_engineSelection.fallbackReason(source)} source=${_safeSourceLabel(uri)}',
      );
      return false;
    }

    final nativeEngine = _nativeEngine;
    if (nativeEngine == null) {
      await _releaseNativeEngineAfterAttempt();
      _logRouteDecision(
        source: source,
        owner: 'current-engine',
        reason: 'native-engine-unavailable',
      );
      _logAudioEngine(
        'fallback=current-engine reason=native-engine-unavailable',
      );
      return false;
    }

    try {
      if (!canReuseExistingNativeOutput) {
        await _releaseNativeEngineAfterAttempt();
      }
      _logRouteDecision(
        source: source,
        owner: 'native-engine',
        reason: _engineSelection.attemptReason(source),
      );
      _logAudioEngine(
        'attempt=native reason=${_engineSelection.attemptReason(source)} source=${_safeSourceLabel(uri)}',
      );
      _nativeEngineAttempted = true;
      _nativePosition = Duration.zero;
      _nativeDuration = null;
      _nativeStateSub ??= nativeEngine.playbackState.listen(
        _handleNativePlaybackState,
        onError: (Object error) {
          _logAudioEngine('native-state-error error=${_safeError(error)}');
        },
      );
      _nativePositionSub ??= nativeEngine.position.listen(
        _handleNativePosition,
        onError: (Object error) {
          _logAudioEngine('native-position-error error=${_safeError(error)}');
        },
      );
      _nativeDurationSub ??= nativeEngine.duration.listen(
        _handleNativeDuration,
        onError: (Object error) {
          _logAudioEngine('native-duration-error error=${_safeError(error)}');
        },
      );
      await nativeEngine.init();
      await nativeEngine.load(source);
      _nativeEngineActive = true;
      _nativeEnginePlaying = false;
      _nativeCompletionArmed = false;
      _positionController.add(_nativePosition);
      _durationController.add(_nativeDuration);
      _broadcastNativeState(playing: false);
      _logAudioEngine('native-ready source=${_safeSourceLabel(uri)}');
      return true;
    } catch (error) {
      await _releaseNativeEngineAfterAttempt();
      _logAudioEngine(
        'fallback=current-engine reason=native-error native-error code=${_nativeErrorCode(error)} error=${_safeError(error)}',
      );
      return false;
    }
  }

  Future<void> _releaseNativeEngineAfterAttempt({
    bool preservePlaybackState = false,
  }) async {
    if (!_nativeEngineAttempted) return;
    if (preservePlaybackState) {
      _nativeEngineAttempted = false;
      _nativeEngineActive = false;
      _nativeEnginePlaying = false;
      _handlingNativeCompletion = false;
      _nativeCompletionArmed = false;
    }
    try {
      await _nativeEngine?.stop();
    } catch (error) {
      _logAudioEngine('native-release-stop-failed error=${_safeError(error)}');
    } finally {
      await audioSession.setActive(false);
      if (!preservePlaybackState) {
        _nativeEngineAttempted = false;
        _nativeEngineActive = false;
        _nativeEnginePlaying = false;
        _nativePosition = Duration.zero;
        _nativeDuration = null;
        _handlingNativeCompletion = false;
        _nativeCompletionArmed = false;
      }
    }
  }

  Future<bool> _tryPromoteCurrentItemToNativeForPlay() async {
    if (_skipNativePromotionForNextPlay) {
      _skipNativePromotionForNextPlay = false;
      return false;
    }
    final index = _currentQueueIndex;
    final items = queue.value;
    if (index == null || index < 0 || index >= items.length) return false;

    final item = items[index];
    final position = _player.position;
    Uri uri;
    try {
      uri = (await resolveQueueItemUris([
        item,
      ], _streamResolverRegistry)).single;
    } catch (_) {
      return false;
    }

    final nativeReady = await _tryNativeEngineOrFallback(
      uri,
      originalItem: item,
      title: item.title,
    );
    if (!nativeReady) return false;

    try {
      await _player.pause();
    } catch (_) {
      // The current engine may not have been fully prepared yet; native owns
      // playback from this point, so a failed pause should not block routing.
    }
    if (position > Duration.zero) {
      try {
        await _nativeEngine?.seek(position);
        _nativePosition = position;
        _positionController.add(position);
      } catch (error) {
        await _releaseNativeEngineAfterAttempt();
        _logAudioEngine(
          'fallback=current-engine reason=native-promote-seek-error native-error code=${_nativeErrorCode(error)} error=${_safeError(error)}',
        );
        await _prepareCurrentEngineForCurrentItem();
        return false;
      }
    }
    _currentEngineHasFullQueue = false;
    _logAudioEngine('owner=native-engine action=playback-route');
    return true;
  }

  Future<void> _disposeNativeEngineAfterAttempt() async {
    await _releaseNativeEngineAfterAttempt();
    try {
      await _nativeEngine?.dispose();
    } catch (error) {
      _logAudioEngine(
        'native-release-dispose-failed error=${_safeError(error)}',
      );
    } finally {
      _nativeEngineAttempted = false;
      await _nativeStateSub?.cancel();
      _nativeStateSub = null;
    }
  }

  void _handleAudioInterruption(AudioInterruptionEvent event) {
    if (!_nativeEngineActive || !_nativeEnginePlaying) return;

    switch (event.type) {
      case AudioInterruptionType.pause:
      case AudioInterruptionType.unknown:
        if (!event.begin) return;
        unawaited(_pause(_NativePauseOrigin.audioSessionInterruption));
        return;
      case AudioInterruptionType.duck:
        unawaited(_setNativeDucked(event.begin));
        return;
    }
  }

  void _handleBecomingNoisy() {
    if (!_nativeEngineActive || !_nativeEnginePlaying) return;
    unawaited(_pause(_NativePauseOrigin.becomingNoisy));
  }

  Future<void> _setNativeDucked(bool ducked) async {
    if (!_nativeEngineActive) return;
    if (_nativeDucked == ducked) return;
    _nativeDucked = ducked;
    try {
      await _nativeEngine?.setVolume(ducked ? 0.2 : 1.0);
      _logAudioEngine('native-duck=${ducked ? 'active' : 'released'}');
    } catch (error) {
      _logAudioEngine('native-duck-failed error=${_safeError(error)}');
    }
  }

  Future<void> _loadQueueItemForSelectedEngine(int index) async {
    final items = queue.value;
    if (index < 0 || index >= items.length) return;
    final item = items[index];
    _queueIndex = index;
    mediaItem.add(item);
    final uri = (await resolveQueueItemUris([
      item,
    ], _streamResolverRegistry)).single;
    final nativeReady = await _tryNativeEngineOrFallback(
      uri,
      originalItem: item,
      title: item.title,
      allowNativeOutputReuse: _nativeEngineActive,
    );
    if (nativeReady) {
      _currentEngineHasFullQueue = false;
      _logAudioEngine('owner=native-engine action=playback-route');
      return;
    }

    await _player.setAudioSource(AudioSource.uri(uri, tag: item));
    _currentEngineHasFullQueue = false;
    _skipNativePromotionForNextPlay = true;
    _logAudioEngine('owner=current-engine action=playback-route');
  }

  Future<void> _skipToIndex(int index) async {
    final items = queue.value;
    if (index < 0 || index >= items.length) return;
    final shouldResume = _nativeEngineActive
        ? _nativeEnginePlaying
        : _player.playing;
    if (_currentEngineHasFullQueue && !_nativeEngineActive) {
      await _player.seek(Duration.zero, index: index);
      _queueIndex = index;
      mediaItem.add(items[index]);
    } else {
      await _loadQueueItemForSelectedEngine(index);
    }
    if (shouldResume) await play();
    _scheduleSessionPersist();
  }

  void _handleNativePlaybackState(VantaPlaybackState state) {
    if (!_nativeEngineActive) return;
    switch (state.status) {
      case VantaPlaybackStatus.playing:
        _nativeEnginePlaying = true;
        _nativeCompletionArmed = true;
        _broadcastNativeState(playing: true, positionOverride: _nativePosition);
      case VantaPlaybackStatus.paused:
        _nativeEnginePlaying = false;
        _nativeCompletionArmed = false;
        _broadcastNativeState(
          playing: false,
          positionOverride: _nativePosition,
        );
      case VantaPlaybackStatus.stopped:
        _nativeEnginePlaying = false;
        _nativeCompletionArmed = false;
        _nativePosition = Duration.zero;
        _positionController.add(Duration.zero);
        _broadcastNativeState(playing: false);
      case VantaPlaybackStatus.completed:
        if (!_nativeCompletionArmed) return;
        final duration = _nativeDuration;
        if (duration != null) {
          _nativePosition = duration;
          _positionController.add(duration);
        }
        _nativeCompletionArmed = false;
        unawaited(_advanceAfterNativeCompletion());
      case VantaPlaybackStatus.error:
        _logAudioEngine('native-state-error');
      case VantaPlaybackStatus.idle:
      case VantaPlaybackStatus.loading:
      case VantaPlaybackStatus.ready:
      case VantaPlaybackStatus.buffering:
        break;
    }
  }

  void _handleNativePosition(Duration position) {
    if (!_nativeEngineAttempted) return;
    _nativePosition = position;
    if (!_nativeEngineActive) return;
    _positionController.add(position);
    _broadcastNativeState(
      playing: _nativeEnginePlaying,
      positionOverride: position,
    );
  }

  void _handleNativeDuration(Duration? duration) {
    if (!_nativeEngineAttempted) return;
    _nativeDuration = duration;
    if (!_nativeEngineActive) return;
    _durationController.add(duration);
  }

  Future<void> _advanceAfterNativeCompletion() async {
    if (_handlingNativeCompletion || !_nativeEngineActive) return;
    _handlingNativeCompletion = true;
    _nativeEnginePlaying = false;
    _logAudioEngine('native-completed');
    _emitNativeCompletedIfNeeded();

    final currentIndex = _currentQueueIndex;
    final items = queue.value;
    if (currentIndex == null || currentIndex + 1 >= items.length) {
      _broadcastNativeState(
        playing: false,
        processingState: AudioProcessingState.completed,
        positionOverride: _nativePosition,
      );
      await _releaseNativeEngineAfterAttempt(preservePlaybackState: true);
      return;
    }

    final nextIndex = currentIndex + 1;
    _logAudioEngine('advance-next owner=native-completed');
    await _loadQueueItemForSelectedEngine(nextIndex);
    _handlingNativeCompletion = false;
    await play();
    _scheduleSessionPersist();
  }

  void _emitNativeCompletedIfNeeded() {
    final sink = _intelligenceSink;
    final item = mediaItem.value;
    if (sink == null || item == null) return;
    final trackKey = normalizeTrackKey(item);
    if (trackKey == null ||
        trackKey.isEmpty ||
        trackKey == _lastCompletedTrackKey) {
      return;
    }
    sink.recordPlaybackCompleted(trackKey: trackKey);
    _lastCompletedTrackKey = trackKey;
  }

  void _logAudioEngine(String message) {
    // ignore: avoid_print
    print('[VantaAudioEngine] $message');
  }

  void _logRouteDecision({
    required VantaAudioSource source,
    required String owner,
    required String reason,
  }) {
    _logAudioEngine(
      'route-decision mode=${_audioSettings.audioEngineType.name} owner=$owner reason=$reason source=${_safeSourceLabel(source.uri)}',
    );
  }

  String _safeSourceLabel(Uri uri) {
    if (uri.isScheme('file')) {
      return 'file://local';
    }
    if (uri.isScheme('content')) return 'content://redacted';
    if (uri.isScheme('http') || uri.isScheme('https')) {
      return '${uri.scheme}://redacted';
    }
    if (uri.isScheme('subsonic')) return 'subsonic://redacted';
    return '${uri.scheme}:redacted';
  }

  String _safeError(Object error) {
    if (error is VantaAudioEngineException) {
      return 'VantaAudioEngineException(${error.code})';
    }
    return error.runtimeType.toString();
  }

  String _nativeErrorCode(Object error) {
    if (error is VantaAudioEngineException) return error.code;
    return 'unknown';
  }
}

enum _NativePauseOrigin {
  externalCommand('external-command'),
  audioSessionInterruption('audio-session-interruption'),
  becomingNoisy('becoming-noisy');

  const _NativePauseOrigin(this.logValue);

  final String logValue;
}

abstract class StreamResolverRegistry {
  Future<Uri> resolve(MediaItem item);
}

const int retryablePlaybackErrorCode = 1;
const int nonRetryablePlaybackErrorCode = 2;

class RemoteTrackFailure {
  const RemoteTrackFailure({
    required this.item,
    required this.message,
    required this.retryable,
  });

  factory RemoteTrackFailure.nonRetryable({
    required MediaItem item,
    required String message,
  }) {
    return RemoteTrackFailure(item: item, message: message, retryable: false);
  }

  final MediaItem item;
  final String message;
  final bool retryable;
}

class RemoteTrackResolveException implements Exception {
  const RemoteTrackResolveException(this.failure);

  factory RemoteTrackResolveException.retryable({
    required MediaItem item,
    required String message,
  }) {
    return RemoteTrackResolveException(
      RemoteTrackFailure(item: item, message: message, retryable: true),
    );
  }

  factory RemoteTrackResolveException.fromSubsonicFailure({
    required MediaItem item,
    required Exception error,
  }) {
    final retryable =
        error is TimeoutException ||
        error is SubsonicTimeoutFailure ||
        error is SubsonicUnavailableFailure;
    return RemoteTrackResolveException(
      RemoteTrackFailure(
        item: item,
        message:
            'Could not play ${item.title}. ${retryable ? 'Retry this track.' : 'Skip to keep the queue moving.'}',
        retryable: retryable,
      ),
    );
  }

  final RemoteTrackFailure failure;

  bool get retryable => failure.retryable;
  String get message => failure.message;
}

class LocalStreamResolverRegistry implements StreamResolverRegistry {
  const LocalStreamResolverRegistry();

  @override
  Future<Uri> resolve(MediaItem item) async => Uri.parse(item.id);
}

class ResolvedQueueItems {
  const ResolvedQueueItems({
    required this.queueItems,
    required this.uris,
    required this.failures,
  });

  final List<MediaItem> queueItems;
  final List<Uri> uris;
  final List<RemoteTrackFailure> failures;
}

class _SafeSessionResult extends PlaybackSession {
  _SafeSessionResult({
    required super.queue,
    required super.currentIndex,
    required super.position,
    required super.savedAt,
    required this.pendingReconcileUris,
  });

  final List<Uri> pendingReconcileUris;
}
