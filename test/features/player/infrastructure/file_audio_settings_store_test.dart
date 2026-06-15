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

  test('returns default settings for malformed JSON payloads', () async {
    final directory = await Directory.systemTemp.createTemp(
      'audio_settings_store_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}/audio_settings.json');
    await file.writeAsString('{not valid json');

    final store = FileAudioSettingsStore(
      appSupportDirectory: () async => directory,
    );

    expect(await store.load(), AudioSettings.defaults);
  });

  test(
    'returns default settings when resolving the settings path fails',
    () async {
      final store = FileAudioSettingsStore(
        appSupportDirectory: () async =>
            throw const FileSystemException('support directory unavailable'),
      );

      expect(await store.load(), AudioSettings.defaults);
    },
  );

  test(
    'returns default settings when reading the settings file fails',
    () async {
      if (Platform.isWindows) {
        return;
      }

      final directory = await Directory.systemTemp.createTemp(
        'audio_settings_store_test_',
      );
      final file = File('${directory.path}/audio_settings.json');
      await file.writeAsString('{"crossfade":true}');
      await Process.run('chmod', ['000', file.path]);
      addTearDown(() async {
        await Process.run('chmod', ['600', file.path]);
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final store = FileAudioSettingsStore(
        appSupportDirectory: () async => directory,
      );

      expect(await store.load(), AudioSettings.defaults);
    },
  );

  test('ignores write failures after best-effort save attempts', () async {
    final blocker = await File(
      '${Directory.systemTemp.path}/audio_settings_store_blocker_${DateTime.now().microsecondsSinceEpoch}',
    ).create();
    addTearDown(() async {
      if (await blocker.exists()) {
        await blocker.delete();
      }
    });

    final store = FileAudioSettingsStore(
      appSupportDirectory: () async => Directory(blocker.path),
    );

    await store.save(const AudioSettings(crossfade: true));
  });
}
