import 'package:flutter/material.dart';

import '../../providers/youtube/youtube_playlist.dart';

class PlaylistUrlDialog extends StatefulWidget {
  const PlaylistUrlDialog({super.key, this.initialUrl = ''});

  final String initialUrl;

  @override
  State<PlaylistUrlDialog> createState() => _PlaylistUrlDialogState();
}

class _PlaylistUrlDialogState extends State<PlaylistUrlDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _url = widget.initialUrl;

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(
        context,
      ).pop(YoutubePlaylist.normalizeUrl(Uri.parse(_url.trim())));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add YouTube playlist'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add the whole playlist as its own group. Review each video’s quality, audio and subtitles before downloading.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                autofocus: true,
                initialValue: _url,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'YouTube playlist link',
                  hintText: 'https://youtube.com/playlist?list=…',
                  prefixIcon: Icon(Icons.playlist_play),
                  errorMaxLines: 3,
                ),
                onChanged: (value) => _url = value,
                onFieldSubmitted: (_) => _submit(),
                validator: (value) {
                  final url = Uri.tryParse(value?.trim() ?? '');
                  return url != null &&
                          YoutubePlaylist.normalizeUrl(url) != null
                      ? null
                      : 'Enter a YouTube playlist link containing list=.';
                },
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.playlist_add),
        label: const Text('Add playlist'),
      ),
    ],
  );
}
