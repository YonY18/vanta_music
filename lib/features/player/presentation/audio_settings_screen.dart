import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../application/audio_settings_controller.dart';
import '../domain/audio_settings.dart';

class AudioSettingsScreen extends ConsumerWidget {
  const AudioSettingsScreen({super.key});

  static const String cleanAudioInfo =
      '“Vanta plays audio as cleanly as Android allows. No EQ, bass boost, virtualizer, loudness enhancement, compression or forced normalization is applied by default.”';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(audioSettingsControllerProvider);
    final settings = settingsState.valueOrNull ?? AudioSettings.defaults;
    final togglesEnabled = settingsState.hasValue;
    final controller = ref.read(audioSettingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Audio Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            const _InfoCard(),
            SizedBox(height: 16),
            _SettingsCard(
              settings: settings,
              controller: controller,
              togglesEnabled: togglesEnabled,
            ),
            SizedBox(height: 16),
            _NotesCard(settings: settings),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  static const _statusLabels = [
    'Enabled',
    'No EQ',
    'No bass boost',
    'No virtualizer',
    'No loudness enhancer',
    'No compression',
    'No forced normalization',
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Clean Audio Path',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              AudioSettingsScreen.cleanAudioInfo,
              style: TextStyle(color: VantaColors.muted, height: 1.45),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final label in _statusLabels) _StatusChip(label: label),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.settings,
    required this.controller,
    required this.togglesEnabled,
  });

  final AudioSettings settings;
  final AudioSettingsController controller;
  final bool togglesEnabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const _SectionHeader(
            title: 'Playback Options',
            subtitle:
                'Only these playback preferences are editable and stored locally.',
          ),
          Divider(height: 1, color: VantaColors.border),
          _ToggleTile(
            icon: Icons.queue_music_rounded,
            title: 'Gapless Playback',
            subtitle:
                'Keeps album and playlist transitions continuous when the source path supports it.',
            value: settings.gaplessPlayback,
            onChanged: togglesEnabled ? controller.setGaplessPlayback : null,
          ),
          const Divider(height: 1, color: VantaColors.border),
          _ToggleTile(
            icon: Icons.compare_arrows_rounded,
            title: 'Crossfade',
            subtitle:
                'Stored for future support. Off keeps the current clean transition path.',
            value: settings.crossfade,
            onChanged: togglesEnabled ? controller.setCrossfade : null,
          ),
          const Divider(height: 1, color: VantaColors.border),
          _ToggleTile(
            icon: Icons.graphic_eq_rounded,
            title: 'ReplayGain',
            subtitle:
                'Stored for future support. Vanta does not apply ReplayGain processing yet.',
            value: settings.replayGain,
            onChanged: togglesEnabled ? controller.setReplayGain : null,
          ),
          const Divider(height: 1, color: VantaColors.border),
          _ToggleTile(
            icon: Icons.high_quality_rounded,
            title: 'Prefer Original Stream',
            subtitle:
                'Keeps Subsonic and Navidrome requests on the original stream path. Turning this off is stored, but Vanta still avoids client-side transcoding by default.',
            value: settings.preferOriginalStream,
            onChanged: togglesEnabled
                ? controller.setPreferOriginalStream
                : null,
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.settings});

  final AudioSettings settings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Navidrome / Subsonic',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _StateRow(
              title: settings.preferOriginalStream
                  ? 'Original stream preferred'
                  : 'Original stream preference stored locally',
              subtitle:
                  'Vanta keeps stream URLs free of client-side transcoding parameters by default.',
            ),
            const SizedBox(height: 12),
            const _StateRow(
              title: 'No client-side transcoding',
              subtitle:
                  'Vanta does not request format, bitRate, maxBitRate, or transcode parameters in the current streaming path.',
            ),
            const SizedBox(height: 12),
            const _StateRow(
              title:
                  'Server may still transcode depending on server configuration',
              subtitle:
                  'Server-side rules can still affect the delivered stream even when the client requests the original path.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: VantaColors.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeThumbColor: VantaColors.violet,
      activeTrackColor: VantaColors.violet.withValues(alpha: 0.4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    );
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: VantaColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: VantaColors.muted, height: 1.45),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: VantaColors.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: VantaColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: VantaColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
