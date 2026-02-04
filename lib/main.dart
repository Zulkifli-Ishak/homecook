import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'main_navigation.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // WEB CONFIGURATION (Keep your existing config if different)
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBYIGyKpaMDCTSQJ7cMJj31BYqO_ljtcXY",
        authDomain: "homecook-9e577.firebaseapp.com",
        projectId: "homecook-9e577",
        storageBucket: "homecook-9e577.firebasestorage.app",
        messagingSenderId: "110457770025",
        appId: "1:110457770025:web:4cfb151f16deae59290c38"
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(const HomecookApp());
}

class HomecookApp extends StatelessWidget {
  const HomecookApp({super.key});

  @override
Widget build(BuildContext context) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(primarySwatch: Colors.green),
    home: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If Firebase is still checking the login status...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingSplashScreen(); // Use a custom splash screen
        }
        
        if (snapshot.hasData) {
          return const MainNavigation();
        } else {
          return const LoginPage();
        }
      },
    ),
  );
}


}


// Add this Widget at the bottom of main.dart
class LoadingSplashScreen extends StatelessWidget {
  const LoadingSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_menu, size: 100, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              "Homecook",
              style: TextStyle(
                fontSize: 28, 
                fontWeight: FontWeight.bold, 
                color: Colors.green
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Colors.green),
          ],
        ),
      ),
    );
  }
}
// --- LOGIN PAGE ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _handleLogin() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // ADD THIS LINE:
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Login failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_menu, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text("Homecook", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 50),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder())),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _handleLogin, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("Login", style: TextStyle(color: Colors.white)))),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpPage())), 
              child: const Text("Don't have an account? Sign Up"),
            )
          ],
        ),
      ),
    );
  }
}

// --- SIGN UP PAGE ---
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _handleSignUp() async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      _showDietaryDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showDietaryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Dietary Preference"),
        content: const Text("Would you like to see only Halal content?"),
        actions: [
          TextButton(onPressed: () => _finalizeSignUp(false), child: const Text("Show All")),
          ElevatedButton(onPressed: () => _finalizeSignUp(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("Halal Only")),
        ],
      ),
    );
  }

  void _finalizeSignUp(bool isHalalOnly) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'username': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'isHalalOnly': isHalalOnly,
        'stars': 0,
        'followers': 0,
        'following': 0,
        'successRecipes': 0,
        'createdAt': DateTime.now(),
      });
      Navigator.pop(context); // Close dialog
      Navigator.pop(context); // Close Signup page
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Username")),
            const SizedBox(height: 10),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
            const SizedBox(height: 10),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _handleSignUp, child: const Text("Create Account")),
          ],
        ),
      ),
    );
  }
}