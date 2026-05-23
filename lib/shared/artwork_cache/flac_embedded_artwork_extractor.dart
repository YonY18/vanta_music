import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'artwork_cache_diagnostics.dart';
import 'artwork_cache_resolver.dart';

class FlacEmbeddedArtworkExtractor implements EmbeddedArtworkBytesSource {
  const FlacEmbeddedArtworkExtractor({this.maxReadBytes = 16 * 1024 * 1024});

  final int maxReadBytes;

  @override
  Future<Uint8List?> fetch({required Uri uri, required int sizePx}) async {
    if (!uri.isScheme('file')) return null;
    final path = uri.toFilePath();
    if (!path.toLowerCase().endsWith('.flac')) return null;

    try {
      final file = File(path);
      if (!await file.exists()) {
        _debugLog(uri, 'file does not exist');
        return null;
      }
      final length = await file.length();
      _debugLog(
        uri,
        'reading ${length < maxReadBytes ? length : maxReadBytes} of $length bytes',
      );
      final bytes = await file.openRead(0, maxReadBytes).fold<BytesBuilder>(
        BytesBuilder(copy: false),
        (builder, chunk) {
          builder.add(chunk);
          return builder;
        },
      );
      final result = extractFromFlacBytes(bytes.takeBytes());
      _debugLog(
        uri,
        result == null
            ? 'no picture found in read window'
            : 'picture found bytes=${result.length}',
      );
      return result;
    } on IOException {
      _debugLog(uri, 'io error');
      return null;
    }
  }

  static Uint8List? extractFromFlacBytes(Uint8List data) {
    if (data.length < 8) return null;
    if (data[0] != 0x66 ||
        data[1] != 0x4C ||
        data[2] != 0x61 ||
        data[3] != 0x43) {
      return null;
    }

    var offset = 4;
    while (offset + 4 <= data.length) {
      final isLast = (data[offset] & 0x80) != 0;
      final blockType = data[offset] & 0x7F;
      final blockLength =
          (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];
      final blockStart = offset + 4;
      final blockEnd = blockStart + blockLength;
      if (blockLength < 0 || blockEnd > data.length) return null;

      if (blockType == 6) {
        return _parsePictureBlock(data, blockStart, blockEnd);
      }

      if (blockType == 4) {
        final picture = _parseVorbisCommentPicture(data, blockStart, blockEnd);
        if (picture != null) return picture;
      }

      offset = blockEnd;
      if (isLast) break;
    }

    return null;
  }
}

void _debugLog(Uri uri, String message) {
  logArtworkCacheDiagnostic('[ArtworkCache][FLAC] $message | uri=$uri');
}

Uint8List? _parseVorbisCommentPicture(Uint8List data, int start, int end) {
  var cursor = start;

  final vendorLength = _readU32le(data, cursor, end);
  if (vendorLength == null) return null;
  cursor += 4;
  if (cursor + vendorLength > end) return null;
  cursor += vendorLength;

  final commentCount = _readU32le(data, cursor, end);
  if (commentCount == null) return null;
  cursor += 4;

  for (var i = 0; i < commentCount; i++) {
    final commentLength = _readU32le(data, cursor, end);
    if (commentLength == null) return null;
    cursor += 4;
    final commentEnd = cursor + commentLength;
    if (commentEnd > end) return null;

    final comment = utf8.decode(
      Uint8List.sublistView(data, cursor, commentEnd),
      allowMalformed: true,
    );
    cursor = commentEnd;

    const key = 'METADATA_BLOCK_PICTURE=';
    if (!comment.toUpperCase().startsWith(key)) continue;

    try {
      final pictureBlock = base64.decode(comment.substring(key.length).trim());
      return _parsePictureBlock(
        Uint8List.fromList(pictureBlock),
        0,
        pictureBlock.length,
      );
    } on FormatException {
      return null;
    }
  }

  return null;
}

Uint8List? _parsePictureBlock(Uint8List data, int start, int end) {
  var cursor = start;

  final type = _readU32(data, cursor, end);
  if (type == null) return null;
  cursor += 4;

  final mimeLength = _readU32(data, cursor, end);
  if (mimeLength == null) return null;
  cursor += 4;
  if (cursor + mimeLength > end) return null;
  cursor += mimeLength;

  final descriptionLength = _readU32(data, cursor, end);
  if (descriptionLength == null) return null;
  cursor += 4;
  if (cursor + descriptionLength > end) return null;
  cursor += descriptionLength;

  // width, height, depth, colors
  for (var i = 0; i < 4; i++) {
    final field = _readU32(data, cursor, end);
    if (field == null) return null;
    cursor += 4;
  }

  final imageDataLength = _readU32(data, cursor, end);
  if (imageDataLength == null) return null;
  cursor += 4;
  final imageEnd = cursor + imageDataLength;
  if (imageEnd > end) return null;
  if (imageDataLength == 0) return null;

  return Uint8List.sublistView(data, cursor, imageEnd);
}

int? _readU32(Uint8List data, int offset, int end) {
  if (offset + 4 > end) return null;
  return (data[offset] << 24) |
      (data[offset + 1] << 16) |
      (data[offset + 2] << 8) |
      data[offset + 3];
}

int? _readU32le(Uint8List data, int offset, int end) {
  if (offset + 4 > end) return null;
  return data[offset] |
      (data[offset + 1] << 8) |
      (data[offset + 2] << 16) |
      (data[offset + 3] << 24);
}
