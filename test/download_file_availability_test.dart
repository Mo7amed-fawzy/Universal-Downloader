import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:universal_downloader/app/app_controller.dart';
import 'package:universal_downloader/core/services/download_file_service.dart';
import 'package:universal_downloader/ui/widgets/download_tile.dart';

import 'support/persistence_fixtures.dart';

void main() {
  for (final width in [320.0, 1162.0]) {
    testWidgets('missing badge and location action refresh at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final task = completedDownload('/videos/video.mkv');
      addTearDown(task.dispose);
      final files = MutableFileService();
      final controller = FileAvailabilityController();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppController>.value(
          value: controller,
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.linux),
            home: Scaffold(
              body: DownloadTile(task: task, fileService: files),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Open location'), findsOneWidget);
      expect(find.text('File not found'), findsNothing);
      files.available = false;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('File not found'), findsOneWidget);
      expect(find.byTooltip('Open location'), findsNothing);
      expect(find.byTooltip('Remove'), findsOneWidget);
      expect(tester.takeException(), isNull);
      files.available = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('File not found'), findsNothing);
      expect(find.byTooltip('Open location'), findsOneWidget);
      await tester.tap(find.byTooltip('Open location'));
      await tester.pumpAndSettle();
      expect(controller.opened, ['/videos/video.mkv']);
      files.available = false;
      await tester.tap(find.byTooltip('Open location'));
      await tester.pumpAndSettle();
      expect(controller.opened, hasLength(1));
      expect(find.text('File not found'), findsOneWidget);
      expect(find.byTooltip('Open location'), findsNothing);
    });
  }

  testWidgets('ignores old file checks after a tile is reused or disposed', (
    tester,
  ) async {
    final first = completedDownload('/first.mkv');
    final second = completedDownload('/second.mkv');
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final files = DelayedFileService();
    await tester.pumpWidget(
      MaterialApp(
        home: DownloadTile(task: first, fileService: files),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DownloadTile(task: second, fileService: files),
      ),
    );
    files.checks[1].complete(true);
    await tester.pump();
    files.checks[0].complete(false);
    await tester.pump();
    expect(find.text('File not found'), findsNothing);
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpWidget(const SizedBox());
    files.checks[2].complete(false);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

class MutableFileService extends DownloadFileService {
  bool available = true;

  @override
  Future<bool?> exists(String? location) async => available;
}

class DelayedFileService extends DownloadFileService {
  final checks = <Completer<bool?>>[];

  @override
  Future<bool?> exists(String? location) {
    final check = Completer<bool?>();
    checks.add(check);
    return check.future;
  }
}

class FileAvailabilityController extends Fake implements AppController {
  final opened = <String>[];

  @override
  Future<void> openDownload(String location) async => opened.add(location);

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
