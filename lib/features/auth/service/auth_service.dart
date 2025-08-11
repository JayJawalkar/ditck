import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream to listen to authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> createCompanyAndSuperAdmin({
    required String companyName,
    required String companyMobile,
    required String companyEmail,
    required String superAdminName,
    required String superAdminMobile,
    required String superAdminEmail,
    required String superAdminPassword,
  }) async {
    // Validate mobile uniqueness
    await _validateMobileUniqueness(superAdminMobile);

    // Create company document
    final companyDoc = _firestore.collection('companies').doc(companyMobile);
    await companyDoc.set({
      'name': companyName,
      'mobile': companyMobile,
      'email': companyEmail,
      'createdAt': FieldValue.serverTimestamp(),
      'admins': [],
    });

    // Create super admin user
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: superAdminEmail,
      password: superAdminPassword,
    );

    // Create super admin profile
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'uid': userCredential.user!.uid,
      'name': superAdminName,
      'mobile': superAdminMobile,
      'email': superAdminEmail,
      'companyId': companyMobile,
      'role': 'super_admin',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Add admin to company
    await companyDoc.update({
      'admins': FieldValue.arrayUnion([userCredential.user!.uid]),
    });
  }

  // Check mobile number uniqueness
  Future<void> _validateMobileUniqueness(String mobile) async {
    final query = await _firestore
        .collection('users')
        .where('mobile', isEqualTo: mobile)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      throw FirebaseAuthException(
        code: 'mobile-already-exists',
        message: 'Mobile number is already registered',
      );
    }
  }

  // Create admin account (to be called by super admin)
  Future<void> createAdminAccount({
    required String name,
    required String mobile,
    required String email,
    required String companyId,
    required String password,
    required String currentUserId,
  }) async {
    // Verify current user is super admin of this company
    final companyDoc = await _firestore
        .collection('companies')
        .doc(companyId)
        .get();
    if (!companyDoc.exists ||
        !(companyDoc.data()?['admins'] as List).contains(currentUserId)) {
      throw FirebaseAuthException(
        code: 'permission-denied',
        message: 'Only super admins can create admins',
      );
    }

    await _validateMobileUniqueness(mobile);

    // Create user
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Create admin profile
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'uid': userCredential.user!.uid,
      'name': name,
      'mobile': mobile,
      'email': email,
      'companyId': companyId,
      'role': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Add to company admins
    await _firestore.collection('companies').doc(companyId).update({
      'admins': FieldValue.arrayUnion([userCredential.user!.uid]),
    });
  }

  // Create employee account (to be called by admins)
  Future<void> createEmployeeAccount({
    required String name,
    required String mobile,
    required String email,
    required String companyId,
    required String currentUserId,
  }) async {
    // Verify current user is admin of this company
    final companyDoc = await _firestore
        .collection('companies')
        .doc(companyId)
        .get();
    if (!companyDoc.exists ||
        !(companyDoc.data()?['admins'] as List).contains(currentUserId)) {
      throw FirebaseAuthException(
        code: 'permission-denied',
        message: 'Only admins can create employees',
      );
    }

    await _validateMobileUniqueness(mobile);
    const staticPassword = "Default@123"; // Should be changed after first login

    // Create user
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: staticPassword,
    );

    // Create employee profile
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'uid': userCredential.user!.uid,
      'name': name,
      'mobile': mobile,
      'email': email,
      'companyId': companyId,
      'role': 'employee',
      'createdAt': FieldValue.serverTimestamp(),
      'passwordChanged': false,
    });
  }

  // Sign up with email and password
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String company,
    required String mobile,
    required String designation,
  }) async {
    try {
      // Check if mobile already exists
      final mobileCheck = await _firestore
          .collection('users')
          .where('mobile', isEqualTo: mobile)
          .get();

      if (mobileCheck.docs.isNotEmpty) {
        throw FirebaseAuthException(
          code: 'mobile-already-in-use',
          message: 'This mobile number is already registered.',
        );
      }

      // Create user with email and password
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Add user details to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'company': company,
        'mobile': mobile,
        'designation': designation,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update display name
      await userCredential.user!.updateDisplayName(name);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'The password provided is too weak.',
        );
      } else if (e.code == 'email-already-in-use') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'The account already exists for that email.',
        );
      } else {
        throw FirebaseAuthException(
          code: e.code,
          message: e.message ?? 'An unknown error occurred.',
        );
      }
    } catch (e) {
      throw Exception('Failed to register: $e');
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String mobile,
    required String password,
  }) async {
    try {
      // Find user with the given mobile number
      final userQuery = await _firestore
          .collection('users')
          .where('mobile', isEqualTo: mobile)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found with this mobile number.',
        );
      }

      // Get user email from Firestore
      final userDoc = userQuery.docs.first;
      final userEmail = userDoc['email'] as String;

      // Sign in with email and password
      return await _auth.signInWithEmailAndPassword(
        email: userEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'No user found with this mobile number.',
        );
      } else if (e.code == 'wrong-password') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'Wrong password provided.',
        );
      } else {
        throw FirebaseAuthException(
          code: e.code,
          message: e.message ?? 'An unknown error occurred.',
        );
      }
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  // Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger the Google Sign In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google sign in was canceled by user');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Check if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        // Check if the user's email already exists in another account
        final email = userCredential.user?.email;
        if (email != null) {
          final emailCheck = await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .get();

          if (emailCheck.docs.isNotEmpty) {
            // Email exists but in a different auth method
            await userCredential.user?.delete();
            await _googleSignIn.signOut();

            throw FirebaseAuthException(
              code: 'email-already-exists',
              message:
                  'This email is already registered with a different method.',
            );
          }
        }

        // Generate a unique mobile ID for Google users if needed
        // You might want to prompt the user to provide this info instead
        final uniqueId = userCredential.user!.uid.substring(0, 10);

        // Save user data to Firestore
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': userCredential.user!.displayName ?? 'Google User',
          'email': userCredential.user!.email ?? '',
          'mobile': uniqueId, // You might want to collect this from the user
          'company': '', // Collect after signup
          'designation': '', // Collect after signup
          'photoURL': userCredential.user!.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'authProvider': 'google',
        });
      }

      return userCredential;
    } on PlatformException catch (e) {
      throw Exception('Failed to sign in with Google: ${e.message}');
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(
        code: e.code,
        message: e.message ?? 'An unknown error occurred.',
      );
    } catch (e) {
      throw Exception('Failed to sign in with Google: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(
        code: e.code,
        message: e.message ?? 'An unknown error occurred.',
      );
    } catch (e) {
      throw Exception('Failed to reset password: $e');
    }
  }

  // Reset password by mobile
  Future<void> resetPasswordByMobile(String mobile) async {
    try {
      // Find user with the given mobile number
      final userQuery = await _firestore
          .collection('users')
          .where('mobile', isEqualTo: mobile)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found with this mobile number.',
        );
      }

      // Get user email from Firestore
      final userDoc = userQuery.docs.first;
      final userEmail = userDoc['email'] as String;

      // Send password reset email
      await _auth.sendPasswordResetEmail(email: userEmail);
    } catch (e) {
      throw Exception('Failed to reset password: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Get user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      if (currentUser == null) {
        throw Exception('No user is currently signed in');
      }

      final doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (!doc.exists) {
        throw Exception('User profile not found');
      }

      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? name,
    String? company,
    String? mobile,
    String? designation,
  }) async {
    try {
      if (currentUser == null) {
        throw Exception('No user is currently signed in');
      }

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updates['name'] = name;
      if (company != null) updates['company'] = company;
      if (mobile != null) {
        // Check if mobile already exists for another user
        if (mobile.isNotEmpty) {
          final mobileCheck = await _firestore
              .collection('users')
              .where('mobile', isEqualTo: mobile)
              .where(FieldPath.documentId, isNotEqualTo: currentUser!.uid)
              .get();

          if (mobileCheck.docs.isNotEmpty) {
            throw Exception('This mobile number is already registered');
          }
        }

        updates['mobile'] = mobile;
      }
      if (designation != null) updates['designation'] = designation;

      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .update(updates);

      // Update display name if provided
      if (name != null) {
        await currentUser!.updateDisplayName(name);
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }
}
