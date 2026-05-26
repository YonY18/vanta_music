import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/metadata_models.dart';
import 'file_metadata_override_store.dart';

class FilePaletteCacheStore {
  FilePaletteCacheStore({
    PremiumAppSupportDirectoryResolver? appSupportDirectory,
    this.maxEntries = defaultMaxEntries,
  }) : _appSupportDirectory =
           appSupportDirectory ?? getApplicationSupportDirectory;

  static const fileName = 'palette_cache.json';
  static const defaultMaxEntries = 500;

  final PremiumAppSupportDirectoryResolver _appSupportDirectory;
  final int maxEntries;

  Future<ArtworkPalette?> loadPalette(String artworkKey) async {
    final entries = await _loadAll();
    final entry = entries[artworkKey];
    if (entry == null) return null;
    return entry.palette;
  }

  Future<void> savePalette(String artworkKey, ArtworkPalette palette) async {
    final entries = await _loadAll();
    entries[artworkKey] = _PaletteCacheEntry(
      palette: palette,
      updatedAt: DateTime.now().toUtc(),
    );
    _prune(entries);
    await _saveAll(entries);
  }

  Future<void> clearPalette(String artworkKey) async {
    final entries = await _loadAll();
    entries.remove(artworkKey);
    await _saveAll(entries);
  }

  Future<Map<String, _PaletteCacheEntry>> _loadAll() async {
    try {
      final file = await _file();
      if (!await file.exists()) return {};

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return {};

      final entries = <String, _PaletteCacheEntry>{};
      for (final MapEntry(:key, :value) in decoded.entries) {
        if (value is Map<String, dynamic>) {
          entries[key] = _PaletteCacheEntry.fromJson(value);
        }
      }
      return entries;
    } on FormatException {
      return {};
    } on IOException {
      return {};
    }
  }

  Future<void> _saveAll(Map<String, _PaletteCacheEntry> entries) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      final json = entries.map((key, value) => MapEntry(key, value.toJson()));
      await file.writeAsString(jsonEncode(json));
    } on IOException {
      return;
    }
  }

  void _prune(Map<String, _PaletteCacheEntry> entries) {
    if (entries.length <= maxEntries) return;

    final ordered = entries.entries.toList()
      ..sort((a, b) => a.value.updatedAt.compareTo(b.value.updatedAt));
    final removeCount = entries.length - maxEntries;
    for (final entry in ordered.take(removeCount)) {
      entries.remove(entry.key);
    }
  }

  Future<File> _file() async {
    final dir = await _appSupportDirectory();
    return File(p.join(dir.path, fileName));
  }
}

class _PaletteCacheEntry {
  const _PaletteCacheEntry({required this.palette, required this.updatedAt});

  final ArtworkPalette palette;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'palette': palette.toJson(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory _PaletteCacheEntry.fromJson(Map<String, dynamic> json) {
    final paletteJson = json['palette'];
    return _PaletteCacheEntry(
      palette: paletteJson is Map<String, dynamic>
          ? ArtworkPalette.fromJson(paletteJson)
          : const ArtworkPalette(dominantColor: 0),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
