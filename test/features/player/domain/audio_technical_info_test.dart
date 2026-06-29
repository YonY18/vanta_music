import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_music/features/player/domain/audio_technical_info.dart';

void main() {
  group('audio technical info formatters', () {
    test('formats unknown values safely', () {
      expect(formatBitrate(null), 'Unknown');
      expect(formatSampleRate(null), 'Unknown');
      expect(formatBitDepth(null), 'Unknown');
      expect(formatChannels(null), 'Unknown');
      expect(formatAudioInfoDuration(null), 'Unknown');
      expect(formatFileSize(null), 'Unknown');
      expect(formatLossless(null), 'Unknown');
    });

    test('formats visible values', () {
      expect(formatBitrate(921), '921 kbps');
      expect(formatSampleRate(44100), '44.1 kHz');
      expect(formatSampleRate(48000), '48 kHz');
      expect(formatBitDepth(16), '16-bit');
      expect(formatChannels(1), 'Mono');
      expect(formatChannels(2), 'Stereo');
      expect(formatChannels(6), '6 channels');
      expect(
        formatAudioInfoDuration(const Duration(minutes: 3, seconds: 5)),
        '3:05',
      );
      expect(formatFileSize(1_572_864), '1.5 MB');
      expect(formatLossless(true), 'Lossless');
      expect(formatLossless(false), 'Lossy');
    });
  });

  group('average encoded bitrate calculation', () {
    test('uses file size and duration without reporting PCM bitrate', () {
      expect(
        calculateAverageEncodedBitrateKbps(
          fileSizeBytes: 9_600_000,
          duration: const Duration(minutes: 5),
        ),
        256,
      );
    });

    test('returns null when duration or size is unsafe', () {
      expect(
        calculateAverageEncodedBitrateKbps(
          fileSizeBytes: 0,
          duration: const Duration(minutes: 5),
        ),
        isNull,
      );
      expect(
        calculateAverageEncodedBitrateKbps(
          fileSizeBytes: 1_000,
          duration: Duration.zero,
        ),
        isNull,
      );
    });
  });
}
