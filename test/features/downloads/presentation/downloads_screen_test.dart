import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/app/theme.dart';
import 'package:vanta_music/features/downloads/application/download_providers.dart';
import 'package:vanta_music/features/downloads/domain/download_item.dart';
import 'package:vanta_music/features/downloads/presentation/downloads_screen.dart';

void main() {
  testWidgets('shows a loading state while downloads are resolving', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupedDownloadsProvider.overrideWith((ref) => const AsyncLoading()),
          downloadsSummaryProvider.overrideWith((ref) => const AsyncLoading()),
          downloadStorageSummaryProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp(
          theme: buildVantaDarkTheme(),
          home: const DownloadsScreen(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
  });

  testWidgets('shows an empty state when no download records exist', (
    tester,
  ) async {
    await tester.pumpDownloadsScreen();

    expect(find.text('No downloads yet'), findsOneWidget);
    expect(
      find.text('Download remote tracks to manage them offline here.'),
      findsOneWidget,
    );
  });

  testWidgets('renders grouped downloads with storage summary and status totals', (
    tester,
  ) async {
    await tester.pumpDownloadsScreen(
      downloads: [
        _item('queued', status: DownloadStatus.queued),
        _item('downloading', status: DownloadStatus.downloading),
        _item('completed', status: DownloadStatus.completed, sizeBytes: 512),
        _item(
          'failed',
          status: DownloadStatus.failed,
          retryable: true,
          errorMessage: 'Storage full',
        ),
      ],
      storageSummary: const DownloadStorageSummary(
        completedCount: 1,
        totalBytes: 512,
      ),
    );

    expect(find.text('512 B saved offline'), findsOneWidget);
    expect(find.text('1 active'), findsOneWidget);
    expect(find.text('1 pending'), findsOneWidget);
    expect(find.text('1 downloaded'), findsOneWidget);
    expect(find.text('1 failed'), findsOneWidget);
    expect(find.text('Downloading & queued'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Track downloading'), findsOneWidget);
    expect(find.text('Track queued'), findsOneWidget);
    expect(find.text('Track completed'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Track failed'), findsOneWidget);
  });

  testWidgets('shows an operational error card with retry affordance', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupedDownloadsProvider.overrideWith(
            (ref) => AsyncError(Exception('Server unavailable'), StackTrace.empty),
          ),
          downloadsSummaryProvider.overrideWith(
            (ref) => AsyncError(Exception('Server unavailable'), StackTrace.empty),
          ),
          downloadStorageSummaryProvider.overrideWith(
            (ref) => Stream.value(
              const DownloadStorageSummary(completedCount: 0, totalBytes: 0),
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildVantaDarkTheme(),
          home: const DownloadsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Could not load downloads'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('Server unavailable'), findsOneWidget);
  });

  testWidgets('retries failed items, clears failed items, and cancels active items', (
    tester,
  ) async {
    final controller = _TestDownloadControllerState();
    await tester.pumpDownloadsScreen(
      controller: controller,
      downloads: [
        _item('queued', status: DownloadStatus.queued),
        _item(
          'failed',
          status: DownloadStatus.failed,
          retryable: true,
          errorMessage: 'Storage full',
        ),
      ],
    );

    await tester.tap(find.byTooltip('Retry Track failed'));
    await tester.pump();
    expect(controller.retriedKeys, ['subsonic:home::failed']);
    expect(find.text('Retry started for Track failed.'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancel Track queued'));
    await tester.pump();
    expect(controller.cancelledKeys, ['subsonic:home::queued']);
    expect(find.text('Cancelled Track queued.'), findsOneWidget);

    await tester.tap(find.text('Clear failed'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear failed'));
    await tester.pumpAndSettle();

    expect(controller.clearFailedCalls, 1);
    expect(find.text('Cleared 2 failed downloads.'), findsOneWidget);
  });

  testWidgets('confirms delete before removing a non-playing item', (tester) async {
    final controller = _TestDownloadControllerState();
    await tester.pumpDownloadsScreen(
      controller: controller,
      downloads: [_item('completed', status: DownloadStatus.completed)],
    );

    await tester.tap(find.byTooltip('Delete Track completed'));
    await tester.pumpAndSettle();

    expect(find.text('Delete download?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pump();

    expect(controller.deletedKeys, ['subsonic:home::completed']);
    expect(find.text('Deleted Track completed.'), findsOneWidget);
  });

  testWidgets('blocks delete for the currently playing item with clear feedback', (
    tester,
  ) async {
    final controller = _TestDownloadControllerState(
      blockedKeys: {'subsonic:home::completed'},
    );
    await tester.pumpDownloadsScreen(
      controller: controller,
      downloads: [_item('completed', status: DownloadStatus.completed)],
    );

    await tester.tap(find.byTooltip('Delete Track completed'));
    await tester.pump();

    expect(find.text('Delete download?'), findsNothing);
    expect(
      find.text('Stop playback first before deleting this download.'),
      findsOneWidget,
    );
    expect(controller.deletedKeys, isEmpty);
  });
}

extension on WidgetTester {
  Future<void> pumpDownloadsScreen({
    List<DownloadItem> downloads = const <DownloadItem>[],
    DownloadStorageSummary storageSummary = const DownloadStorageSummary(
      completedCount: 0,
      totalBytes: 0,
    ),
    _TestDownloadControllerState? controller,
  }) async {
    final grouped = GroupedDownloads(
      active: downloads
          .where(
            (item) =>
                item.status == DownloadStatus.queued ||
                item.status == DownloadStatus.downloading,
          )
          .toList(growable: false),
      completed: downloads
          .where((item) => item.status == DownloadStatus.completed)
          .toList(growable: false),
      failed: downloads
          .where((item) => item.status == DownloadStatus.failed)
          .toList(growable: false),
    );
    final summary = DownloadsSummary(
      totalCount: downloads.length,
      activeCount: grouped.active
          .where((item) => item.status == DownloadStatus.downloading)
          .length,
      completedCount: grouped.completed.length,
      failedCount: grouped.failed.length,
    );

    await pumpWidget(
      ProviderScope(
        overrides: [
          groupedDownloadsProvider.overrideWith((ref) => AsyncData(grouped)),
          downloadsSummaryProvider.overrideWith((ref) => AsyncData(summary)),
          downloadStorageSummaryProvider.overrideWith(
            (ref) => Stream.value(storageSummary),
          ),
          downloadControllerProvider.overrideWith((ref) {
            final state = controller ?? _TestDownloadControllerState();
            return _TestDownloadController(ref, state);
          }),
        ],
        child: MaterialApp(
          theme: buildVantaDarkTheme(),
          home: const DownloadsScreen(),
        ),
      ),
    );
    await pump();
  }
}

DownloadItem _item(
  String trackId, {
  required DownloadStatus status,
  bool retryable = false,
  int? sizeBytes,
  String? errorMessage,
}) {
  return DownloadItem.createQueued(
    identity: DownloadIdentity(
      providerFamily: 'subsonic',
      providerId: 'subsonic:home',
      serverId: 'home',
      trackId: trackId,
      remoteItemId: 'subsonic:home:$trackId',
      canonicalUri: 'subsonic://track?serverId=home&id=$trackId',
    ),
    title: 'Track $trackId',
    artist: 'Artist',
    album: 'Album',
    now: DateTime.utc(2026, 6, 1, 12),
  ).copyWith(
    status: status,
    retryable: retryable,
    sizeBytes: sizeBytes,
    errorMessage: errorMessage,
    updatedAt: DateTime.utc(2026, 6, 1, 13),
  );
}

class _TestDownloadController extends DownloadController {
  _TestDownloadController(super.ref, this.state);

  final _TestDownloadControllerState state;

  @override
  Future<void> retry(String downloadKey) async {
    state.retriedKeys.add(downloadKey);
  }

  @override
  Future<void> cancel(String downloadKey) async {
    state.cancelledKeys.add(downloadKey);
  }

  @override
  Future<void> delete(String downloadKey) async {
    state.deletedKeys.add(downloadKey);
  }

  @override
  Future<int> clearFailed() async {
    state.clearFailedCalls += 1;
    return 2;
  }

  @override
  DeleteDownloadGuard deleteGuard(String downloadKey) {
    if (state.blockedKeys.contains(downloadKey)) {
      return const DeleteDownloadGuard(
        isBlocked: true,
        reason: 'Stop playback first before deleting this download.',
      );
    }
    return const DeleteDownloadGuard(isBlocked: false);
  }
}

class _TestDownloadControllerState {
  _TestDownloadControllerState({Set<String>? blockedKeys})
    : blockedKeys = blockedKeys ?? <String>{};

  final Set<String> blockedKeys;
  final List<String> retriedKeys = <String>[];
  final List<String> cancelledKeys = <String>[];
  final List<String> deletedKeys = <String>[];
  int clearFailedCalls = 0;
}
