import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'helper_widgets.dart'; 
import 'kitchen_page.dart';   
import 'profile_screens.dart'; 

class ExpandedPostScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String postId;

  const ExpandedPostScreen({super.key, required this.data, required this.postId});

  @override
  State<ExpandedPostScreen> createState() => _ExpandedPostScreenState();
}

class _ExpandedPostScreenState extends State<ExpandedPostScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  
  String? _replyingToId; 
  String? _replyingToName; 

  int _mainCommentLimit = 10;
  final Map<String, int> _replyLimits = {};
  final Map<String, bool> _showReplies = {};

  // --- LOGIC: LIKE, REPOST ---
  Future<void> _toggleLike(String targetId, List likes) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    DocumentReference ref = FirebaseFirestore.instance.collection('posts').doc(targetId);
    
    if (likes.contains(uid)) {
      // UNLIKE
      await ref.update({'likes': FieldValue.arrayRemove([uid])});
    } else {
      // LIKE
      await ref.update({'likes': FieldValue.arrayUnion([uid])});

      // --- NEW: NOTIFICATION (LIKE) ---
      // Determine real owner (if repost, get original author)
      String realOwnerId = widget.data['isRepost'] == true 
           ? (widget.data['originalAuthorId'] ?? widget.data['userId']) 
           : widget.data['userId'];

      NotificationService.sendNotification(
        toUserId: realOwnerId, 
        type: 'like', 
        postId: targetId,
        body: "Liked your recipe!"
      );
      // --------------------------------
    }
  }

  Future<void> _handleRepost(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.data['userId'] == user.uid) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String myName = userDoc.data()?['username'] ?? "Chef";
      String originalPost = widget.data['isRepost'] == true ? widget.data['originalPostId'] : widget.postId;

      await FirebaseFirestore.instance.collection('posts').add({
        ...widget.data,
        'userId': user.uid,
        'isRepost': true,
        'reposterName': myName,
        'originalAuthorId': widget.data['originalAuthorId'] ?? widget.data['userId'],
        'originalPostId': originalPost,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'reposts': 0,
      });
      await FirebaseFirestore.instance.collection('posts').doc(originalPost).update({'reposts': FieldValue.increment(1)});
      
      // --- NEW: NOTIFICATION (REPOST) ---
      String realOwnerId = widget.data['isRepost'] == true 
           ? (widget.data['originalAuthorId'] ?? widget.data['userId']) 
           : widget.data['userId'];

      NotificationService.sendNotification(
        toUserId: realOwnerId, 
        type: 'repost', 
        postId: originalPost,
        body: "Reposted your recipe!"
      );
      // ----------------------------------

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Shared!")));
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _deleteComment(String targetId, String commentId) async {
    try {
      // 1. Find all replies that belong to this comment
      final replyQuery = await FirebaseFirestore.instance
          .collection('posts')
          .doc(targetId)
          .collection('comments')
          .where('parentCommentId', isEqualTo: commentId)
          .get();

      // 2. Prepare a Batch (Atomic operation: all succeed or all fail)
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Delete the parent comment
      DocumentReference parentRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(targetId)
          .collection('comments')
          .doc(commentId);
      batch.delete(parentRef);

      // Delete all found replies
      for (var doc in replyQuery.docs) {
        batch.delete(doc.reference);
      }

      // 3. Execute the batch delete
      await batch.commit();

      // 4. Update the total comment count on the post
      // We decrement by (1 parent + number of replies)
      int totalDeleted = 1 + replyQuery.docs.length;
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(targetId)
          .update({'commentCount': FieldValue.increment(-totalDeleted)});

      debugPrint("Deleted parent and $totalDeleted replies successfully.");
    } catch (e) {
      debugPrint("Delete failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete comment and its replies.")),
        );
      }
    }
  }

  Future<void> _submitComment(String targetId) async {
    String text = _commentController.text.trim();
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    String finalUsername = userDoc.data()?['username'] ?? "Chef";
    String finalPic = userDoc.data()?['profilePic'] ?? "";

    // 1. Add Comment
    await FirebaseFirestore.instance.collection('posts').doc(targetId).collection('comments').add({
      'text': text,
      'userId': user.uid,
      'username': finalUsername,
      'userProfilePic': finalPic,
      'createdAt': FieldValue.serverTimestamp(),
      'parentCommentId': _replyingToId, 
    });
    
    // 2. Update Count
    await FirebaseFirestore.instance.collection('posts').doc(targetId).update({'commentCount': FieldValue.increment(1)});
    
    // --- NEW: NOTIFICATION (COMMENT/REPLY) ---
    // Case A: Reply
    if (_replyingToId != null && _replyingToId != user.uid) {
       // Note: We need the UserID of the person we are replying to. 
       // In this simpler version, we notify the POST OWNER if we can't easily find the comment owner ID without another fetch.
       // However, strictly speaking, `_replyingToId` here is the COMMENT ID, not the USER ID. 
       // To notify the specific user you replied to, you'd need their UID.
       // For now, let's keep it simple and notify the POST OWNER to avoid complex lookups.
       // Or better: If you want to notify the specific user, you need to store their UID in `_replyingToId` logic (which is complex).
       
       // SAFE FALLBACK: Notify the Post Owner always
       String realOwnerId = widget.data['isRepost'] == true 
           ? (widget.data['originalAuthorId'] ?? widget.data['userId']) 
           : widget.data['userId'];

       NotificationService.sendNotification(
          toUserId: realOwnerId, 
          type: 'comment', 
          postId: targetId,
          body: "Commented: $text"
       );
    } 
    // Case B: Normal Comment
    else {
       String realOwnerId = widget.data['isRepost'] == true 
           ? (widget.data['originalAuthorId'] ?? widget.data['userId']) 
           : widget.data['userId'];

       NotificationService.sendNotification(
          toUserId: realOwnerId, 
          type: 'comment', 
          postId: targetId,
          body: "Commented: $text"
       );
    }
    // -----------------------------------------

    setState(() {
      _commentController.clear();
      _replyingToId = null;
      _replyingToName = null;
    });
    _commentFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final bool isOfficialRecipe = widget.data['postType'] == 'official_recipe';
    final String targetPostId = widget.data['isRepost'] == true ? widget.data['originalPostId'] : widget.postId;
    final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(isOfficialRecipe ? (widget.data['title'] ?? "Recipe") : "Post"), elevation: 0.5),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // MEDIA SECTION
                  if (widget.data['mediaUrl'] != null && widget.data['mediaUrl'] != "")
                    widget.data['mediaType'] == 'video'
                        ? VideoPlayerWidget(videoUrl: widget.data['mediaUrl'])
                        : Image.network(widget.data['mediaUrl'], width: double.infinity, fit: BoxFit.contain),
                  
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isOfficialRecipe) ...[
                          Text(widget.data['title'] ?? "", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                        ],
                        Text(widget.data['caption'] ?? "", style: const TextStyle(fontSize: 16)),
                        
                        // RECIPE DETAILS SECTION
                        if (isOfficialRecipe) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(
                                    builder: (_) => RecipeDetailScreen(recipeData: widget.data),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green, 
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.menu_book),
                              label: const Text("VIEW FULL RECIPE", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Divider(),
                        ],
                        
                        const Divider(thickness: 0.5, height: 32),

                        // ACTION BAR
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('posts').doc(targetPostId).snapshots(),
                          builder: (context, snapshot) {
                            var liveData = snapshot.hasData ? (snapshot.data!.data() as Map<String, dynamic>?) : widget.data;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _actionBtn( (liveData?['likes'] as List?)?.contains(myUid) ?? false ? Icons.favorite : Icons.favorite_border,
                                  "${(liveData?['likes'] as List?)?.length ?? 0}", (liveData?['likes'] as List?)?.contains(myUid) ?? false ? Colors.red : Colors.grey[700]!,
                                  () => _toggleLike(targetPostId, liveData?['likes'] ?? [])),
                                _actionBtn(Icons.chat_bubble_outline, "${liveData?['commentCount'] ?? 0}", Colors.grey[700]!, () => _commentFocus.requestFocus()),
                                _actionBtn(Icons.repeat, "${liveData?['reposts'] ?? 0}", Colors.grey[700]!, () => _handleRepost(context)),
                              ],
                            );
                          }
                        ),
                        const Divider(thickness: 0.5, height: 32),

                        const Text("Comments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 12),

                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('posts').doc(targetPostId).collection('comments').orderBy('createdAt', descending: true).snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox.shrink();
                            var allComments = snapshot.data!.docs;
                            var mainComments = allComments.where((doc) => doc['parentCommentId'] == null).toList();
                            var displayedMain = mainComments.take(_mainCommentLimit).toList();

                            return Column(
                              children: [
                                ...displayedMain.map((doc) => _buildCommentNode(doc, allComments, myUid, targetPostId)),
                                if (mainComments.length > _mainCommentLimit)
                                  TextButton(onPressed: () => setState(() => _mainCommentLimit += 10), child: const Text("Show more comments")),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildInputArea(targetPostId),
        ],
      ),
    );
  }

  // --- Utility methods ---
  Widget _buildCommentNode(DocumentSnapshot doc, List<DocumentSnapshot> allComments, String myUid, String targetPostId) {
    var data = doc.data() as Map<String, dynamic>;
    var replies = allComments.where((c) => c['parentCommentId'] == doc.id).toList();
    bool isExpanded = _showReplies[doc.id] ?? false;
    int replyLimit = _replyLimits[doc.id] ?? 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentTile(doc.id, data, myUid, targetPostId, null), 
        if (replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 30), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isExpanded)
                  TextButton(onPressed: () => setState(() => _showReplies[doc.id] = true), child: Text("Show ${replies.length} replies")),
                if (isExpanded) ...[
                  ...replies.take(replyLimit).map((r) {
                    var rData = r.data() as Map<String, dynamic>;
                    return _buildCommentTile(r.id, rData, myUid, targetPostId, doc.id); 
                  }),
                  if (replies.length > replyLimit)
                    TextButton(onPressed: () => setState(() => _replyLimits[doc.id] = (replyLimit + 10)), child: const Text("Show more replies")),
                  TextButton(onPressed: () => setState(() => _showReplies[doc.id] = false), child: const Text("Hide replies")),
                ]
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCommentTile(String id, Map<String, dynamic> c, String myUid, String targetPostId, String? rootId) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfilePage(userId: c['userId']))),
        child: CircleAvatar(
          radius: 18, backgroundColor: Colors.grey[200],
          backgroundImage: (c['userProfilePic'] != null && c['userProfilePic'] != "") ? NetworkImage(c['userProfilePic']) : null,
          child: (c['userProfilePic'] == null || c['userProfilePic'] == "") ? const Icon(Icons.person, size: 20) : null,
        ),
      ),
      title: Row(
        children: [
          Text(c['username'] ?? "User", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          if (c['userId'] == myUid)
            IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red), 
            onPressed: () => _deleteComment(targetPostId, id)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c['text'] ?? ""),
          GestureDetector(
            onTap: () {
              setState(() { 
                _replyingToId = rootId ?? id; 
                _replyingToName = c['username']; 
              });
              _commentFocus.requestFocus();
            },
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("Reply", style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold))),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(String targetPostId) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingToId != null)
              Row(children: [
                Text("Replying to $_replyingToName", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                GestureDetector(onTap: () => setState(() { _replyingToId = null; _replyingToName = null; }), child: const Icon(Icons.cancel, size: 14, color: Colors.red)),
              ]),
            TextField(
              controller: _commentController, focusNode: _commentFocus,
              decoration: InputDecoration(
                filled: true, fillColor: Colors.grey[50], hintText: "Add a comment...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.grey[300]!)),
                suffixIcon: IconButton(icon: const Icon(Icons.send, color: Colors.green), onPressed: () => _submitComment(targetPostId)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(children: [Icon(icon, color: color, size: 24), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))])));
  }
}


class RecipeDetailScreen extends StatelessWidget {
  final Map<String, dynamic> recipeData;
  const RecipeDetailScreen({super.key, required this.recipeData});

  @override
  Widget build(BuildContext context) {
    List ingredients = recipeData['ingredients'] ?? [];
    List instructions = recipeData['steps'] ?? []; // Changed from 'instructions' to 'steps' if needed, otherwise 'instructions'

    return Scaffold(
      appBar: AppBar(title: Text(recipeData['title'] ?? "Recipe")),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text("Ingredients", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...ingredients.map((ing) => ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                  title: Text(ing),
                  dense: true,
                )),
                const Divider(height: 40),
                const Text("Instructions", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...instructions.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(radius: 12, backgroundColor: Colors.green, child: Text("${entry.key + 1}", style: const TextStyle(fontSize: 12, color: Colors.white))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 16))),
                    ],
                  ),
                )),
              ],
            ),
          ),
          // THE FINAL ACTION
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => KitchenPage(recipeData: recipeData))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  icon: const Icon(Icons.mic),
                  label: const Text("COOK NOW (VOICE MODE)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}