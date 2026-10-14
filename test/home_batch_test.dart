import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_downloader/app/app_controller.dart';
import 'package:universal_downloader/app/theme/app_theme.dart';
import 'package:universal_downloader/app/routes.dart';
import 'package:universal_downloader/core/errors/downloader_exceptions.dart';
import 'package:universal_downloader/core/models/audio_format.dart';
import 'package:universal_downloader/core/models/audio_output_format.dart';
import 'package:universal_downloader/core/models/download_options.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/models/subtitle_track.dart';
import 'package:universal_downloader/core/models/video_format.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/providers/youtube/youtube_playlist.dart';
import 'package:universal_downloader/ui/widgets/home_playlist_card.dart';
import 'package:universal_downloader/ui/widgets/home_playlist_video_tile.dart';
import 'package:universal_downloader/ui/widgets/playlist_url_dialog.dart';
import 'package:universal_downloader/ui/widgets/home_video_settings.dart';
import 'package:universal_downloader/core/services/dependency_checker.dart';
import 'package:universal_downloader/core/services/log_service.dart';
import 'package:universal_downloader/downloads/download_manager.dart';
import 'package:universal_downloader/downloads/download_repository.dart';
import 'package:universal_downloader/downloads/download_task_state.dart';
import 'package:universal_downloader/downloads/download_task.dart';
import 'package:universal_downloader/providers/downloader_provider.dart';
import 'package:universal_downloader/providers/format_selector.dart';
import 'package:universal_downloader/providers/provider_registry.dart';
import 'package:universal_downloader/providers/youtube/youtube_provider.dart';
import 'package:universal_downloader/settings/app_settings.dart';
import 'package:universal_downloader/settings/settings_service.dart';
import 'package:universal_downloader/ui/pages/app_tabs.dart';
import 'package:universal_downloader/ui/pages/downloads_page.dart';
import 'package:universal_downloader/ui/widgets/app_tab_scope.dart';
import 'package:universal_downloader/ui/widgets/download_history_entry.dart';
import 'package:universal_downloader/ui/pages/settings_page.dart';
import 'package:universal_downloader/ui/widgets/format_pickers.dart';
import 'package:universal_downloader/ui/widgets/home_video_card.dart';
import 'package:universal_downloader/ui/widgets/home_video_folder_button.dart';
import 'package:universal_downloader/ui/widgets/home_video_list.dart';
import 'package:universal_downloader/ui/widgets/home_video_fetch_card.dart';
import 'package:universal_downloader/ui/widgets/media_info_card.dart';
import 'package:universal_downloader/ui/widgets/output_folder_row.dart';
import 'package:universal_downloader/ui/widgets/url_input_card.dart';
import 'package:universal_downloader/ui/widgets/downloaded_video_warning.dart';

import 'support/controlled_download_provider.dart';
import 'support/persistence_fixtures.dart';

void main() {
  late Directory root;
  late BatchProvider firstProvider;
  late BatchProvider otherProvider;
  late BatchController controller;

  setUp(() {
    root = Directory.systemTemp.createTempSync('home_batch_');
    firstProvider = BatchProvider('first');
    otherProvider = BatchProvider('other');
    controller = BatchController(root, [
      firstProvider,
      otherProvider,
      YoutubeProvider(
        ytDlpPath: 'yt-dlp',
        ffmpegPath: 'ffmpeg',
        ffprobePath: 'ffprobe',
      ),
    ]);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    controller.manager.dispose();
    root.deleteSync(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester, {
    double width = 1162,
    double height = 900,
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: MaterialApp(
          theme:
              (brightness == Brightness.dark
                      ? AppTheme.dark()
                      : AppTheme.light())
                  .copyWith(platform: TargetPlatform.linux),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const AppTabs(),
          onGenerateRoute: generateRoute,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> addLinks(WidgetTester tester, String links) async {
    final field = find.byType(TextField);
    await tester.ensureVisible(field);
    await tester.enterText(field, links);
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Add videos'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(FilledButton, 'Add videos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder card(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(HomeVideoCard));

  Future<void> openVideo(WidgetTester tester, String title) async {
    final edit = find.descendant(
      of: card(title),
      matching: find.textContaining(
        RegExp(r'^(View settings|Editing settings)$'),
      ),
    );
    await tester.ensureVisible(edit);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(edit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> fetchSingle(WidgetTester tester, String link) async {
    await tester.ensureVisible(find.byType(UrlInputCard));
    await tester.enterText(find.byType(TextField), link);
    await tester.tap(find.widgetWithText(FilledButton, 'Fetch Info'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> addPlaylist(WidgetTester tester) async {
    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Add playlist'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add playlist'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'https://youtube.com/playlist?list=PLtest',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add playlist'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'playlist selection defaults to all and queues only checked videos',
    (tester) async {
      await mount(tester);
      await addPlaylist(tester);
      final group = tester.widget<HomePlaylistCard>(
        find.byType(HomePlaylistCard),
      );
      expect(group.entries.every((entry) => entry.selectedForDownload), isTrue);
      final unchecked = group.entries.first;
      final checked = group.entries.last;
      final checkbox = find.descendant(
        of: find.byType(HomePlaylistVideoTile).first,
        matching: find.byType(Checkbox),
      );
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();
      expect(unchecked.selectedForDownload, isFalse);
      expect(find.byType(HomeVideoSettings), findsNothing);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isNull,
      );
      await tester.ensureVisible(find.text('Download playlist (1)'));
      await tester.tap(find.text('Download playlist (1)'));
      await tester.pump();
      expect(controller.manager.tasks.map((task) => task.media.id), [
        checked.draft!.info.id,
      ]);
      final remaining = tester.widget<HomePlaylistCard>(
        find.byType(HomePlaylistCard),
      );
      expect(remaining.entries, [unchecked]);
      expect(unchecked.selectedForDownload, isFalse);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Download playlist (0)'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('select all supports clearing restoring and independent groups', (
    tester,
  ) async {
    await mount(tester);
    await addLinks(tester, 'https://first.example/one');
    await addPlaylist(tester);
    final selectAll = find.descendant(
      of: find.byType(HomePlaylistCard),
      matching: find.byType(CheckboxListTile),
    );
    await tester.ensureVisible(selectAll);
    await tester.tap(selectAll);
    await tester.pump();
    expect(find.text('0 of 2 selected'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Download playlist (0)'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<HomeVideoList>(find.byType(HomeVideoList))
          .entries
          .single
          .selectedForDownload,
      isTrue,
    );
    await tester.tap(selectAll);
    await tester.pump();
    expect(find.text('2 of 2 selected'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Download playlist (2)'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'ordinary selection survives editing and mode switches and filters download',
    (tester) async {
      await mount(tester);
      await addLinks(
        tester,
        'https://first.example/one https://first.example/two',
      );
      final entries = tester
          .widget<HomeVideoList>(find.byType(HomeVideoList))
          .entries;
      expect(entries.every((entry) => entry.selectedForDownload), isTrue);
      final checkbox = find.descendant(
        of: card('Video one'),
        matching: find.byType(Checkbox),
      );
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();
      await openVideo(tester, 'Video one');
      expect(entries.first.selectedForDownload, isFalse);
      await controller.updateSettings(
        controller.settings.copyWith(multiDownloadMode: false),
      );
      await tester.pump();
      await controller.updateSettings(
        controller.settings.copyWith(multiDownloadMode: true),
      );
      await tester.pump();
      expect(entries.first.selectedForDownload, isFalse);
      await tester.ensureVisible(find.text('Download selected (1)'));
      await tester.tap(find.text('Download selected (1)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.manager.tasks.map((task) => task.media.id), ['two']);
      AppTabScope.of(tester.element(find.byType(DownloadsPage))).onSelected(0);
      await tester.pumpAndSettle();
      expect(tester.widget<HomeVideoList>(find.byType(HomeVideoList)).entries, [
        entries.first,
      ]);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Download selected (0)'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('unchecking while fetching is retained and prevents auto-start', (
    tester,
  ) async {
    controller.settings = controller.settings.copyWith(autoStartDownload: true);
    firstProvider.pendingInfo = Completer<MediaInfo>();
    await mount(tester);
    await addLinks(tester, 'https://first.example/one');
    final checkbox = find.descendant(
      of: find.byType(HomeVideoFetchCard),
      matching: find.byType(Checkbox),
    );
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pump();
    firstProvider.pendingInfo!.complete(
      firstProvider.media(Uri.parse('https://first.example/one')),
    );
    await tester.pumpAndSettle();
    expect(controller.manager.tasks, isEmpty);
    expect(
      tester
          .widget<HomeVideoList>(find.byType(HomeVideoList))
          .entries
          .single
          .selectedForDownload,
      isFalse,
    );
    expect(find.text('Download selected (0)'), findsOneWidget);
  });

  testWidgets(
    'playlist group has independent videos and queues all with their own options',
    (tester) async {
      await mount(tester);
      await addLinks(tester, 'https://first.example/one');
      await addPlaylist(tester);
      expect(find.byType(HomePlaylistCard), findsOneWidget);
      expect(find.text('Your videos (1)'), findsOneWidget);
      expect(find.byType(HomePlaylistVideoTile), findsNWidgets(2));
      expect(find.byType(FormatSelectionCard), findsNothing);
      final playlistCard = tester.widget<HomePlaylistCard>(
        find.byType(HomePlaylistCard),
      );
      final first = playlistCard.entries.first.draft!;
      first.input.selectVideoHeight(480);
      first.input.selectAudioLanguage('en');
      first.input.selectSubtitle(first.info.subtitleTracks.first);
      first.input.selectDownloadSubtitleFile(true);
      first.input.selectContainer(ContainerPreference.mkv);
      await tester.ensureVisible(find.text('Download playlist (2)'));
      await tester.tap(find.text('Download playlist (2)'));
      await tester.pump();
      expect(controller.manager.tasks, hasLength(2));
      expect(controller.manager.tasks.first.options.videoFormatId, 'v480');
      expect(controller.manager.tasks.first.options.audioLanguage, 'en');
      expect(controller.manager.tasks.first.options.subtitle?.language, 'en');
      expect(
        controller.manager.tasks.first.options.containerPreference,
        ContainerPreference.mkv,
      );
      expect(controller.manager.tasks.last.options.videoFormatId, 'v1080');
      expect(controller.manager.tasks.last.options.audioLanguage, 'ar');
      expect(find.text('Your videos (1)'), findsOneWidget);
      expect(find.textContaining('2 queued'), findsWidgets);
    },
  );

  testWidgets(
    'playlist folder updates every group video and queued destinations',
    (tester) async {
      await mount(tester);
      await addLinks(tester, 'https://first.example/three');
      await addPlaylist(tester);
      final group = tester.widget<HomePlaylistCard>(
        find.byType(HomePlaylistCard),
      );
      group.entries.last.selectForDownload(false);
      final folder = find.descendant(
        of: find.byType(HomePlaylistCard),
        matching: find.byType(OutputFolderRow),
      );
      expect(tester.widget<OutputFolderRow>(folder).directory, root.path);
      tester.widget<OutputFolderRow>(folder).onChanged('${root.path}/playlist');
      await tester.pump();
      expect(
        group.entries.map((entry) => entry.draft!.input.outputDirectory),
        everyElement('${root.path}/playlist'),
      );
      expect(
        tester
            .widget<HomeVideoList>(find.byType(HomeVideoList))
            .entries
            .single
            .draft!
            .input
            .outputDirectory,
        root.path,
      );
      expect(
        tester.widget<OutputFolderRow>(folder).directory,
        '${root.path}/playlist',
      );
      await tester.ensureVisible(find.text('Download playlist (1)'));
      await tester.tap(find.text('Download playlist (1)'));
      await tester.pump();
      expect(
        controller.manager.tasks.single.options.outputDirectory,
        '${root.path}/playlist',
      );
      expect(
        tester
            .widget<HomePlaylistCard>(find.byType(HomePlaylistCard))
            .entries
            .single
            .selectedForDownload,
        isFalse,
      );
    },
  );

  testWidgets('batch folder applies to unchecked videos but not playlists', (
    tester,
  ) async {
    await mount(tester);
    await addLinks(tester, 'https://first.example/three');
    await addPlaylist(tester);
    final list = tester.widget<HomeVideoList>(find.byType(HomeVideoList));
    list.entries.single.selectForDownload(false);
    final folder = find.descendant(
      of: find.byType(HomeVideoList),
      matching: find.byType(OutputFolderRow),
    );
    const channel = MethodChannel('plugins.flutter.io/file_selector');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'getDirectoryPath');
      expect(call.arguments, containsPair('initialDirectory', root.path));
      return '${root.path}/batch';
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final choose = find.descendant(of: folder, matching: find.text('Choose'));
    await tester.ensureVisible(choose);
    await tester.tap(choose);
    await tester.pumpAndSettle();
    expect(
      list.entries.single.draft!.input.outputDirectory,
      '${root.path}/batch',
    );
    expect(
      tester.widget<OutputFolderRow>(folder).directory,
      '${root.path}/batch',
    );
    final group = tester.widget<HomePlaylistCard>(
      find.byType(HomePlaylistCard),
    );
    expect(
      group.entries.map((entry) => entry.draft!.input.outputDirectory),
      everyElement(root.path),
    );
    list.entries.single.selectForDownload(true);
    list.onSelectionChanged();
    await tester.pump();
    await tester.ensureVisible(find.text('Download all (1)'));
    await tester.tap(find.text('Download all (1)'));
    await tester.pump();
    expect(
      controller.manager.tasks.single.options.outputDirectory,
      '${root.path}/batch',
    );
  });

  testWidgets('batch folder is inherited by pending, retried and new videos', (
    tester,
  ) async {
    firstProvider.pendingInfo = Completer<MediaInfo>();
    firstProvider.failures.add('two');
    await mount(tester);
    await addLinks(
      tester,
      'https://first.example/one\nhttps://first.example/two',
    );
    final folder = find.descendant(
      of: find.byType(HomeVideoList),
      matching: find.byType(OutputFolderRow),
    );
    tester.widget<OutputFolderRow>(folder).onChanged('${root.path}/pending');
    final pending = firstProvider.pendingInfo!;
    firstProvider.pendingInfo = null;
    pending.complete(
      firstProvider.media(Uri.parse('https://first.example/one')),
    );
    await tester.pumpAndSettle();
    firstProvider.failures.clear();
    final list = tester.widget<HomeVideoList>(find.byType(HomeVideoList));
    list.onRetry(list.entries.last);
    await tester.pumpAndSettle();
    await addLinks(tester, 'https://first.example/three');
    expect(
      tester
          .widget<HomeVideoList>(find.byType(HomeVideoList))
          .entries
          .map((entry) => entry.draft!.input.outputDirectory),
      everyElement('${root.path}/pending'),
    );
  });

  testWidgets(
    'card folder picker overrides one video and cancellation keeps it',
    (tester) async {
      await mount(tester);
      await addLinks(
        tester,
        'https://first.example/one\nhttps://first.example/two',
      );
      final list = tester.widget<HomeVideoList>(find.byType(HomeVideoList));
      list.onOutputDirectoryChanged('${root.path}/batch');
      await tester.pump();
      const channel = MethodChannel('plugins.flutter.io/file_selector');
      String? selected = '${root.path}/individual';
      final initialDirectories = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'getDirectoryPath');
        initialDirectories.add((call.arguments as Map)['initialDirectory']);
        return selected;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final picker = find.descendant(
        of: card('Video one'),
        matching: find.byType(HomeVideoFolderButton),
      );
      await tester.ensureVisible(picker);
      await tester.tap(
        find.descendant(of: picker, matching: find.byType(TextButton)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeVideoSettings), findsNothing);
      expect(list.entries.first.draft!.input.outputDirectory, selected);
      expect(
        list.entries.last.draft!.input.outputDirectory,
        '${root.path}/batch',
      );
      expect(tester.widget<HomeVideoFolderButton>(picker).directory, selected);
      selected = null;
      await tester.tap(
        find.descendant(of: picker, matching: find.byType(TextButton)),
      );
      await tester.pumpAndSettle();
      expect(initialDirectories, [
        '${root.path}/batch',
        '${root.path}/individual',
      ]);
      await openVideo(tester, 'Video one');
      expect(
        tester
            .widget<FormatSelectionCard>(find.byType(FormatSelectionCard))
            .input
            .outputDirectory,
        '${root.path}/individual',
      );
      await tester.ensureVisible(find.text('Download all (2)'));
      await tester.tap(find.text('Download all (2)'));
      await tester.pump();
      expect(
        controller.manager.tasks.map((task) => task.options.outputDirectory),
        ['${root.path}/individual', '${root.path}/batch'],
      );
    },
  );

  testWidgets('playlist folder chosen while fetching is used by later videos', (
    tester,
  ) async {
    firstProvider.pendingInfo = Completer<MediaInfo>();
    await mount(tester);
    await addPlaylist(tester);
    final folder = find.descendant(
      of: find.byType(HomePlaylistCard),
      matching: find.byType(OutputFolderRow),
    );
    tester
        .widget<OutputFolderRow>(folder)
        .onChanged('${root.path}/pending-playlist');
    await tester.pump();
    final pending = firstProvider.pendingInfo!;
    firstProvider.pendingInfo = null;
    pending.complete(
      firstProvider.media(Uri.parse('https://first.example/one')),
    );
    await tester.pumpAndSettle();
    final group = tester.widget<HomePlaylistCard>(
      find.byType(HomePlaylistCard),
    );
    expect(group.entries, hasLength(2));
    expect(
      group.entries.map((entry) => entry.draft!.input.outputDirectory),
      everyElement('${root.path}/pending-playlist'),
    );
    await tester.ensureVisible(find.text('Download playlist (2)'));
    await tester.tap(find.text('Download playlist (2)'));
    await tester.pump();
    expect(
      controller.manager.tasks.map((task) => task.options.outputDirectory),
      everyElement('${root.path}/pending-playlist'),
    );
    expect(controller.manager.tasks, hasLength(2));
  });

  testWidgets('playlist settings editor can apply choices to its own group', (
    tester,
  ) async {
    await mount(tester);
    await addLinks(tester, 'https://first.example/three');
    await addPlaylist(tester);
    final tile = find.byType(HomePlaylistVideoTile).first;
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    final editor = tester.widget<HomeVideoSettings>(
      find.byType(HomeVideoSettings),
    );
    editor.draft.input.selectVideoHeight(480);
    editor.draft.input.selectAudioLanguage('en');
    editor.draft.input.selectSubtitle(editor.draft.info.subtitleTracks.first);
    editor.draft.input.selectDownloadSubtitleFile(true);
    editor.draft.input.selectKeepMusic(false);
    editor.draft.input.selectMusicRemovalStrength(0.35);
    await tester.ensureVisible(find.text('Apply these settings to playlist'));
    await tester.tap(find.text('Apply these settings to playlist'));
    await tester.pump();
    final entries = tester
        .widget<HomePlaylistCard>(find.byType(HomePlaylistCard))
        .entries;
    expect(
      entries.map((entry) => entry.draft!.input.videoHeight),
      everyElement(480),
    );
    expect(
      entries.map((entry) => entry.draft!.input.audioLanguage),
      everyElement('en'),
    );
    expect(entries.last.draft!.input.keepMusic, isFalse);
    expect(entries.last.draft!.input.musicRemovalStrength, 0.35);
    expect(
      entries.last.draft!.input.subtitle,
      same(entries.last.draft!.info.subtitleTracks.first),
    );
    final ordinary = tester
        .widget<HomeVideoList>(find.byType(HomeVideoList))
        .entries
        .single;
    expect(ordinary.draft!.input.videoHeight, isNull);
    expect(ordinary.draft!.input.audioLanguage, 'ar');
    expect(ordinary.draft!.input.keepMusic, isTrue);
  });

  testWidgets(
    'pasted playlist aliases deduplicate and never join ordinary videos',
    (tester) async {
      await mount(tester);
      await addLinks(
        tester,
        'https://youtube.com/watch?v=abcdefghijk&list=PLtest',
      );
      await addLinks(
        tester,
        'https://youtube.com/playlist?list=PLtest&index=4',
      );
      expect(find.byType(HomePlaylistCard), findsOneWidget);
      expect(find.byType(HomeVideoList), findsNothing);
      expect(controller.playlistFetchCount, 1);
    },
  );

  testWidgets('playlist removes matching regular video cards below it', (
    tester,
  ) async {
    await mount(tester);
    await addLinks(tester, 'https://first.example/one');
    await addPlaylist(tester);

    expect(find.text('Remove duplicates (1)'), findsOneWidget);
    expect(
      find.textContaining('already fetched in regular multi-download list'),
      findsOneWidget,
    );
    final removeDuplicates = find.text('Remove duplicates (1)');
    await tester.ensureVisible(removeDuplicates);
    await tester.tap(removeDuplicates);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Your videos (1)'), findsNothing);
    expect(find.byType(HomeVideoList), findsNothing);
    expect(
      tester.widget<HomePlaylistCard>(find.byType(HomePlaylistCard)).entries,
      hasLength(2),
    );
    expect(find.text('Remove duplicates (1)'), findsNothing);
    expect(
      find.textContaining('Removed 1 duplicate video from the regular'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplicate fetched after playlist names its playlist', (
    tester,
  ) async {
    await mount(tester);
    await addPlaylist(tester);
    await addLinks(tester, 'https://first.example/two');

    expect(
      find.textContaining('already fetched in My learning playlist'),
      findsOneWidget,
    );
    expect(find.text('Remove duplicates (1)'), findsOneWidget);
  });

  testWidgets('regular batch cards keep equal height with a download warning', (
    tester,
  ) async {
    controller.manager.queue.add(
      previousVideoDownload(
        firstProvider,
        Uri.parse('https://first.example/one'),
        root,
      ),
    );
    await mount(tester, width: 375, textScale: 1.3);
    await addLinks(
      tester,
      'https://first.example/one\nhttps://first.example/two',
    );

    final cards = find.byType(HomeVideoCard);
    expect(cards, findsNWidgets(2));
    expect(
      tester.getSize(cards.first).height,
      tester.getSize(cards.last).height,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('single mode hides playlist action and blocks playlist URLs', (
    tester,
  ) async {
    controller.settings = const AppSettings();
    await mount(tester);
    expect(find.text('Add playlist'), findsNothing);
    for (final url in [
      'https://youtube.com/playlist?list=PLtest',
      'https://youtube.com/watch?v=abcdefghijk&list=PLtest',
    ]) {
      await fetchSingle(tester, url);
      expect(
        find.text('Enable Multi-download mode in Settings to add a playlist.'),
        findsOneWidget,
      );
    }
    expect(controller.playlistFetchCount, 0);
    expect(controller.manager.tasks, isEmpty);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'video removal can be cancelled or dismissed at 375px $brightness',
      (tester) async {
        await mount(tester, width: 375, textScale: 1.3, brightness: brightness);
        await addLinks(tester, 'https://first.example/one');
        await openVideo(tester, 'Video one');
        final input = tester
            .widget<FormatSelectionCard>(find.byType(FormatSelectionCard))
            .input;
        input.selectVideoHeight(480);
        final remove = find.byTooltip('Remove Video one');
        await tester.ensureVisible(remove);
        await tester.pumpAndSettle();
        await tester.tap(remove);
        await tester.pumpAndSettle();
        expect(find.text('Remove video?'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(card('Video one'), findsOneWidget);
        expect(input.videoHeight, 480);
        expect(find.byType(FormatSelectionCard), findsOneWidget);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Remove video?'), findsNothing);
        expect(card('Video one'), findsOneWidget);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.text('Remove video?'), findsNothing);
        expect(card('Video one'), findsOneWidget);
        expect(input.videoHeight, 480);
      },
    );
  }

  testWidgets('playlist video and whole playlist each require confirmation', (
    tester,
  ) async {
    await mount(tester);
    await addLinks(tester, 'https://first.example/three');
    await addPlaylist(tester);
    final removeVideo = find.byTooltip('Remove video from playlist').first;
    await tester.ensureVisible(removeVideo);
    await tester.tap(removeVideo);
    await tester.pumpAndSettle();
    expect(find.text('Remove video?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePlaylistVideoTile), findsNWidgets(2));
    await tester.tap(removeVideo);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    final group = tester.widget<HomePlaylistCard>(
      find.byType(HomePlaylistCard),
    );
    expect(group.entries.single.draft!.info.id, 'two');
    expect(card('Video three'), findsOneWidget);
    final removePlaylist = find.byTooltip('Remove playlist');
    await tester.ensureVisible(removePlaylist);
    await tester.tap(removePlaylist);
    await tester.pumpAndSettle();
    expect(find.text('Remove playlist?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePlaylistCard), findsOneWidget);
    await tester.tap(removePlaylist);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePlaylistCard), findsNothing);
    expect(card('Video three'), findsOneWidget);
  });

  testWidgets(
    'metadata completion during removal dialog still removes that entry',
    (tester) async {
      firstProvider.pendingInfo = Completer<MediaInfo>();
      await mount(tester);
      await addLinks(tester, 'https://first.example/one');
      await tester.tap(find.byTooltip('Remove https://first.example/one'));
      await tester.pump();
      firstProvider.pendingInfo!.complete(
        firstProvider.media(Uri.parse('https://first.example/one')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Remove video?'), findsOneWidget);
      expect(card('Video one'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeVideoList), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancel keeps a loading playlist active', (tester) async {
    controller.pendingPlaylist = Completer<YoutubePlaylist>();
    await mount(tester);
    await addPlaylist(tester);
    await tester.tap(find.byTooltip('Remove playlist'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump();
    expect(controller.playlistToken!.isCancelled, isFalse);
    controller.pendingPlaylist!.complete(controller.playlistResult);
    await tester.pumpAndSettle();
    expect(find.byType(HomePlaylistVideoTile), findsNWidgets(2));
  });

  testWidgets('removed loading playlist is cancelled and cannot return', (
    tester,
  ) async {
    controller.pendingPlaylist = Completer<YoutubePlaylist>();
    await mount(tester);
    await addPlaylist(tester);
    expect(find.text('Reading the complete playlist…'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove playlist'));
    await tester.pump();
    expect(controller.playlistToken!.isCancelled, isFalse);
    expect(find.text('Remove playlist?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(controller.playlistToken!.isCancelled, isTrue);
    controller.pendingPlaylist!.complete(controller.playlistResult);
    await tester.pump();
    expect(find.byType(HomePlaylistCard), findsNothing);
    expect(firstProvider.fetchCount, 0);
  });

  testWidgets(
    'playlist failure retries and failed video does not block available videos',
    (tester) async {
      controller.playlistFailure = true;
      firstProvider.failures.add('two');
      await mount(tester);
      await addPlaylist(tester);
      expect(find.text('Playlist unavailable.'), findsOneWidget);
      controller.playlistFailure = false;
      await tester.tap(find.text('Retry playlist'));
      await tester.pump();
      expect(find.textContaining('1 need attention'), findsOneWidget);
      expect(find.text('Download playlist (1)'), findsOneWidget);
      firstProvider.failures.clear();
      await tester.ensureVisible(find.byTooltip('Retry video'));
      await tester.tap(find.byTooltip('Retry video'));
      await tester.pump();
      expect(find.text('Download playlist (2)'), findsOneWidget);
    },
  );

  testWidgets(
    'playlists never auto-start and remain hidden when mode switches during loading',
    (tester) async {
      controller.settings = controller.settings.copyWith(
        autoStartDownload: true,
      );
      controller.pendingPlaylist = Completer<YoutubePlaylist>();
      await mount(tester);
      await addPlaylist(tester);
      await controller.updateSettings(
        controller.settings.copyWith(multiDownloadMode: false),
      );
      controller.pendingPlaylist!.complete(controller.playlistResult);
      await tester.pump();
      expect(find.byType(HomePlaylistCard), findsNothing);
      expect(controller.manager.tasks, isEmpty);
      await controller.updateSettings(
        controller.settings.copyWith(multiDownloadMode: true),
      );
      await tester.pump();
      expect(find.byType(HomePlaylistCard), findsOneWidget);
      expect(find.text('Download playlist (2)'), findsOneWidget);
      expect(controller.manager.tasks, isEmpty);
    },
  );

  for (final brightness in Brightness.values) {
    for (final width in [375.0, 1162.0]) {
      testWidgets(
        'playlist dialog and group fit $width $brightness at large text',
        (tester) async {
          await mount(
            tester,
            width: width,
            textScale: 1.3,
            brightness: brightness,
          );
          await tester.tap(find.widgetWithText(OutlinedButton, 'Add playlist'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Add playlist'));
          await tester.pump();
          expect(
            find.text('Enter a YouTube playlist link containing list=.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.enterText(
            find.byType(TextFormField),
            'https://youtube.com/playlist?list=PLtest',
          );
          await tester.tap(find.widgetWithText(FilledButton, 'Add playlist'));
          await tester.pumpAndSettle();
          expect(find.byType(PlaylistUrlDialog), findsNothing);
          await tester.ensureVisible(find.text('Download playlist (2)'));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(
            tester
                .widget<HomePlaylistCard>(find.byType(HomePlaylistCard))
                .entries,
            hasLength(2),
          );
          final playlistScroll = find.descendant(
            of: find.byType(HomePlaylistCard),
            matching: find.byType(Scrollable),
          );
          await tester.ensureVisible(playlistScroll);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('2. Video two'),
            120,
            scrollable: playlistScroll,
          );
          await tester.pumpAndSettle();
          expect(find.text('2. Video two'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  test(
    'download history matches YouTube variants, not other sites or unfinished tasks',
    () {
      final completed = completedDownload('/missing/video.mkv');
      controller.manager.queue.add(completed);
      controller.manager.queue.add(
        completedDownload('/missing/copy.mkv', id: 'copy'),
      );
      for (final link in [
        'https://youtu.be/NAEp-qL4VHc?si=share',
        'https://www.youtu.be/NAEp-qL4VHc',
        'https://www.youtube.com/watch?v=NAEp-qL4VHc&t=20&list=playlist',
        'https://m.youtube.com/shorts/NAEp-qL4VHc',
        'https://www.youtube-nocookie.com/embed/NAEp-qL4VHc',
        'https://youtube.com/live/NAEp-qL4VHc',
      ]) {
        expect(controller.manager.completedVideoCount([Uri.parse(link)]), 1);
      }
      expect(
        controller.manager.completedVideoCount([
          Uri.parse('https://evil.example/watch?v=NAEp-qL4VHc'),
          Uri.parse('https://youtube.com.evil.example/watch?v=NAEp-qL4VHc'),
          Uri.parse('https://youtube.com/watch?v=XXXXXXXXXXX'),
          Uri.parse('https://youtube.com/playlist?list=NAEp-qL4VHc'),
          Uri.parse('file:///NAEp-qL4VHc'),
        ]),
        0,
      );
      controller.manager.queue.remove('copy');
      for (final state in DownloadTaskState.values.where(
        (state) => state != DownloadTaskState.completed,
      )) {
        completed.setPhase(state);
        expect(
          controller.manager.completedVideoCount([completed.media.pageUrl]),
          0,
        );
      }
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'download warning follows the link and opens Downloads at 375px $brightness',
      (tester) async {
        controller.settings = const AppSettings();
        controller.manager.queue.add(completedDownload('/missing/video.mkv'));
        await mount(tester, width: 375, textScale: 1.3, brightness: brightness);
        expect(find.byType(DownloadedVideoWarning), findsNothing);
        await tester.enterText(
          find.byType(TextField),
          'https://www.youtube.com/watch?v=NAEp-qL4VHc&t=20',
        );
        await tester.pump();
        expect(find.text('Already downloaded'), findsOneWidget);
        expect(
          tester.getBottomLeft(find.text('Provider: YouTube')).dy,
          lessThan(tester.getTopLeft(find.byType(DownloadedVideoWarning)).dy),
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Fetch Info'),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byType(DownloadedVideoWarning));
        await tester.tap(find.byType(DownloadedVideoWarning));
        await tester.pumpAndSettle();
        expect(find.byType(DownloadsPage), findsOneWidget);
        expect(
          tester
              .widget<DownloadsPage>(find.byType(DownloadsPage))
              .initialTaskId,
          'finished',
        );
        AppTabScope.of(
          tester.element(find.byType(DownloadsPage)),
        ).onSelected(0);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(
          find.byType(TextField),
          'https://youtube.com/watch?v=XXXXXXXXXXX',
        );
        await tester.pump();
        expect(find.byType(DownloadedVideoWarning), findsNothing);
        await tester.enterText(
          find.byType(TextField),
          'https://youtu.be/NAEp-qL4VHc',
        );
        await tester.pump();
        expect(find.byType(DownloadedVideoWarning), findsOneWidget);
        await tester.tap(find.byTooltip('Clear URL'));
        await tester.pump();
        expect(find.byType(DownloadedVideoWarning), findsNothing);
      },
    );
  }

  testWidgets('multi-download warning counts unique completed videos', (
    tester,
  ) async {
    controller.manager.queue.add(completedDownload('/missing/video.mkv'));
    controller.manager.queue.add(
      completedDownload('/missing/copy.mkv', id: 'copy'),
    );
    await mount(tester);
    await tester.enterText(
      find.byType(TextField),
      'https://youtu.be/NAEp-qL4VHc\nhttps://youtube.com/watch?v=NAEp-qL4VHc\nhttps://first.example/new',
    );
    await tester.pump();
    expect(
      tester
          .widget<DownloadedVideoWarning>(find.byType(DownloadedVideoWarning))
          .videoCount,
      1,
    );
    expect(find.text('Already downloaded'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add videos'))
          .onPressed,
      isNotNull,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'prepared batch card warns about a previous video in $brightness',
      (tester) async {
        final url = Uri.parse('https://first.example/one');
        controller.manager.queue.add(
          previousVideoDownload(firstProvider, url, root),
        );
        await mount(tester, width: 375, brightness: brightness);
        await addLinks(
          tester,
          'https://first.example/one https://first.example/two',
        );

        final warning = find.descendant(
          of: card('Video one'),
          matching: find.byType(DownloadedVideoWarning),
        );
        expect(warning, findsOneWidget);
        expect(
          find.descendant(
            of: card('Video two'),
            matching: find.byType(DownloadedVideoWarning),
          ),
          findsNothing,
        );
        expect(find.text('Already downloaded'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(warning);
        await tester.tap(warning);
        await tester.pumpAndSettle();
        expect(find.byType(DownloadsPage), findsOneWidget);
        expect(
          tester
              .widget<DownloadsPage>(find.byType(DownloadsPage))
              .initialTaskId,
          'previous-one',
        );
      },
    );
  }

  testWidgets('playlist row warns only for previously downloaded video', (
    tester,
  ) async {
    final url = Uri.parse('https://first.example/two');
    controller.manager.queue.add(
      previousVideoDownload(firstProvider, url, root),
    );
    await mount(tester);
    await addPlaylist(tester);

    final rows = find.byType(HomePlaylistVideoTile);
    expect(
      find.descendant(
        of: rows.first,
        matching: find.byType(DownloadedVideoWarning),
      ),
      findsNothing,
    );
    final warning = find.descendant(
      of: rows.last,
      matching: find.byType(DownloadedVideoWarning),
    );
    expect(warning, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(warning);
    await tester.tap(warning);
    await tester.pumpAndSettle();
    expect(find.byType(DownloadsPage), findsOneWidget);
    expect(
      tester.widget<DownloadsPage>(find.byType(DownloadsPage)).initialTaskId,
      'previous-two',
    );
  });

  testWidgets(
    'playlist removes previously downloaded entries only after confirmation',
    (tester) async {
      final url = Uri.parse('https://first.example/one');
      controller.manager.queue.add(
        previousVideoDownload(firstProvider, url, root),
      );
      await mount(tester, width: 375, textScale: 1.3);
      await addLinks(tester, 'https://first.example/three');
      await addPlaylist(tester);

      final removeDownloaded = find.descendant(
        of: find.byType(HomePlaylistCard),
        matching: find.text('Remove downloaded (1)'),
      );
      expect(removeDownloaded, findsOneWidget);
      await tester.ensureVisible(removeDownloaded);
      await tester.tap(removeDownloaded);
      await tester.pumpAndSettle();
      expect(find.text('Remove downloaded videos?'), findsOneWidget);
      expect(
        find.textContaining('Downloaded files and history will stay'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<HomePlaylistCard>(find.byType(HomePlaylistCard)).entries,
        hasLength(2),
      );

      await tester.tap(removeDownloaded);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      final playlistCard = tester.widget<HomePlaylistCard>(
        find.byType(HomePlaylistCard),
      );
      expect(playlistCard.entries.map((entry) => entry.draft?.info.id), [
        'two',
      ]);
      expect(find.text('1 videos · 1 ready'), findsOneWidget);
      expect(find.text('Remove downloaded (1)'), findsNothing);
      expect(find.byType(HomeVideoList), findsOneWidget);
      expect(controller.manager.tasks.map((task) => task.id), ['previous-one']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('playlist remove action ignores audio-only history', (
    tester,
  ) async {
    final url = Uri.parse('https://first.example/one');
    controller.manager.queue.add(
      previousVideoDownload(firstProvider, url, root, audioOnly: true),
    );
    await mount(tester);
    await addPlaylist(tester);
    expect(find.textContaining('Remove downloaded ('), findsNothing);
  });

  testWidgets('playlist remove action clears all matching videos at once', (
    tester,
  ) async {
    for (final name in ['one', 'two']) {
      controller.manager.queue.add(
        previousVideoDownload(
          firstProvider,
          Uri.parse('https://first.example/$name'),
          root,
        ),
      );
    }
    await mount(tester);
    await addPlaylist(tester);
    final removeDownloaded = find.text('Remove downloaded (2)');
    expect(removeDownloaded, findsOneWidget);
    await tester.ensureVisible(removeDownloaded);
    await tester.tap(removeDownloaded);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<HomePlaylistCard>(find.byType(HomePlaylistCard)).entries,
      isEmpty,
    );
    expect(controller.manager.tasks, hasLength(2));
    expect(find.byType(HomePlaylistCard), findsOneWidget);
  });

  testWidgets('audio-only history does not warn on a prepared batch card', (
    tester,
  ) async {
    final url = Uri.parse('https://first.example/one');
    controller.manager.queue.add(
      previousVideoDownload(firstProvider, url, root, audioOnly: true),
    );
    await mount(tester);
    await addLinks(tester, url.toString());
    expect(
      find.descendant(
        of: card('Video one'),
        matching: find.byType(DownloadedVideoWarning),
      ),
      findsNothing,
    );
  });

  testWidgets('audio-only completion does not claim the video was downloaded', (
    tester,
  ) async {
    controller.settings = const AppSettings();
    final media = firstProvider.media(Uri.parse('https://first.example/one'));
    controller.manager.queue.add(
      DownloadTask.completed(
        id: 'audio-only',
        media: media,
        options: DownloadOptions(
          taskId: 'audio-only',
          outputDirectory: root.path,
          title: media.title,
          videoFormatId: 'v2160',
          audioFormatId: 'ar256',
          audioOutputFormat: AudioOutputFormat.mp3,
        ),
        providerId: firstProvider.id,
        providerName: firstProvider.displayName,
        videoLabel: 'Audio only',
        audioLabel: 'MP3',
        outputPath: '${root.path}/audio.mp3',
        startedAt: DateTime.utc(2026, 10, 14),
        completedAt: DateTime.utc(2026, 10, 14),
      ),
    );
    await mount(tester);
    await tester.enterText(find.byType(TextField), media.pageUrl.toString());
    await tester.pump();
    expect(find.byType(DownloadedVideoWarning), findsNothing);
  });

  testWidgets('warning reveals the newest matching download deep in history', (
    tester,
  ) async {
    controller.settings = const AppSettings();
    for (var index = 0; index < 100; index++) {
      final task = completedDownload(
        '/missing/video-$index.mkv',
        id: 'history-$index',
      );
      if (index == 80) task.markCompleted('/missing/latest.mkv');
      controller.manager.queue.add(task);
    }
    await mount(tester);
    await tester.enterText(
      find.byType(TextField),
      'https://youtube.com/watch?v=NAEp-qL4VHc',
    );
    await tester.pump();
    await tester.tap(find.byType(DownloadedVideoWarning));
    await tester.pumpAndSettle();
    final match = find.byWidgetPredicate(
      (widget) =>
          widget is DownloadHistoryEntry && widget.task.id == 'history-80',
    );
    expect(match, findsOneWidget);
    expect(tester.widget<DownloadHistoryEntry>(match).highlighted, isTrue);
    expect(find.text('Downloaded before'), findsOneWidget);
    final bounds = tester.getRect(match);
    expect(bounds.top, greaterThan(0));
    expect(bounds.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
    expect(tester.takeException(), isNull);
  });

  testWidgets('warning updates when a download finishes or is removed', (
    tester,
  ) async {
    controller.settings = const AppSettings();
    final media = firstProvider.media(Uri.parse('https://first.example/one'));
    controller.manager.add(
      provider: firstProvider,
      media: media,
      options: DownloadOptions(
        taskId: 'finishing',
        outputDirectory: root.path,
        title: media.title,
        videoFormatId: 'v2160',
      ),
      videoLabel: '2160p',
      audioLabel: 'Arabic',
    );
    await mount(tester);
    await tester.enterText(find.byType(TextField), media.pageUrl.toString());
    await tester.pump();
    expect(find.byType(DownloadedVideoWarning), findsNothing);
    firstProvider.calls.single.complete(
      DownloadTaskResult(
        outputFile: File('${root.path}/one.mkv'),
        merged: false,
      ),
    );
    await tester.pump();
    expect(find.byType(DownloadedVideoWarning), findsOneWidget);
    await controller.manager.remove('finishing');
    await tester.pump();
    expect(find.byType(DownloadedVideoWarning), findsNothing);
  });

  test('single mode is the default for new and existing settings', () async {
    expect(const AppSettings().multiDownloadMode, isFalse);
    expect(
      AppSettings.fromJson({'autoStartDownload': true}).multiDownloadMode,
      isFalse,
    );
    final service = SettingsService();
    await service.save(const AppSettings(multiDownloadMode: true));
    final restored = await service.load();
    expect(restored.multiDownloadMode, isTrue);
    expect(
      restored.copyWith(preferredLanguage: 'en').multiDownloadMode,
      isTrue,
    );
    await service.save(restored.copyWith(multiDownloadMode: false));
    expect((await service.load()).multiDownloadMode, isFalse);
  });

  testWidgets(
    'single mode fetches straight into the original editor and queues one video',
    (tester) async {
      controller.settings = const AppSettings(
        defaultVideoQuality: VideoQuality.q480,
        autoSelectBestAudio: false,
        preferredLanguage: 'en',
        containerPreference: ContainerPreference.mkv,
      );
      await mount(tester);
      expect(find.text('Paste a URL to download'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).maxLines, 1);
      await fetchSingle(tester, 'https://first.example/one');
      expect(find.byType(HomeVideoList), findsNothing);
      expect(find.byType(MediaInfoCard), findsOneWidget);
      final input = tester
          .widget<FormatSelectionCard>(find.byType(FormatSelectionCard))
          .input;
      expect(input.videoHeight, 480);
      expect(input.autoBestAudio, isFalse);
      expect(input.audioLanguage, 'en');
      input.selectKeepMusic(false);
      input.selectMusicRemovalStrength(0.4);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'https://first.example/one',
      );
      input.selectSubtitle(
        firstProvider
            .media(Uri.parse('https://first.example/one'))
            .subtitleTracks
            .first,
      );
      input.selectDownloadSubtitleFile(true);
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Download'));
      await tester.tap(find.widgetWithText(FilledButton, 'Download'));
      await tester.pumpAndSettle();
      expect(find.byType(DownloadsPage), findsOneWidget);
      final task = controller.manager.tasks.single;
      expect(task.options.videoFormatId, 'v480');
      expect(task.options.audioLanguage, 'en');
      expect(task.options.audioFormatId, 'en128');
      expect(task.options.keepMusic, isFalse);
      expect(task.options.musicRemovalStrength, 0.4);
      expect(task.options.containerPreference, ContainerPreference.mkv);
      expect(task.options.subtitle?.language, 'en');
    },
  );

  testWidgets('single mode offers audio-only formats beside video download', (
    tester,
  ) async {
    controller.settings = const AppSettings(preferredLanguage: 'en');
    await mount(tester, width: 375);
    await fetchSingle(tester, 'https://first.example/one');
    await tester.ensureVisible(find.text('Download audio'));
    await tester.tap(find.text('Download audio'));
    await tester.pumpAndSettle();
    for (final label in ['MP3', 'M4A', 'FLAC']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('MP3'));
    await tester.pumpAndSettle();
    final task = controller.manager.tasks.single;
    expect(task.options.audioOutputFormat, AudioOutputFormat.mp3);
    expect(task.options.audioFormatId, 'en128');
    expect(task.options.audioLanguage, 'en');
    expect(task.options.subtitle, isNull);
    expect(task.videoLabel, 'Audio only');
  });

  testWidgets('batch editor queues selected audio-only format', (tester) async {
    await mount(tester);
    await addLinks(tester, 'https://first.example/one');
    await openVideo(tester, 'Video one');
    final audioAction = find.descendant(
      of: find.byType(HomeVideoSettings),
      matching: find.text('Download audio'),
    );
    await tester.ensureVisible(audioAction);
    await tester.tap(audioAction);
    await tester.pumpAndSettle();
    await tester.tap(find.text('FLAC'));
    await tester.pumpAndSettle();
    expect(
      controller.manager.tasks.single.options.audioOutputFormat,
      AudioOutputFormat.flac,
    );
    expect(find.byType(HomeVideoList), findsNothing);
  });

  testWidgets(
    'batch audio action queues only checked videos with their settings',
    (tester) async {
      await mount(tester);
      await addLinks(
        tester,
        'https://first.example/one https://first.example/two',
      );
      final entries = tester
          .widget<HomeVideoList>(find.byType(HomeVideoList))
          .entries;
      entries.first.draft!.input.selectAudioLanguage('en');
      entries.first.draft!.input.selectSubtitle(
        entries.first.draft!.info.subtitleTracks.single,
      );
      entries.first.draft!.input.selectDownloadSubtitleFile(true);
      entries.last.selectedForDownload = false;
      await tester.pump();

      await tester.ensureVisible(find.text('Download audio'));
      await tester.tap(find.text('Download audio'));
      await tester.pumpAndSettle();
      for (final label in ['MP3', 'M4A', 'FLAC']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('M4A'));
      await tester.pumpAndSettle();

      final tasks = controller.manager.tasks;
      expect(tasks, hasLength(1));
      expect(tasks.single.media.id, 'one');
      expect(tasks.single.options.audioOutputFormat, AudioOutputFormat.m4a);
      expect(tasks.single.options.audioFormatId, 'en128');
      expect(tasks.single.options.audioLanguage, 'en');
      expect(tasks.single.options.subtitle, isNull);
      expect(tasks.single.videoLabel, 'Audio only');
      expect(find.byType(DownloadsPage), findsOneWidget);
    },
  );

  testWidgets('batch audio action queues every selected video', (tester) async {
    await mount(tester);
    await addLinks(
      tester,
      'https://first.example/one https://first.example/two',
    );
    await tester.ensureVisible(find.text('Download audio'));
    await tester.tap(find.text('Download audio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MP3'));
    await tester.pumpAndSettle();

    expect(controller.manager.tasks.map((task) => task.media.id), [
      'one',
      'two',
    ]);
    expect(
      controller.manager.tasks.map((task) => task.options.audioOutputFormat),
      everyElement(AudioOutputFormat.mp3),
    );
  });

  testWidgets('playlist audio action queues its checked entries only', (
    tester,
  ) async {
    await mount(tester);
    await addLinks(tester, 'https://first.example/three');
    await addPlaylist(tester);
    final playlistCard = tester.widget<HomePlaylistCard>(
      find.byType(HomePlaylistCard),
    );
    playlistCard.entries.last.selectedForDownload = false;
    final draft = playlistCard.entries.first.draft!;
    draft.input.selectAudioLanguage('en');
    await tester.pump();

    final audioAction = find.descendant(
      of: find.byType(HomePlaylistCard),
      matching: find.text('Download audio'),
    );
    await tester.ensureVisible(audioAction);
    await tester.tap(audioAction);
    await tester.pumpAndSettle();
    await tester.tap(find.text('FLAC'));
    await tester.pumpAndSettle();

    expect(controller.manager.tasks, hasLength(1));
    final task = controller.manager.tasks.single;
    expect(task.media.id, draft.info.id);
    expect(task.options.audioOutputFormat, AudioOutputFormat.flac);
    expect(task.options.audioLanguage, 'en');
    expect(task.options.outputDirectory, playlistCard.playlist.outputDirectory);
    expect(find.byType(HomePlaylistCard), findsOneWidget);
    expect(find.byType(HomeVideoList), findsOneWidget);
  });

  testWidgets('batch audio keeps muted items for correction', (tester) async {
    await mount(tester);
    await addLinks(
      tester,
      'https://first.example/one https://first.example/two',
    );
    final entries = tester
        .widget<HomeVideoList>(find.byType(HomeVideoList))
        .entries;
    final muted = entries.first.draft!.input;
    muted.selectKeepSpeech(false);
    muted.selectKeepMusic(false);
    muted.selectKeepEffects(false);
    await tester.pump();

    await tester.ensureVisible(find.text('Download audio'));
    await tester.tap(find.text('Download audio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MP3'));
    await tester.pumpAndSettle();

    expect(controller.manager.tasks.map((task) => task.media.id), ['two']);
    expect(find.text('Your videos (1)'), findsOneWidget);
    expect(
      find.textContaining('Audio is muted for this video'),
      findsOneWidget,
    );
  });

  testWidgets(
    'single mode rejects multiple links and can retry a failed fetch',
    (tester) async {
      controller.settings = const AppSettings();
      await mount(tester);
      await fetchSingle(
        tester,
        'https://first.example/one https://first.example/two',
      );
      expect(find.text('Enter one valid video URL.'), findsOneWidget);
      expect(firstProvider.fetchCount, 0);
      firstProvider.failures.add('one');
      await fetchSingle(tester, 'https://first.example/one');
      expect(find.byType(AlertDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();
      firstProvider.failures.clear();
      await fetchSingle(tester, 'https://first.example/one');
      expect(find.byType(MediaInfoCard), findsOneWidget);
      expect(find.byType(HomeVideoList), findsNothing);
    },
  );

  testWidgets('single mode Enter fetches and Ctrl Enter downloads', (
    tester,
  ) async {
    controller.settings = const AppSettings();
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'https://first.example/one');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(MediaInfoCard), findsOneWidget);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(controller.manager.tasks, hasLength(1));
    expect(find.byType(DownloadsPage), findsOneWidget);
  });

  testWidgets('single mode automatic download keeps the original navigation', (
    tester,
  ) async {
    controller.settings = const AppSettings(autoStartDownload: true);
    await mount(tester);
    await fetchSingle(tester, 'https://first.example/one');
    expect(controller.manager.tasks, hasLength(1));
    expect(find.byType(DownloadsPage), findsOneWidget);
  });

  testWidgets('Settings switches both ways and preserves separate drafts', (
    tester,
  ) async {
    controller.settings = const AppSettings();
    await mount(tester);
    await fetchSingle(tester, 'https://first.example/one');
    final singleInput = tester
        .widget<FormatSelectionCard>(find.byType(FormatSelectionCard))
        .input;
    singleInput.selectVideoHeight(480);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Multi-download mode'),
    );
    await tester.pumpAndSettle();
    expect((await SettingsService().load()).multiDownloadMode, isTrue);
    AppTabScope.of(tester.element(find.byType(SettingsPage))).onSelected(0);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Add videos'), findsOneWidget);
    expect(find.byType(MediaInfoCard), findsNothing);
    await addLinks(tester, 'https://first.example/two');
    await openVideo(tester, 'Video two');
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Multi-download mode'),
    );
    await tester.pumpAndSettle();
    expect((await SettingsService().load()).multiDownloadMode, isFalse);
    AppTabScope.of(tester.element(find.byType(SettingsPage))).onSelected(0);
    await tester.pumpAndSettle();
    expect(find.byType(HomeVideoList), findsNothing);
    expect(
      tester.widget<MediaInfoCard>(find.byType(MediaInfoCard)).info.id,
      'one',
    );
    expect(
      tester
          .widget<FormatSelectionCard>(find.byType(FormatSelectionCard))
          .input
          .videoHeight,
      480,
    );
    await controller.updateSettings(
      controller.settings.copyWith(multiDownloadMode: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your videos (1)'), findsOneWidget);
    expect(
      tester.widget<MediaInfoCard>(find.byType(MediaInfoCard)).info.id,
      'two',
    );
    expect(controller.manager.tasks, isEmpty);
  });

  testWidgets(
    'turning off multi mode during fetch does not auto-queue hidden videos',
    (tester) async {
      controller.settings = controller.settings.copyWith(
        autoStartDownload: true,
      );
      firstProvider.pendingInfo = Completer<MediaInfo>();
      await mount(tester);
      await addLinks(tester, 'https://first.example/one');
      await controller.updateSettings(
        controller.settings.copyWith(multiDownloadMode: false),
      );
      await tester.pump();
      firstProvider.pendingInfo!.complete(
        firstProvider.media(Uri.parse('https://first.example/one')),
      );
      await tester.pumpAndSettle();
      expect(controller.manager.tasks, isEmpty);
      expect(find.byType(MediaInfoCard), findsNothing);
      expect(find.byType(HomeVideoList), findsNothing);
      await controller.updateSettings(
        controller.settings.copyWith(multiDownloadMode: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your videos (1)'), findsOneWidget);
    },
  );

  testWidgets('only card selection changes the editor above the row', (
    tester,
  ) async {
    await mount(tester);
    await addLinks(tester, 'https://first.example/one');
    expect(find.byType(MediaInfoCard), findsNothing);
    await openVideo(tester, 'Video one');
    expect(
      tester.widget<MediaInfoCard>(find.byType(MediaInfoCard)).info.id,
      'one',
    );
    expect(
      tester
          .widget<FormatSelectionCard>(find.byType(FormatSelectionCard))
          .info
          .id,
      'one',
    );
    expect(
      tester.getTopLeft(find.byType(MediaInfoCard)).dy,
      lessThan(tester.getTopLeft(find.byType(FormatSelectionCard)).dy),
    );
    expect(
      tester
          .getTopLeft(
            find.descendant(
              of: find.byType(HomeVideoSettings),
              matching: find.byType(OutputFolderRow),
            ),
          )
          .dy,
      lessThan(tester.getTopLeft(find.byType(HomeVideoList)).dy),
    );
    await addLinks(tester, 'https://first.example/two');
    expect(
      tester.widget<MediaInfoCard>(find.byType(MediaInfoCard)).info.id,
      'one',
    );
    expect(find.byType(HomeVideoCard), findsNWidgets(2));
    expect(
      tester.getTopLeft(card('Video one')).dy,
      tester.getTopLeft(card('Video two')).dy,
    );
    await openVideo(tester, 'Video two');
    expect(
      tester.widget<MediaInfoCard>(find.byType(MediaInfoCard)).info.id,
      'two',
    );
    await openVideo(tester, 'Video one');
    expect(
      tester.getTopLeft(find.byType(MediaInfoCard)).dy,
      greaterThanOrEqualTo(0),
    );
    await tester.ensureVisible(find.text('Collapse'));
    await tester.tap(find.text('Collapse'));
    await tester.pump();
    expect(find.byType(HomeVideoCard), findsNothing);
    expect(
      tester.widget<MediaInfoCard>(find.byType(MediaInfoCard)).info.id,
      'one',
    );
  });

  testWidgets('batch selects best per video and preserves its provider', (
    tester,
  ) async {
    controller.settings = controller.settings.copyWith(
      defaultVideoQuality: VideoQuality.q360,
      autoSelectBestAudio: false,
    );
    await mount(tester);
    await addLinks(
      tester,
      'https://first.example/one\nhttps://other.example/two\nhttps://first.example/three',
    );
    expect(find.text('Your videos (3)'), findsOneWidget);
    expect(find.text('2160p · Auto'), findsOneWidget);
    expect(find.text('1080p · Auto'), findsOneWidget);
    expect(find.text('720p · Auto'), findsOneWidget);
    expect(find.byType(FormatSelectionCard), findsNothing);
    await tester.enterText(
      find.byType(TextField),
      'https://other.example/not-added',
    );
    await tester.ensureVisible(find.text('Download all (3)'));
    await tester.tap(find.text('Download all (3)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final tasks = controller.manager.tasks;
    expect(tasks, hasLength(3));
    expect(tasks.map((task) => task.options.videoFormatId), [
      'v2160',
      'v1080',
      'v720',
    ]);
    expect(tasks.map((task) => task.providerId), ['first', 'other', 'first']);
    expect(
      tasks.map((task) => task.options.audioFormatId),
      everyElement('ar256'),
    );
    expect(tasks.map((task) => task.options.audioLanguage), everyElement('ar'));
    expect(tasks.map((task) => task.id).toSet(), hasLength(3));
    expect(firstProvider.calls, hasLength(1));
    expect(otherProvider.calls, hasLength(1));
    expect(controller.manager.activeCount, 2);
    expect(tasks.last.state, DownloadTaskState.queued);
    firstProvider.calls.first.completeError(DownloadCancelledException());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(firstProvider.calls, hasLength(2));
    expect(controller.manager.activeCount, 2);
    AppTabScope.of(tester.element(find.byType(DownloadsPage))).onSelected(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HomeVideoCard), findsNothing);
  });

  testWidgets('individual controls survive switching, collapse, and adding', (
    tester,
  ) async {
    await mount(tester);
    await addLinks(
      tester,
      'https://first.example/one\nhttps://first.example/two',
    );
    await openVideo(tester, 'Video one');
    final quality = find.byType(DropdownButtonFormField<int>).first;
    await tester.ensureVisible(quality);
    await tester.tap(quality);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('480p').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final first = tester.widget<FormatSelectionCard>(
      find.byType(FormatSelectionCard),
    );
    first.input.selectAudioLanguage('en');
    first.input.selectAudioBitrate(128);
    first.input.selectContainer(ContainerPreference.mkv);
    first.input.selectSubtitle(first.info.subtitleTracks.single);
    first.input.selectDownloadSubtitleFile(true);
    first.onChanged();
    final folder = tester.widget<OutputFolderRow>(
      find.descendant(
        of: find.byType(HomeVideoSettings),
        matching: find.byType(OutputFolderRow),
      ),
    );
    folder.onChanged('${root.path}/custom');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('480p · Custom'), findsOneWidget);
    await openVideo(tester, 'Video two');
    final second = tester.widget<FormatSelectionCard>(
      find.byType(FormatSelectionCard),
    );
    expect(second.input.videoHeight, isNull);
    expect(second.input.audioLanguage, 'ar');
    expect(second.input.subtitleToDownload, isNull);
    expect(second.input.containerPreference, ContainerPreference.auto);
    expect(second.input.outputDirectory, root.path);
    await openVideo(tester, 'Video one');
    expect(
      tester
          .widget<FormatSelectionCard>(find.byType(FormatSelectionCard))
          .input,
      same(first.input),
    );
    await tester.ensureVisible(find.text('Collapse'));
    await tester.tap(find.text('Collapse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HomeVideoCard), findsNothing);
    await tester.tap(find.text('Expand'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('480p · Custom'), findsOneWidget);
    await addLinks(tester, 'https://first.example/three');
    expect(find.text('480p · Custom'), findsOneWidget);
    await tester.ensureVisible(find.text('Download all (3)'));
    await tester.tap(find.text('Download all (3)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final options = controller.manager.tasks.first.options;
    expect(options.videoFormatId, 'v480');
    expect(options.audioFormatId, 'en128');
    expect(options.audioLanguage, 'en');
    expect(options.containerPreference, ContainerPreference.mkv);
    expect(options.subtitle, first.info.subtitleTracks.single);
    expect(options.outputDirectory, '${root.path}/custom');
    expect(controller.manager.tasks[1].options.audioFormatId, 'ar256');
  });

  testWidgets('invalid and failed links retain successes and can be retried', (
    tester,
  ) async {
    firstProvider.failures.add('two');
    await mount(tester);
    await addLinks(
      tester,
      'https://first.example/one\nnot-a-link\nhttps://unsupported.example/video\nhttps://first.example/two',
    );
    expect(find.text('Your videos (4)'), findsOneWidget);
    expect(find.byType(HomeVideoFetchCard), findsNWidgets(3));
    expect(controller.manager.tasks, isEmpty);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
    firstProvider.failures.clear();
    final retry = find.descendant(
      of: find.widgetWithText(HomeVideoFetchCard, 'https://first.example/two'),
      matching: find.text('Retry'),
    );
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HomeVideoCard), findsNWidgets(2));
    expect(find.byType(HomeVideoFetchCard), findsNWidgets(2));
    await addLinks(
      tester,
      'https://first.example/one\nhttps://first.example/one?alias=true',
    );
    expect(find.text('Your videos (4)'), findsOneWidget);
    expect(find.byType(HomeVideoCard), findsNWidgets(2));
    expect(find.byType(MediaInfoCard), findsNothing);
  });

  testWidgets('removing selected video and downloading one preserves the rest', (
    tester,
  ) async {
    await mount(tester);
    await addLinks(
      tester,
      'https://first.example/one\nhttps://first.example/two\nhttps://first.example/three',
    );
    await openVideo(tester, 'Video one');
    await tester.ensureVisible(find.byTooltip('Remove Video one'));
    await tester.tap(find.byTooltip('Remove Video one'));
    await tester.pumpAndSettle();
    expect(find.text('Your videos (3)'), findsOneWidget);
    expect(find.byType(FormatSelectionCard), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FormatSelectionCard), findsNothing);
    expect(find.text('Your videos (2)'), findsOneWidget);
    await openVideo(tester, 'Video two');
    await tester.ensureVisible(find.text('Download'));
    await tester.tap(find.text('Download'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.manager.tasks.single.media.id, 'two');
    AppTabScope.of(tester.element(find.byType(DownloadsPage))).onSelected(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Your videos (1)'), findsOneWidget);
    expect(card('Video three'), findsOneWidget);
    final removeRemaining = find.descendant(
      of: card('Video three'),
      matching: find.byType(IconButton),
    );
    await tester.ensureVisible(removeRemaining);
    await tester.pumpAndSettle();
    await tester.tap(removeRemaining);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HomeVideoList), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'queue validation failure retains failed draft and queues valid video once',
    (tester) async {
      await mount(tester);
      await addLinks(
        tester,
        'https://first.example/empty\nhttps://first.example/one',
      );
      await tester.ensureVisible(find.text('Download all (2)'));
      await tester.tap(find.text('Download all (2)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.manager.tasks.single.media.id, 'one');
      expect(find.text('Your videos (1)'), findsOneWidget);
      expect(
        find.text('No video format is available for this media.'),
        findsOneWidget,
      );
      expect(find.byType(MediaInfoCard), findsNothing);
      await tester.ensureVisible(find.text('Download all (1)'));
      await tester.tap(find.text('Download all (1)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.manager.tasks, hasLength(1));
    },
  );

  testWidgets('fetch shortcuts cannot duplicate an in-flight batch', (
    tester,
  ) async {
    firstProvider.pendingInfo = Completer<MediaInfo>();
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'https://first.example/one');
    await tester.tap(find.widgetWithText(FilledButton, 'Add videos'));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(firstProvider.fetchCount, 1);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, true);
    firstProvider.pendingInfo!.complete(
      firstProvider.media(Uri.parse('https://first.example/one')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Your videos (1)'), findsOneWidget);
  });

  testWidgets(
    'fetching stays in the strip and additional links do not replace the selected editor',
    (tester) async {
      await mount(tester);
      await addLinks(tester, 'https://first.example/one');
      await openVideo(tester, 'Video one');
      firstProvider.pendingInfo = Completer<MediaInfo>();
      final pending = firstProvider.pendingInfo!;
      await addLinks(tester, 'https://first.example/two');
      expect(find.byType(HomeVideoFetchCard), findsOneWidget);
      final input = find.byType(UrlInputCard);
      expect(
        find.descendant(
          of: input,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(HomeVideoList),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.text('Fetching...'), findsNothing);
      expect(
        tester.widget<MediaInfoCard>(find.byType(MediaInfoCard)).info.id,
        'one',
      );
      await addLinks(tester, 'https://other.example/three');
      expect(find.text('Your videos (3)'), findsOneWidget);
      expect(find.text('Waiting to fetch…'), findsOneWidget);
      expect(otherProvider.fetchCount, 0);
      firstProvider.pendingInfo = null;
      pending.complete(
        firstProvider.media(Uri.parse('https://first.example/two')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(HomeVideoFetchCard), findsNothing);
      expect(
        tester.widget<MediaInfoCard>(find.byType(MediaInfoCard)).info.id,
        'one',
      );
      await openVideo(tester, 'Video two');
      expect(
        tester.widget<MediaInfoCard>(find.byType(MediaInfoCard)).info.id,
        'two',
      );
    },
  );

  testWidgets('removed pending cards never return when metadata completes', (
    tester,
  ) async {
    firstProvider.pendingInfo = Completer<MediaInfo>();
    await mount(tester);
    await addLinks(tester, 'https://first.example/one');
    expect(find.byType(HomeVideoFetchCard), findsOneWidget);
    expect(find.byType(MediaInfoCard), findsNothing);
    await tester.tap(find.byTooltip('Remove https://first.example/one'));
    await tester.pump();
    expect(find.text('Remove video?'), findsOneWidget);
    expect(find.byType(HomeVideoFetchCard), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pump();
    firstProvider.pendingInfo!.complete(
      firstProvider.media(Uri.parse('https://first.example/one')),
    );
    await tester.pump();
    expect(find.byType(HomeVideoList), findsNothing);
    expect(find.byType(MediaInfoCard), findsNothing);
  });

  testWidgets('fetch completion after disposal does not update the page', (
    tester,
  ) async {
    firstProvider.pendingInfo = Completer<MediaInfo>();
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'https://first.example/one');
    await tester.tap(find.widgetWithText(FilledButton, 'Add videos'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    firstProvider.pendingInfo!.complete(
      firstProvider.media(Uri.parse('https://first.example/one')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(controller.manager.tasks, isEmpty);
  });

  testWidgets('auto-start only queues newly added videos after fetching', (
    tester,
  ) async {
    await mount(tester);
    await addLinks(tester, 'https://first.example/one');
    controller.settings = controller.settings.copyWith(autoStartDownload: true);
    await addLinks(
      tester,
      'https://first.example/two\nhttps://first.example/three',
    );
    expect(controller.manager.tasks.map((task) => task.media.id), [
      'two',
      'three',
    ]);
    expect(find.byType(DownloadsPage), findsNothing);
    expect(find.text('Your videos (1)'), findsOneWidget);
    expect(card('Video one'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 900),
    const Size(375, 900),
    const Size(900, 375),
    const Size(1162, 900),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('batch cards and expanded controls fit $size $brightness', (
        tester,
      ) async {
        await mount(
          tester,
          width: size.width,
          height: size.height,
          brightness: brightness,
          textScale: 1.3,
        );
        await addLinks(
          tester,
          'https://first.example/one\nhttps://first.example/two\nhttps://first.example/three',
        );
        expect(tester.takeException(), isNull);
        await openVideo(tester, 'Video one');
        await tester.ensureVisible(
          find.descendant(
            of: find.byType(HomeVideoSettings),
            matching: find.byType(OutputFolderRow),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.byType(FormatSelectionCard), findsOneWidget);
        expect(
          tester.widget<UrlInputCard>(find.byType(UrlInputCard)).fetching,
          false,
        );
      });
    }
  }
}

class BatchProvider extends ControlledDownloadProvider {
  BatchProvider(this.providerId);
  final String providerId;
  final failures = <String>{};
  Completer<MediaInfo>? pendingInfo;
  int fetchCount = 0;

  @override
  String get id => providerId;

  @override
  bool canHandle(Uri url) => url.host == '$providerId.example';

  @override
  Future<MediaInfo> fetchInfo(Uri url) async {
    fetchCount++;
    if (pendingInfo case final pending?) return pending.future;
    if (failures.contains(url.pathSegments.last)) {
      throw NetworkException('Try again later.');
    }
    return media(url);
  }

  MediaInfo media(Uri url) {
    final name = url.pathSegments.last;
    final height = switch (name) {
      'one' => 2160,
      'two' => 1080,
      _ => 720,
    };
    return MediaInfo(
      id: name,
      title: 'Video $name',
      providerId: id,
      providerName: displayName,
      pageUrl: url,
      videoFormats: name == 'empty'
          ? []
          : [
              VideoFormat(
                formatId: 'v$height',
                width: height * 16 ~/ 9,
                height: height,
                videoOnly: true,
              ),
              const VideoFormat(
                formatId: 'v480',
                width: 854,
                height: 480,
                videoOnly: true,
              ),
            ],
      audioFormats: const [
        AudioFormat(formatId: 'ar128', language: 'ar', bitrate: 128),
        AudioFormat(formatId: 'ar256', language: 'ar', bitrate: 256),
        AudioFormat(formatId: 'en128', language: 'en', bitrate: 128),
      ],
      subtitleTracks: const [SubtitleTrack(language: 'en', extension: 'vtt')],
    );
  }
}

class BatchController extends Fake implements AppController {
  BatchController(this.root, List<DownloaderProvider> providers) {
    registry = ProviderRegistry(providers);
    final paths = QueueTestPaths(root);
    log = LogService(paths: paths);
    manager = DownloadManager(
      registry: registry,
      repository: DownloadRepository(paths: paths),
      log: log,
    );
  }

  final Directory root;
  int playlistFetchCount = 0;
  bool playlistFailure = false;
  Completer<YoutubePlaylist>? pendingPlaylist;
  CancelToken? playlistToken;
  final playlistResult = YoutubePlaylist(
    title: 'My learning playlist',
    videoUrls: [
      Uri.parse('https://first.example/one'),
      Uri.parse('https://first.example/two'),
    ],
  );
  @override
  Future<YoutubePlaylist> fetchYoutubePlaylist(
    Uri url, {
    CancelToken? cancelToken,
  }) async {
    playlistFetchCount++;
    playlistToken = cancelToken;
    if (playlistFailure) throw NetworkException('Playlist unavailable.');
    return pendingPlaylist?.future ?? playlistResult;
  }

  @override
  AppSettings settings = const AppSettings(multiDownloadMode: true);
  @override
  late final ProviderRegistry registry;
  @override
  late final DownloadManager manager;
  @override
  late final LogService log;
  @override
  bool get updatingTools => false;
  @override
  List<DependencyStatus> get dependencies => const [];
  @override
  ThemeMode get themeMode => ThemeMode.light;
  @override
  String resolveOutputDirectory() => root.path;
  @override
  Future<MediaInfo> fetchMediaInfo(DownloaderProvider provider, Uri url) =>
      provider.fetchInfo(url);
  @override
  Future<void> rememberDirectory(String path) async {}
  final _notifier = ChangeNotifier();
  @override
  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    await SettingsService().save(next);
    _notifier.notifyListeners();
  }

  @override
  QueueTestPaths get pathUtils => QueueTestPaths(root);
  @override
  bool get clearingLinkCache => false;
  @override
  String? get linkCacheMessage => null;
  @override
  bool get checkingDependencies => false;
  @override
  String? get toolUpdateMessage => null;
  @override
  Future<void> clearLinkCache() async {}
  @override
  Future<void> refreshDependencies() async {}
  @override
  void addListener(VoidCallback listener) => _notifier.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      _notifier.removeListener(listener);
}

DownloadTask previousVideoDownload(
  BatchProvider provider,
  Uri url,
  Directory root, {
  bool audioOnly = false,
}) {
  final media = provider.media(url);
  final name = url.pathSegments.last;
  return DownloadTask.completed(
    id: 'previous-$name',
    media: media,
    options: DownloadOptions(
      taskId: 'previous-$name',
      outputDirectory: root.path,
      title: media.title,
      videoFormatId: 'v2160',
      audioOutputFormat: audioOnly ? AudioOutputFormat.mp3 : null,
    ),
    providerId: provider.id,
    providerName: provider.displayName,
    videoLabel: audioOnly ? 'Audio only' : '2160p',
    audioLabel: 'Arabic',
    outputPath: '${root.path}/$name.${audioOnly ? 'mp3' : 'mkv'}',
    startedAt: DateTime.utc(2026, 10, 14),
    completedAt: DateTime.utc(2026, 10, 14),
  );
}
