import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'recipe_card_post.dart';
import 'helper_widgets.dart';
import 'creation_screens.dart';
import 'profile_screens.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  List<String> _followingIds = [];
  bool _isLoadingFollowing = true;

  @override
  void initState() {
    super.initState();
    _loadFollowingList();
  }

  // Fetch the current user's following list to separate Following vs Explore
  Future<void> _loadFollowingList() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('following')
          .get();

      if (mounted) {
        setState(() {
          _followingIds = snapshot.docs.map((doc) => doc.id).toList();
          _isLoadingFollowing = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading following list: $e");
      if (mounted) setState(() => _isLoadingFollowing = false);
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
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text("Quick Post"),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateQuickPostScreen())); },
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu, color: Colors.green),
              title: const Text("Official Recipe"),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRecipeScreen())); },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('HomeCook'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => showSearch(context: context, delegate: RecipeSearchDelegate()),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.green,
            labelColor: Colors.green,
            tabs: [Tab(text: "Following"), Tab(text: "Explore")],
          ),
        ),
        body: _isLoadingFollowing 
            ? const Center(child: CircularProgressIndicator(color: Colors.green))
            : TabBarView(
                children: [
                  _buildPostList(isFollowingTab: true),
                  _buildPostList(isFollowingTab: false),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateMenu(context),
          backgroundColor: Colors.green,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildPostList({required bool isFollowingTab}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const EmptyStateWidget(message: "No posts found");

        // Logic to filter content based on your 3 rules
        var filteredDocs = snapshot.data!.docs.where((doc) {
          String postAuthorId = doc['userId'];

          // 1. Hide my own posts from both tabs
          if (postAuthorId == myUid) return false;

          if (isFollowingTab) {
            // 2. Following Tab: Only show people I follow
            return _followingIds.contains(postAuthorId);
          } else {
            // 3. Explore Tab: Only show people I do NOT follow
            return !_followingIds.contains(postAuthorId);
          }
        }).toList();

        if (filteredDocs.isEmpty) {
          return EmptyStateWidget(
            message: isFollowingTab 
              ? "Follow some chefs to see their posts here!" 
              : "You've seen it all! No new chefs to explore right now."
          );
        }

        return ListView.builder(
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var doc = filteredDocs[index];
            return RecipeCardPost(data: doc.data() as Map<String, dynamic>, postId: doc.id);
          },
        );
      },
    );
  }
}

class RecipeSearchDelegate extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null)
  );

  @override
  Widget buildResults(BuildContext context) => _searchLogic(context);

  @override
  Widget buildSuggestions(BuildContext context) => _searchLogic(context);

  Widget _searchLogic(BuildContext context) {
    final String searchKey = query.trim().toLowerCase();
    if (searchKey.isEmpty) return const Center(child: Text("Search for chefs..."));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: searchKey)
          .where('username', isLessThanOrEqualTo: '$searchKey\uf8ff')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final users = snapshot.data!.docs;
        if (users.isEmpty) return const Center(child: Text("No users found"));

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(userData['username'] ?? "Anonymous"),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (context) => PublicProfilePage(userId: users[index].id)
              )),
            );
          },
        );
      },
    );
  }
}