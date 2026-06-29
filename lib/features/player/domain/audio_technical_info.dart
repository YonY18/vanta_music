class VantaAudioTechnicalInfo {
  const VantaAudioTechnicalInfo({
    this.codec,
    this.bitrateKbps,
    this.sampleRateHz,
    this.bitDepth,
    this.channels,
    this.duration,
    this.fileSizeBytes,
    this.isLossless,
    this.isVariableBitrate,
    this.container,
    this.decoderName,
    this.engineName,
    this.sourceType,
    this.fallbackReason,
    this.pcmFormat,
    this.outputSampleRateHz,
    this.outputChannels,
  });

  final String? codec;
  final int? bitrateKbps;
  final int? sampleRateHz;
  final int? bitDepth;
  final int? channels;
  final Duration? duration;
  final int? fileSizeBytes;
  final bool? isLossless;
  final bool? isVariableBitrate;
  final String? container;
  final String? decoderName;
  final String? engineName;
  final String? sourceType;
  final String? fallbackReason;
  final String? pcmFormat;
  final int? outputSampleRateHz;
  final int? outputChannels;

  VantaAudioTechnicalInfo copyWith({
    String? codec,
    int? bitrateKbps,
    int? sampleRateHz,
    int? bitDepth,
    int? channels,
    Duration? duration,
    int? fileSizeBytes,
    bool? isLossless,
    bool? isVariableBitrate,
    String? container,
    String? decoderName,
    String? engineName,
    String? sourceType,
    String? fallbackReason,
    String? pcmFormat,
    int? outputSampleRateHz,
    int? outputChannels,
  }) {
    return VantaAudioTechnicalInfo(
      codec: codec ?? this.codec,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
      sampleRateHz: sampleRateHz ?? this.sampleRateHz,
      bitDepth: bitDepth ?? this.bitDepth,
      channels: channels ?? this.channels,
      duration: duration ?? this.duration,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      isLossless: isLossless ?? this.isLossless,
      isVariableBitrate: isVariableBitrate ?? this.isVariableBitrate,
      container: container ?? this.container,
      decoderName: decoderName ?? this.decoderName,
      engineName: engineName ?? this.engineName,
      sourceType: sourceType ?? this.sourceType,
      fallbackReason: fallbackReason ?? this.fallbackReason,
      pcmFormat: pcmFormat ?? this.pcmFormat,
      outputSampleRateHz: outputSampleRateHz ?? this.outputSampleRateHz,
      outputChannels: outputChannels ?? this.outputChannels,
    );
  }
}

const unknownAudioInfoValue = 'Unknown';

String formatBitrate(int? bitrateKbps) =>
    bitrateKbps == null || bitrateKbps <= 0
    ? unknownAudioInfoValue
    : '$bitrateKbps kbps';

String formatSampleRate(int? sampleRateHz) {
  if (sampleRateHz == null || sampleRateHz <= 0) return unknownAudioInfoValue;
  final khz = sampleRateHz / 1000;
  return khz == khz.roundToDouble()
      ? '${khz.toStringAsFixed(0)} kHz'
      : '${khz.toStringAsFixed(1)} kHz';
}

String formatBitDepth(int? bitDepth) =>
    bitDepth == null || bitDepth <= 0 ? unknownAudioInfoValue : '$bitDepth-bit';

String formatChannels(int? channels) {
  return switch (channels) {
    null || <= 0 => unknownAudioInfoValue,
    1 => 'Mono',
    2 => 'Stereo',
    _ => '$channels channels',
  };
}

String formatAudioInfoDuration(Duration? duration) {
  if (duration == null || duration.isNegative) return unknownAudioInfoValue;
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return unknownAudioInfoValue;
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0
      ? '${value.round()} ${units[unit]}'
      : '${value.toStringAsFixed(1)} ${units[unit]}';
}

String formatLossless(bool? isLossless) => isLossless == null
    ? unknownAudioInfoValue
    : (isLossless ? 'Lossless' : 'Lossy');

int? calculateAverageEncodedBitrateKbps({
  int? fileSizeBytes,
  Duration? duration,
}) {
  if (fileSizeBytes == null || fileSizeBytes <= 0) return null;
  if (duration == null || duration.inMilliseconds <= 0) return null;
  return ((fileSizeBytes * 8) / duration.inMilliseconds).round();
}
