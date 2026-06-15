import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/player/domain/audio_settings.dart';
import 'package:vanta_music/features/player/infrastructure/file_audio_settings_store.dart';

void main() {
  test('returns default settings when no persisted file exists', () async {
    final directory = await Directory.systemTemp.createTemp(
      'audio_settings_store_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final store = FileAudioSettingsStore(
      appSupportDirectory: () async => directory,
    );

    final settings = await store.load();

    expect(settings, AudioSettings.defaults);
  });

  test('persists and restores editable audio settings', () async {
    final directory = await Directory.systemTemp.createTemp(
      'audio_settings_store_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final store = FileAudioSettingsStore(
      appSupportDirectory: () async => directory,
    );
    const expected = AudioSettings(
      gaplessPlayback: false,
      crossfade: true,
      replayGain: true,
      preferOriginalStream: false,
    );

    await store.save(expected);
    final restored = await store.load();

    expect(restored, expected);
  });
}
