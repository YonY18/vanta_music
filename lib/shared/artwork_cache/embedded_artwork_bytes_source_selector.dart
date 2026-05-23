import 'dart:typed_data';

import 'artwork_cache_diagnostics.dart';
import 'artwork_cache_resolver.dart';

class EmbeddedArtworkBytesSourceSelector implements EmbeddedArtworkBytesSource {
  const EmbeddedArtworkBytesSourceSelector({
    required this.mp3Source,
    required this.flacSource,
    required this.folderSource,
  });

  final EmbeddedArtworkBytesSource mp3Source;
  final EmbeddedArtworkBytesSource flacSource;
  final EmbeddedArtworkBytesSource folderSource;

  @override
  Future<Uint8List?> fetch({required Uri uri, required int sizePx}) async {
    if (!uri.isScheme('file')) return Future.value(null);
    final path = uri.path.toLowerCase();

    if (path.endsWith('.mp3')) {
      final bytes = await mp3Source.fetch(uri: uri, sizePx: sizePx);
      if (bytes != null && bytes.isNotEmpty) {
        _debugLog(uri, 'mp3 embedded hit bytes=${bytes.length}');
        return bytes;
      }
      _debugLog(uri, 'mp3 embedded miss');
    }
    if (path.endsWith('.flac')) {
      final bytes = await flacSource.fetch(uri: uri, sizePx: sizePx);
      if (bytes != null && bytes.isNotEmpty) {
        _debugLog(uri, 'flac embedded hit bytes=${bytes.length}');
        return bytes;
      }
      _debugLog(uri, 'flac embedded miss');
    }

    final folderBytes = await folderSource.fetch(uri: uri, sizePx: sizePx);
    _debugLog(
      uri,
      folderBytes == null || folderBytes.isEmpty
          ? 'folder cover miss'
          : 'folder cover hit bytes=${folderBytes.length}',
    );
    return folderBytes;
  }

  void _debugLog(Uri uri, String message) {
    logArtworkCacheDiagnostic('[ArtworkCache] $message | uri=$uri');
  }
}
