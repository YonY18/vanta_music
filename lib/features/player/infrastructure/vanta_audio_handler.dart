import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../library_intelligence/application/library_intelligence_sink.dart';
import '../../library/application/file_validation_cache.dart';
import '../../library/domain/track.dart';
import '../application/playback_session_store.dart';
import '../domain/playback_session.dart';

class VantaAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  VantaAudioHandler({
    PlaybackSessionStore? sessionStore,
    InMemoryFileValidationCache? validationCache,
    LibraryIntelligenceSink? intelligenceSink,
  }) : _sessionStore = sessionStore,
       _validationCache = validationCache ?? InMemoryFileValidationCache(),
       _intelligenceSink = intelligenceSink {
    _eventSub = _player.playbackEventStream.listen(_broadcastState);
    _indexSub = _player.currentIndexStream.listen((index) {
      final items = queue.value;
      if (index != null && index >= 0 && index < items.length) {
        mediaItem.add(items[index]);
      }
      _broadcastState(_player.playbackEvent);
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final PlaybackSessionStore? _sessionStore;
  final InMemoryFileValidationCache _validationCache;
  final LibraryIntelligenceSink? _intelligenceSink;
  late final StreamSubscription<PlaybackEvent> _eventSub;
  late final StreamSubscription<int?> _indexSub;

  Timer? _persistDebounce;
  bool _restoring = false;
  String? _lastCompletedTrackKey;

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
    await _player.setAudioSources(
      safe.queue
          .map((item) => AudioSource.uri(Uri.parse(item.id), tag: item))
          .toList(growable: false),
      initialIndex: safe.currentIndex,
      initialPosition: safe.position,
    );
    _restoring = false;
    _broadcastState(_player.playbackEvent);

    if (safe.pendingReconcileUris.isNotEmpty) {
      unawaited(_validationCache.reconcileBatch(safe.pendingReconcileUris));
    }
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  Future<void> setQueueAndPlay(
    List<Track> tracks, {
    int initialIndex = 0,
  }) async {
    if (tracks.isEmpty) return;

    final items = tracks.map(_toMediaItem).toList(growable: false);
    queue.add(items);
    mediaItem.add(items[initialIndex]);

    await _player.setAudioSources(
      items
          .map((item) => AudioSource.uri(Uri.parse(item.id), tag: item))
          .toList(growable: false),
      initialIndex: initialIndex,
      initialPosition: Duration.zero,
    );
    await play();
    _scheduleSessionPersist();
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    queue.add([mediaItem]);
    this.mediaItem.add(mediaItem);
    await _player.setAudioSource(
      AudioSource.uri(Uri.parse(mediaItem.id), tag: mediaItem),
    );
    await play();
    _scheduleSessionPersist();
  }

  @override
  Future<void> play() async {
    _emitPlayStarted();
    return _player.play();
  }

  @override
  Future<void> pause() async {
    _emitProgress();
    return _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _emitProgress(positionOverride: position);
  }

  @override
  Future<void> skipToQueueItem(int index) =>
      _player.seek(Duration.zero, index: index).then((_) => _scheduleSessionPersist());

  @override
  Future<void> skipToNext() => _player.seekToNext().then((_) => _scheduleSessionPersist());

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious().then((_) => _scheduleSessionPersist());

  @override
  Future<void> stop() async {
    await _player.stop();
    await _sessionStore?.clear();
    return super.stop();
  }

  Future<void> dispose() async {
    await _eventSub.cancel();
    await _indexSub.cancel();
    _persistDebounce?.cancel();
    await _intelligenceSink?.dispose();
    await _player.dispose();
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

  MediaItem _toMediaItem(Track track) {
    return MediaItem(
      id: track.uri.toString(),
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
      extras: {
        'trackId': track.id,
        'providerId': track.providerId,
        'artworkId': track.artworkId,
      },
    );
  }

  void _broadcastState(PlaybackEvent event) {
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
        queueIndex: event.currentIndex,
      ),
    );
    if (!_restoring) {
      _emitCompletedIfNeeded();
      _scheduleSessionPersist();
    }
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

    final position = (positionOverride ?? _player.position).inMilliseconds;
    final duration = (_player.duration ?? item.duration)?.inMilliseconds ?? 0;
    if (position <= 0 || duration <= 0) return;

    sink.recordProgress(trackKey: trackKey, positionMs: position, durationMs: duration);
  }

  void _emitCompletedIfNeeded() {
    if (_player.processingState != ProcessingState.completed) return;
    final sink = _intelligenceSink;
    final item = mediaItem.value;
    if (sink == null || item == null) return;
    final trackKey = normalizeTrackKey(item);
    if (trackKey == null || trackKey.isEmpty || trackKey == _lastCompletedTrackKey) {
      return;
    }
    sink.recordPlaybackCompleted(trackKey: trackKey);
    _lastCompletedTrackKey = trackKey;
  }

  void _scheduleSessionPersist() {
    if (_sessionStore == null) return;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 350), () async {
      final currentQueue = queue.value;
      final index = _player.currentIndex;
      if (currentQueue.isEmpty || index == null || index < 0) return;

      await _sessionStore!.save(
        PlaybackSession(
          queue: currentQueue,
          currentIndex: index,
          position: _player.position,
        ),
      );
    });
  }

  _SafeSessionResult? _safeSession(PlaybackSession session) {
    final pendingReconcileUris = <Uri>[];
    final cleanedQueue = session.queue.where((item) {
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
    }).toList(growable: false);

    if (cleanedQueue.isEmpty) return null;
    final maxIndex = cleanedQueue.length - 1;
    final index = session.currentIndex > maxIndex ? maxIndex : session.currentIndex;

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
