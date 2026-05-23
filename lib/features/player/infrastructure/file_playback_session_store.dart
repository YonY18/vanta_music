import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../application/playback_session_store.dart';
import '../domain/playback_session.dart';

class FilePlaybackSessionStore implements PlaybackSessionStore {
  static const _fileName = 'playback_session.json';

  @override
  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<PlaybackSession?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;

    final text = await file.readAsString();
    final data = jsonDecode(text);
    if (data is! Map<String, dynamic>) return null;
    return PlaybackSession.fromJson(data);
  }

  @override
  Future<void> save(PlaybackSession session) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(session.toJson()));
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }
}
