enum VantaAudioEngineType {
  androidDefault,
  vantaNativeExperimental;

  static VantaAudioEngineType fromJson(Object? value) {
    return switch (value) {
      'vantaNativeExperimental' => vantaNativeExperimental,
      _ => androidDefault,
    };
  }

  String toJson() => name;
}

class AudioSettings {
  const AudioSettings({
    this.gaplessPlayback = true,
    this.crossfade = false,
    this.replayGain = false,
    this.preferOriginalStream = true,
    this.audioEngineType = VantaAudioEngineType.androidDefault,
  });

  static const defaults = AudioSettings();

  final bool gaplessPlayback;
  final bool crossfade;
  final bool replayGain;
  final bool preferOriginalStream;
  final VantaAudioEngineType audioEngineType;

  AudioSettings copyWith({
    bool? gaplessPlayback,
    bool? crossfade,
    bool? replayGain,
    bool? preferOriginalStream,
    VantaAudioEngineType? audioEngineType,
  }) {
    return AudioSettings(
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      crossfade: crossfade ?? this.crossfade,
      replayGain: replayGain ?? this.replayGain,
      preferOriginalStream: preferOriginalStream ?? this.preferOriginalStream,
      audioEngineType: audioEngineType ?? this.audioEngineType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gaplessPlayback': gaplessPlayback,
      'crossfade': crossfade,
      'replayGain': replayGain,
      'preferOriginalStream': preferOriginalStream,
      'audioEngineType': audioEngineType.toJson(),
    };
  }

  factory AudioSettings.fromJson(Map<String, dynamic> json) {
    return AudioSettings(
      gaplessPlayback: json['gaplessPlayback'] is bool
          ? json['gaplessPlayback'] as bool
          : defaults.gaplessPlayback,
      crossfade: json['crossfade'] is bool
          ? json['crossfade'] as bool
          : defaults.crossfade,
      replayGain: json['replayGain'] is bool
          ? json['replayGain'] as bool
          : defaults.replayGain,
      preferOriginalStream: json['preferOriginalStream'] is bool
          ? json['preferOriginalStream'] as bool
          : defaults.preferOriginalStream,
      audioEngineType: VantaAudioEngineType.fromJson(json['audioEngineType']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioSettings &&
        other.gaplessPlayback == gaplessPlayback &&
        other.crossfade == crossfade &&
        other.replayGain == replayGain &&
        other.preferOriginalStream == preferOriginalStream &&
        other.audioEngineType == audioEngineType;
  }

  @override
  int get hashCode => Object.hash(
    gaplessPlayback,
    crossfade,
    replayGain,
    preferOriginalStream,
    audioEngineType,
  );
}
