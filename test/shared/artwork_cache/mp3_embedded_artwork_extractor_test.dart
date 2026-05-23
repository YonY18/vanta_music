import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/shared/artwork_cache/mp3_embedded_artwork_extractor.dart';

void main() {
  test('extracts APIC payload from ID3v2.3 tag bytes', () {
    final imageBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
    final data = _buildId3v23WithApic(imageBytes);

    final result = Mp3EmbeddedArtworkExtractor.extractFromId3Bytes(data);

    expect(result, imageBytes);
  });

  test('returns null for non-id3 data', () {
    final data = Uint8List.fromList([1, 2, 3, 4, 5, 6]);

    final result = Mp3EmbeddedArtworkExtractor.extractFromId3Bytes(data);

    expect(result, isNull);
  });
}

Uint8List _buildId3v23WithApic(Uint8List imageBytes) {
  final apicPayload = <int>[
    0x00,
    ...'image/jpeg'.codeUnits,
    0x00,
    0x03,
    ...'Cover'.codeUnits,
    0x00,
    ...imageBytes,
  ];

  final apicFrame = <int>[
    ...'APIC'.codeUnits,
    ..._u32be(apicPayload.length),
    0x00,
    0x00,
    ...apicPayload,
  ];

  final tagSize = apicFrame.length;
  return Uint8List.fromList([
    ...'ID3'.codeUnits,
    0x03,
    0x00,
    0x00,
    ..._synchsafe(tagSize),
    ...apicFrame,
  ]);
}

List<int> _u32be(int value) => [
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];

List<int> _synchsafe(int value) => [
  (value >> 21) & 0x7F,
  (value >> 14) & 0x7F,
  (value >> 7) & 0x7F,
  value & 0x7F,
];
