import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/audio_settings.dart';
import '../infrastructure/file_audio_settings_store.dart';
import 'audio_handler_provider.dart';
import 'audio_settings_store.dart';

typedef ApplyAudioSettings = Future<void> Function(AudioSettings settings);

final audioSettingsStoreProvider = Provider<AudioSettingsStore>((ref) {
  return FileAudioSettingsStore();
});

final applyAudioSettingsProvider = Provider<ApplyAudioSettings>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.applyAudioSettings;
});

final audioSettingsControllerProvider =
    AsyncNotifierProvider<AudioSettingsController, AudioSettings>(
      AudioSettingsController.new,
    );

class AudioSettingsController extends AsyncNotifier<AudioSettings> {
  @override
  Future<AudioSettings> build() async {
    final settings = await ref.read(audioSettingsStoreProvider).load();
    await ref.read(applyAudioSettingsProvider)(settings);
    return settings;
  }

  Future<void> setGaplessPlayback(bool value) =>
      _save(_currentSettings.copyWith(gaplessPlayback: value));

  Future<void> setCrossfade(bool value) =>
      _save(_currentSettings.copyWith(crossfade: value));

  Future<void> setReplayGain(bool value) =>
      _save(_currentSettings.copyWith(replayGain: value));

  Future<void> setPreferOriginalStream(bool value) =>
      _save(_currentSettings.copyWith(preferOriginalStream: value));

  AudioSettings get _currentSettings =>
      state.valueOrNull ?? AudioSettings.defaults;

  Future<void> _save(AudioSettings settings) async {
    await ref.read(audioSettingsStoreProvider).save(settings);
    await ref.read(applyAudioSettingsProvider)(settings);
    state = AsyncValue.data(settings);
  }
}
