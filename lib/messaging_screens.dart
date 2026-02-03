import 'package:flutter/material.dart';

// ----------------------------------------------------------------------
// 1. INBOX SCREEN
// ----------------------------------------------------------------------
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inbox", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: ListView(
        children: [
          // Notification Center Entry
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.notifications, color: Colors.white)),
            title: const Text("Notification Center", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Likes and success alerts"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationCenterScreen())),
          ),
          const Divider(thickness: 1, height: 1),
          const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 8), child: Text("Messages", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          
          // Dummy Messages
          _msgTile(context, "Chef Ahmad", "Bro, that Sambal Udang looks fire!", "2m ago", true),
          _msgTile(context, "Siti_Cooks", "I just sent you 50 Stars!", "1h ago", false),
        ],
      ),
    );
  }

  Widget _msgTile(BuildContext context, String name, String msg, String time, bool unread) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.green[100], child: Text(name[0])),
      title: Text(name, style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(time, style: const TextStyle(fontSize: 12)),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(username: name))),
    );
  }
}

// ----------------------------------------------------------------------
// 2. CHAT SCREEN
// ----------------------------------------------------------------------
class ChatScreen extends StatefulWidget {
  final String username;
  const ChatScreen({super.key, required this.username});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {"text": "Bro, that Sambal Udang looks fire! What's the secret?", "isMe": false},
    {"text": "Thanks! The secret is the slow-toasted belacan.", "isMe": true},
  ];

  void _send() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        _messages.add({"text": _controller.text, "isMe": true});
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.username)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg['isMe'] ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: msg['isMe'] ? Colors.green : Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(msg['text'], style: TextStyle(color: msg['isMe'] ? Colors.white : Colors.black)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: "Message...", border: OutlineInputBorder()))),
                IconButton(icon: const Icon(Icons.send, color: Colors.green), onPressed: _send),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 3. NOTIFICATION CENTER
// ----------------------------------------------------------------------
class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Notifications"),
          bottom: const TabBar(labelColor: Colors.green, indicatorColor: Colors.green, tabs: [Tab(text: "Activity"), Tab(text: "Cook Success")]),
        ),
        body: TabBarView(
          children: [
            ListView(children: const [
              ListTile(leading: Icon(Icons.favorite, color: Colors.red), title: Text("Chef Ahmad liked your post"), subtitle: Text("2m ago")),
              ListTile(leading: Icon(Icons.star, color: Colors.orange), title: Text("Siti sent 50 stars"), subtitle: Text("1h ago")),
            ]),
            ListView(children: const [
              ListTile(leading: Icon(Icons.verified, color: Colors.green), title: Text("Mama_Gee cooked your recipe!"), subtitle: Text("80% Success Rate")),
            ]),
          ],
        ),
      ),
    );
  }
}