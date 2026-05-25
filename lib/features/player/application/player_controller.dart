import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/domain/track.dart';
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

final currentQueueProvider = StreamProvider<List<MediaItem>>((ref) {
  return ref.watch(audioHandlerProvider).queue;
});

final playerControllerProvider = Provider<PlayerController>((ref) {
  return PlayerController(ref.watch(audioHandlerProvider));
});

abstract interface class PlayerAudioControl {
  Stream<MediaItem?> get mediaItem;
  Stream<PlaybackState> get playbackState;
  Stream<List<MediaItem>> get queue;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;

  Future<void> playTracks(List<Track> tracks, {int initialIndex = 0});
  Future<void> play();
  Future<void> pause();
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> seek(Duration position);
  Future<void> skipToQueueItem(int index);
  Future<void> removeQueueItemById(String mediaItemId);
  Future<void> playNext(Track track);
  Future<void> addToQueueEnd(Track track);
}

class PlayerController {
  const PlayerController(this._handler);

  final PlayerAudioControl _handler;

  Future<void> playTracks(List<Track> tracks, int index) =>
      _handler.playTracks(tracks, initialIndex: index);
  Future<void> play() => _handler.play();
  Future<void> pause() => _handler.pause();
  Future<void> next() => _handler.skipToNext();
  Future<void> previous() => _handler.skipToPrevious();
  Future<void> seek(Duration position) => _handler.seek(position);
  Future<void> jumpToQueueItem(int index) => _handler.skipToQueueItem(index);
  Future<void> removeFromQueue(String mediaItemId) =>
      _handler.removeQueueItemById(mediaItemId);
  Future<void> playNext(Track track) => _handler.playNext(track);
  Future<void> addToQueueEnd(Track track) => _handler.addToQueueEnd(track);
}
