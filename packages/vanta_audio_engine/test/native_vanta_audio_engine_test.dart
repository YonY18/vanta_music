import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_audio_engine/vanta_audio_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'maps native technical info events without mixing PCM and encoded bitrate',
    () {
      final info = NativeAudioTechnicalInfo.fromEvent({
        'codec': 'FLAC',
        'bitrateKbps': 921,
        'sampleRateHz': 44100,
        'bitDepth': 24,
        'channels': 2,
        'durationMs': 180000,
        'fileSizeBytes': 20722500,
        'isLossless': true,
        'container': 'FLAC',
        'decoderName': 'dr_flac',
        'engineName': 'Vanta Native Engine',
        'sourceType': 'Local file',
        'pcmFormat': 'float32',
        'outputSampleRateHz': 44100,
        'outputChannels': 2,
      });

      expect(info.codec, 'FLAC');
      expect(info.bitrateKbps, 921);
      expect(info.sampleRateHz, 44100);
      expect(info.bitDepth, 24);
      expect(info.channels, 2);
      expect(info.duration, const Duration(minutes: 3));
      expect(info.fileSizeBytes, 20722500);
      expect(info.isLossless, isTrue);
      expect(info.decoderName, 'dr_flac');
      expect(info.pcmFormat, 'float32');
      expect(info.outputSampleRateHz, 44100);
      expect(info.outputChannels, 2);
    },
  );

  test('maps native MP3 technical info without inventing source bit depth', () {
    final info = NativeAudioTechnicalInfo.fromEvent({
      'codec': 'MP3',
      'bitrateKbps': 320,
      'sampleRateHz': 44100,
      'channels': 2,
      'durationMs': 240000,
      'fileSizeBytes': 9600000,
      'isLossless': false,
      'container': 'MP3',
      'decoderName': 'dr_mp3',
      'engineName': 'Vanta Native Engine',
      'sourceType': 'Local file',
      'pcmFormat': 'float32',
      'outputSampleRateHz': 48000,
      'outputChannels': 2,
    });

    expect(info.codec, 'MP3');
    expect(info.bitDepth, isNull);
    expect(info.pcmFormat, 'float32');
    expect(info.outputSampleRateHz, 48000);
    expect(info.outputChannels, 2);
  });

  test('rejects remote sources before platform invocation', () async {
    final calls = <MethodCall>[];
    final channel = MethodChannel('native_vanta_audio_engine_test_remote');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final engine = NativeVantaAudioEngine(methodChannel: channel);

    expect(
      () => engine.load(Uri.https('music.example', '/track.flac')),
      throwsA(isA<NativeVantaAudioEngineException>()),
    );
    expect(calls, isEmpty);
  });

  test(
    'rejects content sources with explicit unsupported Dart evidence before platform invocation',
    () async {
      final calls = <MethodCall>[];
      final channel = MethodChannel(
        'native_vanta_audio_engine_test_content_flac',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final engine = NativeVantaAudioEngine(methodChannel: channel);

      await expectLater(
        engine.load(
          Uri.parse('content://media/external/audio/media/1'),
          contentMimeType: 'audio/mpeg',
          contentDisplayName: 'private-track.mp3',
        ),
        throwsA(
          isA<NativeVantaAudioEngineException>()
              .having((error) => error.code, 'code', 'unsupported_format')
              .having(
                (error) => error.message,
                'message',
                allOf(
                  isNot(contains('content://')),
                  isNot(contains('private-track')),
                ),
              ),
        ),
      );
      expect(calls, isEmpty);
    },
  );

  test(
    'rejects content ALAC display evidence before platform invocation',
    () async {
      final calls = <MethodCall>[];
      final channel = MethodChannel(
        'native_vanta_audio_engine_test_content_alac_display',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final engine = NativeVantaAudioEngine(methodChannel: channel);

      await expectLater(
        engine.load(
          Uri.parse('content://media/external/audio/media/1'),
          contentDisplayName: 'track.alac',
        ),
        throwsA(
          isA<NativeVantaAudioEngineException>().having(
            (error) => error.code,
            'code',
            'unsupported_format',
          ),
        ),
      );
      expect(calls, isEmpty);
    },
  );

  test(
    'rejects content ALAC path evidence before platform invocation',
    () async {
      final calls = <MethodCall>[];
      final channel = MethodChannel(
        'native_vanta_audio_engine_test_content_alac_path',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final engine = NativeVantaAudioEngine(methodChannel: channel);

      await expectLater(
        engine.load(
          Uri.parse('content://media/external/audio/media/track.alac'),
        ),
        throwsA(
          isA<NativeVantaAudioEngineException>().having(
            (error) => error.code,
            'code',
            'unsupported_format',
          ),
        ),
      );
      expect(calls, isEmpty);
    },
  );

  test(
    'passes content sources without Dart metadata to the platform for validation',
    () async {
      final calls = <MethodCall>[];
      final channel = MethodChannel(
        'native_vanta_audio_engine_test_content_unknown',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final engine = NativeVantaAudioEngine(methodChannel: channel);
      final uri = Uri.parse('content://media/external/audio/media/1');

      await engine.load(uri);

      expect(calls.single.method, 'load');
      expect(calls.single.arguments, {'uri': uri.toString()});
    },
  );

  test(
    'passes content WAV sources to the platform with redaction-safe arguments',
    () async {
      final calls = <MethodCall>[];
      final channel = MethodChannel(
        'native_vanta_audio_engine_test_content_wav',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final engine = NativeVantaAudioEngine(methodChannel: channel);
      final uri = Uri.parse('content://media/external/audio/media/1');

      await engine.load(
        uri,
        contentMimeType: 'audio/wav',
        contentDisplayName: 'private-track.wav',
      );

      expect(calls.single.method, 'load');
      expect(calls.single.arguments, {
        'uri': uri.toString(),
        'contentMimeType': 'audio/wav',
        'contentDisplayName': 'private-track.wav',
      });
    },
  );

  test(
    'passes content FLAC sources to the platform with redaction-safe arguments',
    () async {
      final calls = <MethodCall>[];
      final channel = MethodChannel(
        'native_vanta_audio_engine_test_content_flac',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final engine = NativeVantaAudioEngine(methodChannel: channel);
      final uri = Uri.parse('content://media/external/audio/media/1');

      await engine.load(
        uri,
        contentMimeType: 'audio/flac',
        contentDisplayName: 'private-track.flac',
      );

      expect(calls.single.method, 'load');
      expect(calls.single.arguments, {
        'uri': uri.toString(),
        'contentMimeType': 'audio/flac',
        'contentDisplayName': 'private-track.flac',
      });
    },
  );

  test('redacts platform content errors from public exception text', () async {
    final channel = MethodChannel(
      'native_vanta_audio_engine_test_content_error',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(
            code: 'content-open-failed',
            message: 'Native engine could not open this content source.',
          );
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final engine = NativeVantaAudioEngine(methodChannel: channel);

    await expectLater(
      engine.load(
        Uri.parse('content://media/external/audio/media/private-token'),
        contentMimeType: 'audio/wav',
        contentDisplayName: 'private-track.wav',
      ),
      throwsA(
        isA<NativeVantaAudioEngineException>()
            .having((error) => error.code, 'code', 'content_open_failed')
            .having(
              (error) => error.message,
              'message',
              allOf(
                isNot(contains('content://')),
                isNot(contains('private-track')),
                isNot(contains('private-token')),
              ),
            ),
      ),
    );
  });

  test(
    'rejects unsupported local music-adjacent formats before platform invocation',
    () async {
      final files = <File>[];
      for (final extension in [
        'm4a',
        'aac',
        'alac',
        'opus',
        'ogg',
        'oga',
        'amr',
        '3gp',
      ]) {
        files.add(
          await File(
            '${Directory.systemTemp.path}/vanta_engine_test.$extension',
          ).writeAsString('not real audio'),
        );
      }
      addTearDown(() async {
        for (final file in files) {
          if (await file.exists()) await file.delete();
        }
      });
      final calls = <MethodCall>[];
      final channel = MethodChannel('native_vanta_audio_engine_test_local');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final engine = NativeVantaAudioEngine(methodChannel: channel);

      for (final file in files) {
        await expectLater(
          engine.load(file.uri),
          throwsA(
            isA<NativeVantaAudioEngineException>().having(
              (error) => error.code,
              'code',
              'unsupported_format',
            ),
          ),
        );
      }

      expect(calls, isEmpty);
    },
  );

  test('redacts missing local source names from preflight errors', () async {
    final missing = File(
      '${Directory.systemTemp.path}/private-track-title.wav',
    );
    if (await missing.exists()) await missing.delete();
    final channel = MethodChannel('native_vanta_audio_engine_test_missing');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final engine = NativeVantaAudioEngine(methodChannel: channel);

    await expectLater(
      engine.load(missing.uri),
      throwsA(
        isA<NativeVantaAudioEngineException>()
            .having((error) => error.code, 'code', 'file_not_found')
            .having(
              (error) => error.message,
              'message',
              isNot(contains('private-track-title')),
            ),
      ),
    );
  });

  test('calls platform load for existing local WAV files', () async {
    final file = await File(
      '${Directory.systemTemp.path}/vanta_engine_test.wav',
    ).writeAsString('not real audio');
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    final calls = <MethodCall>[];
    final channel = MethodChannel('native_vanta_audio_engine_test_wav');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final engine = NativeVantaAudioEngine(methodChannel: channel);

    await engine.load(file.uri);

    expect(calls.single.method, 'load');
    expect(calls.single.arguments, {'path': file.path});
  });

  test('calls platform load for existing local FLAC files', () async {
    final file = await File(
      '${Directory.systemTemp.path}/vanta_engine_test.flac',
    ).writeAsString('not real audio');
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    final calls = <MethodCall>[];
    final channel = MethodChannel('native_vanta_audio_engine_test_flac');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final engine = NativeVantaAudioEngine(methodChannel: channel);

    await engine.load(file.uri);

    expect(calls.single.method, 'load');
    expect(calls.single.arguments, {'path': file.path});
  });

  test('calls platform load for existing local MP3 files', () async {
    final file = await File(
      '${Directory.systemTemp.path}/vanta_engine_test.mp3',
    ).writeAsString('not real audio');
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    final calls = <MethodCall>[];
    final channel = MethodChannel('native_vanta_audio_engine_test_mp3');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final engine = NativeVantaAudioEngine(methodChannel: channel);

    await engine.load(file.uri);

    expect(calls.single.method, 'load');
    expect(calls.single.arguments, {'path': file.path});
  });

  test('clamps negative seek positions before platform invocation', () async {
    final calls = <MethodCall>[];
    final channel = MethodChannel('native_vanta_audio_engine_test_seek');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final engine = NativeVantaAudioEngine(methodChannel: channel);

    await engine.seek(const Duration(milliseconds: -250));

    expect(calls.single.method, 'seek');
    expect(calls.single.arguments, {'positionMs': 0});
  });

  test('maps stopped playback state events', () async {
    const channel = EventChannel('native_vanta_audio_engine_test_state');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel.name, (message) async {
          const codec = StandardMethodCodec();
          final call = codec.decodeMethodCall(message);
          if (call.method == 'listen') {
            await TestDefaultBinaryMessengerBinding
                .instance
                .defaultBinaryMessenger
                .handlePlatformMessage(
                  channel.name,
                  codec.encodeSuccessEnvelope({
                    'status': 'stopped',
                    'errorMessage': null,
                  }),
                  (_) {},
                );
            return codec.encodeSuccessEnvelope(null);
          }
          return codec.encodeSuccessEnvelope(null);
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(channel.name, null);
    });

    final engine = NativeVantaAudioEngine(playbackStateChannel: channel);

    await expectLater(
      engine.playbackState,
      emits(
        isA<NativePlaybackState>().having(
          (state) => state.status,
          'status',
          NativePlaybackStatus.stopped,
        ),
      ),
    );
  });
}
