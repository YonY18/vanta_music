import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../application/library_intelligence_store.dart';
import '../domain/library_snapshot.dart';

class FileLibraryIntelligenceStore implements LibraryIntelligenceStore {
  static const fileName = 'library_intelligence.json';

  @override
  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<LibrarySnapshot> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const LibrarySnapshot.empty();

      final data = jsonDecode(await file.readAsString());
      if (data is! Map<String, dynamic>) return const LibrarySnapshot.empty();
      return LibrarySnapshot.fromJson(data);
    } catch (_) {
      return const LibrarySnapshot.empty();
    }
  }

  @override
  Future<void> save(LibrarySnapshot snapshot) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(snapshot.toJson()));
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, fileName));
  }
}
