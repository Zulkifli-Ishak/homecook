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
import 'messaging_screens.dart';

// ----------------------------------------------------------------------
// 1. THE REUSABLE TEMPLATE (Updated Background Color)
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
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
          builder: (context, snapshot) {
            var data = snapshot.data?.data() as Map<String, dynamic>?;
            String username = data?['username'] ?? "";
            String bio = data?['bio'] ?? "";
            String pic = data?['profilePic'] ?? "";
            
            return NestedScrollView(
              headerSliverBuilder: (context, _) => [
                // --- 1. SLIVER APP BAR (Green Background) ---
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  backgroundColor: Colors.transparent, // <--- CHANGED HERE
                  foregroundColor: Colors.black, 
                  elevation: 0,
                  centerTitle: true,
                  title: null, 
                ),

                // --- 2. PROFILE INFO SECTION ---
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Avatar
                      GestureDetector(
                        onTap: onAvatarTap,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.green.shade100,
                              backgroundImage: (pic.isNotEmpty) ? NetworkImage(pic) : null,
                              child: (pic.isEmpty) ? const Icon(Icons.person, size: 50, color: Colors.green) : null,
                            ),
                            if (isUploading)
                              const Positioned.fill(child: CircularProgressIndicator(color: Colors.white)),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),

                      // Name below picture
                      Text(
                        username, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)
                      ),

                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(bio, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // STATS ROW
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem(
                            "Followers", 
                            "${data?['followers'] ?? 0}", 
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserListScreen(
                                title: "Followers", userId: userId, collectionPath: 'followers'
                            )))
                          ),
                          _buildStatItem(
                            "Following", 
                            "${data?['following'] ?? 0}",
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserListScreen(
                                title: "Following", userId: userId, collectionPath: 'following'
                            )))
                          ),
                          _buildStatItem(
                            "Recipes", 
                            "${data?['recipeCount'] ?? 0}", 
                            null 
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      if (actionButton != null) actionButton!,
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // --- 3. STICKY TABS ---
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      labelColor: Colors.green,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.green,
                      tabs: [
                        const Tab(text: "Posts"),
                        const Tab(text: "Recipes"),
                        if (showSavedTab) const Tab(text: "Saved"),
                      ],
                    ),
                  ),
                  pinned: true,
                ),
              ],
              body: TabBarView(
                children: [
                  PostsTab(viewingUid: userId),
                  const RecipesTab(),
                  if (showSavedTab) const SavedTab(),
                ],
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String count, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// Needed for the sticky TabBar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: Colors.white, child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
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

  void _showAvatarOptions(String? currentPic) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Text("Profile Picture", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            leading: const Icon(Icons.fullscreen, color: Colors.blue),
            title: const Text("View Profile Picture"),
            onTap: () {
              Navigator.pop(context);
              _viewFullImage(currentPic);
            },
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined, color: Colors.green),
            title: const Text("Change Profile Picture"),
            onTap: () {
              Navigator.pop(context);
              _updateProfilePicture();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text("Remove Profile Picture"),
            onTap: () {
              Navigator.pop(context);
              _removeProfilePicture();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _viewFullImage(String? url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: (url != null && url != "") 
                  ? Image.network(url, fit: BoxFit.contain)
                  : Container(color: Colors.white, padding: const EdgeInsets.all(50), child: const Icon(Icons.person, size: 150, color: Colors.grey)),
            ),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white, size: 30))
          ],
        ),
      ),
    );
  }

  Future<void> _removeProfilePicture() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get the current data to find the old URL
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String? oldUrl = doc.data()?['profilePic'];

      // Delete the file from Storage if it exists
      if (oldUrl != null && oldUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(oldUrl).delete();
        } catch (e) {
          debugPrint("Old file not found in storage, skipping delete.");
        }
      }

      // Update Firestore to empty
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'profilePic': ""
      });
      await user.updatePhotoURL(null);
      
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Remove error: $e");
    }
  }

  Future<void> _updateProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 75);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // GET OLD URL TO DELETE IT LATER
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String? oldUrl = doc.data()?['profilePic'];

      // Upload New Image
      final Uint8List bytes = await image.readAsBytes();
      final String base64Image = base64Encode(bytes);
      Reference ref = FirebaseStorage.instance.ref().child('profiles/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putString(base64Image, format: PutStringFormat.base64, metadata: SettableMetadata(contentType: 'image/jpeg'));
      String newUrl = await ref.getDownloadURL();

      // Update Firestore and Auth
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'profilePic': newUrl});
      await user.updatePhotoURL(newUrl);

      // DELETE THE OLD IMAGE FROM STORAGE
      if (oldUrl != null && oldUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(oldUrl).delete();
        } catch (e) {
          debugPrint("Could not delete old profile pic: $e");
        }
      }

    } catch (e) {
      debugPrint("Upload Error: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        // --- FIX START: HANDLE LOADING & NEW USERS ---
        
        // 1. Connection Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. Data Missing (Race Condition Fix)
        if (!snapshot.hasData || !snapshot.data!.exists) {
           return const Scaffold(
             body: Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   CircularProgressIndicator(),
                   SizedBox(height: 20),
                   Text("Setting up your profile..."),
                 ],
               )
             )
           );
        }
        // --- FIX END ---

        // Data is now safe to use
        final data = snapshot.data!.data() as Map<String, dynamic>;
        String? currentPic = data['profilePic'];
        
        return ProfileBaseLayout(
          userId: user.uid,
          showStars: true, 
          showSavedTab: true,
          isUploading: _isUploading,
          onAvatarTap: () => _showAvatarOptions(currentPic),
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
                onPressed: () => _showAvatarOptions(currentPic),
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
    );
  }
}

// ----------------------------------------------------------------------
// 3. PUBLIC PROFILE PAGE
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
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(me)
          .collection('following')
          .doc(widget.userId)
          .get();
      if (mounted) setState(() => isFollowing = doc.exists);
    } catch (e) {
      debugPrint("Error checking follow status: $e");
    }
  }

  void _viewFullImage(String? url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: (url != null && url != "") 
                  ? Image.network(url, fit: BoxFit.contain)
                  : Container(
                      color: Colors.white, 
                      padding: const EdgeInsets.all(50), 
                      child: const Icon(Icons.person, size: 150, color: Colors.grey)
                    ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context), 
              icon: const Icon(Icons.close, color: Colors.white, size: 30)
            )
          ],
        ),
      ),
    );
  }

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
            child: const Text("Cancel", style: TextStyle(color: Colors.grey))
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
      // UNFOLLOW
      await followRef.delete();
      await followerRef.delete();
      await FirebaseFirestore.instance.collection('users').doc(me).update({'following': FieldValue.increment(-1)});
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({'followers': FieldValue.increment(-1)});
    } else {
      // FOLLOW
      await followRef.set({'timestamp': FieldValue.serverTimestamp()});
      await followerRef.set({'timestamp': FieldValue.serverTimestamp()});
      await FirebaseFirestore.instance.collection('users').doc(me).update({'following': FieldValue.increment(1)});
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({'followers': FieldValue.increment(1)});

      // --- NEW: SEND NOTIFICATION (FOLLOW) ---
      NotificationService.sendNotification(
        toUserId: widget.userId, 
        type: 'follow', 
        postId: "", // No post involved in a follow
        body: "started following you."
      );
      // ---------------------------------------
    }
    setState(() => isFollowing = !isFollowing);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
      builder: (context, snapshot) {
        // 1. Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }

        // 2. Error/Missing
        if (!snapshot.hasData || !snapshot.data!.exists) {
           return Scaffold(appBar: AppBar(), body: const Center(child: Text("User not found")));
        }

        // 3. Success
        final data = snapshot.data!.data() as Map<String, dynamic>;
        String? profilePic = data['profilePic'];
        String chefName = data['username'] ?? "Chef";
        
        return Scaffold(
          body: ProfileBaseLayout(
            userId: widget.userId,
            onAvatarTap: () => _viewFullImage(profilePic),
            actionButton: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 45,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing ? Colors.grey[200] : Colors.green,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => isFollowing ? _confirmUnfollow(context) : _handleFollowAction(),
                        child: Text(
                          isFollowing ? "Followed" : "Follow", 
                          style: TextStyle(
                            color: isFollowing ? Colors.black87 : Colors.white, 
                            fontWeight: FontWeight.bold
                          )
                        ),
                      ),
                    ),
                  ),
                  if (isFollowing) ...[
                    const SizedBox(width: 12),
                    Container(
                      height: 45, width: 45,
                      decoration: BoxDecoration(
                        color: Colors.green[50], 
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatRoomScreen(
                                receiverId: widget.userId,
                                receiverName: chefName,
                              ),
                            ),
                          );
                        }, 
                        icon: const Icon(Icons.mail_outline, color: Colors.green)
                      ),
                    )
                  ]
                ],
              ),
            ),
          ),
        );
      }
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


// ----------------------------------------------------------------------
// 7. USER LIST SCREEN (Show Followers/Following)
// ----------------------------------------------------------------------
class UserListScreen extends StatelessWidget {
  final String title;
  final String userId;
  final String collectionPath; // 'followers' or 'following'

  const UserListScreen({super.key, required this.title, required this.userId, required this.collectionPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        // 1. Get the list of IDs from the subcollection
        stream: FirebaseFirestore.instance.collection('users').doc(userId).collection(collectionPath).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return Center(child: Text("No $title yet"));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              String otherUserId = docs[index].id;
              
              // 2. For each ID, fetch the actual user profile
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
                builder: (context, userSnap) {
                  String name = "Loading...";
                  String pic = "";
                  
                  if (userSnap.hasData && userSnap.data != null && userSnap.data!.exists) {
                    var data = userSnap.data!.data() as Map<String, dynamic>;
                    name = data['username'] ?? "Unknown";
                    pic = data['profilePic'] ?? "";
                  } else if (userSnap.connectionState == ConnectionState.active) {
                    name = "User not found"; // User might be deleted
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (pic.isNotEmpty) ? NetworkImage(pic) : null,
                      child: (pic.isEmpty) ? const Icon(Icons.person) : null,
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                    onTap: () {
                      // Navigate to their profile
                      Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfilePage(userId: otherUserId)));
                    },
                  );
                }
              );
            },
          );
        },
      ),
    );
  }
}


// ----------------------------------------------------------------------
// 8. SAVED TAB (Placeholder)
// ----------------------------------------------------------------------
class SavedTab extends StatelessWidget {
  const SavedTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 50, color: Colors.grey),
          SizedBox(height: 10),
          Text("Saved recipes will appear here.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}