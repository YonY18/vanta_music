import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/app/router.dart';
import 'package:vanta_music/app/theme.dart';
import 'package:vanta_music/features/downloads/application/download_providers.dart';
import 'package:vanta_music/features/downloads/domain/download_item.dart';

void main() {
  testWidgets('opens the downloads route', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupedDownloadsProvider.overrideWith(
            (ref) => const AsyncData(
              GroupedDownloads(
                active: <DownloadItem>[],
                completed: <DownloadItem>[],
                failed: <DownloadItem>[],
              ),
            ),
          ),
          downloadsSummaryProvider.overrideWith(
            (ref) => const AsyncData(
              DownloadsSummary(
                totalCount: 0,
                activeCount: 0,
                completedCount: 0,
                failedCount: 0,
              ),
            ),
          ),
          downloadStorageSummaryProvider.overrideWith(
            (ref) => Stream.value(
              const DownloadStorageSummary(completedCount: 0, totalBytes: 0),
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: buildVantaDarkTheme(),
          routerConfig: buildAppRouter(initialLocation: '/downloads'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('No downloads yet'), findsOneWidget);
  });

  testWidgets('keeps the library route as the default home', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [downloadBootstrapProvider.overrideWith((ref) async {})],
        child: MaterialApp.router(
          theme: buildVantaDarkTheme(),
          routerConfig: buildAppRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vanta Music'), findsOneWidget);
    expect(find.text('Dark. Minimal. Fast.'), findsOneWidget);
  });

  testWidgets('opens the audio settings route', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: buildVantaDarkTheme(),
          routerConfig: buildAppRouter(initialLocation: '/audio-settings'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Audio Settings'), findsOneWidget);
    expect(find.text('Clean Audio Path'), findsOneWidget);
    expect(find.text('Playback Options'), findsOneWidget);
    expect(find.text('Gapless Playback'), findsOneWidget);
    expect(find.text('ReplayGain'), findsOneWidget);
    expect(find.text('Crossfade'), findsOneWidget);
    expect(find.text('Prefer Original Stream'), findsOneWidget);
    expect(
      find.text(
        '“Vanta plays audio as cleanly as Android allows. No EQ, bass boost, virtualizer, loudness enhancement, compression or forced normalization is applied by default.”',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Navidrome / Subsonic'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(find.text('Navidrome / Subsonic'), findsOneWidget);
    expect(find.text('Original stream preferred'), findsOneWidget);
    expect(find.text('No client-side transcoding'), findsOneWidget);
    expect(
      find.text('Server may still transcode depending on server configuration'),
      findsOneWidget,
    );
  });
}
