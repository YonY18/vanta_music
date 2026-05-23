import 'dart:io';
import 'dart:typed_data';

import 'artwork_cache_diagnostics.dart';
import 'artwork_cache_resolver.dart';

class FolderArtworkBytesSource implements EmbeddedArtworkBytesSource {
  const FolderArtworkBytesSource({this.candidateNames = defaultCandidateNames});

  static const defaultCandidateNames = [
    'cover.jpg',
    'cover.jpeg',
    'cover.png',
    'cover.webp',
    'folder.jpg',
    'folder.jpeg',
    'folder.png',
    'folder.webp',
    'front.jpg',
    'front.jpeg',
    'front.png',
    'front.webp',
    'album.jpg',
    'album.jpeg',
    'album.png',
    'album.webp',
    'albumart.jpg',
    'albumart.jpeg',
    'albumart.png',
    'albumartsmall.jpg',
    'albumartsmall.jpeg',
    'albumartsmall.png',
  ];

  final List<String> candidateNames;

  @override
  Future<Uint8List?> fetch({required Uri uri, required int sizePx}) async {
    if (!uri.isScheme('file')) return null;

    try {
      final audioFile = File(uri.toFilePath());
      final directory = audioFile.parent;
      if (!await directory.exists()) {
        _debugLog(uri, 'directory does not exist path=${directory.path}');
        return null;
      }

      final filesByLowerName = <String, File>{};
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = _fileName(entity.path).toLowerCase();
        filesByLowerName[name] = entity;
      }

      for (final candidate in candidateNames) {
        final file = filesByLowerName[candidate.toLowerCase()];
        if (file == null) continue;
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          _debugLog(uri, 'matched exact folder cover ${_fileName(file.path)}');
          return bytes;
        }
      }

      for (final entry in filesByLowerName.entries) {
        if (!_isLooseCoverCandidate(entry.key)) continue;
        final bytes = await entry.value.readAsBytes();
        if (bytes.isNotEmpty) {
          _debugLog(
            uri,
            'matched loose folder cover ${_fileName(entry.value.path)}',
          );
          return bytes;
        }
      }

      _debugLog(uri, 'no folder cover among ${filesByLowerName.keys.toList()}');
    } on IOException {
      _debugLog(uri, 'io error while scanning folder');
      return null;
    } on UnsupportedError {
      _debugLog(uri, 'unsupported uri/path');
      return null;
    }

    return null;
  }
}

String _fileName(String path) {
  final separatorIndex = path.lastIndexOf(Platform.pathSeparator);
  if (separatorIndex == -1) return path;
  return path.substring(separatorIndex + 1);
}

bool _isLooseCoverCandidate(String lowerName) {
  final supportedImage =
      lowerName.endsWith('.jpg') ||
      lowerName.endsWith('.jpeg') ||
      lowerName.endsWith('.png') ||
      lowerName.endsWith('.webp');
  if (!supportedImage) return false;

  return lowerName.startsWith('albumart') ||
      lowerName.startsWith('cover') ||
      lowerName.startsWith('folder') ||
      lowerName.startsWith('front');
}

void _debugLog(Uri uri, String message) {
  logArtworkCacheDiagnostic('[ArtworkCache][Folder] $message | uri=$uri');
}
