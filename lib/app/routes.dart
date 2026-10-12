import 'package:flutter/material.dart';

import '../ui/pages/downloads_page.dart';
import '../ui/pages/home_page.dart';
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
        builder: (_) => const HomePage(),
      );
    case AppRoutes.downloads:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const DownloadsPage(),
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
