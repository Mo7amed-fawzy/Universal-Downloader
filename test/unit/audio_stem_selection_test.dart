import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/models/download_options.dart';
import 'package:universal_downloader/core/models/audio_output_format.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/process/command_runner.dart';
import 'package:universal_downloader/core/process/process_runner_result.dart';
import 'package:universal_downloader/core/services/audio_stem_processor.dart';
import 'package:universal_downloader/core/storage/media_info_codec.dart';
import 'package:universal_downloader/downloads/download_progress.dart';
import 'package:universal_downloader/ui/pages/home_input.dart';
import 'package:universal_downloader/ui/widgets/audio_stem_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DownloadOptions options({
    bool speech = true,
    bool music = true,
    bool effects = true,
    double speechStrength = 1,
    double musicStrength = 1,
    double effectsStrength = 1,
  }) => DownloadOptions(
    taskId: 'stem_test',
    outputDirectory: '/tmp',
    title: 'Video',
    videoFormatId: 'video',
    keepSpeech: speech,
    keepMusic: music,
    keepEffects: effects,
    speechRemovalStrength: speechStrength,
    musicRemovalStrength: musicStrength,
    effectsRemovalStrength: effectsStrength,
  );

  test('audio choices survive recovery and older tasks keep all sounds', () {
    const codec = MediaInfoCodec();
    for (var mask = 0; mask < 8; mask++) {
      final selected = options(
        speech: mask & 1 != 0,
        music: mask & 2 != 0,
        effects: mask & 4 != 0,
      );
      final restored = codec.decodeOptions(
        codec.encodeOptions(selected),
        taskId: selected.taskId,
        title: selected.title,
      );
      expect(restored.keepSpeech, selected.keepSpeech);
      expect(restored.keepMusic, selected.keepMusic);
      expect(restored.keepEffects, selected.keepEffects);
      expect(restored.speechRemovalStrength, 1);
      expect(restored.musicRemovalStrength, 1);
      expect(restored.effectsRemovalStrength, 1);
      expect(restored.needsAudioProcessing, mask != 7);
      expect(restored.isMuted, mask == 0);
    }
    final oldOptions =
        jsonDecode(codec.encodeOptions(options())) as Map<String, dynamic>
          ..remove('keepSpeech')
          ..remove('keepMusic')
          ..remove('keepEffects')
          ..remove('speechRemovalStrength')
          ..remove('musicRemovalStrength')
          ..remove('effectsRemovalStrength');
    final oldPayload = jsonEncode(oldOptions);
    final oldTask = codec.decodeOptions(
      oldPayload,
      taskId: 'old',
      title: 'Old',
    );
    expect(oldTask.needsAudioProcessing, isFalse);
  });

  test('partial removal levels survive recovery and control processing', () {
    const codec = MediaInfoCodec();
    final selected = options(
      speech: false,
      music: false,
      effects: false,
      speechStrength: 0.25,
      musicStrength: 0.5,
      effectsStrength: 0,
    );
    final restored = codec.decodeOptions(
      codec.encodeOptions(selected),
      taskId: selected.taskId,
      title: selected.title,
    );
    expect(restored.speechLevel, 0.75);
    expect(restored.musicLevel, 0.5);
    expect(restored.effectsLevel, 1);
    expect(restored.needsAudioProcessing, isTrue);
    expect(restored.isMuted, isFalse);
    expect(
      options(speech: false, speechStrength: 0).needsAudioProcessing,
      isFalse,
    );
  });

  test('audio-only format survives task recovery', () {
    const codec = MediaInfoCodec();
    final selected = DownloadOptions(
      taskId: 'audio-only',
      outputDirectory: '/tmp',
      title: 'Audio',
      videoFormatId: 'video',
      audioFormatId: 'en128',
      audioLanguage: 'en',
      audioOutputFormat: AudioOutputFormat.flac,
    );
    final restored = codec.decodeOptions(
      codec.encodeOptions(selected),
      taskId: selected.taskId,
      title: selected.title,
    );
    expect(restored.audioOutputFormat, AudioOutputFormat.flac);
    expect(restored.audioFormatId, 'en128');
  });

  test(
    'stem processor passes all choices and reports model progress',
    () async {
      final directory = Directory.systemTemp.createTempSync('stem_test_');
      addTearDown(() => directory.deleteSync(recursive: true));
      final runner = StemRunner();
      final processor = AudioStemProcessor(runner: runner);
      final progress = <DownloadProgress>[];
      await processor.ensureAvailable(CancelToken());
      final selected = await processor.process(
        source: File('${directory.path}/source.mp4'),
        workspace: directory,
        ffmpegPath: '/usr/bin/ffmpeg',
        options: options(
          speech: true,
          music: false,
          effects: false,
          musicStrength: 0.4,
        ),
        onProgress: progress.add,
        cancelToken: CancelToken(),
      );
      expect(selected.existsSync(), isTrue);
      expect(runner.arguments.sublist(runner.arguments.length - 3), [
        '1.0',
        '0.6',
        '0.0',
      ]);
      expect(progress.single.percent, 42);
      expect(
        progress.single.statusLabel,
        'Separating speech, music and effects',
      );
    },
  );

  testWidgets(
    'audio section opens on demand with circular choices and sliders',
    (tester) async {
      final input = HomeInput();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => AudioStemSection(
                  input: input,
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
          ),
        ),
      );
      expect(input.keepSpeech, isTrue);
      expect(input.keepMusic, isTrue);
      expect(input.keepEffects, isTrue);
      expect(find.text('Speech'), findsNothing);
      await tester.tap(find.text('Keep in downloaded video'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
            .checkboxShape,
        isA<CircleBorder>(),
      );
      expect(find.byType(Slider), findsNothing);
      await tester.tap(find.text('Music'));
      await tester.pumpAndSettle();
      expect(input.keepSpeech, isTrue);
      expect(input.keepMusic, isFalse);
      expect(input.keepEffects, isTrue);
      expect(input.musicRemovalStrength, 1);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Removal strength: 100%'), findsOneWidget);
      tester.widget<Slider>(find.byType(Slider)).onChanged!(0.4);
      await tester.pump();
      expect(input.musicRemovalStrength, 0.4);
      expect(find.text('Removal strength: 40%'), findsOneWidget);
      await tester.tap(find.text('Speech'));
      await tester.pumpAndSettle();
      expect(input.keepSpeech, isFalse);
      expect(input.keepEffects, isTrue);
      expect(find.byType(Slider), findsNWidgets(2));
      await tester.tap(find.text('Keep in downloaded video'));
      await tester.pumpAndSettle();
      expect(find.text('Speech'), findsNothing);
      expect(input.musicRemovalStrength, 0.4);
    },
  );
}

class StemRunner implements CommandRunner {
  List<String> arguments = [];

  @override
  Future<ProcessRunnerResult> run({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
    void Function(String line, bool isStdout)? onLine,
    CancelToken? cancelToken,
    String? workingDirectory,
  }) async {
    this.arguments = arguments;
    if (arguments.first == '-u') {
      File('${arguments[3]}/selected.m4a').writeAsBytesSync([1]);
      onLine?.call('PROGRESS\t42\tseparate', true);
    }
    return const ProcessRunnerResult(exitCode: 0, stdout: '', stderr: '');
  }
}
