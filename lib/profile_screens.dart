import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'main.dart'; 
import 'helper_widgets.dart'; 
import 'recipe_card_post.dart'; 
import 'creation_screens.dart'; 

// ----------------------------------------------------------------------
// 1. THE REUSABLE TEMPLATE (Updated Stats & Height)
// ----------------------------------------------------------------------
class ProfileBaseLayout extends StatelessWidget {
  final String userId;
  final Widget? actionButton; 
  final Widget? fab;          
  final bool isUploading;
  final VoidCallback? onAvatarTap;
  final bool showStars;
  final bool showSavedTab;

  const ProfileBaseLayout({
    super.key,
    required this.userId,
    this.actionButton,
    this.fab,
    this.isUploading = false,
    this.onAvatarTap,
    this.showStars = false, 
    this.showSavedTab = false,
  });

  @override
  Widget build(BuildContext context) {
    int tabCount = showSavedTab ? 3 : 2;
    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        floatingActionButton: fab,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 440, // Height adjusted for wider layout
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                    return Padding(
                      padding: const EdgeInsets.only(top: 80, bottom: 20),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: onAvatarTap,
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.green[100],
                              backgroundImage: (data['profilePic'] != null && data['profilePic'] != "") 
                                  ? NetworkImage(data['profilePic']) : null,
                              child: isUploading 
                                  ? const CircularProgressIndicator() 
                                  : (data['profilePic'] == null || data['profilePic'] == "") 
                                      ? const Icon(Icons.person, size: 40, color: Colors.green) : null,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(data['username'] ?? "Cook", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 15),
                          
                          // UPDATED STATS ROW: Following, Followers, Recipes
                          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                            _stat("Following", "${data['following'] ?? 0}"),
                            _stat("Followers", "${data['followers'] ?? 0}"),
                            _stat("Recipes", "${data['recipeCount'] ?? 0}"), // Changed from Success
                          ]),
                          
                          const SizedBox(height: 25),
                          if (showStars) 
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.orange[50], 
                                borderRadius: BorderRadius.circular(15), 
                                border: Border.all(color: Colors.orange[200]!)
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min, 
                                children: [
                                  const Icon(Icons.stars, color: Colors.orange),
                                  const SizedBox(width: 10),
                                  Text("${data['stars'] ?? 0} Stars", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                ]
                              ),
                            ),
                          const SizedBox(height: 15),
                          if (actionButton != null) actionButton!,
                        ],
                      ),
                    );
                  },
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Material(
                  color: Colors.white,
                  child: TabBar(
                    labelColor: Colors.green,
                    indicatorColor: Colors.green,
                    tabs: [
                      const Tab(text: "Posts"),
                      const Tab(text: "Recipes"),
                      if (showSavedTab) const Tab(text: "Saved"),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              PostsTab(viewingUid: userId),
              const RecipesTab(),
              if (showSavedTab) const EmptyStateWidget(message: "No saved recipes yet"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String val) => Column(children: [
    Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))
  ]);
}

// ----------------------------------------------------------------------
// 2. YOUR PROFILE SCREEN
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
    } catch (e) {
      debugPrint("Upload Error: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ProfileBaseLayout(
      userId: user?.uid ?? "",
      showStars: true, 
      showSavedTab: true,
      isUploading: _isUploading,
      onAvatarTap: _updateProfilePicture,
      fab: FloatingActionButton(
        onPressed: () => _showCreateMenu(context),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
      actionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _updateProfilePicture,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: Colors.grey),
            ),
            child: const Text("Edit Profile Picture"),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 3. PUBLIC PROFILE PAGE (Expanded Width Follow & DM Box)
// ----------------------------------------------------------------------
class PublicProfilePage extends StatefulWidget {
  final String userId;
  const PublicProfilePage({super.key, required this.userId});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  bool isFollowing = false;
  final String me = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  void _checkFollowStatus() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(me)
        .collection('following')
        .doc(widget.userId)
        .get();
    if (mounted) setState(() => isFollowing = doc.exists);
  }

  // --- UNFOLLOW CONFIRMATION ---
  void _confirmUnfollow(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Unfollow?"),
        content: const Text("Are you sure you want to stop following this chef?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleFollowAction();
            },
            child: const Text("Unfollow", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleFollowAction() async {
    final followRef = FirebaseFirestore.instance.collection('users').doc(me).collection('following').doc(widget.userId);
    final followerRef = FirebaseFirestore.instance.collection('users').doc(widget.userId).collection('followers').doc(me);

    if (isFollowing) {
      await followRef.delete();
      await followerRef.delete();
      await FirebaseFirestore.instance.collection('users').doc(me).update({'following': FieldValue.increment(-1)});
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({'followers': FieldValue.increment(-1)});
    } else {
      await followRef.set({'timestamp': FieldValue.serverTimestamp()});
      await followerRef.set({'timestamp': FieldValue.serverTimestamp()});
      await FirebaseFirestore.instance.collection('users').doc(me).update({'following': FieldValue.increment(1)});
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({'followers': FieldValue.increment(1)});
    }
    setState(() => isFollowing = !isFollowing);
  }

  @override
  Widget build(BuildContext context) {
    return ProfileBaseLayout(
      userId: widget.userId,
      actionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // EXPANDED FOLLOW BUTTON
            Expanded(
              child: SizedBox(
                height: 45,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? Colors.grey[200] : Colors.green,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (isFollowing) {
                      _confirmUnfollow(context);
                    } else {
                      _handleFollowAction();
                    }
                  },
                  child: Text(
                    isFollowing ? "Followed" : "Follow", 
                    style: TextStyle(
                      color: isFollowing ? Colors.black87 : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    )
                  ),
                ),
              ),
            ),
            // SQUARE DM BOX
            if (isFollowing) ...[
              const SizedBox(width: 12),
              Container(
                height: 45,
                width: 45,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () {
                    // Navigate to Chat Screen
                  },
                  icon: const Icon(Icons.mail_outline, color: Colors.green),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 4. TABS & HELPERS
// ----------------------------------------------------------------------
class PostsTab extends StatelessWidget {
  final String viewingUid;
  const PostsTab({super.key, required this.viewingUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: viewingUid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const EmptyStateWidget(message: "No posts yet");
        
        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 20), 
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

class RecipesTab extends StatelessWidget {
  const RecipesTab({super.key});
  @override
  Widget build(BuildContext context) => const EmptyStateWidget(message: "No official recipes yet");
}

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