import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'helper_widgets.dart';

// ---------------------------------------------------------
// 1. QUICK POST SCREEN
// ---------------------------------------------------------
class CreateQuickPostScreen extends StatefulWidget {
  const CreateQuickPostScreen({super.key});
  @override
  State<CreateQuickPostScreen> createState() => _CreateQuickPostScreenState();
}

class _CreateQuickPostScreenState extends State<CreateQuickPostScreen> {
  final _captionController = TextEditingController();
  bool _isUploading = false;
  Uint8List? _mediaBytes;
  String _mediaType = "text"; 

  Future<void> _pickMedia(bool isVideo) async {
    final picker = ImagePicker();
    XFile? file = isVideo 
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);

    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _mediaBytes = bytes;
        _mediaType = isVideo ? "video" : "image";
      });
    }
  }

  Future<void> _uploadPost() async {
    if (_captionController.text.isEmpty && _mediaBytes == null) return;
    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      String downloadUrl = "";

      if (_mediaBytes != null) {
        String ext = _mediaType == 'video' ? 'mp4' : 'jpg';
        String path = "posts/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.$ext";
        Reference ref = FirebaseStorage.instance.ref().child(path);
        await ref.putData(_mediaBytes!, SettableMetadata(contentType: _mediaType == 'video' ? 'video/mp4' : 'image/jpeg'));
        downloadUrl = await ref.getDownloadURL();
      }

      var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      Map<String, dynamic> userData = userDoc.data() ?? {};

      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'username': userData['username'] ?? "Chef",
        'userProfilePic': userData['profilePic'] ?? "",
        'caption': _captionController.text,
        'mediaUrl': downloadUrl,
        'mediaType': _mediaType,
        'postType': 'quick_post',
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'reposts': 0,
        'commentCount': 0,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Upload Error: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Quick Post"),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _uploadPost,
            child: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("POST"),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _captionController, maxLines: 4, decoration: const InputDecoration(hintText: "What's cooking?", border: InputBorder.none)),
            if (_mediaBytes != null)
              Stack(
                children: [
                  Container(
                    height: 250, width: double.infinity, color: Colors.black,
                    child: _mediaType == 'image' ? Image.memory(_mediaBytes!, fit: BoxFit.cover) : const Center(child: Icon(Icons.play_circle, color: Colors.white, size: 50)),
                  ),
                  Positioned(right: 5, top: 5, child: IconButton(onPressed: () => setState(() => _mediaBytes = null), icon: const Icon(Icons.close, color: Colors.white))),
                ],
              ),
            Row(children: [
              IconButton(onPressed: () => _pickMedia(false), icon: const Icon(Icons.photo, color: Colors.blue)),
              IconButton(onPressed: () => _pickMedia(true), icon: const Icon(Icons.videocam, color: Colors.red)),
              const Text("Add Media")
            ])
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 2. OFFICIAL RECIPE SCREEN
// ---------------------------------------------------------
class CreateRecipeScreen extends StatefulWidget {
  const CreateRecipeScreen({super.key});
  @override
  State<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends State<CreateRecipeScreen> {
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  final List<TextEditingController> _ingredients = [TextEditingController()];
  final List<TextEditingController> _instructions = [TextEditingController()];
  Uint8List? _coverBytes;
  bool _isUploading = false;

  Future<void> _pickCover() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() => _coverBytes = bytes);
    }
  }

  Future<void> _publish() async {
    if (_titleController.text.isEmpty || _coverBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title and Cover Photo required!")));
      return;
    }
    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      Reference ref = FirebaseStorage.instance.ref().child("recipes/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg");
      await ref.putData(_coverBytes!, SettableMetadata(contentType: 'image/jpeg'));
      String url = await ref.getDownloadURL();

      var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      Map<String, dynamic> userData = userDoc.data() ?? {};

      // 1. Create Post
      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'username': userData['username'] ?? "Chef",
        'userProfilePic': userData['profilePic'] ?? "",
        'title': _titleController.text,
        'caption': _captionController.text,
        'mediaUrl': url,
        'mediaType': 'image',
        'ingredients': _ingredients.map((c) => c.text).where((t) => t.isNotEmpty).toList(),
        'instructions': _instructions.map((c) => c.text).where((t) => t.isNotEmpty).toList(),
        'postType': 'official_recipe',
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'reposts': 0,
        'commentCount': 0,
        'triedCount': 0,
        'successRate': 0,
      });

      // 2. Increment recipeCount for Profile Stats
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'recipeCount': FieldValue.increment(1)
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Recipe Error: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Recipe"),
        actions: [TextButton(onPressed: _isUploading ? null : _publish, child: _isUploading ? const CircularProgressIndicator() : const Text("PUBLISH"))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickCover,
              child: Container(
                height: 200, width: double.infinity, color: Colors.grey[200],
                child: _coverBytes != null ? Image.memory(_coverBytes!, fit: BoxFit.cover) : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt), Text("Add Cover")]),
              ),
            ),
            const SizedBox(height: 15),
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: "Recipe Title", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _captionController, decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            const Text("Ingredients", style: TextStyle(fontWeight: FontWeight.bold)),
            ..._ingredients.map((c) => TextField(controller: c, decoration: const InputDecoration(hintText: "Item"))),
            TextButton(onPressed: () => setState(() => _ingredients.add(TextEditingController())), child: const Text("+ Add")),
            const Text("Steps", style: TextStyle(fontWeight: FontWeight.bold)),
            ..._instructions.map((c) => TextField(controller: c, decoration: const InputDecoration(hintText: "Instruction"))),
            TextButton(onPressed: () => setState(() => _instructions.add(TextEditingController())), child: const Text("+ Add")),
          ],
        ),
      ),
    );
  }
}