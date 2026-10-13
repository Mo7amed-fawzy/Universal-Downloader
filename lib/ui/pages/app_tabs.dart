import 'package:flutter/material.dart';

import '../widgets/app_tab_panel.dart';
import '../widgets/app_tab_scope.dart';
import '../widgets/app_scaffold.dart';
import 'downloads_page.dart';
import 'home_page.dart';
import 'settings_page.dart';

class AppTabs extends StatefulWidget {
  const AppTabs({super.key});

  @override
  State<AppTabs> createState() => _AppTabsState();
}

class _AppTabsState extends State<AppTabs> {
  int _selectedIndex = 0;
  final _visited = <int>{0};
  String? _targetTaskId;
  int _revealRequest = 0;

  void _select(int index, {String? taskId}) {
    if (_selectedIndex == index && taskId == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedIndex = index;
      _visited.add(index);
      if (index == 1 && taskId != null) {
        _targetTaskId = taskId;
        _revealRequest++;
      }
    });
  }

  @override
  Widget build(BuildContext context) => AppTabScope(
    selectedIndex: _selectedIndex,
    onSelected: _select,
    child: AppScaffold(
      isTabShell: true,
      selectedIndex: _selectedIndex,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          AppTabPanel(active: _selectedIndex == 0, child: const HomePage()),
          AppTabPanel(
            active: _selectedIndex == 1,
            child: _visited.contains(1)
                ? DownloadsPage(
                    initialTaskId: _targetTaskId,
                    revealRequest: _revealRequest,
                  )
                : const SizedBox.shrink(),
          ),
          AppTabPanel(
            active: _selectedIndex == 2,
            child: _visited.contains(2)
                ? const SettingsPage()
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}
