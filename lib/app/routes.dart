import 'package:flutter/material.dart';

import '../ui/pages/downloads_page.dart';
import '../ui/pages/downloads_navigation.dart';
import '../ui/pages/app_tabs.dart';
import '../ui/pages/settings_page.dart';

/// Named routes for the application.
abstract final class AppRoutes {
  static const String home = '/';
  static const String downloads = '/downloads';
  static const String settings = '/settings';
}

Route<dynamic>? generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.home:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const AppTabs(),
      );
    case AppRoutes.downloads:
      final target = settings.arguments;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => DownloadsPage(
          initialTaskId: target is DownloadsNavigation ? target.taskId : null,
        ),
      );
    case AppRoutes.settings:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const SettingsPage(),
      );
    default:
      return null;
  }
}
