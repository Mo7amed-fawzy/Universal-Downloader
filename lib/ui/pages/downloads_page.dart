import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/download_history_confirmation_dialog.dart';
import '../widgets/download_history_list.dart';
import '../widgets/downloads_header.dart';
import '../widgets/downloads_empty_state.dart';

/// Full download queue with per-task state, progress and actions.
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key, this.initialTaskId, this.revealRequest = 0});

  final String? initialTaskId;
  final int revealRequest;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    return ListenableBuilder(
      listenable: controller.manager,
      builder: (context, _) {
        final tasks = controller.manager.tasks;

        return AppScaffold(
          selectedIndex: 1,
          body: tasks.isEmpty
              ? const DownloadsEmptyState()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: DownloadsHeader(
                        activeCount: controller.manager.activeCount,
                        canClear: tasks.any((task) => task.state.isTerminal),
                        onClear: () => _clearTerminal(context, controller),
                        historyError: controller.manager.historyError,
                      ),
                    ),
                    Expanded(
                      child: DownloadHistoryList(
                        key: ValueKey(revealRequest),
                        tasks: tasks,
                        initialTaskId: initialTaskId,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _clearTerminal(
    BuildContext context,
    AppController controller,
  ) async {
    final terminal = controller.manager.tasks
        .where((t) => t.state.isTerminal)
        .map((t) => t.id)
        .toList();
    final confirmed = await DownloadHistoryConfirmationDialog.confirm(
      context,
      clearAll: true,
    );
    if (!context.mounted || !confirmed) return;
    for (final id in terminal) {
      await controller.manager.remove(id);
    }
  }
}
