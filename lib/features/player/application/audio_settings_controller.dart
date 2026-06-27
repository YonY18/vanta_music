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
  AudioSettings _current = AudioSettings.defaults;
  Future<void> _pendingSave = Future<void>.value();

  @override
  Future<AudioSettings> build() async {
    final settings = await ref.read(audioSettingsStoreProvider).load();
    _current = settings;
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

  Future<void> setAudioEngineType(VantaAudioEngineType value) =>
      _save(_currentSettings.copyWith(audioEngineType: value));

  AudioSettings get _currentSettings => state.valueOrNull ?? _current;

  Future<void> _save(AudioSettings settings) async {
    _current = settings;
    state = AsyncValue.data(settings);
    final store = ref.read(audioSettingsStoreProvider);
    final applyAudioSettings = ref.read(applyAudioSettingsProvider);
    final saveOperation = _pendingSave.catchError((_) {}).then((_) async {
      await store.save(settings);
      await applyAudioSettings(settings);
    });
    _pendingSave = saveOperation.catchError((_) {});
    await saveOperation;
  }
}
