import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'helper_widgets.dart'; // Ensure you have this file for VideoPlayerWidget

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
  String _mediaType = "text"; // "image", "video", or "text"

  Future<void> _pickMedia(bool isVideo) async {
    final picker = ImagePicker();
    XFile? file;
    
    if (isVideo) {
      file = await picker.pickVideo(source: ImageSource.gallery);
    } else {
      file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
    }

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
      String downloadUrl = "";

      // 1. Upload Media if exists
      if (_mediaBytes != null) {
        String ext = _mediaType == 'video' ? 'mp4' : 'jpg';
        String path = "posts/${user!.uid}_${DateTime.now().millisecondsSinceEpoch}.$ext";
        Reference ref = FirebaseStorage.instance.ref().child(path);
        
        // Setup metadata so browser/phone knows it's a video/image
        SettableMetadata meta = SettableMetadata(contentType: _mediaType == 'video' ? 'video/mp4' : 'image/jpeg');
        
        await ref.putData(_mediaBytes!, meta);
        downloadUrl = await ref.getDownloadURL();
      }

      // 2. Save to Firestore
      // Fetch username first
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      String username = userDoc.data()?['username'] ?? "Chef";

      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'username': username,
        'caption': _captionController.text,
        'mediaUrl': downloadUrl,
        'mediaType': _mediaType,
        'postType': 'quick_post',
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'reposts': 0,
        'commentCount': 0,
        'triedCount': 0,
        'successRate': 0,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error: $e");
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
            child: _isUploading ? const CircularProgressIndicator() : const Text("POST", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _captionController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: "What's cooking?", border: InputBorder.none),
            ),
            if (_mediaBytes != null)
              Stack(
                children: [
                  Container(
                    height: 250, 
                    width: double.infinity,
                    color: Colors.black,
                    child: _mediaType == 'image' 
                        ? Image.memory(_mediaBytes!, fit: BoxFit.cover)
                        : const Center(child: Icon(Icons.play_circle, color: Colors.white, size: 50)),
                  ),
                  Positioned(
                    right: 5, top: 5,
                    child: IconButton(
                      onPressed: () => setState(() { _mediaBytes = null; _mediaType = "text"; }),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  )
                ],
              ),
            Row(
              children: [
                IconButton(onPressed: () => _pickMedia(false), icon: const Icon(Icons.photo, color: Colors.blue)),
                IconButton(onPressed: () => _pickMedia(true), icon: const Icon(Icons.videocam, color: Colors.red)),
                const Text("Add Media")
              ],
            )
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

  void _add(List<TextEditingController> list) => setState(() => list.add(TextEditingController()));
  void _remove(List<TextEditingController> list, int index) {
    if (list.length > 1) setState(() => list.removeAt(index));
  }

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
      
      // Upload Cover
      Reference ref = FirebaseStorage.instance.ref().child("recipes/${user!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg");
      await ref.putData(_coverBytes!, SettableMetadata(contentType: 'image/jpeg'));
      String url = await ref.getDownloadURL();

      // Clean lists
      List<String> ingList = _ingredients.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
      List<String> stepList = _instructions.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
      
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String username = userDoc.data()?['username'] ?? "Chef";

      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'username': username,
        'title': _titleController.text,
        'caption': _captionController.text,
        'mediaUrl': url,
        'mediaType': 'image',
        'ingredients': ingList,
        'instructions': stepList,
        'postType': 'official_recipe',
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'reposts': 0,
        'commentCount': 0,
        'triedCount': 0,
        'successRate': 0,
      });
      
      if (mounted) Navigator.pop(context);

    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Recipe"),
        actions: [
           TextButton(
             onPressed: _isUploading ? null : _publish,
             child: _isUploading ? const CircularProgressIndicator() : const Text("PUBLISH", style: TextStyle(fontWeight: FontWeight.bold)),
           )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _pickCover,
              child: Container(
                height: 200, width: double.infinity,
                color: Colors.grey[200],
                child: _coverBytes != null 
                  ? Image.memory(_coverBytes!, fit: BoxFit.cover)
                  : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt), Text("Add Cover Photo")]),
              ),
            ),
            const SizedBox(height: 15),
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: "Recipe Title", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _captionController, decoration: const InputDecoration(labelText: "Description / Story", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            
            const Text("Ingredients", style: TextStyle(fontWeight: FontWeight.bold)),
            ..._ingredients.asMap().entries.map((entry) => Row(children: [
              Expanded(child: TextField(controller: entry.value)),
              IconButton(onPressed: () => _remove(_ingredients, entry.key), icon: const Icon(Icons.remove_circle, color: Colors.red)),
            ])),
            TextButton(onPressed: () => _add(_ingredients), child: const Text("+ Add Ingredient")),
            
            const SizedBox(height: 20),
            const Text("Instructions", style: TextStyle(fontWeight: FontWeight.bold)),
             ..._instructions.asMap().entries.map((entry) => Row(children: [
              Expanded(child: TextField(controller: entry.value, decoration: InputDecoration(prefixText: "Step ${entry.key + 1}: "))),
              IconButton(onPressed: () => _remove(_instructions, entry.key), icon: const Icon(Icons.remove_circle, color: Colors.red)),
            ])),
            TextButton(onPressed: () => _add(_instructions), child: const Text("+ Add Step")),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}