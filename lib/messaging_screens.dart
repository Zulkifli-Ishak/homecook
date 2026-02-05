import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; 
import 'profile_screens.dart';
import 'expanded_post_screen.dart'; // <--- IMPORT THIS for navigation

// ----------------------------------------------------------------------
// 1. MAIN INBOX SCREEN
// ----------------------------------------------------------------------
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return const Scaffold(body: Center(child: Text("Please log in.")));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Inbox"),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: Colors.green,
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            tabs: [
              // MESSAGE BADGE
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: myUid).snapshots(),
                builder: (context, snapshot) {
                  int count = 0;
                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      count += (doc.data() as Map<String, dynamic>)['unread_$myUid'] as int? ?? 0;
                    }
                  }
                  return Tab(child: _tabWithBadge("Messages", count));
                },
              ),
              // NOTIFICATION BADGE
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(myUid).collection('notifications').where('isRead', isEqualTo: false).snapshots(),
                builder: (context, snapshot) {
                  int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Tab(child: _tabWithBadge("Notifications", count));
                },
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ChatListTab(myUid: myUid),
            _NotificationListTab(myUid: myUid),
          ],
        ),
      ),
    );
  }

  Widget _tabWithBadge(String text, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text),
        if (count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: Text(count > 99 ? "99+" : count.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]
      ],
    );
  }
}

// ----------------------------------------------------------------------
// 2. CHAT LIST TAB
// ----------------------------------------------------------------------
class _ChatListTab extends StatelessWidget {
  final String myUid;
  const _ChatListTab({required this.myUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: myUid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No messages yet."));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var chatDoc = snapshot.data!.docs[index];
            var chatData = chatDoc.data() as Map<String, dynamic>;
            
            List participants = chatData['participants'] ?? [];
            String otherId = participants.firstWhere((id) => id != myUid, orElse: () => "");
            
            if (otherId.isEmpty) {
               return const ListTile(title: Text("Deleted User"), subtitle: Text("Chat unavailable"));
            }

            int unreadCount = chatData['unread_$myUid'] ?? 0;

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(otherId).snapshots(),
              builder: (context, userSnap) {
                String displayName = "Loading...";
                String profilePic = "";
                
                if (userSnap.hasData && userSnap.data != null && userSnap.data!.exists) {
                  var userData = userSnap.data!.data() as Map<String, dynamic>;
                  displayName = userData['username'] ?? "Unknown";
                  profilePic = userData['profilePic'] ?? "";
                } else if (userSnap.connectionState == ConnectionState.active) {
                   displayName = "User not found";
                }

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: GestureDetector(
                    onTap: () {
                        if (otherId.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfilePage(userId: otherId)));
                    },
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: (profilePic.isNotEmpty) ? NetworkImage(profilePic) : null,
                      child: (profilePic.isEmpty) ? const Icon(Icons.person, color: Colors.grey) : null,
                    ),
                  ),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatRoomScreen(receiverId: otherId, receiverName: displayName)));
                  },
                  title: Text(displayName, style: TextStyle(fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.bold, fontSize: 16)),
                  subtitle: Text(
                    chatData['lastMessage'] ?? "Photo", 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: unreadCount > 0 ? Colors.black87 : Colors.grey, fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal),
                  ),
                  trailing: unreadCount > 0 
                    ? Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    : null,
                );
              }
            );
          },
        );
      },
    );
  }
}

// ----------------------------------------------------------------------
// 3. NOTIFICATION TAB (Updated for Follows)
// ----------------------------------------------------------------------
class _NotificationListTab extends StatelessWidget {
  final String myUid;
  const _NotificationListTab({required this.myUid});

  Future<void> _markAllRead() async {
    var collection = FirebaseFirestore.instance.collection('users').doc(myUid).collection('notifications');
    var snapshot = await collection.where('isRead', isEqualTo: false).get();
    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // --- HANDLES CLICKS ---
  void _handleNotificationTap(BuildContext context, Map<String, dynamic> data, DocumentReference ref) async {
    ref.update({'isRead': true});

    // CASE A: FOLLOW NOTIFICATION -> Go to User Profile
    if (data['type'] == 'follow') {
       String fromId = data['fromId'] ?? "";
       if (fromId.isNotEmpty) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfilePage(userId: fromId)));
       }
       return;
    }

    // CASE B: POST NOTIFICATION -> Go to Post
    String postId = data['postId'] ?? "";
    if (postId.isNotEmpty) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      try {
        DocumentSnapshot postDoc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
        if (context.mounted) Navigator.pop(context); 

        if (postDoc.exists) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ExpandedPostScreen(
            data: postDoc.data() as Map<String, dynamic>, 
            postId: postId
          )));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("This post has been deleted.")));
        }
      } catch (e) {
        if (context.mounted) Navigator.pop(context);
        debugPrint("Error fetching post: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all, size: 16),
              label: const Text("Mark all read"),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(myUid).collection('notifications').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No notifications"));

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  bool isRead = data['isRead'] ?? true;
                  String fromId = data['fromId'] ?? "";

                  return Container(
                    color: isRead ? Colors.transparent : Colors.green.withOpacity(0.1),
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(fromId).snapshots(),
                      builder: (context, userSnap) {
                        String name = "Someone";
                        String pic = "";
                        
                        if (userSnap.hasData && userSnap.data!.exists) {
                          var userData = userSnap.data!.data() as Map<String, dynamic>;
                          name = userData['username'] ?? "Someone";
                          pic = userData['profilePic'] ?? "";
                        }

                        return ListTile(
                          leading: GestureDetector(
                            onTap: () {
                               if (fromId.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfilePage(userId: fromId)));
                            },
                            child: CircleAvatar(
                              backgroundImage: (pic.isNotEmpty) ? NetworkImage(pic) : null,
                              child: (pic.isEmpty) ? const Icon(Icons.person) : null,
                            ),
                          ),
                          title: RichText(
                            text: TextSpan(style: const TextStyle(color: Colors.black), children: [
                              TextSpan(text: "$name ", style: const TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: _getNotificationText(data['type'])),
                            ]),
                          ),
                          subtitle: Text(data['body'] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                          onTap: () => _handleNotificationTap(context, data, doc.reference),
                        );
                      }
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _getNotificationText(String type) {
    switch (type) {
      case 'like': return "liked your post.";
      case 'comment': return "commented on your post.";
      case 'reply': return "replied to your comment.";
      case 'repost': return "reposted your recipe.";
      case 'follow': return "started following you."; // <--- ADDED THIS
      default: return "interacted with you.";
    }
  }
}

// ----------------------------------------------------------------------
// 4. CHAT ROOM SCREEN 
// ----------------------------------------------------------------------
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

  @override
  void initState() {
    super.initState();
    _resetUnreadCount();
  }

  void _resetUnreadCount() async {
    final chatQuery = await FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: myUid).get();
    for (var doc in chatQuery.docs) {
      if ((doc['participants'] as List).contains(widget.receiverId)) {
        doc.reference.update({'unread_$myUid': 0});
      }
    }
  }

  void _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    String msg = _msgController.text.trim();
    _msgController.clear();
    
    final myUser = FirebaseAuth.instance.currentUser!;
    
    final chatQuery = await FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: myUid).get();
    DocumentReference? chatRef;
    
    for (var doc in chatQuery.docs) {
      if ((doc['participants'] as List).contains(widget.receiverId)) {
        chatRef = doc.reference;
        break;
      }
    }

    if (chatRef == null) {
      chatRef = FirebaseFirestore.instance.collection('chats').doc();
      await chatRef.set({
        'participants': [myUid, widget.receiverId],
        'names': {myUid: myUser.displayName, widget.receiverId: widget.receiverName}, 
        'unread_$myUid': 0,
        'unread_${widget.receiverId}': 0,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }

    await chatRef.collection('messages').add({
      'text': msg,
      'senderId': myUid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await chatRef.update({
      'lastMessage': msg,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unread_${widget.receiverId}': FieldValue.increment(1),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.receiverName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: myUid).snapshots(),
              builder: (context, snapshot) {
                 if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                 
                 DocumentSnapshot? chatDoc;
                 try {
                   chatDoc = snapshot.data!.docs.firstWhere((d) => (d['participants'] as List).contains(widget.receiverId));
                 } catch (e) {
                   return const Center(child: Text("Say hi!")); 
                 }

                 return StreamBuilder<QuerySnapshot>(
                   stream: chatDoc.reference.collection('messages').orderBy('timestamp', descending: true).snapshots(),
                   builder: (context, msgSnap) {
                     if (!msgSnap.hasData) return const Center(child: CircularProgressIndicator());
                     
                     return ListView.builder(
                       reverse: true,
                       padding: const EdgeInsets.all(10), 
                       itemCount: msgSnap.data!.docs.length,
                       itemBuilder: (context, index) {
                         var msg = msgSnap.data!.docs[index];
                         bool isMe = msg['senderId'] == myUid;
                         return Align(
                           alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                           child: Container(
                             margin: const EdgeInsets.symmetric(vertical: 4),
                             padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                             constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), 
                             decoration: BoxDecoration(
                               color: isMe ? Colors.green : Colors.grey[200],
                               borderRadius: BorderRadius.only(
                                 topLeft: const Radius.circular(15),
                                 topRight: const Radius.circular(15),
                                 bottomLeft: isMe ? const Radius.circular(15) : Radius.zero,
                                 bottomRight: isMe ? Radius.zero : const Radius.circular(15),
                               ),
                             ),
                             child: Text(msg['text'], style: TextStyle(color: isMe ? Colors.white : Colors.black)),
                           ),
                         );
                       },
                     );
                   }
                 );
              },
            ),
          ),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
            ),
            child: SafeArea( 
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end, 
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        minLines: 1,
                        maxLines: 5, 
                        decoration: InputDecoration(
                          hintText: "Type a message...",
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      margin: const EdgeInsets.only(bottom: 4), 
                      child: CircleAvatar(
                        backgroundColor: Colors.green,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 20),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}