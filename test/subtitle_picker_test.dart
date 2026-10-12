import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/models/subtitle_track.dart';
import 'package:universal_downloader/ui/pages/home_input.dart';
import 'package:universal_downloader/ui/widgets/subtitle_picker.dart';

void main() {
  const tracks = [
    SubtitleTrack(language: 'ar', extension: 'vtt'),
    SubtitleTrack(language: 'en', extension: 'vtt', isAutomatic: true),
  ];

  testWidgets('defaults to None, selects a track, and returns to None', (
    tester,
  ) async {
    final input = HomeInput();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SubtitlePicker(
              tracks: tracks,
              input: input,
              onChanged: () => setState(() {}),
            ),
          ),
        ),
      ),
    );
    expect(input.subtitle, isNull);
    expect(input.downloadSubtitleFile, isFalse);
    expect(input.subtitleToDownload, isNull);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
    expect(find.text('None'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tracks.last.label).last);
    await tester.pumpAndSettle();
    expect(input.subtitle, same(tracks.last));
    expect(input.subtitleToDownload, isNull);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(input.subtitleToDownload, same(tracks.last));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();
    expect(input.subtitle, isNull);
    expect(input.downloadSubtitleFile, isFalse);
    expect(input.subtitleToDownload, isNull);
  });

  testWidgets('toggle controls saving without losing the selected language', (
    tester,
  ) async {
    final input = HomeInput()..selectSubtitle(tracks.first);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SubtitlePicker(
              tracks: tracks,
              input: input,
              onChanged: () => setState(() {}),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Add separate subtitle file'), findsOneWidget);
    expect(input.subtitleToDownload, isNull);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(input.downloadSubtitleFile, isTrue);
    expect(input.subtitleToDownload, same(tracks.first));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(input.downloadSubtitleFile, isFalse);
    expect(input.subtitleToDownload, isNull);
    expect(input.subtitle, same(tracks.first));
    expect(find.text(tracks.first.label), findsOneWidget);
  });

  testWidgets('new fetch reset clears the visible selection', (tester) async {
    final input = HomeInput()
      ..selectSubtitle(tracks.first)
      ..selectDownloadSubtitleFile(true);
    final widget = MaterialApp(
      home: Scaffold(
        body: SubtitlePicker(tracks: tracks, input: input, onChanged: () {}),
      ),
    );
    await tester.pumpWidget(widget);
    expect(find.text(tracks.first.label), findsOneWidget);
    input.selectSubtitle(null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubtitlePicker(tracks: tracks, input: input, onChanged: () {}),
        ),
      ),
    );
    expect(find.text('None'), findsOneWidget);
    expect(input.subtitle, isNull);
    expect(input.downloadSubtitleFile, isFalse);
    expect(input.subtitleToDownload, isNull);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });

  testWidgets('no available subtitles leaves a disabled None field', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubtitlePicker(
            tracks: const [],
            input: HomeInput(),
            onChanged: () {},
          ),
        ),
      ),
    );
    expect(find.text('None'), findsOneWidget);
    expect(find.text('No subtitles available'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .onChanged,
      isNull,
    );
  });

  testWidgets('long subtitle names fit a narrow field', (tester) async {
    final longTrack = SubtitleTrack(
      language: 'en-orig',
      extension: 'vtt',
      isAutomatic: true,
      name: List.filled(20, 'Long language name').join(' '),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: SubtitlePicker(
              tracks: [longTrack],
              input: HomeInput()..selectSubtitle(longTrack),
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
