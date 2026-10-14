import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import 'app_tab_scope.dart';
import 'downloaded_video_warning.dart';

class PreviousVideoDownloadWarning extends StatelessWidget {
  const PreviousVideoDownloadWarning({
    super.key,
    required this.url,
    this.padding = EdgeInsets.zero,
  });

  final Uri url;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final manager = context.read<AppController>().manager;
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final previous = manager.completedVideosForUrls([url]).firstOrNull;
        if (previous == null) return const SizedBox.shrink();
        return Padding(
          padding: padding,
          child: DownloadedVideoWarning(
            videoCount: 1,
            onViewDownloads: () =>
                AppTabScope.of(context).onSelected(1, taskId: previous.id),
          ),
        );
      },
    );
  }
}
