import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final libraryIntelligenceRefresh = LibraryIntelligenceRefresh();

final libraryIntelligenceRefreshProvider =
    ChangeNotifierProvider<LibraryIntelligenceRefresh>((ref) {
      return libraryIntelligenceRefresh;
    });

class LibraryIntelligenceRefresh extends ChangeNotifier {
  void markChanged() => notifyListeners();
}
