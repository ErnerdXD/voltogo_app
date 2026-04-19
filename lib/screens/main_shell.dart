import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:voltogo_app/widgets/settings_sheet.dart';

class MainShell extends StatelessWidget {
  const MainShell({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar removed for a fully immersive experience
      body: navigationShell,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            currentIndex: navigationShell.currentIndex,
            onTap: _onTap,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            showSelectedLabels: true,
            items: const [
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Icon(Icons.map_outlined),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Icon(Icons.map),
                ),
                label: 'Map',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Icon(Icons.history_outlined),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Icon(Icons.history),
                ),
                label: 'Activity',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Icon(Icons.dashboard_outlined),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Icon(Icons.dashboard),
                ),
                label: 'Stats',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Icon(Icons.person_outline),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Icon(Icons.person),
                ),
                label: 'Profile',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Icon(Icons.book_online_outlined),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Icon(Icons.book_online),
                ),
                label: 'Reservation',
              ),
            ],
          ),
        ),
      ),
    );
  }
}