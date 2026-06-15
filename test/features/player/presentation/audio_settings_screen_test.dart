import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/app/theme.dart';
import 'package:vanta_music/features/player/application/audio_settings_controller.dart';
import 'package:vanta_music/features/player/application/audio_settings_store.dart';
import 'package:vanta_music/features/player/domain/audio_settings.dart';
import 'package:vanta_music/features/player/presentation/audio_settings_screen.dart';

void main() {
  testWidgets('renders informative and configurable audio sections', (
    tester,
  ) async {
    final store = _FakeAudioSettingsStore(
      initial: const AudioSettings(crossfade: true, replayGain: true),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioSettingsStoreProvider.overrideWithValue(store),
          applyAudioSettingsProvider.overrideWithValue((settings) async {}),
        ],
        child: MaterialApp(
          theme: buildVantaDarkTheme(),
          home: const AudioSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Clean Audio Path'), findsOneWidget);
    expect(find.text('Enabled'), findsOneWidget);
    expect(find.text('No EQ'), findsOneWidget);
    expect(find.text('No bass boost'), findsOneWidget);
    expect(find.text('No virtualizer'), findsOneWidget);
    expect(find.text('No loudness enhancer'), findsOneWidget);
    expect(find.text('No compression'), findsOneWidget);
    expect(find.text('No forced normalization'), findsOneWidget);
    expect(find.text('Playback Options'), findsOneWidget);
    expect(find.widgetWithText(SwitchListTile, 'Crossfade'), findsOneWidget);
    expect(
      find.text(
        'Stored for future support. Off keeps the current clean transition path.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(SwitchListTile, 'ReplayGain'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Navidrome / Subsonic'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(find.text('Navidrome / Subsonic'), findsOneWidget);
    expect(find.text('Original stream preferred'), findsOneWidget);
    expect(find.text('No client-side transcoding'), findsOneWidget);
    expect(
      find.text('Server may still transcode depending on server configuration'),
      findsOneWidget,
    );
  });

  testWidgets('persists toggle changes without claiming replay gain processing', (
    tester,
  ) async {
    final store = _FakeAudioSettingsStore();
    final applied = <AudioSettings>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioSettingsStoreProvider.overrideWithValue(store),
          applyAudioSettingsProvider.overrideWithValue((settings) async {
            applied.add(settings);
          }),
        ],
        child: MaterialApp(
          theme: buildVantaDarkTheme(),
          home: const AudioSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(SwitchListTile, 'ReplayGain'),
      250,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'ReplayGain'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(SwitchListTile, 'Prefer Original Stream'),
      250,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Prefer Original Stream'),
    );
    await tester.pumpAndSettle();

    expect(store.saved, [
      const AudioSettings(replayGain: true),
      const AudioSettings(replayGain: true, preferOriginalStream: false),
    ]);
    expect(
      applied.last,
      const AudioSettings(replayGain: true, preferOriginalStream: false),
    );
    expect(
      find.text(
        'Stored for future support. Vanta does not apply ReplayGain processing yet.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps toggles disabled until persisted settings load', (
    tester,
  ) async {
    final store = _DelayedAudioSettingsStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioSettingsStoreProvider.overrideWithValue(store),
          applyAudioSettingsProvider.overrideWithValue((settings) async {}),
        ],
        child: MaterialApp(
          theme: buildVantaDarkTheme(),
          home: const AudioSettingsScreen(),
        ),
      ),
    );
    await tester.pump();

    var gapless = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Gapless Playback'),
    );
    expect(gapless.onChanged, isNull);

    store.complete(AudioSettings.defaults);
    await tester.pumpAndSettle();

    gapless = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Gapless Playback'),
    );
    expect(gapless.onChanged, isNotNull);
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

class _DelayedAudioSettingsStore implements AudioSettingsStore {
  final Completer<AudioSettings> _loadCompleter = Completer<AudioSettings>();

  void complete(AudioSettings settings) => _loadCompleter.complete(settings);

  @override
  Future<AudioSettings> load() => _loadCompleter.future;

  @override
  Future<void> save(AudioSettings settings) async {}
}
