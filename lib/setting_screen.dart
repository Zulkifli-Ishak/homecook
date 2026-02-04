import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart'; // Needed for LoginPage navigation

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
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()), 
          (route) => false
        );
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
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            const Text("This cannot be undone."),
            TextField(controller: controller, obscureText: true, decoration: const InputDecoration(labelText: "Password"))
          ]
        ),
        actions: [
          ElevatedButton(
            onPressed: () => _deleteAccount(context, controller.text), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
            child: const Text("DELETE FOREVER")
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Account", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red), 
            title: const Text("Logout", style: TextStyle(color: Colors.red)), 
            onTap: () async { 
              await FirebaseAuth.instance.signOut(); 
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            }
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red), 
            title: const Text("Delete Account", style: TextStyle(color: Colors.red)), 
            onTap: () => _showDeleteDialog(context)
          ),
        ],
      ),
    );
  }
}