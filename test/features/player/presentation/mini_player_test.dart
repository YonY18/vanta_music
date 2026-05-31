import 'package:audio_service/audio_service.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/player/application/player_controller.dart';
import 'package:vanta_music/features/player/presentation/mini_player.dart';
import 'package:vanta_music/features/premium_metadata/application/premium_metadata_providers.dart';
import 'package:vanta_music/features/premium_metadata/domain/metadata_models.dart';

void main() {
  testWidgets('renders source title first, then non-blocking enriched title', (
    tester,
  ) async {
    final store = _ControlledMetadataOverrideStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaItemProvider.overrideWith((ref) => Stream.value(_item('a'))),
          playbackStateProvider.overrideWith(
            (ref) => Stream.value(PlaybackState()),
          ),
          playerControllerProvider.overrideWithValue(
            PlayerController(_FakePlayerAudioControl()),
          ),
          metadataOverrideStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: Scaffold(bottomNavigationBar: MiniPlayer()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Source Track'), findsOneWidget);
    expect(find.text('Source Artist'), findsOneWidget);

    store.complete(
      const MetadataOverride(title: 'Display Track', artist: 'Display Artist'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Display Track'), findsOneWidget);
    expect(find.text('Display Artist'), findsOneWidget);
  });
}

MediaItem _item(String id) => MediaItem(
  id: 'content://song/$id',
  title: 'Source Track',
  artist: 'Source Artist',
  album: 'Source Album',
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
  Future<void> playTracks(tracks, {int initialIndex = 0}) async {}

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
  Future<void> skipToQueueItem(int index) async {}

  @override
  Future<void> removeQueueItemById(String mediaItemId) async {}

  @override
  Future<void> playNext(track) async {}

  @override
  Future<void> addToQueueEnd(track) async {}

  @override
  Future<void> retryFailedTrack() async {}
}
