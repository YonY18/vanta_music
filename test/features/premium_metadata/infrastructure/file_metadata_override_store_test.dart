import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vanta_music/features/premium_metadata/domain/metadata_models.dart';
import 'package:vanta_music/features/premium_metadata/infrastructure/file_metadata_override_store.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'metadata-override-store-test',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saves and loads override by stable track key', () async {
    final store = FileMetadataOverrideStore(
      appSupportDirectory: () async => tempDir,
    );
    const override = MetadataOverride(
      title: 'Local Title',
      artist: 'Local Artist',
    );

    await store.saveOverride('local::42', override);
    final loaded = await store.loadOverride('local::42');

    expect(loaded?.title, 'Local Title');
    expect(loaded?.artist, 'Local Artist');
    expect(loaded?.album, isNull);
  });

  test(
    'clear removes a saved override without touching other entries',
    () async {
      final store = FileMetadataOverrideStore(
        appSupportDirectory: () async => tempDir,
      );

      await store.saveOverride(
        'local::1',
        const MetadataOverride(title: 'One'),
      );
      await store.saveOverride(
        'local::2',
        const MetadataOverride(title: 'Two'),
      );
      await store.clearOverride('local::1');

      expect(await store.loadOverride('local::1'), isNull);
      expect((await store.loadOverride('local::2'))?.title, 'Two');
    },
  );

  test(
    'returns null for invalid json and keeps source metadata reversible',
    () async {
      final store = FileMetadataOverrideStore(
        appSupportDirectory: () async => tempDir,
      );
      final file = File(p.join(tempDir.path, 'metadata_overrides.json'));
      await file.writeAsString('{invalid json');

      final loaded = await store.loadOverride('local::broken');

      expect(loaded, isNull);
    },
  );
}
