import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/domain/track.dart';
import '../infrastructure/vanta_audio_handler.dart';
import 'audio_handler_provider.dart';

final mediaItemProvider = StreamProvider<MediaItem?>((ref) {
  return ref.watch(audioHandlerProvider).mediaItem;
});

final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  return ref.watch(audioHandlerProvider).playbackState;
});

final playbackPositionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(audioHandlerProvider).positionStream;
});

final playbackDurationProvider = StreamProvider<Duration?>((ref) {
  return ref.watch(audioHandlerProvider).durationStream;
});

final playerControllerProvider = Provider<PlayerController>((ref) {
  return PlayerController(ref.watch(audioHandlerProvider));
});

class PlayerController {
  const PlayerController(this._handler);

  final VantaAudioHandler _handler;

  Future<void> playTracks(List<Track> tracks, int index) =>
      _handler.setQueueAndPlay(tracks, initialIndex: index);
  Future<void> play() => _handler.play();
  Future<void> pause() => _handler.pause();
  Future<void> next() => _handler.skipToNext();
  Future<void> previous() => _handler.skipToPrevious();
  Future<void> seek(Duration position) => _handler.seek(position);
}
