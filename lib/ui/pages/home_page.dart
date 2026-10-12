import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../core/errors/downloader_exceptions.dart';
import '../../core/models/audio_format.dart';
import '../../core/models/download_options.dart';
import '../../core/models/video_format.dart';
import '../../core/utils/language_names.dart';
import '../../downloads/download_repository.dart';
import '../../providers/downloader_provider.dart';
import '../../providers/format_selector.dart';
import '../widgets/dependency_banner.dart';
import '../widgets/download_tile.dart';
import '../widgets/error_dialog.dart';
import '../widgets/home_video_list.dart';
import '../widgets/home_video_settings.dart';
import '../widgets/url_input_card.dart';
import '../widgets/app_scaffold.dart';
import 'home_video_draft.dart';
import 'home_video_entry.dart';
import 'downloads_navigation.dart';

/// Main screen: URLs → prepare videos → choose individual formats → download.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _urlController = TextEditingController();
  final _urlFocusNode = FocusNode();
  final _videoDetailsKey = GlobalKey();

  bool _fetching = false;
  bool _singleFetching = false;
  HomeVideoDraft? _singleVideo;
  DownloaderProvider? _provider;
  String? _errorMessage;
  final _entries = <HomeVideoEntry>[];
  List<HomeVideoDraft> get _drafts =>
      _entries.map((entry) => entry.draft).whereType<HomeVideoDraft>().toList();
  HomeVideoDraft? _selected;
  bool _collapsed = false;
  bool _submitting = false;

  static const _selector = FormatSelector();
  final _repository = DownloadRepository();

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final links = _urlController.text.trim().split(RegExp(r'\s+'));
    final url = links.length == 1 ? Uri.tryParse(links.single) : null;
    setState(() {
      _provider = url != null && _isValidUrl(url)
          ? context.read<AppController>().registry.resolve(url)
          : null;
      _errorMessage =
          !context.read<AppController>().settings.multiDownloadMode &&
              url != null &&
              _isValidUrl(url) &&
              _provider == null
          ? 'Unsupported website.\nThis website is not supported yet.'
          : null;
    });
  }

  bool _isValidUrl(Uri url) =>
      (url.scheme == 'http' || url.scheme == 'https') && url.host.isNotEmpty;

  void _viewPreviousDownload() {
    final matches = context
        .read<AppController>()
        .manager
        .completedVideosForUrls(
          _urlController.text
              .trim()
              .split(RegExp(r'\s+'))
              .map(Uri.tryParse)
              .whereType<Uri>(),
        );
    Navigator.of(context).pushNamed(
      AppRoutes.downloads,
      arguments: matches.isEmpty
          ? null
          : DownloadsNavigation(taskId: matches.first.id),
    );
  }

  Future<void> _fetchInfo() async {
    final controller = context.read<AppController>();
    if (_submitting || controller.updatingTools) return;
    if (!controller.settings.multiDownloadMode) {
      await _fetchSingleVideo();
      return;
    }
    final text = _urlController.text.trim();
    if (text.isEmpty) {
      _urlFocusNode.requestFocus();
      return;
    }
    final links = text.split(RegExp(r'\s+')).toSet();
    setState(() {
      for (final link in links) {
        if (!_entries.any((entry) => entry.link == link)) {
          _entries.add(HomeVideoEntry(link));
        }
      }
      _collapsed = false;
    });
    _urlController.clear();
    await _fetchPending();
  }

  Future<void> _fetchSingleVideo() async {
    if (_singleFetching) return;
    final controller = context.read<AppController>();
    final text = _urlController.text.trim();
    if (text.isEmpty) {
      _urlFocusNode.requestFocus();
      return;
    }
    final url = Uri.tryParse(text);
    if (url == null || !_isValidUrl(url) || RegExp(r'\s').hasMatch(text)) {
      setState(() {
        _provider = null;
        _errorMessage = 'Enter one valid video URL.';
      });
      return;
    }
    final provider = controller.registry.resolve(url);
    if (provider == null) {
      setState(() {
        _provider = null;
        _errorMessage =
            'Unsupported website.\nThis website is not supported yet.';
      });
      return;
    }
    final outputDirectory =
        _singleVideo?.input.outputDirectory ??
        controller.resolveOutputDirectory();
    setState(() {
      _provider = provider;
      _errorMessage = null;
      _singleFetching = true;
      _singleVideo = null;
    });
    try {
      final info = await controller.fetchMediaInfo(provider, url);
      if (!mounted) return;
      final settings = controller.settings;
      final draft = HomeVideoDraft(
        info: info,
        provider: provider,
        preferredLanguage: settings.preferredLanguage,
        outputDirectory: outputDirectory,
        containerPreference: settings.containerPreference,
      );
      draft.input.selectAutoBestAudio(settings.autoSelectBestAudio);
      draft.input.resetVideoQuality(
        info.videoFormats,
        settings.defaultVideoQuality,
      );
      setState(() => _singleVideo = draft);
      if (!settings.multiDownloadMode && settings.autoStartDownload) {
        await _startSingleDownload();
      }
    } catch (error) {
      if (!mounted) return;
      if (!controller.settings.multiDownloadMode) {
        await showErrorDialog(
          context,
          message: error is DownloaderException
              ? error.message
              : 'An unexpected error occurred while fetching media info.',
          details: error is DownloaderException
              ? error.details
              : error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _singleFetching = false);
    }
  }

  Future<void> _startSingleDownload() async {
    final controller = context.read<AppController>();
    final draft = _singleVideo;
    if (draft == null || _submitting || controller.updatingTools) return;
    try {
      final directory = _queueDownload(draft);
      unawaited(
        controller.rememberDirectory(directory).catchError((Object error) {
          controller.log.error('Could not remember output directory: $error');
        }),
      );
      Navigator.of(context).pushNamed(AppRoutes.downloads);
    } catch (error) {
      await showErrorDialog(
        context,
        message: error is DownloaderException
            ? error.message
            : 'Could not start this download. Please try again.',
        details: error is DownloaderException
            ? error.details
            : error.toString(),
      );
    }
  }

  Future<void> _fetchPending() async {
    if (_fetching) return;
    _fetching = true;
    final controller = context.read<AppController>();
    final added = <HomeVideoDraft>[];
    try {
      while (mounted) {
        final entry = _entries.where((entry) => entry.waiting).firstOrNull;
        if (entry == null) break;
        setState(() => entry.fetching = true);
        try {
          final url = Uri.tryParse(entry.link);
          if (url == null || !_isValidUrl(url)) {
            throw const FormatException('Enter a valid HTTP or HTTPS URL.');
          }
          final provider = controller.registry.resolve(url);
          if (provider == null) {
            throw const FormatException('This website is not supported yet.');
          }
          final info = await controller.fetchMediaInfo(provider, url);
          if (!mounted) return;
          if (!_entries.contains(entry)) continue;
          if (_drafts.any(
            (draft) =>
                draft.provider.id == provider.id && draft.info.id == info.id,
          )) {
            setState(() => _entries.remove(entry));
            continue;
          }
          final draft = HomeVideoDraft(
            info: info,
            provider: provider,
            preferredLanguage: controller.settings.preferredLanguage,
            outputDirectory: controller.resolveOutputDirectory(),
            containerPreference: controller.settings.containerPreference,
          );
          added.add(draft);
          setState(() {
            entry.draft = draft;
            entry.fetching = false;
          });
        } catch (error) {
          if (!mounted) return;
          if (!_entries.contains(entry)) continue;
          setState(() {
            entry.fetching = false;
            entry.errorMessage = switch (error) {
              DownloaderException() => error.message,
              FormatException() => error.message,
              _ => 'Could not fetch video information. Please try again.',
            };
          });
          controller.log.error('Could not prepare video: $error');
        }
      }
    } finally {
      _fetching = false;
    }
    if (mounted &&
        controller.settings.multiDownloadMode &&
        controller.settings.autoStartDownload &&
        added.isNotEmpty) {
      _startDownloads(added, navigate: false);
    }
  }

  void _retryEntry(HomeVideoEntry entry) {
    if (entry.fetching || !_entries.contains(entry)) return;
    setState(() => entry.errorMessage = null);
    _fetchPending();
  }

  void _removeEntry(HomeVideoEntry entry) {
    setState(() {
      _entries.remove(entry);
      if (_selected == entry.draft) _selected = null;
    });
  }

  void _selectDraft(HomeVideoDraft draft) {
    setState(() => _selected = draft);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final detailsContext = _videoDetailsKey.currentContext;
      if (detailsContext == null) return;
      Scrollable.ensureVisible(
        detailsContext,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
      );
    });
  }

  void _startDownloads(List<HomeVideoDraft> drafts, {bool navigate = true}) {
    final controller = context.read<AppController>();
    if (_submitting || controller.updatingTools) return;
    final pending = drafts.where(_drafts.contains).toList();
    if (pending.isEmpty) return;
    setState(() => _submitting = true);
    final failed = <HomeVideoDraft>[];
    String? lastDirectory;
    for (final draft in pending) {
      try {
        lastDirectory = _queueDownload(draft);
        _entries.removeWhere((entry) => entry.draft == draft);
        if (_selected == draft) _selected = null;
      } catch (error) {
        draft.errorMessage = error is DownloaderException
            ? error.message
            : 'Could not start this download. Please try again.';
        failed.add(draft);
        controller.log.error('Could not queue video: $error');
      }
    }
    setState(() {
      _submitting = false;
      if (failed.isNotEmpty) {
        _collapsed = false;
      }
    });
    if (lastDirectory != null) {
      unawaited(
        controller.rememberDirectory(lastDirectory).catchError((Object error) {
          controller.log.error('Could not remember output directory: $error');
        }),
      );
    }
    if (failed.isEmpty && navigate) {
      Navigator.of(context).pushNamed(AppRoutes.downloads);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${pending.length - failed.length} queued'
            '${failed.isEmpty ? '' : ' · ${failed.length} need attention'}',
          ),
        ),
      );
    }
  }

  String _queueDownload(HomeVideoDraft draft) {
    final controller = context.read<AppController>();
    final info = draft.info;
    final input = draft.input;

    final video = _selector.selectBestVideo(
      info.videoFormats,
      maxHeight: input.videoHeight,
    );
    if (video == null) {
      throw FormatExtractionException(
        'No video format is available for this media.',
      );
    }

    final hasSeparateAudio = info.audioFormats.isNotEmpty;
    AudioFormat? audio;
    String? audioLabel;
    String? audioLanguageCode;

    if (hasSeparateAudio) {
      final language =
          input.audioLanguage ?? controller.settings.preferredLanguage;
      if (input.autoBestAudio) {
        audio = _selector.selectBestAudio(
          info.audioFormats,
          preferredLanguage: language,
          fallbackLanguage: _fallbackOrNull(
            controller.settings.fallbackLanguage,
          ),
        );
      } else {
        final bitrate = input.audioBitrate;
        audio = bitrate == null
            ? _selector.selectBestAudio(
                info.audioFormats,
                preferredLanguage: language,
              )
            : _selector.selectAudioAtBitrate(
                info.audioFormats,
                language: language,
                bitrate: bitrate,
              );
      }

      if (audio == null) {
        final available = info.audioLanguages
            .map(LanguageNames.nameFor)
            .join(', ');
        throw AudioNotAvailableException(
          'The selected ${LanguageNames.nameFor(language)} audio quality '
          'is unavailable. Fetch info again and select an available quality.',
          details: available.isEmpty
              ? null
              : 'Available audio languages: $available',
        );
      }

      audioLabel =
          '${LanguageNames.nameFor(audio.language)}'
                  '${audio.bitrate != null ? ' ${audio.bitrate} kbps' : ''}'
              .trim();
      audioLanguageCode = audio.language;
    } else {
      audioLabel = 'Embedded audio';
    }

    var directory = input.outputDirectory.trim();
    if (directory.isEmpty) {
      directory = controller.resolveOutputDirectory();
    }
    _repository.ensureDirectory(directory);
    final taskId = '${draft.id}_${DateTime.now().microsecondsSinceEpoch}';
    final options = DownloadOptions(
      taskId: taskId,
      outputDirectory: directory,
      title: info.title,
      videoFormatId: video.formatId,
      audioFormatId: audio?.formatId,
      audioLanguage: audioLanguageCode,
      subtitle: input.subtitleToDownload,
      overwrite: false,
      containerPreference: input.containerPreference,
    );

    controller.log.info(
      'Starting download with '
      'video=${video.formatId} audio=${audio?.formatId ?? 'embedded'}',
    );
    controller.manager.add(
      provider: draft.provider,
      media: info,
      options: options,
      videoLabel: _videoLabel(video),
      audioLabel: audioLabel,
    );
    return directory;
  }

  String? _fallbackOrNull(String fallback) =>
      fallback.trim().isEmpty ? null : fallback.trim();

  String _videoLabel(VideoFormat video) {
    final label = video.resolutionLabel;
    return label == 'unknown' ? 'Best' : label;
  }

  void _handlePrimaryShortcut() {
    if (!context.read<AppController>().settings.multiDownloadMode) {
      if (_singleVideo == null) {
        _fetchInfo();
      } else {
        _startSingleDownload();
      }
      return;
    }
    if (_urlController.text.trim().isNotEmpty || _drafts.isEmpty) {
      _fetchInfo();
    } else {
      _startDownloads(_drafts);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final multiDownloadMode = controller.settings.multiDownloadMode;
    final selected = multiDownloadMode ? _selected : _singleVideo;
    final busy =
        _submitting ||
        controller.updatingTools ||
        (!multiDownloadMode && _singleFetching);
    final activeTasks = controller.manager.tasks
        .where((t) => t.state.isActive)
        .toList();

    return AppScaffold(
      selectedIndex: 0,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, control: true): () =>
              _handlePrimaryShortcut(),
        },
        child: Focus(
          autofocus: true,
          child: DragTarget<String>(
            onWillAcceptWithDetails: (_) => !busy,
            onAcceptWithDetails: (details) {
              if (busy) return;
              _urlController.text = details.data;
              _fetchInfo();
            },
            builder: (context, candidates, rejected) {
              final isDragging = candidates.isNotEmpty;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const DependencyBanner(),
                        if (isDragging) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                multiDownloadMode
                                    ? 'Drop URLs to add videos'
                                    : 'Drop URL to download',
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        ListenableBuilder(
                          listenable: controller.manager,
                          builder: (context, child) => UrlInputCard(
                            controller: _urlController,
                            focusNode: _urlFocusNode,
                            fetching: !multiDownloadMode && _singleFetching,
                            multiDownloadMode: multiDownloadMode,
                            enabled: !busy,
                            onFetch: _fetchInfo,
                            provider: _provider,
                            errorMessage: _errorMessage,
                            previousDownloadCount: controller.manager
                                .completedVideoCount(
                                  _urlController.text
                                      .trim()
                                      .split(RegExp(r'\s+'))
                                      .map(Uri.tryParse)
                                      .whereType<Uri>(),
                                ),
                            onViewDownloads: _viewPreviousDownload,
                          ),
                        ),
                        if (multiDownloadMode &&
                            controller.settings.autoStartDownload)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'Auto-start is on: new videos download after fetching. '
                              'Turn it off in Settings to review them first.',
                            ),
                          ),
                        if (selected != null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            key: _videoDetailsKey,
                            child: HomeVideoSettings(
                              key: ValueKey(selected.id),
                              draft: selected,
                              preferredLanguage:
                                  controller.settings.preferredLanguage,
                              onChanged: () =>
                                  setState(() => selected.errorMessage = null),
                              onDownload: busy
                                  ? null
                                  : multiDownloadMode
                                  ? () => _startDownloads([selected])
                                  : _startSingleDownload,
                            ),
                          ),
                        ],
                        if (multiDownloadMode && _entries.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          HomeVideoList(
                            entries: _entries,
                            onRetry: _retryEntry,
                            selected: selected,
                            collapsed: _collapsed,
                            onToggleCollapsed: () =>
                                setState(() => _collapsed = !_collapsed),
                            onSelect: _selectDraft,
                            onRemove: _removeEntry,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Best quality is selected automatically for each new video. '
                            '${controller.manager.queue.maxConcurrent} downloads run at a time; the rest wait in the queue.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: busy || _drafts.isEmpty
                                  ? null
                                  : () => _startDownloads(_drafts),
                              icon: const Icon(Icons.download),
                              label: Text('Download all (${_drafts.length})'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(220, 52),
                              ),
                            ),
                          ),
                        ],
                        if (activeTasks.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Active downloads',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          for (final task in activeTasks) ...[
                            DownloadTile(task: task),
                            const SizedBox(height: 8),
                          ],
                        ],
                        const SizedBox(height: 16),
                        Text(
                          Theme.of(context).platform == TargetPlatform.android
                              ? 'Keep the app open while downloading in this preview.'
                              : multiDownloadMode
                              ? 'Tip: press Ctrl+Enter to add videos or download all. Drag & drop URLs anywhere on this page.'
                              : 'Tip: press Ctrl+Enter to fetch or download. Drag & drop a URL anywhere on this page.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
