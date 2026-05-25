import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/player/application/player_controller.dart';

void main() {
  group('PlayerController queue commands', () {
    test(
      'delegates queue jump and remove commands to the audio control',
      () async {
        final control = _FakePlayerAudioControl();
        final controller = PlayerController(control);

        await controller.jumpToQueueItem(2);
        await controller.removeFromQueue('file:///queue/b.mp3');

        expect(control.jumpedIndex, 2);
        expect(control.removedMediaItemId, 'file:///queue/b.mp3');
      },
    );

    test(
      'delegates play-next and add-end commands with track identity intact',
      () async {
        final control = _FakePlayerAudioControl();
        final controller = PlayerController(control);
        final track = _track('queue-c', 'file:///queue/c.mp3');

        await controller.playNext(track);
        await controller.addToQueueEnd(track);

        expect(control.playNextTrack, same(track));
        expect(control.addEndTrack, same(track));
      },
    );
  });
}

class _FakePlayerAudioControl implements PlayerAudioControl {
  int? jumpedIndex;
  String? removedMediaItemId;
  Track? playNextTrack;
  Track? addEndTrack;

  @override
  Stream<MediaItem?> get mediaItem => const Stream.empty();

  @override
  Stream<PlaybackState> get playbackState => const Stream.empty();

  @override
  Stream<List<MediaItem>> get queue => const Stream.empty();

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Stream<Duration?> get durationStream => const Stream.empty();

  @override
  Future<void> playTracks(List<Track> tracks, {int initialIndex = 0}) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> skipToNext() async {}

  @override
  Future<void> skipToPrevious() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> skipToQueueItem(int index) async {
    jumpedIndex = index;
  }

  @override
  Future<void> removeQueueItemById(String mediaItemId) async {
    removedMediaItemId = mediaItemId;
  }

  @override
  Future<void> playNext(Track track) async {
    playNextTrack = track;
  }

  @override
  Future<void> addToQueueEnd(Track track) async {
    addEndTrack = track;
  }
}

Track _track(String id, String uri) {
  return Track(
    id: id,
    providerId: 'local',
    title: 'Track $id',
    artist: 'Artist',
    album: 'Album',
    uri: Uri.parse(uri),
    duration: const Duration(minutes: 3),
  );
}
