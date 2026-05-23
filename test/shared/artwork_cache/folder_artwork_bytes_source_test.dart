import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/shared/artwork_cache/folder_artwork_bytes_source.dart';

void main() {
  test(
    'reads common cover image from the same folder as the audio file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'vanta_cover_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final track = File('${directory.path}${Platform.pathSeparator}song.flac');
      final cover = File('${directory.path}${Platform.pathSeparator}cover.jpg');
      await track.writeAsBytes([1, 2, 3]);
      await cover.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);

      const source = FolderArtworkBytesSource();

      final result = await source.fetch(uri: track.uri, sizePx: 256);

      expect(result, Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]));
    },
  );

  test('returns null when folder has no known cover image', () async {
    final directory = await Directory.systemTemp.createTemp(
      'vanta_cover_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final track = File('${directory.path}${Platform.pathSeparator}song.flac');
    await track.writeAsBytes([1, 2, 3]);

    const source = FolderArtworkBytesSource();

    final result = await source.fetch(uri: track.uri, sizePx: 256);

    expect(result, isNull);
  });

  test('matches cover image names case-insensitively', () async {
    final directory = await Directory.systemTemp.createTemp(
      'vanta_cover_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final track = File('${directory.path}${Platform.pathSeparator}song.flac');
    final cover = File('${directory.path}${Platform.pathSeparator}Folder.JPG');
    await track.writeAsBytes([1, 2, 3]);
    await cover.writeAsBytes([9, 8, 7]);

    const source = FolderArtworkBytesSource();

    final result = await source.fetch(uri: track.uri, sizePx: 256);

    expect(result, Uint8List.fromList([9, 8, 7]));
  });

  test('matches Android album art file names loosely', () async {
    final directory = await Directory.systemTemp.createTemp(
      'vanta_cover_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final track = File('${directory.path}${Platform.pathSeparator}song.flac');
    final cover = File(
      '${directory.path}${Platform.pathSeparator}AlbumArt_123_Large.JPG',
    );
    await track.writeAsBytes([1, 2, 3]);
    await cover.writeAsBytes([6, 5, 4]);

    const source = FolderArtworkBytesSource();

    final result = await source.fetch(uri: track.uri, sizePx: 256);

    expect(result, Uint8List.fromList([6, 5, 4]));
  });
}
