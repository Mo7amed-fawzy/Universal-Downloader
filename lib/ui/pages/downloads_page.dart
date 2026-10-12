import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/download_history_confirmation_dialog.dart';
import '../widgets/download_tile.dart';
import '../widgets/downloads_header.dart';

/// Full download queue with per-task state, progress and actions.
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

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
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: tasks.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return DownloadsHeader(
                        activeCount: controller.manager.activeCount,
                        canClear: tasks.any((task) => task.state.isTerminal),
                        onClear: () => _clearTerminal(context, controller),
                        historyError: controller.manager.historyError,
                      );
                    }
                    return Padding(
                      key: ValueKey(tasks[index - 1].id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DownloadTile(task: tasks[index - 1]),
                    );
                  },
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.download_for_offline_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text('No downloads yet', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Paste a URL on the Home page to get started.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
