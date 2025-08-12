import 'package:ditck/features/auth/views/auth_screen.dart';
import 'package:ditck/features/home/views/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final firebaseUser = FirebaseAuth.instance.currentUser;

  // Edge case: SharedPrefs says logged in but FirebaseAuth is null
  Widget startScreen;
  if (isLoggedIn && firebaseUser != null) {
    startScreen = const HomePage();
  } else {
    // If mismatch, reset SharedPrefs
    if (isLoggedIn && firebaseUser == null) {
      await prefs.setBool('isLoggedIn', false);
    }
    startScreen = const AuthScreen();
  }

  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: startScreen));
}