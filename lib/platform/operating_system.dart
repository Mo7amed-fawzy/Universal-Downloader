import 'dart:io';

import 'package:flutter/foundation.dart';

enum OperatingSystem {
  linux,
  android,
  windows,
  macos,
  ios,
  web,
  unsupported;

  static OperatingSystem detect() {
    if (kIsWeb) return web;
    return fromPlatformName(Platform.operatingSystem);
  }

  static OperatingSystem fromPlatformName(String name) {
    return switch (name) {
      'linux' => linux,
      'android' => android,
      'windows' => windows,
      'macos' => macos,
      'ios' => ios,
      _ => unsupported,
    };
  }
}
