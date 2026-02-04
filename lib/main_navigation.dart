import 'package:flutter/material.dart';
import 'feed_screen.dart';
import 'profile_screens.dart'; 
import 'messaging_screens.dart'; 
import 'setting_screen.dart'; // Uncomment this once you create the file!

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  
  final List<Widget> _pages = [
    const FeedScreen(),
    const Scaffold(body: Center(child: Text("Wallet"))), // Replace with your wallet later
    const InboxScreen(),
    const ProfileScreen(),
    const SettingsScreen(), // Now uses the real screen!
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed, // Essential for 5+ items
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey, // Helps keep it looking balanced
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.mail), label: 'Inbox'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'), // New addition
        ],
      ),
    );
  }
}