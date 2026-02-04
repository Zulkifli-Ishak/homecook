import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'helper_widgets.dart';
import 'expanded_post_screen.dart';
import 'profile_screens.dart'; 

class RecipeCardPost extends StatelessWidget {
  final Map<String, dynamic> data;
  final String postId;

  const RecipeCardPost({super.key, required this.data, required this.postId});

  // 1. DATE FORMAT: 10 January 2023 at 23:50
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "Just now";
    DateTime date = (timestamp as Timestamp).toDate();
    
    List<String> months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];

    return "${date.day} ${months[date.month - 1]} ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  // --- REPOST LOGIC ---
  Future<void> _handleRepost(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // RULE: Cannot repost your own post
    if (data['userId'] == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot repost your own content!"))
      );
      return;
    }
    
    try {
      // RULE: Cannot repost the same post twice
      final existing = await FirebaseFirestore.instance.collection('posts')
          .where('userId', isEqualTo: user.uid)
          .where('originalPostId', isEqualTo: postId)
          .limit(1).get();

      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You've already reposted this!"))
        );
        return;
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String myName = userDoc.data()?['username'] ?? "Chef";
      String myPic = userDoc.data()?['profilePic'] ?? "";

      // CREATE REPOST: Links back to Zul (Original Creator)
      await FirebaseFirestore.instance.collection('posts').add({
        ...data,
        'userId': user.uid,           // Zach's ID (the reposter)
        'username': data['username'], // Keep Zul's name in the header
        'userProfilePic': data['userProfilePic'], // Keep Zul's pic in the header
        'isRepost': true,
        'reposterName': myName,       // Zach's name for the label
        'originalAuthorId': data['userId'], // Zul's ID
        'originalPostId': postId,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [], 
        'reposts': 0, 
      });

      await FirebaseFirestore.instance.collection('posts').doc(postId).update({'reposts': FieldValue.increment(1)});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reposted to your profile!")));
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _toggleLike() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    
    // THE KEY CHANGE: 
    // If it's a repost, we target Zul's post ID (originalPostId)
    String targetPostId = data['isRepost'] == true ? data['originalPostId'] : postId;
    
    DocumentReference ref = FirebaseFirestore.instance.collection('posts').doc(targetPostId);
    
    // We need to fetch the latest likes from the ORIGINAL post, not the repost doc
    DocumentSnapshot originalDoc = await ref.get();
    List likes = (originalDoc.data() as Map<String, dynamic>?)?['likes'] ?? [];

    if (likes.contains(uid)) {
      await ref.update({'likes': FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({'likes': FieldValue.arrayUnion([uid])});
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Post?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
              Navigator.pop(context);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  final bool isQuickPost = data['postType'] == 'quick_post';
  final bool hasMedia = data['mediaUrl'] != null && data['mediaUrl'] != "";
  
  // If this is a repost, the "Target" for data (likes/comments) is the original post
  final String targetPostId = data['isRepost'] == true ? data['originalPostId'] : postId;
  final String originalOwnerId = data['originalAuthorId'] ?? data['userId'];

  return Card(
    margin: const EdgeInsets.only(bottom: 25, left: 10, right: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- STEP 2: The Repost Label ---
        if (data['isRepost'] == true)
          Padding(
            padding: const EdgeInsets.only(left: 15, top: 10),
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfilePage(userId: originalOwnerId))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.repeat, size: 14, color: Colors.grey),
                  const SizedBox(width: 5),
                  Text(
                    "${data['reposterName'] ?? 'Someone'} reposted",
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

        // --- STEP 3: Clean Header (Icon/Name go to Original Owner) ---
        ListTile(
          leading: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfilePage(userId: originalOwnerId))),
            child: CircleAvatar(
              backgroundColor: Colors.green[100],
              backgroundImage: (data['userProfilePic'] != null && data['userProfilePic'] != "") 
                  ? NetworkImage(data['userProfilePic']) : null,
              child: (data['userProfilePic'] == null || data['userProfilePic'] == "") 
                  ? const Icon(Icons.person, color: Colors.green) : null,
            ),
          ),
          title: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfilePage(userId: originalOwnerId))),
            child: Text(data['username'] ?? "Chef", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          subtitle: Text(_formatTimestamp(data['createdAt']), style: const TextStyle(fontSize: 11)),
          trailing: PopupMenuButton<String>(
            onSelected: (val) { if(val == 'delete') _showDeleteConfirmation(context); },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'share', child: Text("Share")),
              if (data['userId'] == FirebaseAuth.instance.currentUser?.uid)
                const PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: Colors.red))),
            ],
          ),
        ),

        // --- CONTENT AREA ---
        InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ExpandedPostScreen(data: data, postId: targetPostId))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasMedia) ...[
                if (data['mediaType'] == 'video')
                  const AspectRatio(aspectRatio: 16/9, child: Center(child: Icon(Icons.play_circle_fill, size: 50)))
                else
                  Image.network(data['mediaUrl'], height: 250, width: double.infinity, fit: BoxFit.cover),
              ],
              if (!isQuickPost)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  color: Colors.green[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("👥 ${data['triedCount'] ?? 0} tried", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      Text("✅ ${data['successRate'] ?? 0}% Success", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isQuickPost) 
                      Text(data['title'] ?? "Untitled", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    ExpandableCaption(text: data['caption'] ?? ""),
                  ],
                ),
              ),
            ],
          ),
        ),

        // --- ACTION BAR: SYNCED TO ORIGINAL POST ---
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('posts').doc(targetPostId).snapshots(),
          builder: (context, snapshot) {
            // Use live data from original post, fallback to local data if loading
            var liveData = snapshot.hasData ? (snapshot.data!.data() as Map<String, dynamic>?) : data;
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _buildActionButton(
                    icon: (liveData?['likes'] as List?)?.contains(FirebaseAuth.instance.currentUser?.uid) ?? false 
                        ? Icons.favorite : Icons.favorite_border,
                    label: "${(liveData?['likes'] as List?)?.length ?? 0}",
                    color: Colors.red,
                    onTap: _toggleLike,
                    isExpanded: isQuickPost,
                  ),
                  _buildActionButton(
                    icon: Icons.chat_bubble_outline,
                    label: "${liveData?['commentCount'] ?? 0}",
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (context) => ExpandedPostScreen(data: liveData ?? data, postId: targetPostId)
                    )),
                    isExpanded: isQuickPost,
                  ),
                  _buildActionButton(
                    icon: Icons.repeat,
                    label: "${liveData?['reposts'] ?? 0}",
                    onTap: () => _handleRepost(context),
                    isExpanded: isQuickPost,
                  ),
                  if (!isQuickPost) const Spacer(),
                  if (!isQuickPost)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.stars, color: Colors.orange, size: 18),
                        label: const Text("SUPPORT", style: TextStyle(color: Colors.orange, fontSize: 12)),
                        style: TextButton.styleFrom(backgroundColor: Colors.orange.withOpacity(0.1)),
                      ),
                    ),
                ],
              ),
            );
          }
        ),
      ],
    ),
  );
}

  Widget _buildActionButton({required IconData icon, required String label, Color? color, required VoidCallback onTap, required bool isExpanded}) {
    Widget content = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color ?? Colors.grey[700]),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
    return isExpanded ? Expanded(child: Center(child: content)) : content;
  }
}