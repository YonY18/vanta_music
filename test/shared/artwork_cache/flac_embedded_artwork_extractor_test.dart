import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/shared/artwork_cache/flac_embedded_artwork_extractor.dart';

void main() {
  test('extracts picture bytes from FLAC metadata picture block', () {
    final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
    final data = _buildFlacWithPicture(imageBytes);

    final result = FlacEmbeddedArtworkExtractor.extractFromFlacBytes(data);

    expect(result, imageBytes);
  });

  test('extracts picture bytes after large metadata padding', () {
    final imageBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
    final data = _buildFlacWithBlocks([
      _metadataBlock(type: 1, payload: List.filled(700 * 1024, 0)),
      _metadataBlock(
        type: 6,
        isLast: true,
        payload: _picturePayload(imageBytes, mime: 'image/jpeg'),
      ),
    ]);

    final result = FlacEmbeddedArtworkExtractor.extractFromFlacBytes(data);

    expect(result, imageBytes);
  });

  test('extracts picture bytes from Vorbis METADATA_BLOCK_PICTURE comment', () {
    final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
    final picture = base64.encode(_picturePayload(imageBytes));
    final comment = 'METADATA_BLOCK_PICTURE=$picture';
    final vorbisPayload = <int>[
      ..._u32le('vendor'.length),
      ...'vendor'.codeUnits,
      ..._u32le(1),
      ..._u32le(comment.length),
      ...utf8.encode(comment),
    ];
    final data = _buildFlacWithBlocks([
      _metadataBlock(type: 4, isLast: true, payload: vorbisPayload),
    ]);

    final result = FlacEmbeddedArtworkExtractor.extractFromFlacBytes(data);

    expect(result, imageBytes);
  });

  test('returns null for malformed or non-flac data', () {
    final malformed = Uint8List.fromList([0x66, 0x4C, 0x61, 0x43, 0xFF]);

    final result = FlacEmbeddedArtworkExtractor.extractFromFlacBytes(malformed);

    expect(result, isNull);
  });

  test('fetch returns null for non-file uri', () async {
    const extractor = FlacEmbeddedArtworkExtractor();

    final result = await extractor.fetch(
      uri: Uri.parse('content://media/external/audio/1'),
      sizePx: 256,
    );

    expect(result, isNull);
  });
}

Uint8List _buildFlacWithPicture(Uint8List imageBytes) {
  return _buildFlacWithBlocks([
    _metadataBlock(type: 6, isLast: true, payload: _picturePayload(imageBytes)),
  ]);
}

List<int> _picturePayload(Uint8List imageBytes, {String mime = 'image/png'}) {
  return <int>[
    ..._u32be(3), // front cover
    ..._u32be(mime.length),
    ...mime.codeUnits,
    ..._u32be('Cover'.length),
    ...'Cover'.codeUnits,
    ..._u32be(100),
    ..._u32be(100),
    ..._u32be(24),
    ..._u32be(0),
    ..._u32be(imageBytes.length),
    ...imageBytes,
  ];
}

List<int> _metadataBlock({
  required int type,
  required List<int> payload,
  bool isLast = false,
}) {
  return [(isLast ? 0x80 : 0) | type, ..._u24be(payload.length), ...payload];
}

Uint8List _buildFlacWithBlocks(List<List<int>> blocks) {
  return Uint8List.fromList([
    ...'fLaC'.codeUnits,
    for (final block in blocks) ...block,
  ]);
}

List<int> _u24be(int value) => [
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];

List<int> _u32be(int value) => [
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];

List<int> _u32le(int value) => [
  value & 0xFF,
  (value >> 8) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 24) & 0xFF,
];
