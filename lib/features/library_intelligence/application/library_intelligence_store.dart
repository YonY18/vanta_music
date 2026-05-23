import '../domain/library_snapshot.dart';

abstract class LibraryIntelligenceStore {
  Future<LibrarySnapshot> load();
  Future<void> save(LibrarySnapshot snapshot);
  Future<void> clear();
}
