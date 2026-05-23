import 'package:permission_handler/permission_handler.dart';

enum MediaPermissionState { granted, denied, permanentlyDenied, restricted }

class MediaPermissionService {
  Future<MediaPermissionState> requestAudioAccess() async {
    final status = await Permission.audio.request();
    return _map(status);
  }

  Future<MediaPermissionState> checkAudioAccess() async {
    final status = await Permission.audio.status;
    return _map(status);
  }

  Future<bool> openSettings() => openAppSettings();

  Future<MediaPermissionState> requestNotificationAccess() async {
    final status = await Permission.notification.request();
    return _map(status);
  }

  Future<MediaPermissionState> checkNotificationAccess() async {
    final status = await Permission.notification.status;
    return _map(status);
  }

  MediaPermissionState _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return MediaPermissionState.granted;
    }
    if (status.isPermanentlyDenied) {
      return MediaPermissionState.permanentlyDenied;
    }
    if (status.isRestricted) {
      return MediaPermissionState.restricted;
    }
    return MediaPermissionState.denied;
  }
}
