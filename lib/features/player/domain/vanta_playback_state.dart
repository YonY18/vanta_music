enum VantaPlaybackStatus { idle, loading, buffering, ready, completed, error }

class VantaPlaybackState {
  const VantaPlaybackState({
    required this.playing,
    required this.status,
    this.position = Duration.zero,
    this.duration,
  });

  final bool playing;
  final VantaPlaybackStatus status;
  final Duration position;
  final Duration? duration;
}
