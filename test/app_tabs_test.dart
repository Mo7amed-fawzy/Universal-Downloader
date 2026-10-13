import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_downloader/app/app_controller.dart';
import 'package:universal_downloader/app/theme/app_theme.dart';
import 'package:universal_downloader/ui/pages/app_tabs.dart';
import 'package:universal_downloader/ui/pages/home_page.dart';
import 'package:universal_downloader/ui/pages/settings_page.dart';
import 'package:universal_downloader/ui/widgets/app_scaffold.dart';
import 'package:universal_downloader/ui/widgets/app_tab_scope.dart';
import 'package:universal_downloader/ui/widgets/download_history_entry.dart';

import 'home_batch_test.dart' show BatchController, BatchProvider;
import 'support/persistence_fixtures.dart';

void main() {
  late Directory root;
  late BatchController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('tabs_test_');
    controller = BatchController(root, [BatchProvider('first')]);
  });

  tearDown(() {
    controller.manager.dispose();
    root.deleteSync(recursive: true);
  });

  Future<void> mount(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: MaterialApp(
          theme: width < 600 ? AppTheme.light() : AppTheme.dark(),
          home: const AppTabs(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String label) async {
    final navigation = find.byType(
      tester.view.physicalSize.width < 600 ? NavigationBar : NavigationRail,
    );
    await tester.tap(
      find.descendant(of: navigation, matching: find.text(label)),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [375.0, 1162.0]) {
    testWidgets('tabs retain state without stacking routes at $width', (
      tester,
    ) async {
      await mount(tester, width);
      final home = tester.state(find.byType(HomePage));
      await tester.enterText(
        find.byType(TextField),
        'https://first.example/draft',
      );
      await select(tester, 'Settings');
      final settings = tester.state(find.byType(SettingsPage));
      final settingsScroll = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(SettingsPage),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      settingsScroll.jumpTo(100);
      await tester.pump();
      for (var index = 0; index < 5; index++) {
        await select(tester, 'Downloads');
        await select(tester, 'Settings');
        expect(tester.state(find.byType(SettingsPage)), same(settings));
        expect(settingsScroll.pixels, 100);
        await select(tester, 'Home');
        expect(tester.state(find.byType(HomePage)), same(home));
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'https://first.example/draft',
        );
        expect(
          Navigator.of(tester.element(find.byType(AppTabs))).canPop(),
          isFalse,
        );
        expect(find.byType(BackButton), findsNothing);
      }
      expect(find.byType(HomePage, skipOffstage: false), findsOneWidget);
      expect(find.byType(SettingsPage, skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('revisiting Settings refreshes saved values', (tester) async {
    await mount(tester, 1162);
    await select(tester, 'Settings');
    await select(tester, 'Home');
    await controller.updateSettings(
      controller.settings.copyWith(preferredLanguage: 'fr'),
    );
    await select(tester, 'Settings');
    final language = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Preferred language code',
    );
    expect(tester.widget<TextField>(language).controller!.text, 'fr');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same download can be revealed again without a new route', (
    tester,
  ) async {
    for (var index = 0; index < 40; index++) {
      controller.manager.queue.add(
        completedDownload('${root.path}/$index.mp4', id: 'item-$index'),
      );
    }
    await mount(tester, 1162);
    for (var attempt = 0; attempt < 2; attempt++) {
      AppTabScope.of(
        tester.element(find.byType(AppScaffold).first),
      ).onSelected(1, taskId: 'item-30');
      await tester.pumpAndSettle();
      final entry = find.byWidgetPredicate(
        (widget) =>
            widget is DownloadHistoryEntry && widget.task.id == 'item-30',
      );
      expect(tester.widget<DownloadHistoryEntry>(entry).highlighted, isTrue);
      expect(
        Navigator.of(tester.element(find.byType(AppTabs))).canPop(),
        isFalse,
      );
      await tester.pump(const Duration(seconds: 4));
      expect(tester.widget<DownloadHistoryEntry>(entry).highlighted, isFalse);
      await select(tester, 'Home');
    }
    expect(tester.takeException(), isNull);
  });
}
