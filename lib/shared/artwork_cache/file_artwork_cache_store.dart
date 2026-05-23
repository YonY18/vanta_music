import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'artwork_cache_key.dart';

typedef AppSupportDirectoryResolver = Future<Directory> Function();

abstract class ArtworkCacheStore {
  Future<String?> readPath(ArtworkCacheKey key);
  Future<void> writeBytes(ArtworkCacheKey key, Uint8List bytes);
}

class FileArtworkCacheStore implements ArtworkCacheStore {
  FileArtworkCacheStore({
    AppSupportDirectoryResolver? appSupportDirectory,
    int maxCacheSizeBytes = defaultMaxCacheSizeBytes,
  }) : _maxCacheSizeBytes = maxCacheSizeBytes,
       _appSupportDirectory =
          appSupportDirectory ?? getApplicationSupportDirectory;

  static const _artworkDirectoryName = 'artwork';
  // Premium app behavior: keep scroll smooth with persistent thumbnails
  // while bounding storage usage to a predictable cap.
  static const int defaultMaxCacheSizeBytes = 256 * 1024 * 1024;

  final AppSupportDirectoryResolver _appSupportDirectory;
  final int _maxCacheSizeBytes;

  Future<File> resolveFile(ArtworkCacheKey key) async {
    final root = await _appSupportDirectory();
    return File(
      p.join(root.path, _artworkDirectoryName, artworkCacheFileName(key)),
    );
  }

  @override
  Future<String?> readPath(ArtworkCacheKey key) async {
    try {
      final file = await resolveFile(key);
      if (!await file.exists()) return null;
      await _touch(file);
      return file.path;
    } on IOException {
      return null;
    }
  }

  @override
  Future<void> writeBytes(ArtworkCacheKey key, Uint8List bytes) async {
    try {
      final file = await resolveFile(key);
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsBytes(bytes, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await temp.rename(file.path);
      await _pruneIfNeeded(file.parent);
    } on IOException {
      return;
    }
  }

  Future<void> _touch(File file) async {
    try {
      await file.setLastModified(DateTime.now());
    } on IOException {
      return;
    }
  }

  Future<void> _pruneIfNeeded(Directory cacheDir) async {
    try {
      if (!await cacheDir.exists()) return;

      final files = <File>[];
      await for (final entity in cacheDir.list(followLinks: false)) {
        if (entity is! File) continue;
        if (entity.path.endsWith('.tmp')) continue;
        files.add(entity);
      }

      var totalSizeBytes = 0;
      final fileStats = <_CacheFileStat>[];
      for (final file in files) {
        final stat = await file.stat();
        totalSizeBytes += stat.size;
        fileStats.add(
          _CacheFileStat(
            file: file,
            sizeBytes: stat.size,
            lastModified: stat.modified,
          ),
        );
      }

      if (totalSizeBytes <= _maxCacheSizeBytes) return;

      fileStats.sort((a, b) => a.lastModified.compareTo(b.lastModified));
      for (final stat in fileStats) {
        try {
          await stat.file.delete();
          totalSizeBytes -= stat.sizeBytes;
          if (totalSizeBytes <= _maxCacheSizeBytes) break;
        } on IOException {
          continue;
        }
      }
    } on IOException {
      return;
    }
  }
}

class _CacheFileStat {
  _CacheFileStat({
    required this.file,
    required this.sizeBytes,
    required this.lastModified,
  });

  final File file;
  final int sizeBytes;
  final DateTime lastModified;
}
