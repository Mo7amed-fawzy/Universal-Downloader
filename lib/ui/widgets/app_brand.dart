import 'package:flutter/material.dart';

import 'app_wordmark.dart';

class AppBrand extends StatelessWidget {
  const AppBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/branding/catchit-icon.png',
          width: 44,
          height: 44,
          excludeFromSemantics: true,
          filterQuality: FilterQuality.high,
        ),
        const SizedBox(width: 8),
        const Flexible(child: AppWordmark()),
      ],
    );
  }
}
