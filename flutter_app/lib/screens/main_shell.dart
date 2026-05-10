import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'reservation_screen.dart';
import 'chats_overview_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';

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
    NotificationScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        stream: user == null
            ? const Stream.empty()
            : FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: user.uid)
                .where('read', isEqualTo: false)
                .snapshots(),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data?.docs.length ?? 0;

          return BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.black54,
            items: [
              const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              const BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Reservaties'),
              const BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
              const BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Kaart'),
              BottomNavigationBarItem(
                label: 'Notificaties',
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined),
                    if (unreadCount > 0)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profiel'),
            ],
          );
        },
      ),
    );
  }
}