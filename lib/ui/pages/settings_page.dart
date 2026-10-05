import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import '../../core/models/download_options.dart';
import '../../providers/format_selector.dart';
import '../../settings/app_settings.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/advanced_settings_section.dart';
import '../widgets/tool_diagnostics.dart';

/// Settings and dependency status.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppSettings _draft;
  late final TextEditingController _dirController;
  late final TextEditingController _preferredLangController;
  late final TextEditingController _fallbackLangController;
  late final TextEditingController _ytDlpPathController;
  late final TextEditingController _ffmpegPathController;
  late final TextEditingController _ffprobePathController;
  late final TextEditingController _extraArgsController;

  @override
  void initState() {
    super.initState();
    _draft = context.read<AppController>().settings;
    _dirController = TextEditingController(text: _draft.defaultDownloadDirectory);
    _preferredLangController = TextEditingController(text: _draft.preferredLanguage);
    _fallbackLangController = TextEditingController(text: _draft.fallbackLanguage);
    _ytDlpPathController = TextEditingController(text: _draft.ytDlpPath);
    _ffmpegPathController = TextEditingController(text: _draft.ffmpegPath);
    _ffprobePathController = TextEditingController(text: _draft.ffprobePath);
    _extraArgsController = TextEditingController(text: _draft.extraYtDlpArgs);
  }

  @override
  void dispose() {
    _dirController.dispose();
    _preferredLangController.dispose();
    _fallbackLangController.dispose();
    _ytDlpPathController.dispose();
    _ffmpegPathController.dispose();
    _ffprobePathController.dispose();
    _extraArgsController.dispose();
    super.dispose();
  }

  Future<void> _save(AppSettings next) async {
    setState(() => _draft = next);
    await context.read<AppController>().updateSettings(next);
  }

  Future<void> _saveTextFields() async {
    await _save(_draft.copyWith(
      defaultDownloadDirectory: _dirController.text.trim(),
      preferredLanguage: _preferredLangController.text.trim(),
      fallbackLanguage: _fallbackLangController.text.trim(),
      ytDlpPath: _ytDlpPathController.text.trim(),
      ffmpegPath: _ffmpegPathController.text.trim(),
      ffprobePath: _ffprobePathController.text.trim(),
      extraYtDlpArgs: _extraArgsController.text.trim(),
    ));
  }

  Future<void> _restoreIncludedTools() async {
    final controller = context.read<AppController>();
    await controller.updateTools(restoreIncluded: true);
    if (!mounted) return;
    setState(() {
      _draft = controller.settings;
      _ytDlpPathController.text = _draft.ytDlpPath;
      _ffmpegPathController.text = _draft.ffmpegPath;
      _ffprobePathController.text = _draft.ffprobePath;
    });
  }

  Future<void> _pickDefaultDir() async {
    final dir = await getDirectoryPath(
      initialDirectory: _dirController.text.trim().isEmpty
          ? null
          : _dirController.text.trim(),
    );
    if (dir == null || dir.isEmpty) return;
    _dirController.text = dir;
    await _save(_draft.copyWith(defaultDownloadDirectory: dir));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    return AppScaffold(
      selectedIndex: 2,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'General',
            children: [
              Row(
                children: [
                  Expanded(
                    child: _TextField(
                      controller: _dirController,
                      label: 'Default download directory',
                      hint: 'e.g. ~/Videos',
                      onSaved: _saveTextFields,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _pickDefaultDir,
                    child: const Text('Choose'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Remember last directory'),
                subtitle: const Text(
                  'Keep using the last folder you chose per session.',
                ),
                value: _draft.rememberLastDirectory,
                onChanged: (v) => _save(
                  _draft.copyWith(rememberLastDirectory: v),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Automatic downloads'),
                subtitle: const Text(
                  'Start downloading immediately after fetching media info.',
                ),
                value: _draft.autoStartDownload,
                onChanged: (v) =>
                    _save(_draft.copyWith(autoStartDownload: v)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Video',
            children: [
              DropdownButtonFormField<VideoQuality>(
                initialValue: _draft.defaultVideoQuality,
                decoration: const InputDecoration(
                  labelText: 'Default quality',
                ),
                items: VideoQuality.values
                    .map(
                      (q) => DropdownMenuItem(
                        value: q,
                        child: Text(
                          q == VideoQuality.best
                              ? 'Auto / Best Available'
                              : q.label,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    _save(_draft.copyWith(defaultVideoQuality: v));
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ContainerPreference>(
                initialValue: _draft.containerPreference,
                decoration: const InputDecoration(
                  labelText: 'Container preference',
                ),
                items: ContainerPreference.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.label),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    _save(_draft.copyWith(containerPreference: v));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Audio',
            children: [
              _TextField(
                controller: _preferredLangController,
                label: 'Preferred language code',
                hint: 'e.g. ar, en, fr',
                onSaved: _saveTextFields,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-select best audio in preferred language'),
                subtitle: const Text(
                  'Automatically pick the highest quality track, e.g. best '
                  'Arabic audio.',
                ),
                value: _draft.autoSelectBestAudio,
                onChanged: (v) =>
                    _save(_draft.copyWith(autoSelectBestAudio: v)),
              ),
              _TextField(
                controller: _fallbackLangController,
                label: 'Fallback language (empty = None)',
                hint: 'Leave empty to never fall back to another language',
                onSaved: _saveTextFields,
              ),
            ],
          ),
          const SizedBox(height: 16),
          AdvancedSettingsSection(
            children: [
              ToolDiagnostics(
                controller: controller,
                onRestoreIncluded: _restoreIncludedTools,
              ),
              const SizedBox(height: 12),
              _PathField(
                controller: _ytDlpPathController,
                label: 'yt-dlp executable path',
                onSaved: _saveTextFields,
              ),
              const SizedBox(height: 12),
              _PathField(
                controller: _ffmpegPathController,
                label: 'FFmpeg executable path',
                onSaved: _saveTextFields,
              ),
              const SizedBox(height: 12),
              _PathField(
                controller: _ffprobePathController,
                label: 'FFprobe executable path',
                onSaved: _saveTextFields,
              ),
              const SizedBox(height: 12),
              _TextField(
                controller: _extraArgsController,
                label: 'Additional yt-dlp arguments',
                hint: 'e.g. --proxy socks5://127.0.0.1:9050',
                onSaved: _saveTextFields,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Debug logging'),
                subtitle: const Text(
                  'Write verbose [DEBUG] lines to the log file.',
                ),
                value: _draft.debugLogging,
                onChanged: (v) => _save(_draft.copyWith(debugLogging: v)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Log file: '
            '${controller.pathUtils.logDirectory().path}/universal_downloader.log',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _TextField extends StatefulWidget {
  const _TextField({
    required this.controller,
    required this.label,
    required this.onSaved,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final Future<void> Function() onSaved;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
      ),
      onSubmitted: (_) => widget.onSaved(),
      onTapOutside: (_) => widget.onSaved(),
      textInputAction: TextInputAction.done,
    );
  }
}

class _PathField extends StatelessWidget {
  const _PathField({
    required this.controller,
    required this.label,
    required this.onSaved,
  });

  final TextEditingController controller;
  final String label;
  final Future<void> Function() onSaved;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TextField(
            controller: controller,
            label: label,
            hint: 'Leave empty to use included tools',
            onSaved: onSaved,
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () {
            controller.clear();
            onSaved();
          },
          child: const Text('Auto'),
        ),
      ],
    );
  }
}
