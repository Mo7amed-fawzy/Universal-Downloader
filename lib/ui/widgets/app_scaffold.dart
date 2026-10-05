import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import 'app_bottom_navigation.dart';

/// Shared desktop scaffold: top bar + navigation rail + body.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.selectedIndex,
    required this.body,
    this.bottomBar,
  });

  final int selectedIndex;
  final Widget body;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Universal Downloader',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [_ThemeToggle(), _SettingsButton()],
      ),
      body: compact
          ? SafeArea(child: body)
          : Row(
              children: [
                NavigationRail(
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
                const VerticalDivider(width: 1),
                Expanded(child: body),
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
    final route = switch (index) {
      0 => AppRoutes.home,
      1 => AppRoutes.downloads,
      _ => AppRoutes.settings,
    };
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return;
    if (index == 0) {
      Navigator.of(context).popUntil((r) => r.settings.name == AppRoutes.home);
    } else {
      Navigator.of(context).pushNamed(route);
    }
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
  @override
  Widget build(BuildContext context) {
    final current = ModalRoute.of(context)?.settings.name;
    return IconButton(
      tooltip: 'Settings',
      icon: const Icon(Icons.settings_outlined),
      onPressed: current == AppRoutes.settings
          ? null
          : () => Navigator.of(context).pushNamed(AppRoutes.settings),
    );
  }
}
