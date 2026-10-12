import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/models/video_format.dart';
import 'package:universal_downloader/providers/format_selector.dart';
import 'package:universal_downloader/ui/pages/home_input.dart';
import 'package:universal_downloader/ui/widgets/format_pickers.dart';

void main() {
  for (final maximum in [720, 1080, 2160, 4320]) {
    testWidgets('maximum quality follows the video at ${maximum}p', (
      tester,
    ) async {
      await pumpCard(tester, HomeInput(), [maximum, 360, 144]);
      final picker = tester.widget<DropdownButton<int>>(
        find.byType(DropdownButton<int>),
      );
      expect(picker.items!.map((item) => item.value), [0, maximum, 360, 144]);
    });
  }

  testWidgets('offers only unique heights present in a 720p video', (
    tester,
  ) async {
    final input = HomeInput();
    await pumpCard(tester, input, [720, 360, 240, 144, 720]);
    await tester.tap(videoPicker);
    await tester.pumpAndSettle();
    for (final height in [720, 360, 240, 144]) {
      expect(find.text('${height}p'), findsOneWidget);
    }
    for (final height in [2160, 1440, 1080, 480]) {
      expect(find.text('${height}p'), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects 240p and 144p and returns to Auto', (tester) async {
    final input = HomeInput();
    final info = await pumpCard(tester, input, [720, 360, 240, 144]);
    for (final height in [240, 144]) {
      await chooseHeight(tester, '${height}p');
      expect(input.videoHeight, height);
      expect(
        const FormatSelector()
            .selectBestVideo(info.videoFormats, maxHeight: input.videoHeight)
            ?.height,
        height,
      );
    }
    await chooseHeight(tester, 'Auto / Best Available');
    expect(input.videoHeight, isNull);
    expect(
      const FormatSelector()
          .selectBestVideo(info.videoFormats, maxHeight: input.videoHeight)
          ?.height,
      720,
    );
  });

  testWidgets('supports actual nonstandard heights and videos below 360p', (
    tester,
  ) async {
    final input = HomeInput();
    await pumpCard(tester, input, [240, 144, 180]);
    await chooseHeight(tester, '180p');
    expect(input.videoHeight, 180);
    expect(find.text('360p'), findsNothing);
  });

  testWidgets('resolves saved quality to an available height on each fetch', (
    tester,
  ) async {
    final input = HomeInput();
    await pumpCard(tester, input, [1080, 720, 360]);
    await chooseHeight(tester, '1080p');
    final next = mediaInfo([720, 240, 144]);
    input.resetVideoQuality(next.videoFormats, VideoQuality.q1080);
    await pumpCard(tester, input, [720, 240, 144]);
    expect(input.videoHeight, 720);
    expect(tester.state<FormFieldState<int>>(videoPicker).value, 720);
    expect(tester.takeException(), isNull);

    input.resetVideoQuality(next.videoFormats, VideoQuality.q360);
    expect(input.videoHeight, 240);
    input.resetVideoQuality(next.videoFormats, VideoQuality.best);
    await pumpCard(tester, input, [720, 240, 144]);
    expect(tester.state<FormFieldState<int>>(videoPicker).value, 0);
  });

  testWidgets('does not invent heights when metadata has none', (tester) async {
    await pumpCard(tester, HomeInput(), []);
    final picker = tester.widget<DropdownButton<int>>(
      find.byType(DropdownButton<int>),
    );
    expect(picker.items!.map((item) => item.value), [0]);
    expect(tester.takeException(), isNull);
  });
}

final videoPicker = find.byType(DropdownButtonFormField<int>);

MediaInfo mediaInfo(List<int> heights) => MediaInfo(
  id: 'video-test',
  title: 'Video test',
  providerId: 'youtube',
  providerName: 'YouTube',
  pageUrl: Uri.parse('https://youtu.be/test'),
  videoFormats: [
    for (var i = 0; i < heights.length; i++)
      VideoFormat(
        formatId: 'video-$i',
        width: heights[i] * 16 ~/ 9,
        height: heights[i],
        videoOnly: true,
      ),
  ],
);

Future<void> chooseHeight(WidgetTester tester, String label) async {
  await tester.tap(videoPicker);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<MediaInfo> pumpCard(
  WidgetTester tester,
  HomeInput input,
  List<int> heights,
) async {
  final info = mediaInfo(heights);
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
  return info;
}
