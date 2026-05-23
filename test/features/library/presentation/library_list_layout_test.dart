import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/presentation/library_list_layout.dart';

void main() {
  group('songs list layout helpers', () {
    test('adds one slot when notification banner is visible', () {
      expect(songsListItemCount(trackCount: 3, hasNotificationBanner: true), 4);
      expect(songsListItemCount(trackCount: 3, hasNotificationBanner: false), 3);
    });

    test('maps list index to track index when banner is present', () {
      expect(isNotificationBannerIndex(0, hasNotificationBanner: true), isTrue);
      expect(trackIndexFromSongsListIndex(1, hasNotificationBanner: true), 0);
      expect(trackIndexFromSongsListIndex(3, hasNotificationBanner: true), 2);
    });

    test('maps list index to track index without banner offset', () {
      expect(isNotificationBannerIndex(0, hasNotificationBanner: false), isFalse);
      expect(trackIndexFromSongsListIndex(0, hasNotificationBanner: false), 0);
      expect(trackIndexFromSongsListIndex(2, hasNotificationBanner: false), 2);
    });
  });
}
