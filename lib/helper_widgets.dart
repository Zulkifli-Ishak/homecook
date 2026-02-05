import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

// --- 1. VIDEO PLAYER ---
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerWidget({super.key, required this.videoUrl});
  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
          _controller.setLooping(true);
          _controller.setVolume(0); // Start muted
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return Container(height: 250, color: Colors.black, child: const Center(child: CircularProgressIndicator()));
    return GestureDetector(
      onTap: () => setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play()),
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            if (!_controller.value.isPlaying) const Icon(Icons.play_circle_fill, size: 50, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

// --- 2. EXPANDABLE CAPTION ---
class ExpandableCaption extends StatefulWidget {
  final String text;
  const ExpandableCaption({super.key, required this.text});
  @override
  State<ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<ExpandableCaption> {
  bool isExpanded = false;
  @override
  Widget build(BuildContext context) {
    final bool canExpand = widget.text.length > 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.text, maxLines: isExpanded ? null : 2, overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis),
        if (canExpand)
          GestureDetector(
            onTap: () => setState(() => isExpanded = !isExpanded),
            child: Text(isExpanded ? "Show less" : "Read more", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}

// --- 3. EMPTY STATE ---
class EmptyStateWidget extends StatelessWidget {
  final String message;
  const EmptyStateWidget({super.key, required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.search_off, size: 60, color: Colors.grey),
      const SizedBox(height: 10),
      Text(message, style: const TextStyle(color: Colors.grey)),
    ]));
  }
}

// ----------------------------------------------------------------------
// 4. NOTIFICATION HELPER
// ----------------------------------------------------------------------
class NotificationService {
  static Future<void> sendNotification({
    required String toUserId,
    required String type, // 'like', 'comment', 'repost', 'reply'
    required String postId,
    String? body,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || me.uid == toUserId) return; // Don't notify yourself

    await FirebaseFirestore.instance.collection('users').doc(toUserId).collection('notifications').add({
      'fromId': me.uid,
      'fromName': me.displayName ?? "Someone",
      'fromPic': me.photoURL ?? "",
      'type': type,
      'postId': postId,
      'body': body ?? "",
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}