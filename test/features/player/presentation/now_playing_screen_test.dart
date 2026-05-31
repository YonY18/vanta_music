import 'package:audio_service/audio_service.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/player/application/player_controller.dart';
import 'package:vanta_music/features/player/presentation/now_playing_screen.dart';
import 'package:vanta_music/features/premium_metadata/application/premium_metadata_providers.dart';
import 'package:vanta_music/features/premium_metadata/domain/metadata_models.dart';

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

  testWidgets(
    'renders source metadata first, then enriched now-playing metadata',
    (tester) async {
      final store = _ControlledMetadataOverrideStore();

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
            playerControllerProvider.overrideWithValue(
              PlayerController(_FakePlayerAudioControl()),
            ),
            metadataOverrideStoreProvider.overrideWithValue(store),
          ],
          child: const MaterialApp(home: NowPlayingScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Track a'), findsOneWidget);
      expect(find.text('Artist'), findsOneWidget);

      store.complete(
        const MetadataOverride(
          title: 'Display Track',
          artist: 'Display Artist',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Display Track'), findsOneWidget);
      expect(find.text('Display Artist'), findsOneWidget);
    },
  );

  testWidgets('shows retryable playback errors and exposes retry action', (
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
            (ref) => Stream.value(
              PlaybackState(
                errorMessage: 'Could not play Track a. Retry this track.',
                errorCode: 1,
              ),
            ),
          ),
          playerControllerProvider.overrideWithValue(controller),
        ],
        child: const MaterialApp(home: NowPlayingScreen()),
      ),
    );
    await tester.pump();

    expect(
      find.text('Could not play Track a. Retry this track.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Retry track'));
    await tester.tap(find.text('Retry track'));
    await tester.pump();

    expect(control.retryRequested, isTrue);
  });
}

MediaItem _item(String id) => MediaItem(
  id: id,
  title: 'Track $id',
  artist: 'Artist',
  extras: {'trackId': id, 'providerId': 'local'},
);

class _ControlledMetadataOverrideStore implements MetadataOverrideStore {
  final Completer<MetadataOverride?> _completer =
      Completer<MetadataOverride?>();

  void complete(MetadataOverride? override) {
    _completer.complete(override);
  }

  @override
  Future<MetadataOverride?> loadOverride(String trackKey) => _completer.future;

  @override
  Future<void> saveOverride(String trackKey, MetadataOverride override) async {}

  @override
  Future<void> clearOverride(String trackKey) async {}
}

class _FakePlayerAudioControl implements PlayerAudioControl {
  int? jumpedIndex;
  String? removedMediaItemId;
  Track? playNextTrack;
  Track? addEndTrack;
  bool retryRequested = false;

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

  @override
  Future<void> retryFailedTrack() async {
    retryRequested = true;
  }
}
