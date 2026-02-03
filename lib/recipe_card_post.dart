import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'helper_widgets.dart';
import 'expanded_post_screen.dart'; // We will create this in File 6

class RecipeCardPost extends StatelessWidget {
  final Map<String, dynamic> data;
  final String postId;

  const RecipeCardPost({super.key, required this.data, required this.postId});

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "Just now";
    DateTime date = (timestamp as Timestamp).toDate();
    return "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  // --- THE REPOST FIX ---
  Future<void> _handleRepost(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String myName = userDoc.data()?['username'] ?? "Chef";

      // 1. DUPLICATE CHECK
      final existing = await FirebaseFirestore.instance.collection('posts')
          .where('userId', isEqualTo: user.uid)
          .where('originalPostId', isEqualTo: postId).limit(1).get();

      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Already shared!")));
        return;
      }

      // 2. EXPLICIT DATA COPYING (This fixes the Ghost Repost)
      await FirebaseFirestore.instance.collection('posts').add({
        'title': data['title'] ?? "Untitled", // <--- CRITICAL: Copy the title
        'caption': data['caption'] ?? "",
        'mediaUrl': data['mediaUrl'] ?? "",
        'mediaType': data['mediaType'] ?? "image",
        'ingredients': data['ingredients'] ?? [], // <--- Copy ingredients
        'instructions': data['instructions'] ?? [], // <--- Copy steps
        'postType': data['postType'] ?? "official_recipe",
        
        // Repost specific fields
        'userId': user.uid,
        'username': myName,
        'isRepost': true,
        'originalAuthor': data['username'] ?? "Chef",
        'originalPostId': postId,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'reposts': 0,
        'commentCount': 0,
        'triedCount': 0, // Reset stats for the new post
        'successRate': 0,
      });

      // 3. Increment original counter
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({'reposts': FieldValue.increment(1)});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Shared to your profile!")));
    } catch (e) {
      debugPrint("Repost failed: $e");
    }
  }

  Future<void> _toggleLike() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    DocumentReference ref = FirebaseFirestore.instance.collection('posts').doc(postId);
    List likes = data['likes'] ?? [];
    if (likes.contains(uid)) {
      await ref.update({'likes': FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({'likes': FieldValue.arrayUnion([uid])});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 25, left: 10, right: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.person, color: Colors.white)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['username'] ?? "Chef", style: const TextStyle(fontWeight: FontWeight.bold)),
                if (data['isRepost'] == true)
                  Text("Shared from ${data['originalAuthor']}", style: const TextStyle(fontSize: 11, color: Colors.green)),
              ],
            ),
            subtitle: Text(_formatTimestamp(data['createdAt'])),
          ),

          // 2. MEDIA (Video or Image)
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ExpandedPostScreen(data: data, postId: postId))),
            child: Column(
              children: [
                if (data['mediaType'] == 'video' && data['mediaUrl'] != null)
                   VideoPlayerWidget(videoUrl: data['mediaUrl'])
                else
                   Container(
                     height: 250, width: double.infinity, color: Colors.grey[200],
                     child: data['mediaUrl'] != null ? Image.network(data['mediaUrl'], fit: BoxFit.cover) : const Icon(Icons.image),
                   ),
                
                // TRUST BAR
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  color: Colors.green[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("👥 ${data['triedCount'] ?? 0} tried this", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      Text("✅ ${data['successRate'] ?? 0}% Success", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['title'] ?? "Untitled", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      ExpandableCaption(text: data['caption'] ?? ""),
                    ],
                  ),
                )
              ],
            ),
          ),

          // 3. ACTION BAR (With SUPPORT button)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon((data['likes'] as List?)?.contains(FirebaseAuth.instance.currentUser?.uid) ?? false ? Icons.favorite : Icons.favorite_border, color: Colors.red),
                  onPressed: _toggleLike,
                ),
                Text("${(data['likes'] as List?)?.length ?? 0}"),
                const SizedBox(width: 15),
                IconButton(icon: const Icon(Icons.chat_bubble_outline), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ExpandedPostScreen(data: data, postId: postId)))),
                Text("${data['commentCount'] ?? 0}"),
                const SizedBox(width: 15),
                IconButton(icon: const Icon(Icons.repeat), onPressed: () => _handleRepost(context)),
                Text("${data['reposts'] ?? 0}"),
                const Spacer(),
                
                // SUPPORT BUTTON (Hardcoded here)
                TextButton.icon(
                  onPressed: () { /* Show Tip Dialog */ },
                  icon: const Icon(Icons.stars, color: Colors.orange),
                  label: const Text("SUPPORT", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(backgroundColor: Colors.orange.withOpacity(0.1)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}