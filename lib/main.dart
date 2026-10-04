import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await AppController.create();
  runApp(UniversalDownloaderApp(controller: controller));
}
