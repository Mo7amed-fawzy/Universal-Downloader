import 'package:flutter/material.dart';

import 'app/app_controller.dart';
import 'app/app_startup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AppStartup(initialize: AppController.create));
}
