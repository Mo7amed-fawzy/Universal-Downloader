import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:universal_downloader/app/app_controller.dart';
import 'package:universal_downloader/core/models/audio_format.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/models/video_format.dart';
import 'package:universal_downloader/ui/pages/home_input.dart';
import 'package:universal_downloader/ui/widgets/app_scaffold.dart';
import 'package:universal_downloader/ui/widgets/format_pickers.dart';
import 'package:universal_downloader/ui/widgets/media_info_card.dart';
import 'package:universal_downloader/ui/widgets/output_folder_row.dart';
import 'package:universal_downloader/ui/widgets/url_input_card.dart';

void main() {
  for (final width in [320.0, 360.0, 412.0, 1024.0]) {
    testWidgets('download controls fit width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final text = TextEditingController();
      final focus = FocusNode();
      addTearDown(text.dispose);
      addTearDown(focus.dispose);
      final info = MediaInfo(
        id: 'test',
        title: 'A video with a title long enough to need several lines',
        providerId: 'youtube',
        providerName: 'YouTube',
        uploader: 'A channel with a very long display name',
        pageUrl: Uri.parse('https://youtu.be/test'),
        videoFormats: const [VideoFormat(formatId: 'video', height: 720)],
        audioFormats: const [
          AudioFormat(formatId: 'audio', language: 'ar', bitrate: 128),
        ],
      );
      final input = HomeInput()..selectAudioLanguage('ar');
      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: LayoutController(),
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: AppScaffold(
              selectedIndex: 0,
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    UrlInputCard(
                      controller: text,
                      focusNode: focus,
                      fetching: false,
                      onFetch: () {},
                      provider: null,
                      errorMessage: null,
                    ),
                    MediaInfoCard(info: info),
                    FormatSelectionCard(
                      info: info,
                      input: input,
                      onChanged: () {},
                      preferredLanguage: 'ar',
                    ),
                    OutputFolderRow(
                      directory: '/private/output',
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byType(width < 600 ? NavigationBar : NavigationRail),
        findsOneWidget,
      );
      expect(find.text('Choose'), findsNothing);
      expect(find.text('Downloads / UniversalDownloader'), findsOneWidget);
    });
  }
}

class LayoutController extends Fake implements AppController {
  @override
  ThemeMode get themeMode => ThemeMode.light;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}
