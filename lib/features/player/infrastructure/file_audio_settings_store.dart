import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../application/audio_settings_store.dart';
import '../domain/audio_settings.dart';

class FileAudioSettingsStore implements AudioSettingsStore {
  FileAudioSettingsStore({Future<Directory> Function()? appSupportDirectory})
    : _appSupportDirectory =
          appSupportDirectory ?? getApplicationSupportDirectory;

  static const _fileName = 'audio_settings.json';

  final Future<Directory> Function() _appSupportDirectory;

  @override
  Future<AudioSettings> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return AudioSettings.defaults;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return AudioSettings.defaults;
      return AudioSettings.fromJson(decoded);
    } on FormatException {
      return AudioSettings.defaults;
    } on FileSystemException {
      return AudioSettings.defaults;
    } catch (_) {
      return AudioSettings.defaults;
    }
  }

  @override
  Future<void> save(AudioSettings settings) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(settings.toJson()));
    } on FileSystemException {
      // Ignore persistence failures and keep playback/settings callers alive.
    } catch (_) {
      // Ignore persistence failures and keep playback/settings callers alive.
    }
  }

  Future<File> _file() async {
    final directory = await _appSupportDirectory();
    return File(p.join(directory.path, _fileName));
  }
}
