import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'feed_screen.dart';
import 'profile_screens.dart'; 
import 'messaging_screens.dart'; 
import 'setting_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  
  final List<Widget> _pages = [
    const FeedScreen(),
    const Scaffold(body: Center(child: Text("Wallet"))), 
    const InboxScreen(),
    const ProfileScreen(),
    const SettingsScreen(), 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed, 
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey, 
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          
          // --- UPDATED INBOX ICON WITH BADGE ---
          BottomNavigationBarItem(
            icon: InboxIconWithBadge(), // <--- Custom Widget used here
            label: 'Inbox'
          ),
          
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// HELPER WIDGET: CALCULATES TOTAL UNREAD (CHATS + NOTIFICATIONS)
// ----------------------------------------------------------------------
class InboxIconWithBadge extends StatelessWidget {
  const InboxIconWithBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return const Icon(Icons.mail);

    // 1. Listen to Chats (to count unread messages)
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: myUid)
          .snapshots(),
      builder: (context, chatSnapshot) {
        
        int chatUnreadCount = 0;
        if (chatSnapshot.hasData) {
          for (var doc in chatSnapshot.data!.docs) {
            // Sum up the 'unread_MYUID' field from all chat docs
            int count = (doc.data() as Map<String, dynamic>)['unread_$myUid'] ?? 0;
            chatUnreadCount += count;
          }
        }

        // 2. Listen to Notifications (to count unread alerts)
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(myUid)
              .collection('notifications')
              .where('isRead', isEqualTo: false)
              .snapshots(),
          builder: (context, notifSnapshot) {
            
            int notifUnreadCount = 0;
            if (notifSnapshot.hasData) {
              notifUnreadCount = notifSnapshot.data!.docs.length;
            }

            // 3. Combine Totals
            int totalUnread = chatUnreadCount + notifUnreadCount;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.mail),
                if (totalUnread > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        totalUnread > 99 ? "99+" : totalUnread.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}