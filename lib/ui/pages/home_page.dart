import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../core/errors/downloader_exceptions.dart';
import '../../core/models/audio_format.dart';
import '../../core/models/download_options.dart';
import '../../core/models/media_info.dart';
import '../../core/models/video_format.dart';
import '../../core/utils/language_names.dart';
import '../../downloads/download_repository.dart';
import '../../providers/downloader_provider.dart';
import '../../providers/format_selector.dart';
import '../widgets/dependency_banner.dart';
import '../widgets/download_tile.dart';
import '../widgets/error_dialog.dart';
import '../widgets/format_pickers.dart';
import '../widgets/media_info_card.dart';
import '../widgets/output_folder_row.dart';
import '../widgets/url_input_card.dart';
import '../widgets/app_scaffold.dart';

/// Main screen: URL → detect provider → fetch info → choose formats → download.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _urlController = TextEditingController();
  final _urlFocusNode = FocusNode();

  bool _fetching = false;
  DownloaderProvider? _provider;
  String? _errorMessage;
  MediaInfo? _info;

  VideoQuality _videoQuality = VideoQuality.best;
  String? _audioLanguage;
  bool _autoBestAudio = true;
  int? _audioBitrate;
  ContainerPreference _containerPreference = ContainerPreference.auto;
  String _outputDirectory = '';

  static const _selector = FormatSelector();
  final _repository = DownloadRepository();

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
    _outputDirectory = context.read<AppController>().resolveOutputDirectory();
    final settings = context.read<AppController>().settings;
    _autoBestAudio = settings.autoSelectBestAudio;
    _videoQuality = settings.defaultVideoQuality;
    _containerPreference = settings.containerPreference;
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final controller = context.read<AppController>();
    final url = Uri.tryParse(_urlController.text.trim());
    setState(() {
      if (url != null && (url.scheme == 'http' || url.scheme == 'https')) {
        _provider = controller.registry.resolve(url);
        _errorMessage = _provider == null
            ? 'Unsupported website.\nThis website is not supported yet.'
            : null;
      } else {
        _provider = null;
        _errorMessage = null;
      }
    });
  }

  Future<void> _fetchInfo() async {
    final controller = context.read<AppController>();
    final text = _urlController.text.trim();
    if (text.isEmpty) {
      _urlFocusNode.requestFocus();
      return;
    }

    final url = Uri.tryParse(text);
    if (url == null || (url.scheme != 'http' && url.scheme != 'https')) {
      setState(() {
        _errorMessage = 'That does not look like a valid URL.';
        _provider = null;
      });
      return;
    }

    final provider = controller.registry.resolve(url);
    if (provider == null) {
      setState(() {
        _provider = null;
        _errorMessage = 'Unsupported website.\n'
            'This website is not supported yet.';
      });
      return;
    }

    setState(() {
      _provider = provider;
      _errorMessage = null;
      _fetching = true;
      _info = null;
    });

    try {
      controller.log.info('Resolving provider');
      final info = await provider.fetchInfo(url);
      if (!mounted) return;

      final settings = controller.settings;
      final preferred = info.audioFormats.isNotEmpty ? preferredAudioLanguage(info, settings.preferredLanguage) : null;

      setState(() {
        _info = info;
        _audioLanguage = preferred;
        _audioBitrate = null;
        _autoBestAudio = settings.autoSelectBestAudio;
        _videoQuality = settings.defaultVideoQuality;
        _containerPreference = settings.containerPreference;
      });

      if (settings.autoStartDownload) {
        await _startDownload();
      }
    } on DownloaderException catch (e) {
      if (!mounted) return;
      setState(() {
        _info = null;
      });
      await showErrorDialog(context, message: e.message, details: e.details);
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(
        context,
        message: 'An unexpected error occurred while fetching media info.',
        details: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _fetching = false);
      }
    }
  }

  String? preferredAudioLanguage(MediaInfo info, String preferred) {
    if (info.hasAudioForLanguage(preferred)) return preferred;
    final languages = info.audioLanguages;
    return languages.isEmpty ? null : languages.first;
  }

  Future<void> _startDownload() async {
    final controller = context.read<AppController>();
    final info = _info;
    if (info == null) return;

    final video = _selector.selectBestVideo(info.videoFormats, quality: _videoQuality);
    if (video == null) {
      await showErrorDialog(
        context,
        message: 'No video format is available for this media.',
      );
      return;
    }

    final hasSeparateAudio = info.audioFormats.isNotEmpty;
    AudioFormat? audio;
    String? audioLabel;
    String? audioLanguageCode;

    if (hasSeparateAudio) {
      final language = _audioLanguage ?? info.audioLanguages.first;
      if (_autoBestAudio) {
        audio = _selector.selectBestAudio(
          info.audioFormats,
          preferredLanguage: language,
          fallbackLanguage: _fallbackOrNull(controller.settings.fallbackLanguage),
        );
      } else {
        audio = _pickBitrate(info, language, _audioBitrate);
      }

      if (audio == null) {
        final available = info.audioLanguages
            .map(LanguageNames.nameFor)
            .join(', ');
        await showErrorDialog(
          context,
          message: 'No ${LanguageNames.nameFor(language)} audio track is '
              'available for this video.',
          details: available.isEmpty
              ? null
              : 'Available audio languages: $available',
        );
        return;
      }

      audioLabel = '${LanguageNames.nameFor(audio.language)}'
          '${audio.bitrate != null ? ' ${audio.bitrate} kbps' : ''}'
          .trim();
      audioLanguageCode = language;
    } else {
      audioLabel = 'Embedded audio';
    }

    var directory = _outputDirectory.trim();
    if (directory.isEmpty) {
      directory = controller.resolveOutputDirectory();
    }
    try {
      _repository.ensureDirectory(directory);
    } on DownloaderException catch (e) {
      await showErrorDialog(context, message: e.message, details: e.details);
      return;
    }

    final taskId =
        'task_${DateTime.now().millisecondsSinceEpoch}_${info.id.hashCode.abs()}';
    final options = DownloadOptions(
      taskId: taskId,
      outputDirectory: directory,
      title: info.title,
      videoFormatId: video.formatId,
      audioFormatId: audio?.formatId,
      audioLanguage: audioLanguageCode,
      overwrite: false,
      containerPreference: _containerPreference,
    );

    controller.log.info('Starting download with '
        'video=${video.formatId} audio=${audio?.formatId ?? 'embedded'}');
    controller.manager.add(
      provider: _provider!,
      media: info,
      options: options,
      videoLabel: _videoLabel(video),
      audioLabel: audioLabel,
    );
    controller.rememberDirectory(directory);

    if (mounted) {
      Navigator.of(context).pushNamed(AppRoutes.downloads);
    }
  }

  String? _fallbackOrNull(String fallback) =>
      fallback.trim().isEmpty ? null : fallback.trim();

  AudioFormat? _pickBitrate(MediaInfo info, String language, int? bitrate) {
    final matches = _selector.audioForLanguage(info.audioFormats, language);
    if (bitrate != null) {
      for (final f in matches) {
        if (f.bitrate != null && (f.bitrate! - bitrate).abs() <= 1) {
          return f;
        }
      }
    }
    return matches.isEmpty ? null : _selector.selectBestAudio(
      matches,
      preferredLanguage: language,
    );
  }

  String _videoLabel(VideoFormat video) {
    final label = video.resolutionLabel;
    return label == 'unknown' ? 'Best' : label;
  }

  Future<void> _handlePrimaryShortcut() async {
    if (_info == null) {
      await _fetchInfo();
    } else {
      await _startDownload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final activeTasks = controller.manager.tasks
        .where((t) => t.state.isActive)
        .toList();

    return AppScaffold(
      selectedIndex: 0,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(
            LogicalKeyboardKey.enter,
            control: true,
          ): () => _handlePrimaryShortcut(),
        },
        child: Focus(
          autofocus: true,
          child: DragTarget<String>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) {
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
                            child: const Center(
                              child: Text('Drop URL to download'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        UrlInputCard(
                          controller: _urlController,
                          focusNode: _urlFocusNode,
                          fetching: _fetching,
                          onFetch: _fetchInfo,
                          provider: _provider,
                          errorMessage: _errorMessage,
                        ),
                        if (_info != null) ...[
                          const SizedBox(height: 12),
                          MediaInfoCard(info: _info!),
                          const SizedBox(height: 12),
                          FormatSelectionCard(
                            info: _info!,
                            videoQuality: _videoQuality,
                            onVideoQualityChanged: (v) =>
                                setState(() => _videoQuality = v),
                            audioLanguage: _audioLanguage,
                            onAudioLanguageChanged: (v) => setState(() {
                              _audioLanguage = v;
                              _audioBitrate = null;
                            }),
                            autoBestAudio: _autoBestAudio,
                            onAutoBestAudioChanged: (v) =>
                                setState(() => _autoBestAudio = v),
                            audioBitrate: _audioBitrate,
                            onAudioBitrateChanged: (v) =>
                                setState(() => _audioBitrate = v),
                            preferredLanguage:
                                controller.settings.preferredLanguage,
                            containerPreference: _containerPreference,
                            onContainerPreferenceChanged: (v) =>
                                setState(() => _containerPreference = v),
                          ),
                          const SizedBox(height: 12),
                          OutputFolderRow(
                            directory: _outputDirectory,
                            onChanged: (d) =>
                                setState(() => _outputDirectory = d),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _startDownload,
                              icon: const Icon(Icons.download),
                              label: const Text('Download'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(220, 52),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (activeTasks.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Active downloads',
                            style:
                                Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          for (final task in activeTasks) ...[
                            DownloadTile(task: task),
                            const SizedBox(height: 8),
                          ],
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Tip: press Ctrl+Enter to fetch or download. '
                          'Drag & drop a URL anywhere on this page.',
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
