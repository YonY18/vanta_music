import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/player/application/player_controller.dart';
import 'package:vanta_music/features/player/presentation/now_playing_screen.dart';

void main() {
  testWidgets('shows current queue and exposes basic queue commands', (
    tester,
  ) async {
    final control = _FakePlayerAudioControl();
    final controller = PlayerController(control);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaItemProvider.overrideWith((ref) => Stream.value(_item('a'))),
          currentQueueProvider.overrideWith(
            (ref) => Stream.value([_item('a'), _item('b')]),
          ),
          playbackPositionProvider.overrideWith(
            (ref) => Stream.value(Duration.zero),
          ),
          playbackDurationProvider.overrideWith(
            (ref) => Stream.value(const Duration(minutes: 3)),
          ),
          playbackStateProvider.overrideWith(
            (ref) => Stream.value(PlaybackState()),
          ),
          playerControllerProvider.overrideWithValue(controller),
        ],
        child: const MaterialApp(home: NowPlayingScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Queue'));
    await tester.pumpAndSettle();

    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('Track a'), findsWidgets);
    expect(find.text('Track b'), findsOneWidget);

    await tester.tap(find.byTooltip('Play Track b'));
    await tester.pump();
    await tester.tap(find.byTooltip('Remove Track b from queue'));
    await tester.pump();

    expect(control.jumpedIndex, 1);
    expect(control.removedMediaItemId, 'b');
  });

  testWidgets('exposes play-next and add-end actions from track info', (
    tester,
  ) async {
    final control = _FakePlayerAudioControl();
    final controller = PlayerController(control);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaItemProvider.overrideWith((ref) => Stream.value(_item('a'))),
          currentQueueProvider.overrideWith(
            (ref) => Stream.value([_item('a')]),
          ),
          playbackPositionProvider.overrideWith(
            (ref) => Stream.value(Duration.zero),
          ),
          playbackDurationProvider.overrideWith(
            (ref) => Stream.value(const Duration(minutes: 3)),
          ),
          playbackStateProvider.overrideWith(
            (ref) => Stream.value(PlaybackState()),
          ),
          playerControllerProvider.overrideWithValue(controller),
        ],
        child: const MaterialApp(home: NowPlayingScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Track info'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play next'));
    await tester.pump();
    await tester.tap(find.text('Add to queue end'));
    await tester.pump();

    expect(control.playNextTrack?.id, 'a');
    expect(control.addEndTrack?.id, 'a');
  });
}

MediaItem _item(String id) => MediaItem(
  id: id,
  title: 'Track $id',
  artist: 'Artist',
  extras: {'trackId': id, 'providerId': 'local'},
);

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
