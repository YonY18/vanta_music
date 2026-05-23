import 'dart:io';
import 'dart:typed_data';

import 'artwork_cache_resolver.dart';

class Mp3EmbeddedArtworkExtractor implements EmbeddedArtworkBytesSource {
  const Mp3EmbeddedArtworkExtractor({this.maxReadBytes = 256 * 1024});

  final int maxReadBytes;

  @override
  Future<Uint8List?> fetch({required Uri uri, required int sizePx}) async {
    if (!uri.isScheme('file')) return null;
    final path = uri.toFilePath();
    if (!path.toLowerCase().endsWith('.mp3')) return null;

    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.openRead(0, maxReadBytes).fold<BytesBuilder>(
        BytesBuilder(copy: false),
        (builder, chunk) {
          builder.add(chunk);
          return builder;
        },
      );
      return extractFromId3Bytes(bytes.takeBytes());
    } on IOException {
      return null;
    }
  }

  static Uint8List? extractFromId3Bytes(Uint8List data) {
    if (data.length < 10) return null;
    if (data[0] != 0x49 || data[1] != 0x44 || data[2] != 0x33) return null;

    final major = data[3];
    if (major < 2 || major > 4) return null;

    final tagSize = _synchsafeToInt(data, 6);
    final limit = (10 + tagSize).clamp(10, data.length);
    var offset = 10;

    while (offset + (major == 2 ? 6 : 10) <= limit) {
      if (major == 2) {
        final frameId = String.fromCharCodes(data.sublist(offset, offset + 3));
        if (frameId.trim().isEmpty) break;
        final frameSize = (data[offset + 3] << 16) |
            (data[offset + 4] << 8) |
            data[offset + 5];
        final payloadStart = offset + 6;
        final payloadEnd = payloadStart + frameSize;
        if (frameSize <= 0 || payloadEnd > limit) break;
        if (frameId == 'PIC') {
          return _parsePicFrame(data.sublist(payloadStart, payloadEnd));
        }
        offset = payloadEnd;
        continue;
      }

      final frameId = String.fromCharCodes(data.sublist(offset, offset + 4));
      if (frameId.trim().isEmpty) break;
      final frameSize = major == 4
          ? _synchsafeToInt(data, offset + 4)
          : _u32beToInt(data, offset + 4);
      final payloadStart = offset + 10;
      final payloadEnd = payloadStart + frameSize;
      if (frameSize <= 0 || payloadEnd > limit) break;

      if (frameId == 'APIC') {
        return _parseApicFrame(data.sublist(payloadStart, payloadEnd));
      }

      offset = payloadEnd;
    }

    return null;
  }
}

Uint8List? _parseApicFrame(Uint8List payload) {
  if (payload.length < 4) return null;
  final encoding = payload[0];
  final mimeEnd = payload.indexOf(0x00, 1);
  if (mimeEnd == -1 || mimeEnd + 2 >= payload.length) return null;
  var cursor = mimeEnd + 2;
  cursor = _skipEncodedText(payload, cursor, encoding);
  if (cursor <= 0 || cursor >= payload.length) return null;
  return Uint8List.sublistView(payload, cursor);
}

Uint8List? _parsePicFrame(Uint8List payload) {
  if (payload.length < 6) return null;
  final encoding = payload[0];
  var cursor = 1 + 3 + 1;
  cursor = _skipEncodedText(payload, cursor, encoding);
  if (cursor <= 0 || cursor >= payload.length) return null;
  return Uint8List.sublistView(payload, cursor);
}

int _skipEncodedText(Uint8List data, int start, int encoding) {
  if (start >= data.length) return -1;
  if (encoding == 1 || encoding == 2) {
    for (var i = start; i + 1 < data.length; i += 2) {
      if (data[i] == 0x00 && data[i + 1] == 0x00) return i + 2;
    }
    return -1;
  }
  final end = data.indexOf(0x00, start);
  if (end == -1) return -1;
  return end + 1;
}

int _synchsafeToInt(Uint8List bytes, int offset) {
  return ((bytes[offset] & 0x7F) << 21) |
      ((bytes[offset + 1] & 0x7F) << 14) |
      ((bytes[offset + 2] & 0x7F) << 7) |
      (bytes[offset + 3] & 0x7F);
}

int _u32beToInt(Uint8List bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}
