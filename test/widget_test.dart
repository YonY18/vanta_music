import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vanta_music/app/app.dart';

void main() {
  testWidgets('shows app title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VantaMusicApp()));
    expect(find.text('Vanta Music'), findsOneWidget);
  });
}
