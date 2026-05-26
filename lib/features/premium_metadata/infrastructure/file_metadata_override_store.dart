import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/metadata_models.dart';

typedef PremiumAppSupportDirectoryResolver = Future<Directory> Function();

class FileMetadataOverrideStore {
  FileMetadataOverrideStore({
    PremiumAppSupportDirectoryResolver? appSupportDirectory,
  }) : _appSupportDirectory =
           appSupportDirectory ?? getApplicationSupportDirectory;

  static const fileName = 'metadata_overrides.json';

  final PremiumAppSupportDirectoryResolver _appSupportDirectory;

  Future<MetadataOverride?> loadOverride(String trackKey) async {
    final overrides = await _loadAll();
    return overrides[trackKey];
  }

  Future<void> saveOverride(String trackKey, MetadataOverride override) async {
    final overrides = await _loadAll();
    if (override.isEmpty) {
      overrides.remove(trackKey);
    } else {
      overrides[trackKey] = override;
    }
    await _saveAll(overrides);
  }

  Future<void> clearOverride(String trackKey) async {
    final overrides = await _loadAll();
    overrides.remove(trackKey);
    await _saveAll(overrides);
  }

  Future<Map<String, MetadataOverride>> _loadAll() async {
    try {
      final file = await _file();
      if (!await file.exists()) return {};

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return {};

      return decoded.map((key, value) {
        if (value is! Map<String, dynamic>) {
          return MapEntry(key, const MetadataOverride());
        }
        return MapEntry(key, MetadataOverride.fromJson(value));
      })..removeWhere((_, value) => value.isEmpty);
    } on FormatException {
      return {};
    } on IOException {
      return {};
    }
  }

  Future<void> _saveAll(Map<String, MetadataOverride> overrides) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      final json = overrides.map((key, value) => MapEntry(key, value.toJson()));
      await file.writeAsString(jsonEncode(json));
    } on IOException {
      return;
    }
  }

  Future<File> _file() async {
    final dir = await _appSupportDirectory();
    return File(p.join(dir.path, fileName));
  }
}
