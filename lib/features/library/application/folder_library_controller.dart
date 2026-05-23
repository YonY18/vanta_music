import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../infrastructure/file_folder_library_store.dart';
import '../domain/track.dart';
import 'folder_library_store.dart';

final folderLibraryControllerProvider =
    AsyncNotifierProvider<FolderLibraryController, List<Track>>(
      FolderLibraryController.new,
    );

typedef FolderPathPicker = Future<String?> Function();
typedef FolderTrackScanner = Future<List<Track>> Function(String path);

final folderLibraryStoreProvider = Provider<FolderLibraryStore>(
  (ref) => FileFolderLibraryStore(),
);

final folderPathPickerProvider = Provider<FolderPathPicker>((ref) {
  return () => FilePicker.platform.getDirectoryPath(
    dialogTitle: 'Elegí una carpeta con música',
  );
});

final folderTrackScannerProvider = Provider<FolderTrackScanner>((ref) {
  return scanTracksFromFolder;
});

class FolderLibraryController extends AsyncNotifier<List<Track>> {
  @override
  Future<List<Track>> build() async {
    final folders = await ref.read(folderLibraryStoreProvider).loadSelectedFolders();
    if (folders.isEmpty) return const [];
    return _scanFolders(folders);
  }

  Future<void> pickAndScanFolder() async {
    final selectedPath = await ref.read(folderPathPickerProvider)();

    if (selectedPath == null) {
      return;
    }

    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final currentPaths = await ref.read(folderLibraryStoreProvider).loadSelectedFolders();
      final paths = _dedupePaths([...currentPaths, selectedPath]);
      final tracks = await _scanFolders(paths);
      await ref.read(folderLibraryStoreProvider).saveSelectedFolders(paths);
      return tracks;
    });
  }

  Future<void> rescan() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final paths = await ref.read(folderLibraryStoreProvider).loadSelectedFolders();
      return _scanFolders(paths);
    });
  }

  Future<List<Track>> _scanFolders(List<String> paths) async {
    final scanner = ref.read(folderTrackScannerProvider);
    final allTracks = <Track>[];
    for (final path in paths) {
      allTracks.addAll(await scanner(path));
    }
    return _dedupeTracksByUri(allTracks);
  }

  List<String> _dedupePaths(List<String> paths) {
    final seen = <String>{};
    final deduped = <String>[];
    for (final raw in paths) {
      final normalized = raw.trim();
      if (normalized.isEmpty) continue;
      final key = normalized.toLowerCase();
      if (seen.add(key)) deduped.add(normalized);
    }
    return deduped;
  }

  List<Track> _dedupeTracksByUri(List<Track> tracks) {
    final seen = <String>{};
    final result = <Track>[];
    for (final track in tracks) {
      final key = track.uri.toString().trim().toLowerCase();
      if (seen.add(key)) result.add(track);
    }
    return List.unmodifiable(result);
  }
}

Future<List<Track>> scanTracksFromFolder(String path) async {
    final directory = Directory(path);
    if (!directory.existsSync()) {
      return const [];
    }

    final files = await directory
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File && _isSupported(entity.path))
        .cast<File>()
        .toList();

    files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    return files
        .map((file) {
          final title = p.basenameWithoutExtension(file.path);
          return Track(
            id: 'folder:${file.path}',
            providerId: 'folder',
            title: title,
            artist: 'Carpeta local',
            album: p.basename(file.parent.path),
            uri: Uri.file(file.path),
          );
        })
        .toList(growable: false);
}

bool _isSupported(String path) {
  final ext = p.extension(path).toLowerCase();
  return ext == '.mp3' || ext == '.flac' || ext == '.ogg' || ext == '.m4a';
}
