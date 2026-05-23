import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/shared/artwork_cache/artwork_cache_resolver.dart';
import 'package:vanta_music/shared/artwork_cache/embedded_artwork_bytes_source_selector.dart';

void main() {
  test('routes .flac URIs to FLAC source', () async {
    final mp3 = _FakeEmbeddedSource(result: Uint8List.fromList([1]));
    final flac = _FakeEmbeddedSource(result: Uint8List.fromList([9, 8]));
    final selector = EmbeddedArtworkBytesSourceSelector(
      mp3Source: mp3,
      flacSource: flac,
      folderSource: _FakeEmbeddedSource(result: null),
    );

    final result = await selector.fetch(
      uri: Uri.parse('file:///music/track.flac'),
      sizePx: 256,
    );

    expect(result, [9, 8]);
    expect(flac.calls, 1);
    expect(mp3.calls, 0);
  });

  test('returns null for unsupported extension', () async {
    final selector = EmbeddedArtworkBytesSourceSelector(
      mp3Source: _FakeEmbeddedSource(result: Uint8List.fromList([1])),
      flacSource: _FakeEmbeddedSource(result: Uint8List.fromList([2])),
      folderSource: _FakeEmbeddedSource(result: null),
    );

    final result = await selector.fetch(
      uri: Uri.parse('file:///music/track.wav'),
      sizePx: 128,
    );

    expect(result, isNull);
  });

  test('falls back to folder source when embedded source misses', () async {
    final folder = _FakeEmbeddedSource(result: Uint8List.fromList([7, 7]));
    final selector = EmbeddedArtworkBytesSourceSelector(
      mp3Source: _FakeEmbeddedSource(result: null),
      flacSource: _FakeEmbeddedSource(result: null),
      folderSource: folder,
    );

    final result = await selector.fetch(
      uri: Uri.parse('file:///music/track.flac'),
      sizePx: 128,
    );

    expect(result, [7, 7]);
    expect(folder.calls, 1);
  });
}

class _FakeEmbeddedSource implements EmbeddedArtworkBytesSource {
  _FakeEmbeddedSource({required this.result});

  final Uint8List? result;
  int calls = 0;

  @override
  Future<Uint8List?> fetch({required Uri uri, required int sizePx}) async {
    calls += 1;
    return result;
  }
}
