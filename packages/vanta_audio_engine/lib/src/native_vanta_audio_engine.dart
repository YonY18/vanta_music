import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

enum NativePlaybackStatus {
  idle,
  loading,
  ready,
  playing,
  paused,
  buffering,
  completed,
  error,
}

class NativePlaybackState {
  const NativePlaybackState({required this.status, this.errorMessage});

  final NativePlaybackStatus status;
  final String? errorMessage;
}

class NativeVantaAudioEngineException implements Exception {
  const NativeVantaAudioEngineException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'NativeVantaAudioEngineException($code): $message';
}

class NativeVantaAudioEngine {
  NativeVantaAudioEngine({
    MethodChannel? methodChannel,
    EventChannel? playbackStateChannel,
    EventChannel? positionChannel,
    EventChannel? durationChannel,
  }) : _methodChannel = methodChannel ?? const MethodChannel(_methodName),
       _playbackStateChannel =
           playbackStateChannel ?? const EventChannel(_stateName),
       _positionChannel = positionChannel ?? const EventChannel(_positionName),
       _durationChannel = durationChannel ?? const EventChannel(_durationName);

  static const _methodName = 'vanta_audio_engine/methods';
  static const _stateName = 'vanta_audio_engine/playback_state';
  static const _positionName = 'vanta_audio_engine/position';
  static const _durationName = 'vanta_audio_engine/duration';

  final MethodChannel _methodChannel;
  final EventChannel _playbackStateChannel;
  final EventChannel _positionChannel;
  final EventChannel _durationChannel;

  Stream<NativePlaybackState>? _playbackState;
  Stream<Duration>? _position;
  Stream<Duration?>? _duration;

  Stream<NativePlaybackState> get playbackState => _playbackState ??=
      _playbackStateChannel.receiveBroadcastStream().map(_mapPlaybackState);

  Stream<Duration> get position => _position ??= _positionChannel
      .receiveBroadcastStream()
      .map((event) => Duration(milliseconds: (event as num).toInt()));

  Stream<Duration?> get duration =>
      _duration ??= _durationChannel.receiveBroadcastStream().map(
        (event) => event == null
            ? null
            : Duration(milliseconds: (event as num).toInt()),
      );

  Future<void> init() => _invokeVoid('init');

  Future<void> load(
    Uri uri, {
    String? contentMimeType,
    String? contentDisplayName,
  }) async {
    if (uri.isScheme('content')) {
      if (_hasUnsupportedContentAudioEvidence(
        uri,
        contentMimeType: contentMimeType,
        contentDisplayName: contentDisplayName,
      )) {
        throw const NativeVantaAudioEngineException(
          'unsupported_format',
          'Native engine currently supports only local WAV or FLAC content sources.',
        );
      }

      final arguments = <String, Object?>{'uri': uri.toString()};
      if (contentMimeType != null) {
        arguments['contentMimeType'] = contentMimeType;
      }
      if (contentDisplayName != null) {
        arguments['contentDisplayName'] = contentDisplayName;
      }
      await _invokeVoid('load', arguments);
      return;
    }

    if (!uri.isScheme('file')) {
      throw const NativeVantaAudioEngineException(
        'unsupported-source',
        'Native engine currently accepts only file:// or eligible content:// local sources.',
      );
    }

    final file = File(uri.toFilePath());
    if (!await file.exists()) {
      throw const NativeVantaAudioEngineException(
        'file_not_found',
        'Local source does not exist.',
      );
    }
    if (!_isSupportedLocalFile(file.path)) {
      throw const NativeVantaAudioEngineException(
        'unsupported_format',
        'Native engine currently supports only local WAV or FLAC files.',
      );
    }

    await _invokeVoid('load', {'path': file.path});
  }

  Future<void> play() => _invokeVoid('play');
  Future<void> pause() => _invokeVoid('pause');
  Future<void> stop() => _invokeVoid('stop');

  Future<void> seek(Duration position) =>
      _invokeVoid('seek', {'positionMs': position.inMilliseconds});

  Future<void> setVolume(double volume) =>
      _invokeVoid('setVolume', {'volume': volume.clamp(0, 1)});

  Future<void> dispose() => _invokeVoid('dispose');

  Future<void> _invokeVoid(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      await _methodChannel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error) {
      throw NativeVantaAudioEngineException(
        error.code.replaceAll('-', '_'),
        error.message ?? 'Native audio engine call failed.',
      );
    }
  }

  NativePlaybackState _mapPlaybackState(Object? event) {
    if (event is! Map) {
      return const NativePlaybackState(status: NativePlaybackStatus.idle);
    }
    final statusName = event['status']?.toString();
    return NativePlaybackState(
      status: NativePlaybackStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => NativePlaybackStatus.error,
      ),
      errorMessage: event['errorMessage']?.toString(),
    );
  }

  bool _isSupportedLocalFile(String path) =>
      _hasSupportedExtension(path.toLowerCase());

  bool _hasUnsupportedContentAudioEvidence(
    Uri uri, {
    String? contentMimeType,
    String? contentDisplayName,
  }) {
    final mimeType = contentMimeType?.toLowerCase();
    if (mimeType == 'audio/flac' ||
        mimeType == 'audio/x-flac' ||
        mimeType == 'audio/wav' ||
        mimeType == 'audio/x-wav' ||
        mimeType == 'audio/wave') {
      return false;
    }
    if (mimeType != null && mimeType.isNotEmpty) {
      return true;
    }

    final displayName = contentDisplayName?.toLowerCase();
    if (displayName != null && _hasAudioExtension(displayName)) {
      return !_hasSupportedExtension(displayName);
    }

    final path = uri.path.toLowerCase();
    if (_hasAudioExtension(path)) return !_hasSupportedExtension(path);

    return false;
  }

  bool _hasSupportedExtension(String value) {
    return value.endsWith('.wav') || value.endsWith('.flac');
  }

  bool _hasAudioExtension(String value) {
    return value.endsWith('.wav') ||
        value.endsWith('.flac') ||
        value.endsWith('.mp3') ||
        value.endsWith('.m4a') ||
        value.endsWith('.aac') ||
        value.endsWith('.ogg') ||
        value.endsWith('.opus');
  }
}
