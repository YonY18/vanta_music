abstract class FolderLibraryStore {
  Future<List<String>> loadSelectedFolders();
  Future<void> saveSelectedFolders(List<String> paths);
  Future<void> clear();
}
