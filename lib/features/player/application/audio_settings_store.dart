import '../domain/audio_settings.dart';

abstract interface class AudioSettingsStore {
  Future<AudioSettings> load();
  Future<void> save(AudioSettings settings);
}
