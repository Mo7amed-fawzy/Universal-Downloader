import 'package:flutter/material.dart';

class DownloadResumeButton extends StatelessWidget {
  const DownloadResumeButton({super.key, required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Resume',
    icon: const Icon(Icons.play_arrow_rounded),
    onPressed: onResume,
  );
}
