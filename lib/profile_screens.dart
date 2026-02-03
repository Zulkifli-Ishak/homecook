import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'main.dart'; // For LoginPage navigation
import 'helper_widgets.dart'; // For EmptyStateWidget
import 'recipe_card_post.dart'; // For PostsTab
import 'creation_screens.dart'; // For FAB menu

// ----------------------------------------------------------------------
// 1. MAIN PROFILE SCREEN
// ----------------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;

  void _showCreateMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Create Content", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue), title: const Text("Quick Post"),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateQuickPostScreen())); },
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu, color: Colors.green), title: const Text("Official Recipe"),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRecipeScreen())); },
            ),
          ],
        ),
      ),
    );
  }

  // --- UPLOAD LOGIC ---
  Future<void> _updateProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 75);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final Uint8List bytes = await image.readAsBytes();
      final String base64Image = base64Encode(bytes);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      Reference ref = FirebaseStorage.instance.ref().child('profiles/${user.uid}.jpg');
      await ref.putString(base64Image, format: PutStringFormat.base64, metadata: SettableMetadata(contentType: 'image/jpeg'));
      String url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'profilePic': url});
      await user.updatePhotoURL(url);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated!")));
    } catch (e) {
      debugPrint("Upload Error: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateMenu(context),
          backgroundColor: Colors.green,
          child: const Icon(Icons.add),
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 400,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                    return Padding(
                      padding: const EdgeInsets.only(top: 80, bottom: 20),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _updateProfilePicture,
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.green[100],
                              backgroundImage: (data['profilePic'] != null && data['profilePic'] != "") ? NetworkImage(data['profilePic']) : null,
                              child: _isUploading ? const CircularProgressIndicator() : (data['profilePic'] == null || data['profilePic'] == "") ? const Icon(Icons.person, size: 40, color: Colors.green) : null,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(data['username'] ?? "Cook", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                            _stat("Following", "${data['following'] ?? 0}"),
                            _stat("Followers", "${data['followers'] ?? 0}"),
                            _stat("Success", "${data['successRecipes'] ?? 0}%"),
                          ]),
                          const SizedBox(height: 20),
                          // Wallet Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orange[200]!)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.stars, color: Colors.orange),
                                const SizedBox(width: 10),
                                Text("${data['stars'] ?? 0} Stars", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                            ]),
                          ),
                          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())), child: const Text("Settings", style: TextStyle(color: Colors.grey))),
                        ],
                      ),
                    );
                  },
                ),
              ),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(48),
                child: Material(
                  color: Colors.white,
                  child: TabBar(
                    labelColor: Colors.green,
                    indicatorColor: Colors.green,
                    tabs: [Tab(text: "Posts"), Tab(text: "Recipes"), Tab(text: "Saved")],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              PostsTab(viewingUid: user?.uid ?? ""),
              const RecipesTab(),
              const EmptyStateWidget(message: "No saved recipes yet"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String val) => Column(children: [Text(val, style: const TextStyle(fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))]);
}

// ----------------------------------------------------------------------
// 2. POSTS TAB (Used in Profile)
// ----------------------------------------------------------------------
class PostsTab extends StatelessWidget {
  final String viewingUid;
  const PostsTab({super.key, required this.viewingUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').where('userId', isEqualTo: viewingUid).orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const EmptyStateWidget(message: "No posts yet");
        
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return RecipeCardPost(data: data, postId: snapshot.data!.docs[index].id);
          },
        );
      },
    );
  }
}

// ----------------------------------------------------------------------
// 3. RECIPES TAB (Placeholder)
// ----------------------------------------------------------------------
class RecipesTab extends StatelessWidget {
  const RecipesTab({super.key});
  @override
  Widget build(BuildContext context) => const EmptyStateWidget(message: "No official recipes yet");
}

// ----------------------------------------------------------------------
// 4. SETTINGS SCREEN (Delete Account)
// ----------------------------------------------------------------------
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _deleteAccount(BuildContext context, String password) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        AuthCredential cred = EmailAuthProvider.credential(email: user.email!, password: password);
        await user.reauthenticateWithCredential(cred);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
        await user.delete();
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showDeleteDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account?"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
           const Text("This cannot be undone."),
           TextField(controller: controller, obscureText: true, decoration: const InputDecoration(labelText: "Password"))
        ]),
        actions: [
          ElevatedButton(onPressed: () => _deleteAccount(context, controller.text), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("DELETE FOREVER")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Logout", style: TextStyle(color: Colors.red)), onTap: () { FirebaseAuth.instance.signOut(); Navigator.of(context, rootNavigator: true).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage())); }),
          ListTile(leading: const Icon(Icons.delete_forever, color: Colors.red), title: const Text("Delete Account", style: TextStyle(color: Colors.red)), onTap: () => _showDeleteDialog(context)),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 5. PUBLIC PROFILE PAGE (For Search Results)
// ----------------------------------------------------------------------
class PublicProfilePage extends StatelessWidget {
  final String userId;
  const PublicProfilePage({super.key, required this.userId});

  Future<void> _toggleFollow() async {
     // (Simplified Follow Logic)
     final me = FirebaseAuth.instance.currentUser!.uid;
     final followRef = FirebaseFirestore.instance.collection('users').doc(me).collection('following').doc(userId);
     final doc = await followRef.get();
     if (doc.exists) {
       await followRef.delete();
       await FirebaseFirestore.instance.collection('users').doc(me).update({'following': FieldValue.increment(-1)});
       await FirebaseFirestore.instance.collection('users').doc(userId).update({'followers': FieldValue.increment(-1)});
     } else {
       await followRef.set({'timestamp': FieldValue.serverTimestamp()});
       await FirebaseFirestore.instance.collection('users').doc(me).update({'following': FieldValue.increment(1)});
       await FirebaseFirestore.instance.collection('users').doc(userId).update({'followers': FieldValue.increment(1)});
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                var data = snapshot.data!.data() as Map<String, dynamic>;
                return Column(
                  children: [
                    const SizedBox(height: 20),
                    CircleAvatar(radius: 40, backgroundImage: data['profilePic'] != null ? NetworkImage(data['profilePic']) : null, child: data['profilePic'] == null ? const Icon(Icons.person) : null),
                    const SizedBox(height: 10),
                    Text(data['username'] ?? "User", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ElevatedButton(onPressed: _toggleFollow, child: const Text("Follow / Unfollow")),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          )
        ],
        body: PostsTab(viewingUid: userId),
      ),
    );
  }
}