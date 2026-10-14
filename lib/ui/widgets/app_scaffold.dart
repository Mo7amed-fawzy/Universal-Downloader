import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import 'app_tab_scope.dart';
import 'app_bottom_navigation.dart';
import 'app_brand.dart';

/// Shared desktop scaffold: top bar + navigation rail + body.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.selectedIndex,
    required this.body,
    this.bottomBar,
    this.isTabShell = false,
  });

  final int selectedIndex;
  final Widget body;
  final Widget? bottomBar;
  final bool isTabShell;

  @override
  Widget build(BuildContext context) {
    if (!isTabShell &&
        context.getInheritedWidgetOfExactType<AppTabScope>() != null) {
      return body;
    }
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const AppBrand(),
        actions: [
          _ThemeToggle(),
          _SettingsButton(selected: selectedIndex == 2),
        ],
      ),
      body: Row(
        children: [
          if (!compact)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 0, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: NavigationRail(
                  selectedIndex: selectedIndex,
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.download_outlined),
                      selectedIcon: Icon(Icons.download),
                      label: Text('Downloads'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Settings'),
                    ),
                  ],
                  onDestinationSelected: (index) => _navigate(context, index),
                ),
              ),
            ),
          Expanded(
            child: SafeArea(
              top: compact,
              bottom: compact,
              left: compact,
              right: compact,
              child: body,
            ),
          ),
        ],
      ),
      bottomNavigationBar: compact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ?bottomBar,
                AppBottomNavigation(
                  selectedIndex: selectedIndex,
                  onSelected: (index) => _navigate(context, index),
                ),
              ],
            )
          : bottomBar,
    );
  }

  static void _navigate(BuildContext context, int index) {
    AppTabScope.of(context).onSelected(index);
  }
}

class _ThemeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final isDark =
        controller.themeMode == ThemeMode.dark ||
        (controller.themeMode == ThemeMode.system &&
            Theme.of(context).brightness == Brightness.dark);
    return IconButton(
      tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () {
        controller.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
      },
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Settings',
      icon: const Icon(Icons.settings_outlined),
      onPressed: selected ? null : () => AppTabScope.of(context).onSelected(2),
    );
  }
}
