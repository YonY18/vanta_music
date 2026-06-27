import 'dart:async';

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
      await container
          .read(audioSettingsControllerProvider.notifier)
          .setAudioEngineType(VantaAudioEngineType.vantaNativeExperimental);

      expect(store.saved, [
        const AudioSettings(preferOriginalStream: false),
        const AudioSettings(crossfade: true, preferOriginalStream: false),
        const AudioSettings(
          crossfade: true,
          preferOriginalStream: false,
          audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
        ),
      ]);
      expect(
        applied.last,
        const AudioSettings(
          crossfade: true,
          preferOriginalStream: false,
          audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
        ),
      );
      expect(
        container.read(audioSettingsControllerProvider).valueOrNull,
        const AudioSettings(
          crossfade: true,
          preferOriginalStream: false,
          audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
        ),
      );
    },
  );

  test('preserves engine selection when settings updates overlap', () async {
    final store = _BlockingAudioSettingsStore();
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
    final controller = container.read(audioSettingsControllerProvider.notifier);

    final engineUpdate = controller.setAudioEngineType(
      VantaAudioEngineType.vantaNativeExperimental,
    );
    await store.firstSaveStarted.future;
    final crossfadeUpdate = controller.setCrossfade(true);
    store.releaseFirstSave();
    await Future.wait([engineUpdate, crossfadeUpdate]);

    expect(
      store.saved.last,
      const AudioSettings(
        crossfade: true,
        audioEngineType: VantaAudioEngineType.vantaNativeExperimental,
      ),
    );
    expect(applied.last, store.saved.last);
    expect(
      container.read(audioSettingsControllerProvider).valueOrNull,
      store.saved.last,
    );
  });

  test('failed save does not prevent a later update from persisting', () async {
    final store = _FailingAudioSettingsStore(failuresBeforeSuccess: 1);
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
    final controller = container.read(audioSettingsControllerProvider.notifier);

    await expectLater(controller.setCrossfade(true), throwsStateError);
    await controller.setReplayGain(true);

    expect(store.saved, [
      const AudioSettings(crossfade: true, replayGain: true),
    ]);
    expect(applied, [
      AudioSettings.defaults,
      const AudioSettings(crossfade: true, replayGain: true),
    ]);
    expect(
      container.read(audioSettingsControllerProvider).valueOrNull,
      const AudioSettings(crossfade: true, replayGain: true),
    );
  });

  test('failed apply does not prevent a later update from applying', () async {
    final store = _FakeAudioSettingsStore();
    var failuresBeforeSuccess = 1;
    final applied = <AudioSettings>[];
    final container = ProviderContainer(
      overrides: [
        audioSettingsStoreProvider.overrideWithValue(store),
        applyAudioSettingsProvider.overrideWithValue((settings) async {
          if (settings != AudioSettings.defaults && failuresBeforeSuccess > 0) {
            failuresBeforeSuccess--;
            throw StateError('apply failed');
          }
          applied.add(settings);
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(audioSettingsControllerProvider.future);
    final controller = container.read(audioSettingsControllerProvider.notifier);

    await expectLater(controller.setCrossfade(true), throwsStateError);

    expect(
      container.read(audioSettingsControllerProvider).valueOrNull,
      const AudioSettings(crossfade: true),
    );

    await controller.setReplayGain(true);

    expect(store.saved, [
      const AudioSettings(crossfade: true),
      const AudioSettings(crossfade: true, replayGain: true),
    ]);
    expect(applied, [
      AudioSettings.defaults,
      const AudioSettings(crossfade: true, replayGain: true),
    ]);
  });
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

class _BlockingAudioSettingsStore extends _FakeAudioSettingsStore {
  final Completer<void> firstSaveStarted = Completer<void>();
  final Completer<void> _releaseFirstSave = Completer<void>();
  bool _blockedFirstSave = false;

  void releaseFirstSave() {
    if (!_releaseFirstSave.isCompleted) _releaseFirstSave.complete();
  }

  @override
  Future<void> save(AudioSettings settings) async {
    if (!_blockedFirstSave) {
      _blockedFirstSave = true;
      firstSaveStarted.complete();
      await _releaseFirstSave.future;
    }
    await super.save(settings);
  }
}

class _FailingAudioSettingsStore extends _FakeAudioSettingsStore {
  _FailingAudioSettingsStore({required this.failuresBeforeSuccess});

  int failuresBeforeSuccess;

  @override
  Future<void> save(AudioSettings settings) async {
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw StateError('save failed');
    }
    await super.save(settings);
  }
}
