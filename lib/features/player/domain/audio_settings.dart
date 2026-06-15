class AudioSettings {
  const AudioSettings({
    this.gaplessPlayback = true,
    this.crossfade = false,
    this.replayGain = false,
    this.preferOriginalStream = true,
  });

  static const defaults = AudioSettings();

  final bool gaplessPlayback;
  final bool crossfade;
  final bool replayGain;
  final bool preferOriginalStream;

  AudioSettings copyWith({
    bool? gaplessPlayback,
    bool? crossfade,
    bool? replayGain,
    bool? preferOriginalStream,
  }) {
    return AudioSettings(
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      crossfade: crossfade ?? this.crossfade,
      replayGain: replayGain ?? this.replayGain,
      preferOriginalStream: preferOriginalStream ?? this.preferOriginalStream,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gaplessPlayback': gaplessPlayback,
      'crossfade': crossfade,
      'replayGain': replayGain,
      'preferOriginalStream': preferOriginalStream,
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
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioSettings &&
        other.gaplessPlayback == gaplessPlayback &&
        other.crossfade == crossfade &&
        other.replayGain == replayGain &&
        other.preferOriginalStream == preferOriginalStream;
  }

  @override
  int get hashCode =>
      Object.hash(gaplessPlayback, crossfade, replayGain, preferOriginalStream);
}
