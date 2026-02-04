import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- 1. THE INBOX LIST SCREEN ---
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    if (myUid == null) {
      return const Scaffold(body: Center(child: Text("Please log in to view messages.")));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Messages"), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        // Fetch chats where I am a participant
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: myUid)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // --- DEBUGGING HELPERS ---
          if (snapshot.hasError) {
            debugPrint("Firestore Error: ${snapshot.error}");
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Error: ${snapshot.error}\n\nHint: Check your debug console for the Index creation link.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No conversations yet.\nStart a chat from a chef's profile!"),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var chatDoc = snapshot.data!.docs[index];
              var chat = chatDoc.data() as Map<String, dynamic>;
              
              // Find the OTHER person's name/ID
              List participants = chat['participants'] ?? [];
              if (participants.length < 2) return const SizedBox();
              
              String otherId = participants.firstWhere((id) => id != myUid, orElse: () => "");

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: const Icon(Icons.person, color: Colors.green),
                ),
                title: Text(chat['participantNames']?[otherId] ?? "Chef"),
                subtitle: Text(
                  chat['lastMessage'] ?? "Click to chat",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  chat['lastMessageTime'] != null 
                    ? (chat['lastMessageTime'] as Timestamp).toDate().toString().substring(11, 16) 
                    : "",
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatRoomScreen(
                    receiverId: otherId, 
                    receiverName: chat['participantNames']?[otherId] ?? "Chef"
                  )
                )),
              );
            },
          );
        },
      ),
    );
  }
}

// --- 2. THE ACTUAL CHAT ROOM ---
class ChatRoomScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatRoomScreen({super.key, required this.receiverId, required this.receiverName});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _msgController = TextEditingController();
  final String myUid = FirebaseAuth.instance.currentUser!.uid;
  late String chatId;

  @override
  void initState() {
    super.initState();
    // Unique ID: Always same room for same two users
    List<String> ids = [myUid, widget.receiverId];
    ids.sort();
    chatId = ids.join("_");
  }

  void _sendMessage() async {
    String text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
    String myName = userDoc.data()?['username'] ?? "Chef";

    // 1. Add Message to Sub-collection
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': myUid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Update Chat Metadata (for the Inbox list)
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'participants': [myUid, widget.receiverId],
      'participantNames': {
        myUid: myName,
        widget.receiverId: widget.receiverName,
      },
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.receiverName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                return ListView.builder(
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var msg = snapshot.data!.docs[index];
                    bool isMe = msg['senderId'] == myUid;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.green : Colors.grey[300],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          msg['text'], 
                          style: TextStyle(color: isMe ? Colors.white : Colors.black)
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.green),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}