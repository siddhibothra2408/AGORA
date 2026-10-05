import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/agora_colors.dart';
import '../../core/theme/agora_spacing.dart';

/// Top-Level Application Shell for Spaces, Focus, and Me navigation
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onItemTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 768;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onItemTapped,
              minWidth: 72,
              minExtendedWidth: 200,
              backgroundColor: AgoraColors.surface,
              selectedIconTheme: const IconThemeData(
                color: AgoraColors.aegean,
                size: 24,
              ),
              unselectedIconTheme: const IconThemeData(
                color: AgoraColors.navySubtle,
                size: 24,
              ),
              selectedLabelTextStyle: const TextStyle(
                color: AgoraColors.aegean,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: AgoraColors.navyMuted,
                fontWeight: FontWeight.w400,
                fontSize: 13,
              ),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: AgoraSpacing.md),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AgoraColors.aegeanContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AgoraColors.aegean,
                    size: 22,
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.forum_outlined),
                  selectedIcon: Icon(Icons.forum),
                  label: Text('Spaces'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.center_focus_strong_outlined),
                  selectedIcon: Icon(Icons.center_focus_strong),
                  label: Text('Focus'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Me'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, color: AgoraColors.surfaceBorder),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AgoraColors.surfaceBorder, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: _onItemTapped,
          backgroundColor: AgoraColors.surface,
          selectedItemColor: AgoraColors.aegean,
          unselectedItemColor: AgoraColors.navySubtle,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.forum_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.forum),
              ),
              label: 'Spaces',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.center_focus_strong_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.center_focus_strong),
              ),
              label: 'Focus',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.person_outline),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.person),
              ),
              label: 'Me',
            ),
          ],
        ),
      ),
    );
  }
}
