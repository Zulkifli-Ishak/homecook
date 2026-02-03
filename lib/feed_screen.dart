import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'recipe_card_post.dart';       // Ensure this file exists
import 'helper_widgets.dart';         // Ensure this file exists
import 'creation_screens.dart';       // Ensure this file exists
import 'profile_screens.dart';        // Needed for PublicProfilePage

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // --- CREATE MENU (Floating Action Button) ---
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('HomeCook'),
          centerTitle: true,
          // --- RESTORED SEARCH BUTTON ---
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                showSearch(context: context, delegate: RecipeSearchDelegate());
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.green,
            labelColor: Colors.green,
            tabs: [Tab(text: "Following"), Tab(text: "Explore")],
          ),
        ),
        body: TabBarView(
          children: [
             const Center(child: Text("Follow users to see posts here")),
             
             // LIVE FEED
             StreamBuilder<QuerySnapshot>(
               stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).snapshots(),
               builder: (context, snapshot) {
                 if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                 if (snapshot.data!.docs.isEmpty) return const EmptyStateWidget(message: "No posts found");
                 
                 return ListView.builder(
                   itemCount: snapshot.data!.docs.length,
                   itemBuilder: (context, index) {
                     var doc = snapshot.data!.docs[index];
                     return RecipeCardPost(data: doc.data() as Map<String, dynamic>, postId: doc.id);
                   },
                 );
               },
             ),
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
}

// --- RESTORED SEARCH DELEGATE ---
class RecipeSearchDelegate extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  }

  @override
  Widget buildResults(BuildContext context) => _searchLogic(context);

  @override
  Widget buildSuggestions(BuildContext context) => _searchLogic(context);

  Widget _searchLogic(BuildContext context) {
    final String searchKey = query.trim().toLowerCase();
    
    // If empty, show recent users (optional logic) or nothing
    if (searchKey.isEmpty) {
      return const Center(child: Text("Search for chefs..."));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          // Using a simple range query for search
          .where('username', isGreaterThanOrEqualTo: searchKey)
          .where('username', isLessThanOrEqualTo: '$searchKey\uf8ff')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No users found"));

        final users = snapshot.data!.docs;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            final String username = userData['username'] ?? "Anonymous";
            final String userId = users[index].id;

            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(username),
              onTap: () {
                // Navigate to the Public Profile Page
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PublicProfilePage(userId: userId)),
                );
              },
            );
          },
        );
      },
    );
  }
}