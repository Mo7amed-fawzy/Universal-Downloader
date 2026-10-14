import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/app/theme/app_theme.dart';
import 'package:universal_downloader/core/models/audio_output_format.dart';
import 'package:universal_downloader/core/models/download_options.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/downloads/download_task.dart';
import 'package:universal_downloader/downloads/download_task_state.dart';
import 'package:universal_downloader/ui/widgets/download_audio_title.dart';
import 'package:universal_downloader/ui/widgets/download_tile.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'audio tile has a distinct style and keeps artwork in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final task = createTask(audioOnly: true);
        addTearDown(task.dispose);
        task.setPhase(DownloadTaskState.downloadingAudio);

        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.dark
                ? AppTheme.dark()
                : AppTheme.light(),
            home: Scaffold(body: DownloadTile(task: task)),
          ),
        );

        final scheme = Theme.of(
          tester.element(find.byType(DownloadTile)),
        ).colorScheme;
        final card = tester.widget<Card>(find.byType(Card));
        final shape = card.shape! as RoundedRectangleBorder;
        expect(shape.side.color, scheme.secondary.withValues(alpha: 0.5));
        expect(find.byType(DownloadAudioTitle), findsOneWidget);
        expect(find.text('Audio only'), findsOneWidget);
        expect(find.text('MP3 · Arabic 129 kbps'), findsOneWidget);
        expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
        final image = tester.widget<Image>(find.byType(Image));
        expect(
          (image.image as NetworkImage).url,
          'https://example.com/cover.jpg',
        );
        expect(tester.getSize(find.byType(Image)), const Size(120, 68));
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .color,
          scheme.secondary,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('video tile retains its original card and progress styling', (
    tester,
  ) async {
    final task = createTask(audioOnly: false);
    addTearDown(task.dispose);
    task.setPhase(DownloadTaskState.downloadingVideo);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: DownloadTile(task: task)),
      ),
    );

    expect(find.byType(DownloadAudioTitle), findsNothing);
    expect(tester.widget<Card>(find.byType(Card)).shape, isNull);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .color,
      isNull,
    );
    expect(find.text('1080p'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop history cards have equal height across task states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final completed = createTask(audioOnly: false);
    final cancelled = createTask(audioOnly: false);
    addTearDown(completed.dispose);
    addTearDown(cancelled.dispose);
    completed.markCompleted('/tmp/universal-downloader-missing-file.mkv');
    cancelled.markCancelled();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Column(
            children: [
              DownloadTile(task: completed),
              DownloadTile(task: cancelled),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final cards = find.byType(Card);
    expect(
      tester.getSize(cards.first).height,
      tester.getSize(cards.last).height,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('audio tile fits narrow layout with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final task = createTask(audioOnly: true);
    addTearDown(task.dispose);
    task.setPhase(DownloadTaskState.downloadingAudio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(child: DownloadTile(task: task)),
        ),
      ),
    );

    expect(find.byType(DownloadAudioTitle), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.text('Audio only'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

DownloadTask createTask({required bool audioOnly}) => DownloadTask(
  id: 'tile',
  media: MediaInfo(
    id: 'item',
    title: 'Networking explained',
    providerId: 'youtube',
    providerName: 'YouTube',
    pageUrl: Uri.parse('https://example.com/watch'),
    thumbnail: Uri.parse('https://example.com/cover.jpg'),
  ),
  options: DownloadOptions(
    taskId: 'tile',
    outputDirectory: '/tmp',
    title: 'Networking explained',
    videoFormatId: audioOnly ? '' : 'video',
    audioOutputFormat: audioOnly ? AudioOutputFormat.mp3 : null,
  ),
  providerId: 'youtube',
  providerName: 'YouTube',
  videoLabel: audioOnly ? 'Audio only' : '1080p',
  audioLabel: audioOnly ? 'MP3 · Arabic 129 kbps' : 'Arabic 129 kbps',
);
