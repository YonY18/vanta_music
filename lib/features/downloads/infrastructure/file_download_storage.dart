import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/download_item.dart';

typedef AppSupportDirectoryResolver = Future<Directory> Function();

class DownloadFileLocations {
  const DownloadFileLocations({
    required this.finalRelativePath,
    required this.tempRelativePath,
    required this.finalFile,
    required this.tempFile,
  });

  final String finalRelativePath;
  final String tempRelativePath;
  final File finalFile;
  final File tempFile;
}

class FileDownloadStorage {
  FileDownloadStorage({AppSupportDirectoryResolver? appSupportDirectory})
    : _appSupportDirectory =
          appSupportDirectory ?? getApplicationSupportDirectory;

  final AppSupportDirectoryResolver _appSupportDirectory;

  Future<DownloadFileLocations> resolvePaths(
    DownloadIdentity identity, {
    String? fileExtension,
  }) async {
    final root = await _appSupportDirectory();
    final extension = _normalizedExtension(fileExtension);
    final relativeDirectory = p.join(
      'downloads',
      identity.providerFamily,
      identity.safeServerSegment,
    );
    final fileName = '${identity.safeTrackSegment}.$extension';
    final finalRelativePath = p.join(relativeDirectory, fileName);
    final tempRelativePath = '$finalRelativePath.part';
    return DownloadFileLocations(
      finalRelativePath: finalRelativePath,
      tempRelativePath: tempRelativePath,
      finalFile: File(p.join(root.path, finalRelativePath)),
      tempFile: File(p.join(root.path, tempRelativePath)),
    );
  }

  Future<void> writeTempChunk(
    String relativePath,
    List<int> bytes, {
    bool append = true,
  }) async {
    final file = await _resolveFile(relativePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      bytes,
      mode: append ? FileMode.writeOnlyAppend : FileMode.writeOnly,
      flush: true,
    );
  }

  Future<File> promoteCompletedFile({
    required String tempRelativePath,
    required String finalRelativePath,
  }) async {
    final tempFile = await _resolveFile(tempRelativePath);
    if (!await tempFile.exists()) {
      throw StateError('Download temp file not found.');
    }
    final stat = await tempFile.stat();
    if (stat.size <= 0) {
      throw StateError('Download temp file is empty.');
    }
    final finalFile = await _resolveFile(finalRelativePath);
    await finalFile.parent.create(recursive: true);
    if (await finalFile.exists()) {
      await finalFile.delete();
    }
    return tempFile.rename(finalFile.path);
  }

  Future<bool> isValidCompletedFile(String relativePath) async {
    final file = await _resolveFile(relativePath);
    if (!await file.exists()) return false;
    return (await file.stat()).size > 0;
  }

  Future<File> resolveFinalFile(String relativePath) {
    return _resolveFile(relativePath);
  }

  Future<void> deleteArtifacts({
    String? finalRelativePath,
    String? tempRelativePath,
  }) async {
    for (final path in [finalRelativePath, tempRelativePath]) {
      if (path == null) continue;
      final file = await _resolveFile(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<List<String>> sweepOrphans(Set<String> referencedRelativePaths) async {
    final root = await _downloadsRoot();
    if (!await root.exists()) return const <String>[];
    final deleted = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relativePath = p.relative(
        entity.path,
        from: (await _appSupportDirectory()).path,
      );
      if (referencedRelativePaths.contains(relativePath)) continue;
      await entity.delete();
      deleted.add(relativePath);
    }
    return deleted;
  }

  Future<Directory> _downloadsRoot() async {
    final root = await _appSupportDirectory();
    return Directory(p.join(root.path, 'downloads'));
  }

  Future<File> _resolveFile(String relativePath) async {
    final root = await _appSupportDirectory();
    return File(p.join(root.path, relativePath));
  }

  String _normalizedExtension(String? fileExtension) {
    final normalized = fileExtension?.trim().replaceFirst(RegExp(r'^\.'), '');
    return normalized == null || normalized.isEmpty ? 'bin' : normalized;
  }
}
