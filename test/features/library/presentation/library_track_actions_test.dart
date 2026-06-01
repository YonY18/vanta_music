import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/downloads/application/download_providers.dart';
import 'package:vanta_music/features/downloads/domain/download_item.dart';
import 'package:vanta_music/features/downloads/presentation/download_track_actions.dart';
import 'package:vanta_music/features/library/domain/track.dart';
import 'package:vanta_music/features/library/presentation/library_track_actions.dart';

void main() {
  group('track quick actions', () {
    test('builds favorite-off actions with add-to-playlist fallback', () {
      final actions = buildTrackQuickActions(isFavorite: false);

      expect(actions, hasLength(2));
      expect(actions.first.type, TrackQuickActionType.toggleFavorite);
      expect(actions.first.label, 'Agregar a favoritos');
      expect(actions.first.icon, Icons.favorite_border_rounded);
      expect(actions.last.type, TrackQuickActionType.addToPlaylist);
      expect(actions.last.label, 'Agregar a playlist');
      expect(actions.last.icon, Icons.playlist_add_rounded);
    });

    test('appends a downloads shortcut when the surface exposes it', () {
      final actions = buildTrackQuickActions(
        isFavorite: false,
        includeDownloadAction: true,
      );

      expect(actions, hasLength(3));
      expect(actions.last.type, TrackQuickActionType.download);
      expect(actions.last.label, 'Downloads');
      expect(actions.last.icon, Icons.download_rounded);
    });

    test('builds favorite-on actions with proper remove label', () {
      final actions = buildTrackQuickActions(isFavorite: true);

      expect(actions, hasLength(2));
      expect(actions.first.type, TrackQuickActionType.toggleFavorite);
      expect(actions.first.label, 'Quitar de favoritos');
      expect(actions.first.icon, Icons.favorite_rounded);
    });

    testWidgets('hides the download action button for local-only tracks', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DownloadTrackActionButton(track: _track('local-1')),
            ),
          ),
        ),
      );

      expect(find.byTooltip('Download actions'), findsNothing);
    });

    testWidgets('shows retry and delete actions for failed remote downloads', (
      tester,
    ) async {
      final track = _remoteTrack('remote-1');
      final download = _download(track).copyWith(
        status: DownloadStatus.failed,
        retryable: true,
        errorMessage: 'Connection lost',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            downloadItemProvider.overrideWith(
              (ref, downloadKey) => Stream.value(
                downloadKey == download.downloadKey ? download : null,
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: DownloadTrackActionButton(track: track)),
          ),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('Download actions'), findsOneWidget);

      await tester.tap(find.byTooltip('Download actions'));
      await tester.pumpAndSettle();

      expect(find.text('Retry download'), findsOneWidget);
      expect(find.text('Delete download'), findsOneWidget);
      expect(find.text('Download for offline'), findsNothing);
      expect(find.text('Cancel download'), findsNothing);
    });

    testWidgets('shows explicit storage-full feedback when enqueue fails', (
      tester,
    ) async {
      final track = _remoteTrack('remote-storage-full');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            downloadControllerProvider.overrideWith(
              (ref) => _ThrowingDownloadController(
                ref,
                enqueueError: 'Storage full',
              ),
            ),
            downloadItemProvider.overrideWith(
              (ref, downloadKey) => const Stream<DownloadItem?>.empty(),
            ),
            downloadProgressProvider.overrideWith(
              (ref, downloadKey) =>
                  const Stream<DownloadProgressSnapshot?>.empty(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: DownloadTrackActionButton(track: track)),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Download actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download for offline'));
      await tester.pump();

      expect(find.text('Download action failed: Storage full'), findsOneWidget);
      expect(find.text('Download for offline'), findsOneWidget);
      expect(find.text('Available offline on this device.'), findsNothing);
    });

    testWidgets('shows explicit storage-full feedback when retry fails', (
      tester,
    ) async {
      final track = _remoteTrack('remote-retry-storage-full');
      final download = _download(track).copyWith(
        status: DownloadStatus.failed,
        retryable: true,
        errorMessage: 'Storage full',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            downloadControllerProvider.overrideWith(
              (ref) =>
                  _ThrowingDownloadController(ref, retryError: 'Storage full'),
            ),
            downloadItemProvider.overrideWith(
              (ref, downloadKey) => Stream.value(
                downloadKey == download.downloadKey ? download : null,
              ),
            ),
            downloadProgressProvider.overrideWith(
              (ref, downloadKey) =>
                  const Stream<DownloadProgressSnapshot?>.empty(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: DownloadTrackActionButton(track: track)),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Download actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry download'));
      await tester.pump();

      expect(find.text('Download action failed: Storage full'), findsOneWidget);
      expect(find.text('Retry download'), findsOneWidget);
      expect(find.text('Storage full'), findsOneWidget);
      expect(find.text('Available offline on this device.'), findsNothing);
    });
  });
}

class _ThrowingDownloadController extends DownloadController {
  // ignore: use_super_parameters
  _ThrowingDownloadController(Ref ref, {this.enqueueError, this.retryError})
    : super(ref);

  final Object? enqueueError;
  final Object? retryError;

  @override
  Future<DownloadItem?> enqueueTrack(Track track) async {
    if (enqueueError != null) throw enqueueError!;
    return super.enqueueTrack(track);
  }

  @override
  Future<void> retry(String downloadKey) async {
    if (retryError != null) throw retryError!;
    await super.retry(downloadKey);
  }
}

Track _track(String id) {
  return Track(
    id: id,
    providerId: 'local',
    title: 'Track $id',
    artist: 'Artist',
    album: 'Album',
    uri: Uri.parse('file:///music/$id.mp3'),
  );
}

Track _remoteTrack(String id) {
  return Track(
    id: 'subsonic:server-a:$id',
    providerId: 'subsonic:server-a',
    title: 'Track $id',
    artist: 'Artist',
    album: 'Album',
    uri: Uri.parse('subsonic://track?serverId=server-a&id=$id'),
  );
}

DownloadItem _download(Track track) {
  return DownloadItem.createQueued(
    identity: DownloadIdentity(
      providerFamily: 'subsonic',
      providerId: track.providerId,
      serverId: 'server-a',
      trackId: track.uri.queryParameters['id']!,
      remoteItemId: track.id,
      canonicalUri: track.uri.toString(),
    ),
    title: track.title,
    artist: track.artist,
    album: track.album,
    now: DateTime.utc(2026, 6, 1),
  );
}
