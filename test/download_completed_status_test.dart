import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:universal_downloader/app/app_controller.dart';
import 'package:universal_downloader/core/services/download_file_service.dart';
import 'package:universal_downloader/ui/download_date_formatter.dart';
import 'package:universal_downloader/ui/widgets/download_completed_status.dart';
import 'package:universal_downloader/ui/widgets/download_tile.dart';

import 'support/persistence_fixtures.dart';

void main() {
  for (final width in [320.0, 360.0, 1162.0]) {
    testWidgets('completed card shows local download date at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final task = completedDownload('/videos/video.mkv');
      addTearDown(task.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: CompletedCardController(),
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 700),
                alwaysUse24HourFormat: true,
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: DownloadTile(
                    task: task,
                    fileService: AvailableFileService(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final local = task.completedAt!.toLocal();
      final localizations = MaterialLocalizations.of(
        tester.element(find.byType(DownloadCompletedStatus)),
      );
      expect(
        find.text(
          DownloadDateFormatter.format(
            local,
            now: DateTime.now(),
            localizations: localizations,
            alwaysUse24HourFormat: true,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('/videos/video.mkv'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Remove from history?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class AvailableFileService extends DownloadFileService {
  @override
  Future<bool?> exists(String? location) async => true;
}

class CompletedCardController extends Fake implements AppController {
  @override
  Future<void> openDownload(String location) async {}

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
