import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_controller.dart';
import 'routes.dart';
import 'theme/app_theme.dart';

/// Root widget of Universal Downloader.
class UniversalDownloaderApp extends StatelessWidget {
  const UniversalDownloaderApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppController>.value(
      value: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return MaterialApp(
            title: 'Universal Downloader',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: controller.themeMode,
            initialRoute: AppRoutes.home,
            onGenerateRoute: generateRoute,
          );
        },
      ),
    );
  }
}
