import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/application/file_validation_cache.dart';

void main() {
  test('validate caches probe result and reuses on next read', () async {
    var calls = 0;
    Future<bool> probe(Uri uri) async {
      calls += 1;
      return uri.path.endsWith('ok.mp3');
    }

    final cache = InMemoryFileValidationCache(existsProbe: probe);
    final uri = Uri.file('/music/ok.mp3');

    final first = await cache.validate(uri);
    final second = cache.read(uri);

    expect(first.state, ValidationState.valid);
    expect(second?.state, ValidationState.valid);
    expect(calls, 1);
  });

  test('reconcileBatch corrects stale entries asynchronously', () async {
    var existsNow = true;
    Future<bool> probe(Uri uri) async => existsNow;

    final cache = InMemoryFileValidationCache(existsProbe: probe);
    final uri = Uri.file('/music/stale.mp3');

    await cache.validate(uri);
    expect(cache.read(uri)?.state, ValidationState.valid);

    existsNow = false;
    await cache.reconcileBatch([uri]);

    expect(cache.read(uri)?.state, ValidationState.invalid);
  });

  test(
    'invalidateAll and invalidateUris clear only intended entries',
    () async {
      Future<bool> probe(Uri uri) async => true;
      final cache = InMemoryFileValidationCache(existsProbe: probe);

      final a = Uri.file('/music/a.mp3');
      final b = Uri.file('/music/b.mp3');

      await cache.validate(a);
      await cache.validate(b);
      cache.invalidateUris([a]);

      expect(cache.read(a), isNull);
      expect(cache.read(b), isNotNull);

      cache.invalidateAll();
      expect(cache.read(b), isNull);
    },
  );
}
