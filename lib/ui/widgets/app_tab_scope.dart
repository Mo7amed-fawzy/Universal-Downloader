import 'package:flutter/widgets.dart';

class AppTabScope extends InheritedWidget {
  const AppTabScope({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required super.child,
  });

  final int selectedIndex;
  final void Function(int index, {String? taskId}) onSelected;

  static AppTabScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppTabScope>()!;

  @override
  bool updateShouldNotify(AppTabScope oldWidget) =>
      selectedIndex != oldWidget.selectedIndex;
}
