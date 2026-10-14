import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/models/audio_format.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/ui/pages/home_input.dart';
import 'package:universal_downloader/ui/widgets/format_pickers.dart';

void main() {
  const formats = [
    AudioFormat(formatId: 'ar-low', language: 'ar', bitrate: 96),
    AudioFormat(formatId: 'ar-high', language: 'ar', bitrate: 160),
    AudioFormat(formatId: 'en', language: 'en', bitrate: 128),
  ];

  testWidgets(
    'audio quality is visible in Auto and supports manual selection',
    (tester) async {
      final input = HomeInput()..selectAudioLanguage('ar');
      await pumpCard(tester, input, formats);
      expect(find.text('Audio Quality'), findsOneWidget);
      expect(input.autoBestAudio, isTrue);

      await chooseQuality(tester, '96 kbps');
      expect(input.audioBitrate, 96);
      expect(input.autoBestAudio, isFalse);
      expect(input.audioLanguage, 'ar');

      await chooseQuality(tester, 'Best Available');
      expect(input.audioBitrate, isNull);
      expect(input.autoBestAudio, isTrue);

      await chooseQuality(tester, '160 kbps');
      await tester.ensureVisible(find.byType(Switch).first);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(input.autoBestAudio, isTrue);
      expect(input.audioBitrate, isNull);
      expect(tester.state<FormFieldState<int?>>(qualityPicker).value, isNull);
    },
  );

  testWidgets('changing language resets quality and offers its own bitrates', (
    tester,
  ) async {
    final input = HomeInput()..selectAudioLanguage('ar');
    await pumpCard(tester, input, formats);
    await chooseQuality(tester, '160 kbps');
    final languagePicker = find.byType(DropdownButtonFormField<String?>);
    await tester.ensureVisible(languagePicker);
    await tester.tap(languagePicker);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('English').last);
    await tester.pumpAndSettle();
    expect(input.audioLanguage, 'en');
    expect(input.audioBitrate, isNull);
    expect(input.autoBestAudio, isTrue);
    expect(tester.takeException(), isNull);
    expect(tester.state<FormFieldState<int?>>(qualityPicker).value, isNull);
    await tester.tap(qualityPicker);
    await tester.pumpAndSettle();
    expect(find.text('160 kbps'), findsNothing);
    expect(find.text('96 kbps'), findsNothing);
    await tester.tap(find.text('128 kbps').last);
    await tester.pumpAndSettle();
    expect(input.audioBitrate, 128);
    expect(input.autoBestAudio, isFalse);
  });

  testWidgets('unknown bitrate retains the automatic quality option', (
    tester,
  ) async {
    final input = HomeInput()..selectAudioLanguage('ar');
    await pumpCard(tester, input, const [
      AudioFormat(formatId: 'audio', language: 'ar'),
    ]);
    expect(find.text('Audio Quality'), findsOneWidget);
    expect(
      find.text('The source does not report a bitrate for this audio track.'),
      findsOneWidget,
    );
    await chooseQuality(tester, 'Best Available');
    expect(input.autoBestAudio, isTrue);
    expect(input.audioBitrate, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers only positive unique source bitrates for this language', (
    tester,
  ) async {
    final input = HomeInput()..selectAudioLanguage('ar');
    await pumpCard(tester, input, const [
      AudioFormat(formatId: 'a', language: 'ar', bitrate: 137),
      AudioFormat(formatId: 'b', language: 'ar', bitrate: 137),
      AudioFormat(formatId: 'c', language: 'ar', bitrate: 51),
      AudioFormat(formatId: 'd', language: 'en', bitrate: 320),
      AudioFormat(formatId: 'e', language: 'ar', bitrate: 0),
      AudioFormat(formatId: 'f', language: 'ar', bitrate: -1),
      AudioFormat(formatId: 'g', language: 'ar'),
    ]);
    final dropdown = tester.widget<DropdownButtonFormField<int?>>(
      qualityPicker,
    );
    await tester.ensureVisible(qualityPicker);
    await tester.tap(qualityPicker);
    await tester.pumpAndSettle();
    expect(find.text('137 kbps'), findsOneWidget);
    expect(find.text('51 kbps'), findsOneWidget);
    for (final bitrate in [0, -1, 96, 128, 160, 192, 256, 320]) {
      expect(find.text('$bitrate kbps'), findsNothing);
    }
    expect(dropdown.enabled, isTrue);
    await tester.tap(find.text('137 kbps'));
    await tester.pumpAndSettle();
    expect(input.audioBitrate, 137);
  });

  testWidgets('embedded audio does not offer separate audio quality', (
    tester,
  ) async {
    await pumpCard(tester, HomeInput(), const []);
    expect(find.text('Audio Quality'), findsNothing);
    expect(find.textContaining('its embedded audio'), findsOneWidget);
  });
}

final qualityPicker = find.byType(DropdownButtonFormField<int?>);

Future<void> chooseQuality(WidgetTester tester, String label) async {
  await tester.ensureVisible(qualityPicker);
  await tester.tap(qualityPicker);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> pumpCard(
  WidgetTester tester,
  HomeInput input,
  List<AudioFormat> formats,
) async {
  final info = MediaInfo(
    id: 'audio-test',
    title: 'Audio test',
    providerId: 'youtube',
    providerName: 'YouTube',
    pageUrl: Uri.parse('https://youtu.be/test'),
    audioFormats: formats,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => FormatSelectionCard(
              info: info,
              input: input,
              preferredLanguage: 'ar',
              onChanged: () => setState(() {}),
            ),
          ),
        ),
      ),
    ),
  );
}
