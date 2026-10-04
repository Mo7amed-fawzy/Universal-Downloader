import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:universal_downloader/app/app_controller.dart';
import 'package:universal_downloader/core/errors/downloader_exceptions.dart';
import 'package:universal_downloader/core/models/download_options.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/services/log_service.dart';
import 'package:universal_downloader/downloads/download_manager.dart';
import 'package:universal_downloader/downloads/download_repository.dart';
import 'package:universal_downloader/providers/provider_registry.dart';
import 'package:universal_downloader/ui/pages/downloads_page.dart';

import 'support/controlled_download_provider.dart';

void main() {
  testWidgets('failed subtitle task updates active count and clear action', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('downloads_widget_');
    addTearDown(() => root.deleteSync(recursive: true));
    final paths = QueueTestPaths(root);
    final provider = ControlledDownloadProvider();
    final manager = DownloadManager(
      registry: ProviderRegistry([provider]),
      repository: DownloadRepository(paths: paths),
      log: LogService(paths: paths),
    );
    addTearDown(manager.dispose);
    final controller = QueueTestController(manager);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: const MaterialApp(home: DownloadsPage()),
      ),
    );
    expect(find.text('No downloads yet'), findsOneWidget);
    manager.add(
      provider: provider,
      media: MediaInfo(
        id: 'task',
        title: 'Test video',
        providerId: provider.id,
        providerName: provider.displayName,
        pageUrl: Uri.parse('https://example.com'),
      ),
      options: DownloadOptions(
        taskId: 'task',
        outputDirectory: root.path,
        title: 'Test',
        videoFormatId: 'video',
      ),
      videoLabel: '720p',
      audioLabel: 'English',
    );
    await tester.pump();
    expect(find.text('1 active'), findsOneWidget);
    provider.calls.single.completeError(
      DownloadFailedException('Subtitle limit reached'),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 active'), findsOneWidget);
    expect(find.text('Subtitle limit reached'), findsOneWidget);
    await tester.tap(find.text('Clear finished'));
    await tester.pumpAndSettle();
    expect(find.text('No downloads yet'), findsOneWidget);
  });
}

class QueueTestController extends Fake implements AppController {
  QueueTestController(this.manager);

  @override
  final DownloadManager manager;

  @override
  ThemeMode get themeMode => ThemeMode.light;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
