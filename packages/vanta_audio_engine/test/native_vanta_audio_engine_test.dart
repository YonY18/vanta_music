import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta_audio_engine/vanta_audio_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    'rejects content sources without WAV evidence before platform invocation',
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
          contentMimeType: 'audio/flac',
          contentDisplayName: 'private-track.flac',
        ),
        throwsA(
          isA<NativeVantaAudioEngineException>()
              .having((error) => error.code, 'code', 'unsupported-format')
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
            .having((error) => error.code, 'code', 'content-open-failed')
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
    'rejects unsupported local formats before platform invocation',
    () async {
      final file = await File(
        '${Directory.systemTemp.path}/vanta_engine_test.flac',
      ).writeAsString('not real audio');
      addTearDown(() async {
        if (await file.exists()) await file.delete();
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

      await expectLater(
        engine.load(file.uri),
        throwsA(
          isA<NativeVantaAudioEngineException>().having(
            (error) => error.code,
            'code',
            'unsupported-format',
          ),
        ),
      );

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
            .having((error) => error.code, 'code', 'file-not-found')
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
}
