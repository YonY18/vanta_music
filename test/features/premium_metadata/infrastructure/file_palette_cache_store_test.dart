import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/premium_metadata/domain/metadata_models.dart';
import 'package:vanta_music/features/premium_metadata/infrastructure/file_palette_cache_store.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('palette-cache-store-test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saves and loads palette by artwork cache key', () async {
    final store = FilePaletteCacheStore(
      appSupportDirectory: () async => tempDir,
    );
    const palette = ArtworkPalette(
      dominantColor: 0xff101010,
      accentColor: 0xffaabbcc,
    );

    await store.savePalette('artwork::1', palette);
    final loaded = await store.loadPalette('artwork::1');

    expect(loaded?.dominantColor, 0xff101010);
    expect(loaded?.accentColor, 0xffaabbcc);
  });

  test('clear removes palette cache entry', () async {
    final store = FilePaletteCacheStore(
      appSupportDirectory: () async => tempDir,
    );

    await store.savePalette(
      'artwork::1',
      const ArtworkPalette(dominantColor: 0xff000001),
    );
    await store.clearPalette('artwork::1');

    expect(await store.loadPalette('artwork::1'), isNull);
  });

  test(
    'evicts oldest palette entries when max entry limit is exceeded',
    () async {
      final store = FilePaletteCacheStore(
        appSupportDirectory: () async => tempDir,
        maxEntries: 2,
      );

      await store.savePalette(
        'artwork::1',
        const ArtworkPalette(dominantColor: 1),
      );
      await store.savePalette(
        'artwork::2',
        const ArtworkPalette(dominantColor: 2),
      );
      await store.savePalette(
        'artwork::3',
        const ArtworkPalette(dominantColor: 3),
      );

      expect(await store.loadPalette('artwork::1'), isNull);
      expect((await store.loadPalette('artwork::2'))?.dominantColor, 2);
      expect((await store.loadPalette('artwork::3'))?.dominantColor, 3);
    },
  );
}
