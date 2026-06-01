import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vanta_music/app/app.dart';
import 'package:vanta_music/features/downloads/application/download_providers.dart';
import 'package:vanta_music/features/library_intelligence/application/library_intelligence_refresh.dart';

void main() {
  testWidgets('shows app title', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadBootstrapProvider.overrideWith((ref) async {}),
          libraryIntelligenceRefreshProvider.overrideWith(
            (ref) => LibraryIntelligenceRefresh(),
          ),
        ],
        child: const VantaMusicApp(),
      ),
    );
    expect(find.text('Vanta Music'), findsOneWidget);
  });

  testWidgets('watches download bootstrap on app startup', (tester) async {
    var bootstrapWatched = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadBootstrapProvider.overrideWith((ref) async {
            bootstrapWatched = true;
          }),
          libraryIntelligenceRefreshProvider.overrideWith(
            (ref) => LibraryIntelligenceRefresh(),
          ),
        ],
        child: const VantaMusicApp(),
      ),
    );

    await tester.pump();

    expect(bootstrapWatched, isTrue);
  });
}
