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

  test('allows native attempts for selected local WAV file sources', () {
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
      isFalse,
    );
    expect(
      selection.shouldAttemptNative(
        settings: settings,
        source: VantaAudioSource(uri: Uri.parse('content://media/song')),
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
  });

  test('allows content WAV only when clear WAV evidence exists', () {
    const settings = AudioSettings(
      audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
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
      isFalse,
    );
  });
}
