import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:vanta_music/shared/widgets/artwork_tile.dart';

void main() {
  testWidgets('renders placeholder only when artwork is deferred', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArtworkTile(
            id: 42,
            type: ArtworkType.AUDIO,
            showPlaceholderOnly: true,
          ),
        ),
      ),
    );

    expect(find.byType(QueryArtworkWidget), findsNothing);
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    expect(tester.getSize(find.byType(ArtworkTile)), const Size.square(56));
  });

  testWidgets('keeps a fixed box for queried artwork', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArtworkTile(
            id: 42,
            type: ArtworkType.AUDIO,
          ),
        ),
      ),
    );

    expect(find.byType(QueryArtworkWidget), findsOneWidget);
    expect(tester.getSize(find.byType(ArtworkTile)), const Size.square(56));
  });
}
