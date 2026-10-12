import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/app/app_controller.dart';
import 'package:universal_downloader/core/services/dependency_checker.dart';
import 'package:universal_downloader/ui/widgets/advanced_settings_section.dart';
import 'package:universal_downloader/ui/widgets/tool_diagnostics.dart';

void main() {

  testWidgets('Android explains APK updates and hides executable replacement', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: ToolDiagnostics(controller: DiagnosticsController()),
        ),
      ),
    );
    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();
    expect(find.text('Update tools'), findsNothing);
    expect(find.text('Use included tools'), findsNothing);
    expect(find.textContaining('newer APK'), findsOneWidget);
    expect(find.text('Check tools'), findsOneWidget);
  });

  testWidgets('tool details are hidden under Advanced then Diagnostics', (
    tester,
  ) async {
    final controller = DiagnosticsController();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.linux),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdvancedSettingsSection(
              children: [ToolDiagnostics(controller: controller)],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Diagnostics'), findsNothing);
    expect(find.textContaining('yt-dlp'), findsNothing);
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.textContaining('yt-dlp'), findsNothing);
    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();
    expect(find.text('yt-dlp · test'), findsOneWidget);
    await tester.tap(find.text('Update tools'));
    await tester.pump();
    expect(controller.updateRequested, isTrue);
    await tester.tap(find.text('Use included tools'));
    await tester.pump();
    expect(controller.restoreRequested, isTrue);
  });

  testWidgets('updates disable duplicate actions and display progress', (
    tester,
  ) async {
    final controller = DiagnosticsController()..updatingTools = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.linux),
        home: Scaffold(body: ToolDiagnostics(controller: controller)),
      ),
    );
    await tester.tap(find.text('Diagnostics'));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}

class DiagnosticsController extends Fake implements AppController {
  @override
  bool updatingTools = false;
  @override
  bool get checkingDependencies => false;
  @override
  String? get toolUpdateMessage => null;
  @override
  List<DependencyStatus> get dependencies => const [
    DependencyStatus(
      name: 'yt-dlp',
      installed: true,
      version: 'test',
      path: '/app/tools/yt-dlp',
    ),
  ];
  bool updateRequested = false;
  bool restoreRequested = false;
  @override
  Future<void> updateTools({bool restoreIncluded = false}) async {
    updateRequested = !restoreIncluded;
    restoreRequested = restoreIncluded;
  }

  @override
  Future<void> refreshDependencies() async {}
}
