import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vanta_music/features/library/application/folder_library_controller.dart';
import 'package:vanta_music/features/library/application/folder_library_store.dart';
import 'package:vanta_music/features/library/domain/track.dart';

void main() {
  test('restores persisted folder sources on initialization', () async {
    final store = _FakeFolderLibraryStore(paths: ['/music/a']);

    final container = ProviderContainer(
      overrides: [
        folderLibraryStoreProvider.overrideWithValue(store),
        folderTrackScannerProvider.overrideWithValue((path) async {
          if (path == '/music/a') {
            return [_track('1', '/music/a/song.mp3')];
          }
          return const [];
        }),
      ],
    );
    addTearDown(container.dispose);

    final tracks = await container.read(folderLibraryControllerProvider.future);

    expect(tracks, hasLength(1));
    expect(tracks.single.uri.toFilePath(), '/music/a/song.mp3');
  });

  test('persists selected folder path after pick and scan', () async {
    final store = _FakeFolderLibraryStore();

    final container = ProviderContainer(
      overrides: [
        folderLibraryStoreProvider.overrideWithValue(store),
        folderPathPickerProvider.overrideWithValue(() async => '/music/a'),
        folderTrackScannerProvider.overrideWithValue(
          (path) async => [_track('1', '$path/song.mp3')],
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(folderLibraryControllerProvider.future);
    await container.read(folderLibraryControllerProvider.notifier).pickAndScanFolder();

    expect(store.paths, ['/music/a']);
    final state = container.read(folderLibraryControllerProvider);
    expect(state.valueOrNull, hasLength(1));
  });

  test('dedupes duplicated persisted folder paths', () async {
    final store = _FakeFolderLibraryStore(paths: ['/music/a', '/music/a']);

    final container = ProviderContainer(
      overrides: [
        folderLibraryStoreProvider.overrideWithValue(store),
        folderPathPickerProvider.overrideWithValue(() async => '/music/a'),
        folderTrackScannerProvider.overrideWithValue((path) async {
          return [_track('1', '$path/song.mp3')];
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(folderLibraryControllerProvider.future);
    await container.read(folderLibraryControllerProvider.notifier).pickAndScanFolder();

    expect(store.paths, ['/music/a']);
    final state = container.read(folderLibraryControllerProvider);
    expect(state.valueOrNull, hasLength(1));
  });
}

class _FakeFolderLibraryStore implements FolderLibraryStore {
  _FakeFolderLibraryStore({List<String>? paths}) : paths = [...?paths];

  List<String> paths;

  @override
  Future<void> clear() async {
    paths = [];
  }

  @override
  Future<List<String>> loadSelectedFolders() async => [...paths];

  @override
  Future<void> saveSelectedFolders(List<String> paths) async {
    this.paths = [...paths];
  }
}

Track _track(String id, String filePath) {
  return Track(
    id: id,
    providerId: 'folder',
    title: 'Song',
    artist: 'Artist',
    album: 'Album',
    uri: Uri.file(filePath),
  );
}
