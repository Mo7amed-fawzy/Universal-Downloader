import 'package:flutter/material.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
      NavigationDestination(
        icon: Icon(Icons.download_outlined),
        label: 'Downloads',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        label: 'Settings',
      ),
    ],
  );
}
