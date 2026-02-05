import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'expanded_post_screen.dart';
import 'profile_screens.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: const InputDecoration(
                hintText: "Search recipes or chefs...",
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.green,
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "Recipes"),
              Tab(text: "People"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RecipeSearchTab(query: _searchQuery),
            _UserSearchTab(query: _searchQuery),
          ],
        ),
      ),
    );
  }
}

class _RecipeSearchTab extends StatelessWidget {
  final String query;
  const _RecipeSearchTab({required this.query});

  @override
  Widget build(BuildContext context) {
    // SCALABLE LOGIC: 
    // This query ONLY fetches 'official_recipe'.
    // As long as you save Reposts as 'postType: "repost"', 
    // this list will NEVER show duplicates and costs $0 for hidden items.
    Query recipeQuery = FirebaseFirestore.instance
        .collection('posts')
        .where('postType', isEqualTo: 'official_recipe');

    if (query.isNotEmpty) {
      String searchKey = query.toLowerCase();
      recipeQuery = recipeQuery
          .where('title_lower', isGreaterThanOrEqualTo: searchKey)
          .where('title_lower', isLessThanOrEqualTo: '$searchKey\uf8ff');
    } else {
      recipeQuery = recipeQuery.orderBy('createdAt', descending: true);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: recipeQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint("INDEX ERROR: ${snapshot.error}");
          return const Center(child: Text("Index missing. Check Console."));
        }
        
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No recipes found."));

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 15,
            childAspectRatio: 0.65, 
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String postId = docs[index].id;
            String? imageUrl = data['mediaUrl'];

            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpandedPostScreen(data: data, postId: postId))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.grey[100]),
                        child: (imageUrl != null && imageUrl != "")
                            ? Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity)
                            : const Icon(Icons.restaurant, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data['title'] ?? "Untitled",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, height: 1.1),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// (UserSearchTab remains the same)
class _UserSearchTab extends StatelessWidget {
  final String query;
  const _UserSearchTab({required this.query});

  @override
  Widget build(BuildContext context) {
    Query userQuery = FirebaseFirestore.instance.collection('users');

    if (query.isNotEmpty) {
      userQuery = userQuery
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '$query\uf8ff');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: userQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error loading users."));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No users found."));

        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String userId = docs[index].id;
            String? profilePic = data['profilePic'];

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.green[50],
                backgroundImage: (profilePic != null && profilePic != "")
                    ? NetworkImage(profilePic) : null,
                child: (profilePic == null || profilePic == "")
                    ? const Icon(Icons.person, color: Colors.green) : null,
              ),
              title: Text(data['username'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(data['bio'] ?? "Chef", maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfilePage(userId: userId))),
            );
          },
        );
      },
    );
  }
}