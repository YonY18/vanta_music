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
    if (source.isContentUri) return _hasSupportedContentWavEvidence(source);
    return false;
  }

  String fallbackReason(VantaAudioSource source) {
    if (source.isRemote) return 'remote-source-unsupported';
    if (source.isContentUri && !_hasSupportedContentWavEvidence(source)) {
      return 'content-uri-unsupported';
    }
    if (!source.isLocalFile) return 'not-a-local-file';
    if (!_isSupportedNativeLocalFormat(source.uri)) return 'unsupported-format';
    return 'native-engine-not-selected';
  }

  bool _isSupportedNativeLocalFormat(Uri uri) {
    return uri.toFilePath().toLowerCase().endsWith('.wav');
  }

  bool _hasSupportedContentWavEvidence(VantaAudioSource source) {
    final mimeType = source.contentMimeType?.toLowerCase();
    if (mimeType == 'audio/wav' ||
        mimeType == 'audio/x-wav' ||
        mimeType == 'audio/wave') {
      return true;
    }

    final displayName = source.contentDisplayName?.toLowerCase();
    if (displayName != null && displayName.endsWith('.wav')) return true;

    return source.uri.path.toLowerCase().endsWith('.wav');
  }
}
