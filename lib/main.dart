import 'package:ditck/features/admin/views/admin_screen.dart';
import 'package:ditck/features/employee/views/employee_screen.dart';
import 'package:ditck/features/super_admin/views/super_admin_screen.dart';
import 'package:ditck/features/auth/views/sign_in_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _getStartScreen() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // No logged-in user → go to sign in
      return const SignInScreen();
    }

    // Fetch role from Firestore
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists || doc.data()?['role'] == null) {
      return const SignInScreen();
    }

    final role = doc['role'];
    switch (role) {
      case 'OWNER':
        return const SuperAdminScreen();
      case 'ADMIN':
        return const AdminScreen();
      case 'EMPLOYEE':
        return const EmployeeScreen();
      default:
        return const SignInScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<Widget>(
        future: _getStartScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(child: Text('Error: ${snapshot.error}')),
            );
          }
          return snapshot.data ?? const SignInScreen();
        },
      ),
    );
  }
}
