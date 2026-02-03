import 'package:flutter/material.dart';
import 'feed_screen.dart';
import 'profile_screens.dart'; // (Assume your profile/wallet/inbox code is in here)
import 'messaging_screens.dart'; // (Assume your inbox code is here)

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  
  final List<Widget> _pages = [
    const FeedScreen(), // Uses the new FeedScreen
    const Scaffold(body: Center(child: Text("Wallet (Copy your WalletScreen here)"))),
    const InboxScreen(), // Uses your Inbox logic
    const ProfileScreen(), // Uses your Profile logic
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.mail), label: 'Inbox'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}