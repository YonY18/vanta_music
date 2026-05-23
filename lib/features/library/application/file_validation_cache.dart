import 'dart:io';

enum ValidationState { valid, invalid }

class ValidationEntry {
  const ValidationEntry({required this.state, required this.checkedAt});

  final ValidationState state;
  final DateTime checkedAt;
}

typedef ExistsProbe = Future<bool> Function(Uri uri);

class InMemoryFileValidationCache {
  InMemoryFileValidationCache({ExistsProbe? existsProbe})
    : _existsProbe = existsProbe ?? _defaultProbe;

  final ExistsProbe _existsProbe;
  final Map<String, ValidationEntry> _entries = <String, ValidationEntry>{};

  ValidationEntry? read(Uri uri) => _entries[_key(uri)];

  Future<ValidationEntry> validate(Uri uri) async {
    final cached = read(uri);
    if (cached != null) return cached;

    final exists = await _existsProbe(uri);
    final entry = ValidationEntry(
      state: exists ? ValidationState.valid : ValidationState.invalid,
      checkedAt: DateTime.now(),
    );
    _entries[_key(uri)] = entry;
    return entry;
  }

  Future<void> reconcileBatch(Iterable<Uri> uris) async {
    for (final uri in uris) {
      final exists = await _existsProbe(uri);
      _entries[_key(uri)] = ValidationEntry(
        state: exists ? ValidationState.valid : ValidationState.invalid,
        checkedAt: DateTime.now(),
      );
    }
  }

  void invalidateAll() => _entries.clear();

  void invalidateUris(Iterable<Uri> uris) {
    for (final uri in uris) {
      _entries.remove(_key(uri));
    }
  }

  static Future<bool> _defaultProbe(Uri uri) async {
    if (uri.scheme == 'file') {
      return File.fromUri(uri).exists();
    }
    return uri.scheme == 'content' || uri.scheme.startsWith('http');
  }

  String _key(Uri uri) => uri.toString().trim().toLowerCase();
}
