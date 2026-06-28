import '../domain/audio_settings.dart';
import '../domain/vanta_audio_engine.dart';

class VantaAudioEngineSelection {
  const VantaAudioEngineSelection();

  bool shouldAttemptNative({
    required AudioSettings settings,
    required VantaAudioSource source,
  }) {
    if (settings.audioEngineType !=
        VantaAudioEngineType.vantaNativeExperimental) {
      return false;
    }
    if (source.isRemote) return false;
    if (source.isLocalFile) return _isSupportedNativeLocalFormat(source.uri);
    if (source.isContentUri) return !_hasUnsupportedContentEvidence(source);
    return false;
  }

  String fallbackReason(VantaAudioSource source) {
    if (source.isRemote) return 'remote-source-unsupported';
    if (source.isContentUri && _hasUnsupportedContentEvidence(source)) {
      return 'content-uri-unsupported-dart-evidence';
    }
    if (source.isContentUri) return 'native-engine-not-selected';
    if (!source.isLocalFile) return 'not-a-local-file';
    if (!_isSupportedNativeLocalFormat(source.uri)) return 'unsupported-format';
    return 'native-engine-not-selected';
  }

  String attemptReason(VantaAudioSource source) {
    if (source.isContentUri) return 'content-platform-validation';
    return 'supported-local-format';
  }

  bool _isSupportedNativeLocalFormat(Uri uri) {
    return _hasSupportedLocalFileExtension(uri.toFilePath().toLowerCase());
  }

  bool _hasUnsupportedContentEvidence(VantaAudioSource source) {
    final mimeType = source.contentMimeType?.toLowerCase();
    if (mimeType == 'audio/flac' ||
        mimeType == 'audio/x-flac' ||
        mimeType == 'audio/wav' ||
        mimeType == 'audio/x-wav' ||
        mimeType == 'audio/wave') {
      return false;
    }
    if (mimeType != null && mimeType.isNotEmpty) {
      return true;
    }

    final displayName = source.contentDisplayName?.toLowerCase();
    if (displayName != null && _hasAudioExtension(displayName)) {
      return !_hasSupportedContentExtension(displayName);
    }

    final path = source.uri.path.toLowerCase();
    if (_hasAudioExtension(path)) return !_hasSupportedContentExtension(path);

    return false;
  }

  bool _hasSupportedLocalFileExtension(String value) {
    return value.endsWith('.wav') ||
        value.endsWith('.flac') ||
        value.endsWith('.mp3');
  }

  bool _hasSupportedContentExtension(String value) {
    return value.endsWith('.wav') || value.endsWith('.flac');
  }

  bool _hasAudioExtension(String value) {
    return value.endsWith('.wav') ||
        value.endsWith('.flac') ||
        value.endsWith('.mp3') ||
        value.endsWith('.alac') ||
        value.endsWith('.m4a') ||
        value.endsWith('.aac') ||
        value.endsWith('.ogg') ||
        value.endsWith('.oga') ||
        value.endsWith('.opus') ||
        value.endsWith('.amr') ||
        value.endsWith('.3gp');
  }
}
