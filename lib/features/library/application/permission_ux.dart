import 'media_permission_service.dart';

enum PermissionCtaType { requestAudio, openSettings, requestNotifications }

class PermissionCta {
  const PermissionCta({required this.type, required this.label});

  final PermissionCtaType type;
  final String label;
}

PermissionCta? resolveAudioPermissionCta(MediaPermissionState? permission) {
  return switch (permission) {
    MediaPermissionState.denied => const PermissionCta(
      type: PermissionCtaType.requestAudio,
      label: 'Permitir música',
    ),
    MediaPermissionState.permanentlyDenied ||
    MediaPermissionState.restricted => const PermissionCta(
      type: PermissionCtaType.openSettings,
      label: 'Abrir ajustes',
    ),
    _ => null,
  };
}

PermissionCta? resolveNotificationPermissionCta({
  required MediaPermissionState notificationPermission,
  required bool hasTracks,
}) {
  if (!hasTracks || notificationPermission == MediaPermissionState.granted) {
    return null;
  }

  if (notificationPermission == MediaPermissionState.denied) {
    return const PermissionCta(
      type: PermissionCtaType.requestNotifications,
      label: 'Permitir controles',
    );
  }

  return const PermissionCta(
    type: PermissionCtaType.openSettings,
    label: 'Abrir ajustes',
  );
}
