import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_downloader/app/app.dart';
import 'package:universal_downloader/app/app_controller.dart';
import 'package:universal_downloader/app/app_startup.dart';
import 'package:universal_downloader/app/theme/app_theme.dart';
import 'package:universal_downloader/ui/widgets/app_wordmark.dart';
import 'package:universal_downloader/ui/widgets/catchit_bird.dart';
import 'package:universal_downloader/ui/widgets/catchit_flight_scene.dart';
import 'package:universal_downloader/ui/widgets/catchit_launch_animation.dart';
import 'package:universal_downloader/ui/widgets/startup_status_app.dart';

import 'home_batch_test.dart' show BatchController, BatchProvider;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'theme_mode': 'dark'}));

  Future<void> loadBird(WidgetTester tester) async {
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/branding/catchit-icon.png'),
        tester.element(find.byType(Scaffold).first),
      ),
    );
    await tester.pump();
  }

  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(1600, 900),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('flight travels, turns and settles at $size / $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        Future<void> frame(double progress) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: brightness == Brightness.dark
                  ? AppTheme.dark()
                  : AppTheme.light(),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: const TextScaler.linear(2),
                  ),
                  child: CatchItFlightScene(progress: progress),
                ),
              ),
            ),
          );
        }

        await frame(0.08);
        final left = tester.getTopLeft(find.byType(CatchItBird)).dx;
        await frame(0.36);
        final right = tester.getTopLeft(find.byType(CatchItBird)).dx;
        expect(right, greaterThan(left));
        await frame(0.62);
        final returning = tester.getTopLeft(find.byType(CatchItBird)).dx;
        expect(returning, lessThan(right));
        expect(returning, greaterThan(size.width / 2));
        final transform = tester.widget<Transform>(
          find
              .ancestor(
                of: find.byType(CatchItBird),
                matching: find.byType(Transform),
              )
              .first,
        );
        expect(transform.transform.entry(0, 0), lessThan(0));
        expect(
          tester.widget<CatchItBird>(find.byType(CatchItBird)).wingAngle,
          greaterThan(0),
        );
        await frame(1);
        final bird = tester.getRect(find.byType(CatchItBird));
        final word = tester.getRect(find.byType(AppWordmark));
        expect((bird.left + word.right) / 2, closeTo(size.width / 2, 3));
        expect(word.center.dy, closeTo(bird.center.dy, 1));
        expect(
          tester.widget<CatchItBird>(find.byType(CatchItBird)).wingAngle,
          0,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('animation completes once and does not replay on rebuild', (
    tester,
  ) async {
    var completions = 0;
    final app = MaterialApp(
      home: Scaffold(
        body: CatchItLaunchAnimation(onCompleted: () => completions++),
      ),
    );
    await tester.pumpWidget(app);
    await loadBird(tester);
    await tester.pump(const Duration(milliseconds: 2000));
    expect(completions, 0);
    await tester.pumpAndSettle();
    expect(completions, 1);
    await tester.pumpWidget(app);
    await tester.pump(const Duration(seconds: 4));
    expect(completions, 1);
  });

  testWidgets('reduced motion shows the settled logo immediately', (
    tester,
  ) async {
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: CatchItLaunchAnimation(onCompleted: () => completions++),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<CatchItFlightScene>(find.byType(CatchItFlightScene))
          .progress,
      1,
    );
    expect(completions, 1);
    expect(tester.takeException(), isNull);
  });

  for (final readyFirst in [true, false]) {
    testWidgets(
      'startup waits for tools and animation (ready first: $readyFirst)',
      (tester) async {
        final root = Directory.systemTemp.createTempSync('startup_test_');
        final controller = BatchController(root, [BatchProvider('first')]);
        addTearDown(() {
          controller.manager.dispose();
          root.deleteSync(recursive: true);
        });
        final ready = Completer<AppController>();
        await tester.pumpWidget(AppStartup(initialize: () => ready.future));
        await tester.pump();
        await loadBird(tester);
        expect(
          tester
              .widget<StartupStatusApp>(find.byType(StartupStatusApp))
              .themeMode,
          ThemeMode.dark,
        );
        if (readyFirst) {
          ready.complete(controller);
          await tester.pump();
          expect(find.byType(UniversalDownloaderApp), findsNothing);
        }
        await tester.pumpAndSettle();
        if (!readyFirst) {
          expect(
            find.text('Preparing included download tools…'),
            findsOneWidget,
          );
          expect(find.byType(UniversalDownloaderApp), findsNothing);
          ready.complete(controller);
          await tester.pumpAndSettle();
        }
        expect(find.byType(UniversalDownloaderApp), findsOneWidget);
        expect(find.byType(CatchItLaunchAnimation), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('startup failure remains recoverable through Retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      AppStartup(
        initialize: () async {
          attempts++;
          throw StateError('Test tool failure');
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Test tool failure'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
