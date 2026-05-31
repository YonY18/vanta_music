import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vanta_music/features/downloads/domain/download_item.dart';
import 'package:vanta_music/features/downloads/infrastructure/file_download_storage.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'file-download-storage-test',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('builds app-private safe final and temp paths', () async {
    final storage = FileDownloadStorage(
      appSupportDirectory: () async => tempDir,
    );

    final paths = await storage.resolvePaths(
      const DownloadIdentity(
        providerFamily: 'subsonic',
        providerId: 'subsonic:My Server',
        serverId: 'My Server',
        trackId: 'track:/42?bad',
        remoteItemId: 'subsonic:My Server:track:/42?bad',
        canonicalUri:
            'subsonic://track?serverId=My%20Server&id=track%3A%2F42%3Fbad',
      ),
      fileExtension: 'mp3',
    );

    expect(
      paths.finalRelativePath,
      'downloads/subsonic/My_Server/track_42_bad.mp3',
    );
    expect(
      paths.tempRelativePath,
      'downloads/subsonic/My_Server/track_42_bad.mp3.part',
    );
    expect(
      paths.finalFile.path,
      p.join(
        tempDir.path,
        'downloads',
        'subsonic',
        'My_Server',
        'track_42_bad.mp3',
      ),
    );
  });

  test('promotes only non-empty temp files into final files', () async {
    final storage = FileDownloadStorage(
      appSupportDirectory: () async => tempDir,
    );
    final paths = await storage.resolvePaths(
      _identity('song-1'),
      fileExtension: 'mp3',
    );

    await storage.writeTempChunk(paths.tempRelativePath, [1, 2, 3]);
    final promoted = await storage.promoteCompletedFile(
      tempRelativePath: paths.tempRelativePath,
      finalRelativePath: paths.finalRelativePath,
    );

    expect(promoted.lengthSync(), 3);
    expect(await File(paths.tempFile.path).exists(), isFalse);
    expect(await storage.isValidCompletedFile(paths.finalRelativePath), isTrue);
  });

  test('rejects empty temp files and sweeps orphan artifacts safely', () async {
    final storage = FileDownloadStorage(
      appSupportDirectory: () async => tempDir,
    );
    final keep = await storage.resolvePaths(
      _identity('keep'),
      fileExtension: 'mp3',
    );
    final orphan = await storage.resolvePaths(
      _identity('orphan'),
      fileExtension: 'mp3',
    );

    await storage.writeTempChunk(keep.tempRelativePath, [7, 7]);
    await storage.promoteCompletedFile(
      tempRelativePath: keep.tempRelativePath,
      finalRelativePath: keep.finalRelativePath,
    );
    await storage.writeTempChunk(orphan.tempRelativePath, const <int>[]);
    await storage.writeTempChunk(orphan.finalRelativePath, [
      9,
      9,
    ], append: false);

    await expectLater(
      () => storage.promoteCompletedFile(
        tempRelativePath: orphan.tempRelativePath,
        finalRelativePath: orphan.finalRelativePath,
      ),
      throwsA(isA<StateError>()),
    );

    final deleted = await storage.sweepOrphans({keep.finalRelativePath});

    expect(deleted, contains(orphan.finalRelativePath));
    expect(await keep.finalFile.exists(), isTrue);
    expect(await orphan.finalFile.exists(), isFalse);
  });
}

DownloadIdentity _identity(String trackId) {
  return DownloadIdentity(
    providerFamily: 'subsonic',
    providerId: 'subsonic:home',
    serverId: 'home',
    trackId: trackId,
    remoteItemId: 'subsonic:home:$trackId',
    canonicalUri: 'subsonic://track?serverId=home&id=$trackId',
  );
}
