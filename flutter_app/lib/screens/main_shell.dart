import 'package:flutter/material.dart';
  import 'home_screen.dart';
  import 'reservation_screen.dart';
  import 'chats_overview_screen.dart';
  import 'map_screen.dart';
  import 'profile_screen.dart';
  
  class MainShell extends StatefulWidget {
    const MainShell({super.key});
  
    @override
    State<MainShell> createState() => _MainShellState();
  }
  
  class _MainShellState extends State<MainShell> {
    int _currentIndex = 0;
  
    final List<Widget> _screens = const [
      HomeScreen(),
      ReservationScreen(),
      ChatsOverviewScreen(),
      MapScreen(),
      ProfileScreen(),
    ];
  
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'Reservaties',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              label: 'Kaart',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profiel',
            ),
          ],
        ),
      );
    }
  }