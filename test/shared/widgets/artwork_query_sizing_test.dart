import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/shared/widgets/artwork_query_sizing.dart';

void main() {
  test('scales artwork query size with pixel ratio and caps max px', () {
    expect(resolveArtworkQuerySize(logicalSize: 56, devicePixelRatio: 3), 160);
  });

  test('never returns less than logical size floor', () {
    expect(resolveArtworkQuerySize(logicalSize: 56, devicePixelRatio: 1), 56);
  });
}
