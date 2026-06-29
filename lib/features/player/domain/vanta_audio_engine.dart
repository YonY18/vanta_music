import 'audio_technical_info.dart';

enum VantaPlaybackStatus {
  idle,
  loading,
  ready,
  playing,
  paused,
  stopped,
  buffering,
  completed,
  error,
}

class VantaAudioSource {
  const VantaAudioSource({
    required this.uri,
    this.title,
    this.artist,
    this.contentMimeType,
    this.contentDisplayName,
  });

  final Uri uri;
  final String? title;
  final String? artist;
  final String? contentMimeType;
  final String? contentDisplayName;

  bool get isLocalFile => uri.isScheme('file') && uri.toFilePath().isNotEmpty;
  bool get isContentUri => uri.isScheme('content');
  bool get isRemote => uri.isScheme('http') || uri.isScheme('https');
}

class VantaPlaybackState {
  const VantaPlaybackState({
    required this.status,
    this.errorMessage,
    this.source,
  });

  static const idle = VantaPlaybackState(status: VantaPlaybackStatus.idle);

  final VantaPlaybackStatus status;
  final String? errorMessage;
  final VantaAudioSource? source;
}

abstract interface class VantaAudioEngine {
  Stream<VantaPlaybackState> get playbackState;
  Stream<Duration> get position;
  Stream<Duration?> get duration;
  Stream<VantaAudioTechnicalInfo?> get technicalInfo;

  Future<void> init();
  Future<void> load(VantaAudioSource source);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

class VantaAudioEngineException implements Exception {
  const VantaAudioEngineException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'VantaAudioEngineException($code): $message';
}
