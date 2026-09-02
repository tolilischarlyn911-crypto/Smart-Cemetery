import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'map_navigation_screen.dart';
import 'request_maintenance_screen.dart';
import 'profile_screen.dart';

class MainNavigationWrapper extends StatefulWidget {
  final UserModel user;
  final VoidCallback onLogout;

  const MainNavigationWrapper({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(
        user: widget.user,
        onNavigateTab: (index) => setState(() => _selectedIndex = index),
      ),
      const SearchScreen(),
      const MapNavigationScreen(),
      const RequestMaintenanceScreen(),
      ProfileScreen(user: widget.user, onLogout: widget.onLogout),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF1B4D2E),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(
              icon: Icon(Icons.assignment), label: 'Requests'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
