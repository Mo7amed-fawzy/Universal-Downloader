import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/process/process_runner.dart';
import 'package:universal_downloader/core/process/process_runner_result.dart';
import 'package:universal_downloader/core/services/file_location_service.dart';
import 'package:universal_downloader/ui/widgets/download_location_button.dart';

void main() {

  testWidgets('Android opens the saved content URI', (tester) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: DownloadLocationButton(
            outputPath: 'content://media/downloads/42',
            openDownload: (uri) async {
              opened = uri;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Open video'));
    await tester.pumpAndSettle();
    expect(opened, 'content://media/downloads/42');
  });

  testWidgets('Open location selects the exact downloaded file', (
    tester,
  ) async {
    const path = '/tmp/فيديو/Video (1) \'quoted\' "name" #100%.mp4';
    final runner = LocationRunner();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.linux),
        home: Scaffold(
          body: DownloadLocationButton(
            outputPath: path,
            locationService: FileLocationService(runner: runner),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Open location'));
    await tester.pumpAndSettle();
    final call = runner.calls.single;
    expect(call.executable, 'gdbus');
    expect(call.arguments, contains('org.freedesktop.FileManager1.ShowItems'));
    final uris = jsonDecode(call.arguments[call.arguments.length - 2]) as List;
    expect(uris, hasLength(1));
    expect(Uri.parse(uris.single as String).toFilePath(), path);
    expect(call.arguments.last, isEmpty);
  });

  for (final missingCommand in [false, true]) {
    test(
      'opens the parent folder if reveal fails, missing=$missingCommand',
      () async {
        final runner = LocationRunner(
          revealFails: true,
          missingCommand: missingCommand,
        );
        await FileLocationService(
          runner: runner,
        ).open('/tmp/My Videos/Video.mp4');
        expect(runner.calls, hasLength(2));
        expect(runner.calls.last.executable, 'xdg-open');
        expect(runner.calls.last.arguments, ['/tmp/My Videos']);
      },
    );
  }

  testWidgets('shows an error when the file manager cannot open', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.linux),
        home: Scaffold(
          body: DownloadLocationButton(
            outputPath: '/tmp/Video.mp4',
            locationService: FileLocationService(
              runner: LocationRunner(revealFails: true, folderFails: true),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Open location'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open the download location.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disables Open location without an output file', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.linux),
        home: const Scaffold(body: DownloadLocationButton(outputPath: null)),
      ),
    );
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
  });
}

class LocationRunner extends ProcessRunner {
  LocationRunner({
    this.revealFails = false,
    this.missingCommand = false,
    this.folderFails = false,
  });

  final bool revealFails;
  final bool missingCommand;
  final bool folderFails;
  final calls = <({String executable, List<String> arguments})>[];

  @override
  Future<ProcessRunnerResult> run({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
    void Function(String line, bool isStdout)? onLine,
    CancelToken? cancelToken,
    String? workingDirectory,
  }) async {
    calls.add((executable: executable, arguments: arguments));
    if (executable == 'gdbus' && missingCommand) {
      throw ProcessException(executable, arguments, 'Command not found');
    }
    final failed = executable == 'gdbus' ? revealFails : folderFails;
    return ProcessRunnerResult(
      exitCode: failed ? 1 : 0,
      stdout: '',
      stderr: failed ? 'File manager unavailable' : '',
    );
  }
}
