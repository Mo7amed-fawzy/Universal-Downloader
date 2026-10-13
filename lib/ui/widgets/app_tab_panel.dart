import 'package:flutter/widgets.dart';

class AppTabPanel extends StatelessWidget {
  const AppTabPanel({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) => TickerMode(
    enabled: active,
    child: ExcludeFocus(excluding: !active, child: child),
  );
}
