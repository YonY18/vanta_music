import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/player/application/audio_settings_controller.dart';
import 'package:vanta_music/features/player/application/audio_settings_store.dart';
import 'package:vanta_music/features/player/domain/audio_settings.dart';

void main() {
  test(
    'loads persisted settings and applies them to playback on build',
    () async {
      final store = _FakeAudioSettingsStore(
        initial: const AudioSettings(crossfade: true),
      );
      final applied = <AudioSettings>[];
      final container = ProviderContainer(
        overrides: [
          audioSettingsStoreProvider.overrideWithValue(store),
          applyAudioSettingsProvider.overrideWithValue((settings) async {
            applied.add(settings);
          }),
        ],
      );
      addTearDown(container.dispose);

      final settings = await container.read(
        audioSettingsControllerProvider.future,
      );

      expect(settings.crossfade, isTrue);
      expect(applied, [const AudioSettings(crossfade: true)]);
    },
  );

  test(
    'persists updates and re-applies playback settings when toggled',
    () async {
      final store = _FakeAudioSettingsStore();
      final applied = <AudioSettings>[];
      final container = ProviderContainer(
        overrides: [
          audioSettingsStoreProvider.overrideWithValue(store),
          applyAudioSettingsProvider.overrideWithValue((settings) async {
            applied.add(settings);
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(audioSettingsControllerProvider.future);
      await container
          .read(audioSettingsControllerProvider.notifier)
          .setPreferOriginalStream(false);
      await container
          .read(audioSettingsControllerProvider.notifier)
          .setCrossfade(true);

      expect(store.saved, [
        const AudioSettings(preferOriginalStream: false),
        const AudioSettings(crossfade: true, preferOriginalStream: false),
      ]);
      expect(
        applied.last,
        const AudioSettings(crossfade: true, preferOriginalStream: false),
      );
      expect(
        container.read(audioSettingsControllerProvider).valueOrNull,
        const AudioSettings(crossfade: true, preferOriginalStream: false),
      );
    },
  );
}

class _FakeAudioSettingsStore implements AudioSettingsStore {
  _FakeAudioSettingsStore({this.initial = AudioSettings.defaults});

  AudioSettings initial;
  final List<AudioSettings> saved = [];

  @override
  Future<AudioSettings> load() async => initial;

  @override
  Future<void> save(AudioSettings settings) async {
    saved.add(settings);
    initial = settings;
  }
}
