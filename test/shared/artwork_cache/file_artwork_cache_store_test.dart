import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vanta_music/shared/artwork_cache/artwork_cache_key.dart';
import 'package:vanta_music/shared/artwork_cache/file_artwork_cache_store.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('artwork-cache-store-test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('writes and reads thumbnail path from cache directory', () async {
    final store = FileArtworkCacheStore(
      appSupportDirectory: () async => tempDir,
    );
    final key = buildArtworkCacheKey(
      providerId: 'local',
      trackId: '42',
      artworkId: 7,
      sizePx: 160,
    );

    await store.writeBytes(key, Uint8List.fromList([1, 2, 3]));
    final cachedPath = await store.readPath(key);

    expect(cachedPath, isNotNull);
    expect(cachedPath!, contains('${p.separator}artwork${p.separator}'));
    expect(await File(cachedPath).readAsBytes(), [1, 2, 3]);
  });

  test('returns null when thumbnail is not cached', () async {
    final store = FileArtworkCacheStore(
      appSupportDirectory: () async => tempDir,
    );
    final key = buildArtworkCacheKey(
      providerId: 'local',
      trackId: '42',
      artworkId: 7,
      sizePx: 160,
    );

    expect(await store.readPath(key), isNull);
  });

  test('resolves deterministic file path under artwork folder', () async {
    final store = FileArtworkCacheStore(
      appSupportDirectory: () async => tempDir,
    );
    final key = buildArtworkCacheKey(
      providerId: 'local',
      trackId: '42',
      artworkId: 7,
      sizePx: 160,
    );

    final file = await store.resolveFile(key);
    expect(file.path, startsWith(tempDir.path));
    expect(file.path, contains('${p.separator}artwork${p.separator}'));
  });

  test('evicts oldest files when cache size exceeds max limit', () async {
    final store = FileArtworkCacheStore(
      appSupportDirectory: () async => tempDir,
      maxCacheSizeBytes: 10,
    );

    final keyA = buildArtworkCacheKey(
      providerId: 'local',
      trackId: 'A',
      artworkId: 1,
      sizePx: 160,
    );
    final keyB = buildArtworkCacheKey(
      providerId: 'local',
      trackId: 'B',
      artworkId: 2,
      sizePx: 160,
    );
    final keyC = buildArtworkCacheKey(
      providerId: 'local',
      trackId: 'C',
      artworkId: 3,
      sizePx: 160,
    );

    await store.writeBytes(keyA, Uint8List.fromList([1, 1, 1, 1, 1, 1]));
    await store.writeBytes(keyB, Uint8List.fromList([2, 2, 2, 2, 2, 2]));
    await store.writeBytes(keyC, Uint8List.fromList([3, 3, 3, 3, 3, 3]));

    expect(await store.readPath(keyA), isNull);
    expect(await store.readPath(keyB), isNull);
    final pathC = await store.readPath(keyC);
    expect(pathC, isNotNull);
    expect(await File(pathC!).readAsBytes(), [3, 3, 3, 3, 3, 3]);
  });

  test('updates recency on read hit and evicts older entry first', () async {
    final store = FileArtworkCacheStore(
      appSupportDirectory: () async => tempDir,
      maxCacheSizeBytes: 12,
    );

    final keyA = buildArtworkCacheKey(
      providerId: 'local',
      trackId: 'A',
      artworkId: 1,
      sizePx: 160,
    );
    final keyB = buildArtworkCacheKey(
      providerId: 'local',
      trackId: 'B',
      artworkId: 2,
      sizePx: 160,
    );
    final keyC = buildArtworkCacheKey(
      providerId: 'local',
      trackId: 'C',
      artworkId: 3,
      sizePx: 160,
    );

    await store.writeBytes(keyA, Uint8List.fromList([1, 1, 1, 1, 1, 1]));
    await store.writeBytes(keyB, Uint8List.fromList([2, 2, 2, 2, 2, 2]));

    final fileA = await store.resolveFile(keyA);
    final fileB = await store.resolveFile(keyB);
    final now = DateTime.now();
    await fileA.setLastModified(now.subtract(const Duration(seconds: 20)));
    await fileB.setLastModified(now.subtract(const Duration(seconds: 10)));

    expect(await store.readPath(keyA), isNotNull);

    await store.writeBytes(keyC, Uint8List.fromList([3, 3, 3, 3, 3, 3]));

    expect(await store.readPath(keyA), isNotNull);
    expect(await store.readPath(keyB), isNull);
    expect(await store.readPath(keyC), isNotNull);
  });
}
