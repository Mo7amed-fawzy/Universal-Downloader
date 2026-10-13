import 'package:flutter/material.dart';

import 'app_navigation_icon.dart';

class AppBottomNavigation extends StatefulWidget {
  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<AppBottomNavigation> createState() => _AppBottomNavigationState();
}

class _AppBottomNavigationState extends State<AppBottomNavigation>
    with SingleTickerProviderStateMixin {
  static const _expandDuration = Duration(milliseconds: 220);
  static const _collapseDuration = Duration(milliseconds: 320);

  late final AnimationController _indicator;
  late int _indicatorIndex;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _indicatorIndex = widget.selectedIndex;
    _indicator = AnimationController(vsync: this, value: 1)
      ..addStatusListener(_onIndicatorStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _settleIndicator();
  }

  @override
  void didUpdateWidget(covariant AppBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex == widget.selectedIndex) return;
    if (_reduceMotion) {
      _settleIndicator();
    } else if (_indicatorIndex == widget.selectedIndex) {
      _expandIndicator();
    } else {
      _indicator.animateBack(
        0,
        duration: _collapseDuration,
        curve: Curves.easeInOutSine,
      );
    }
  }

  void _settleIndicator() {
    _indicatorIndex = widget.selectedIndex;
    _indicator.value = 1;
  }

  void _onIndicatorStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed) return;
    setState(() => _indicatorIndex = widget.selectedIndex);
    _expandIndicator();
  }

  void _expandIndicator() {
    _indicator.animateTo(
      1,
      duration: _expandDuration,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _indicator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _indicator,
      builder: (context, child) {
        final scale = _indicator.value;
        return NavigationBar(
          selectedIndex: widget.selectedIndex,
          onDestinationSelected: widget.onSelected,
          indicatorColor: Colors.transparent,
          animationDuration: _reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 200),
          destinations: [
            NavigationDestination(
              icon: AppNavigationIcon(
                icon: Icons.home_outlined,
                indicatorScale: _indicatorIndex == 0 ? scale : 0,
              ),
              label: 'Home',
            ),
            NavigationDestination(
              icon: AppNavigationIcon(
                icon: Icons.download_outlined,
                indicatorScale: _indicatorIndex == 1 ? scale : 0,
              ),
              label: 'Downloads',
            ),
            NavigationDestination(
              icon: AppNavigationIcon(
                icon: Icons.settings_outlined,
                indicatorScale: _indicatorIndex == 2 ? scale : 0,
              ),
              label: 'Settings',
            ),
          ],
        );
      },
    ),
  );
}
