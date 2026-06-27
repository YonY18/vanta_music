import 'package:vanta_audio_engine/vanta_audio_engine.dart' as native;

import '../domain/vanta_audio_engine.dart';

class NativeVantaEngineAdapter implements VantaAudioEngine {
  NativeVantaEngineAdapter({native.NativeVantaAudioEngine? engine})
    : _engine = engine ?? native.NativeVantaAudioEngine();

  final native.NativeVantaAudioEngine _engine;

  @override
  Stream<VantaPlaybackState> get playbackState => _engine.playbackState.map(
    (state) => VantaPlaybackState(
      status: _mapStatus(state.status),
      errorMessage: state.errorMessage,
    ),
  );

  @override
  Stream<Duration> get position => _engine.position;

  @override
  Stream<Duration?> get duration => _engine.duration;

  @override
  Future<void> init() => _mapNativeErrors(_engine.init);

  @override
  Future<void> load(VantaAudioSource source) => _mapNativeErrors(
    () => _engine.load(
      source.uri,
      contentMimeType: source.contentMimeType,
      contentDisplayName: source.contentDisplayName,
    ),
  );

  @override
  Future<void> play() => _mapNativeErrors(_engine.play);

  @override
  Future<void> pause() => _mapNativeErrors(_engine.pause);

  @override
  Future<void> stop() => _mapNativeErrors(_engine.stop);

  @override
  Future<void> seek(Duration position) =>
      _mapNativeErrors(() => _engine.seek(position));

  @override
  Future<void> setVolume(double volume) =>
      _mapNativeErrors(() => _engine.setVolume(volume));

  @override
  Future<void> dispose() => _mapNativeErrors(_engine.dispose);

  Future<void> _mapNativeErrors(Future<void> Function() action) async {
    try {
      await action();
    } on native.NativeVantaAudioEngineException catch (error) {
      throw VantaAudioEngineException(error.code, error.message);
    }
  }

  VantaPlaybackStatus _mapStatus(native.NativePlaybackStatus status) {
    return switch (status) {
      native.NativePlaybackStatus.idle => VantaPlaybackStatus.idle,
      native.NativePlaybackStatus.loading => VantaPlaybackStatus.loading,
      native.NativePlaybackStatus.ready => VantaPlaybackStatus.ready,
      native.NativePlaybackStatus.playing => VantaPlaybackStatus.playing,
      native.NativePlaybackStatus.paused => VantaPlaybackStatus.paused,
      native.NativePlaybackStatus.stopped => VantaPlaybackStatus.stopped,
      native.NativePlaybackStatus.buffering => VantaPlaybackStatus.buffering,
      native.NativePlaybackStatus.completed => VantaPlaybackStatus.completed,
      native.NativePlaybackStatus.error => VantaPlaybackStatus.error,
    };
  }
}
