import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'helper_widgets.dart'; // Needed for VideoPlayerWidget
import 'kitchen_page.dart';   // Needed to start cooking

class ExpandedPostScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final String postId;
  final TextEditingController _commentController = TextEditingController();

  ExpandedPostScreen({super.key, required this.data, required this.postId});

  // --- SHOW RECIPE OVERVIEW ---
  void _showRecipeOverview(BuildContext context) {
    List ingredients = data['ingredients'] ?? [];
    List steps = data['instructions'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(25),
          children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            
            const Text("Ingredients", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            if (ingredients.isEmpty) const Text("No ingredients listed.", style: TextStyle(color: Colors.grey)),
            ...ingredients.map((i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text("• $i", style: const TextStyle(fontSize: 16)),
            )).toList(),
            
            const SizedBox(height: 20),
            const Text("Instructions", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            if (steps.isEmpty) const Text("No instructions listed.", style: TextStyle(color: Colors.grey)),
            ...steps.map((s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${steps.indexOf(s) + 1}. ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  Expanded(child: Text(s, style: const TextStyle(fontSize: 16))),
                ],
              ),
            )).toList(),
            
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () { 
                 Navigator.pop(context); // Close the sheet
                 // Navigate to the Voice-Activated Kitchen
                 Navigator.push(
                   context, 
                   MaterialPageRoute(builder: (context) => KitchenPage(recipeData: data))
                 );
              },
              icon: const Icon(Icons.mic, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, 
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              label: const Text("START COOKING NOW", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _submitComment(String text) async {
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('posts').doc(postId).collection('comments').add({
      'text': text, 
      'userId': user.uid, 
      'username': user.displayName ?? "User", 
      'createdAt': FieldValue.serverTimestamp()
    });
    
    // Update comment count on the main post
    await FirebaseFirestore.instance.collection('posts').doc(postId).update({
      'commentCount': FieldValue.increment(1)
    });
    
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(data['title'] ?? "Recipe"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // MEDIA DISPLAY
            if (data['mediaType'] == 'video' && data['mediaUrl'] != null)
              VideoPlayerWidget(videoUrl: data['mediaUrl'])
            else 
              Image.network(
                data['mediaUrl'] ?? "https://via.placeholder.com/400", 
                height: 300, 
                width: double.infinity, 
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(height: 300, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
              ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['title'] ?? "Untitled", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(data['caption'] ?? "", style: const TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 20),
                  
                  // ONLY SHOW VIEW RECIPE BUTTON IF IT IS AN OFFICIAL RECIPE
                  if (data['postType'] == 'official_recipe')
                    SizedBox(
                      width: double.infinity, 
                      child: ElevatedButton.icon(
                        onPressed: () => _showRecipeOverview(context), 
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)), 
                        icon: const Icon(Icons.restaurant_menu, color: Colors.white),
                        label: const Text("VIEW RECIPE & COOK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                      )
                    ),
                  
                  const Divider(height: 40),
                  
                  // COMMENT SECTION
                  const Text("Comments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  
                  // Stream for Comments
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('posts').doc(postId).collection('comments').orderBy('createdAt', descending: true).limit(10).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      var comments = snapshot.data!.docs;
                      
                      return Column(
                        children: comments.map((doc) {
                          var c = doc.data() as Map<String, dynamic>;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(backgroundColor: Colors.grey[200], child: Text((c['username'] ?? "U")[0])),
                            title: Text(c['username'] ?? "User", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(c['text'] ?? ""),
                          );
                        }).toList(),
                      );
                    }
                  ),
                  
                  const SizedBox(height: 20),
                  TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: "Add a comment...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      suffixIcon: IconButton(icon: const Icon(Icons.send, color: Colors.green), onPressed: () => _submitComment(_commentController.text)),
                    ),
                  ),
                  const SizedBox(height: 30), // Padding for bottom
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}