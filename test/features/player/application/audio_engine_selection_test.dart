import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/player/application/audio_engine_selection.dart';
import 'package:vanta_music/features/player/domain/audio_settings.dart';
import 'package:vanta_music/features/player/domain/vanta_audio_engine.dart';

void main() {
  const selection = VantaAudioEngineSelection();

  test('keeps current engine as default', () {
    expect(
      selection.shouldAttemptNative(
        settings: AudioSettings.defaults,
        source: VantaAudioSource(uri: Uri.file('/music/song.flac')),
      ),
      isFalse,
    );
  });

  test(
    'allows native attempts for selected local WAV and FLAC file sources',
    () {
      const settings = AudioSettings(
        audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
      );

      expect(
        selection.shouldAttemptNative(
          settings: settings,
          source: VantaAudioSource(uri: Uri.file('/music/song.wav')),
        ),
        isTrue,
      );
      expect(
        selection.shouldAttemptNative(
          settings: settings,
          source: VantaAudioSource(uri: Uri.file('/music/song.flac')),
        ),
        isTrue,
      );
      expect(
        selection.shouldAttemptNative(
          settings: settings,
          source: VantaAudioSource(uri: Uri.file('/music/song.mp3')),
        ),
        isFalse,
      );
      expect(
        selection.shouldAttemptNative(
          settings: settings,
          source: VantaAudioSource(uri: Uri.https('music.example', '/song')),
        ),
        isFalse,
      );
      expect(
        selection.shouldAttemptNative(
          settings: settings,
          source: VantaAudioSource(uri: Uri.parse('subsonic://track?id=1')),
        ),
        isFalse,
      );
    },
  );

  test(
    'allows local content sources to attempt native without Dart metadata',
    () {
      const settings = AudioSettings(
        audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
      );

      expect(
        selection.shouldAttemptNative(
          settings: settings,
          source: VantaAudioSource(
            uri: Uri.parse('content://media/external/audio/media/1'),
          ),
        ),
        isTrue,
      );
      expect(
        selection.shouldAttemptNative(
          settings: AudioSettings.defaults,
          source: VantaAudioSource(
            uri: Uri.parse('content://media/external/audio/media/1'),
          ),
        ),
        isFalse,
      );
      expect(
        selection.shouldAttemptNative(
          settings: settings,
          source: VantaAudioSource(
            uri: Uri.parse('content://media/external/audio/media/1'),
            contentDisplayName: 'track.wav',
          ),
        ),
        isTrue,
      );
      expect(
        selection.shouldAttemptNative(
          settings: settings,
          source: VantaAudioSource(
            uri: Uri.parse('content://media/external/audio/media/track.wav'),
          ),
        ),
        isTrue,
      );
      expect(
        selection.shouldAttemptNative(
          settings: settings,
          source: VantaAudioSource(
            uri: Uri.parse('content://media/external/audio/media/1'),
            contentMimeType: 'audio/flac',
            contentDisplayName: 'track.flac',
          ),
        ),
        isTrue,
      );
      expect(
        selection.shouldAttemptNative(
          settings: settings,
          source: VantaAudioSource(
            uri: Uri.parse('content://media/external/audio/media/1'),
            contentMimeType: 'audio/wav',
          ),
        ),
        isTrue,
      );
      expect(
        selection.shouldAttemptNative(
          settings: settings,
          source: VantaAudioSource(
            uri: Uri.parse('content://media/external/audio/media/1'),
            contentMimeType: 'audio/mpeg',
            contentDisplayName: 'track.mp3',
          ),
        ),
        isFalse,
      );
    },
  );

  test(
    'keeps eligible content fallback reason out of local-file rejection',
    () {
      final source = VantaAudioSource(
        uri: Uri.parse('content://media/external/audio/media/1'),
      );

      expect(selection.fallbackReason(source), 'native-engine-not-selected');
    },
  );

  test('keeps remote sources on the current engine', () {
    const settings = AudioSettings(
      audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
    );

    for (final source in [
      VantaAudioSource(uri: Uri.https('music.example', '/song.flac')),
      VantaAudioSource(uri: Uri.http('music.example', '/song.flac')),
    ]) {
      expect(
        selection.shouldAttemptNative(settings: settings, source: source),
        isFalse,
      );
      expect(selection.fallbackReason(source), 'remote-source-unsupported');
    }
  });

  test('keeps local file format eligibility unchanged', () {
    const settings = AudioSettings(
      audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
    );

    final flac = VantaAudioSource(uri: Uri.file('/music/song.flac'));
    final wav = VantaAudioSource(uri: Uri.file('/music/song.wav'));
    final mp3 = VantaAudioSource(uri: Uri.file('/music/song.mp3'));

    expect(
      selection.shouldAttemptNative(settings: settings, source: flac),
      isTrue,
    );
    expect(
      selection.shouldAttemptNative(settings: settings, source: wav),
      isTrue,
    );
    expect(
      selection.shouldAttemptNative(settings: settings, source: mp3),
      isFalse,
    );
    expect(selection.fallbackReason(mp3), 'unsupported-format');
  });
}
