import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/shared/widgets/artwork_scroll_defer_controller.dart';

void main() {
  group('ArtworkScrollDeferController', () {
    test('enables deferral immediately on active scroll event', () {
      final controller = ArtworkScrollDeferController(
        idleDelay: const Duration(milliseconds: 120),
      );

      expect(controller.deferArtwork, isFalse);

      final changed = controller.onEvent(ScrollActivityEvent.active);

      expect(changed, isTrue);
      expect(controller.deferArtwork, isTrue);
      controller.dispose();
    });

    test('keeps deferral until idle delay elapses', () {
      fakeAsync((async) {
        final controller = ArtworkScrollDeferController(
          idleDelay: const Duration(milliseconds: 120),
        );
        controller.onEvent(ScrollActivityEvent.active);

        controller.onEvent(ScrollActivityEvent.idle);
        async.elapse(const Duration(milliseconds: 119));
        expect(controller.deferArtwork, isTrue);

        async.elapse(const Duration(milliseconds: 1));
        expect(controller.deferArtwork, isFalse);
        controller.dispose();
      });
    });
  });
}
