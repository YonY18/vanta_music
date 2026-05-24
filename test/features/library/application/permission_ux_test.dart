import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/library/application/media_permission_service.dart';
import 'package:vanta_music/features/library/application/permission_ux.dart';

void main() {
  group('resolveAudioPermissionCta', () {
    test('returns request CTA when audio permission is denied', () {
      final cta = resolveAudioPermissionCta(MediaPermissionState.denied);

      expect(cta?.type, PermissionCtaType.requestAudio);
      expect(cta?.label, 'Permitir música');
    });

    test(
      'returns settings CTA when audio permission is permanently denied',
      () {
        final cta = resolveAudioPermissionCta(
          MediaPermissionState.permanentlyDenied,
        );

        expect(cta?.type, PermissionCtaType.openSettings);
        expect(cta?.label, 'Abrir ajustes');
      },
    );
  });

  group('resolveNotificationPermissionCta', () {
    test('returns null when there are no tracks', () {
      final cta = resolveNotificationPermissionCta(
        notificationPermission: MediaPermissionState.denied,
        hasTracks: false,
      );

      expect(cta, isNull);
    });

    test('returns request CTA when notification permission is denied', () {
      final cta = resolveNotificationPermissionCta(
        notificationPermission: MediaPermissionState.denied,
        hasTracks: true,
      );

      expect(cta?.type, PermissionCtaType.requestNotifications);
      expect(cta?.label, 'Permitir controles');
    });
  });
}
