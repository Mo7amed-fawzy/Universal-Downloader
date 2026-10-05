import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_controller.dart';
import 'ui/widgets/startup_status_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StartupStatusApp());
  try {
    final controller = await AppController.create();
    runApp(UniversalDownloaderApp(controller: controller));
  } catch (error) {
    runApp(StartupStatusApp(error: error, onRetry: main));
  }
}
