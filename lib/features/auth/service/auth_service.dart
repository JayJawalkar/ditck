// auth_service.dart
// Centralized Auth + Tenancy service for Flutter (Firebase)
// Enhanced version with better error handling, validation, and security practices

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collections
  CollectionReference get _orgs => _db.collection('organizations');
  CollectionReference get _users => _db.collection('users');
  CollectionReference get _subscriptions => _db.collection('subscriptions');

  /// Create organization doc and OWNER user (super-admin).
  /// Enhanced with better validation and error handling
  Future<void> createCompanyAndSuperAdmin({
    required String companyName,
    required String companyMobile,
    required String companyEmail,
    required String superAdminName,
    required String superAdminMobile,
    required String superAdminEmail,
    required String superAdminPassword,
  }) async {
    // Enhanced validation
    _validateCompanyData(companyName, companyEmail, companyMobile);
    _validateUserData(
      superAdminName,
      superAdminEmail,
      superAdminMobile,
      superAdminPassword,
    );

    // Check for duplicate mobile or email across users
    await _checkDuplicateCredentials(superAdminMobile, superAdminEmail);

    // Use batch write for atomic operations
    final batch = _db.batch();
    DocumentReference? orgRef;
    UserCredential? userCredential;

    try {
      // Step 1: Create Firebase Auth user first
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: superAdminEmail.trim(),
        password: superAdminPassword,
      );

      final uid = userCredential.user!.uid;

      // Step 2: Create organization document
      orgRef = _orgs.doc();
      batch.set(orgRef, {
        'name': companyName.trim(),
        'mobile': companyMobile.trim(),
        'email': companyEmail.trim(),
        'created_at': FieldValue.serverTimestamp(),
        'status': 'trial',
        'plan_id': null,
        'subscription_id': null,
        'owner_id': uid,
        'active': true,
      });

      // Step 3: Create user document with OWNER role
      final userRef = _users.doc(uid);
      batch.set(userRef, {
        'org_id': orgRef.id,
        'role': 'OWNER',
        'name': superAdminName.trim(),
        'email': superAdminEmail.trim(),
        'mobile': superAdminMobile.trim(),
        'created_at': FieldValue.serverTimestamp(),
        'active': true,
        'email_verified': false,
        'last_login': null,
      });

      // Commit batch transaction
      await batch.commit();

      // Step 4: Send verification email
      try {
        await userCredential.user!.sendEmailVerification();
      } catch (emailError) {
        // Log email error but don't fail the entire process
        print('Warning: Could not send verification email: $emailError');
      }

      // Step 5: Update user display name
      try {
        await userCredential.user!.updateDisplayName(superAdminName.trim());
      } catch (displayNameError) {
        print('Warning: Could not update display name: $displayNameError');
      }
    } catch (e) {
      // Rollback: Delete Firebase Auth user if it was created
      if (userCredential?.user != null) {
        try {
          await userCredential!.user!.delete();
        } catch (deleteError) {
          print('Error rolling back user creation: $deleteError');
        }
      }

      // Re-throw the original error
      rethrow;
    }
  }

  /// Enhanced validation for company data
  void _validateCompanyData(String name, String email, String mobile) {
    if (name.trim().isEmpty) {
      throw Exception('Company name is required');
    }
    if (name.trim().length < 2) {
      throw Exception('Company name must be at least 2 characters long');
    }
    if (!_isValidEmail(email)) {
      throw Exception('Invalid company email format');
    }
    if (!_isValidMobile(mobile)) {
      throw Exception('Invalid company mobile number format');
    }
  }

  /// Enhanced validation for user data
  void _validateUserData(
    String name,
    String email,
    String mobile,
    String password,
  ) {
    if (name.trim().isEmpty) {
      throw Exception('Owner name is required');
    }
    if (name.trim().length < 2) {
      throw Exception('Owner name must be at least 2 characters long');
    }
    if (!_isValidEmail(email)) {
      throw Exception('Invalid owner email format');
    }
    if (!_isValidMobile(mobile)) {
      throw Exception('Invalid owner mobile number format');
    }
    if (!_isValidPassword(password)) {
      throw Exception(
        'Password must be at least 8 characters with uppercase, lowercase, and number',
      );
    }
  }

  /// Check for duplicate credentials
  Future<void> _checkDuplicateCredentials(String mobile, String email) async {
    // Check mobile
    final mobileQuery = await _users
        .where('mobile', isEqualTo: mobile.trim())
        .limit(1)
        .get();
    if (mobileQuery.docs.isNotEmpty) {
      throw FirebaseAuthException(
        code: 'mobile-already-in-use',
        message: 'Mobile number is already registered',
      );
    }

    // Check email
    final emailQuery = await _users
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();
    if (emailQuery.docs.isNotEmpty) {
      throw FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'Email address is already registered',
      );
    }
  }

  /// Email validation
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim());
  }

  /// Mobile validation
  bool _isValidMobile(String mobile) {
    return RegExp(r'^[+]?[0-9]{10,15}$').hasMatch(mobile.trim());
  }

  /// Password validation
  bool _isValidPassword(String password) {
    return password.length >= 8 &&
        RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(password);
  }

  /// Sign in with mobile + password. Enhanced with better error handling.
  Future<User?> signInWithMobileAndPassword({
    required String mobile,
    required String password,
  }) async {
    if (!_isValidMobile(mobile)) {
      throw FirebaseAuthException(
        code: 'invalid-mobile',
        message: 'Invalid mobile number format',
      );
    }

    // Find user by mobile
    final query = await _users
        .where('mobile', isEqualTo: mobile.trim())
        .where('active', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No active account found with this mobile number',
      );
    }

    final userData = query.docs.first.data() as Map<String, dynamic>;
    final email = userData['email']?.toString() ?? '';

    if (email.isEmpty) {
      throw FirebaseAuthException(
        code: 'no-email',
        message: 'User account has no email linked',
      );
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last login timestamp
      await _users.doc(credential.user!.uid).update({
        'last_login': FieldValue.serverTimestamp(),
      });

      return credential.user;
    } catch (e) {
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'wrong-password':
            throw FirebaseAuthException(
              code: 'wrong-password',
              message: 'Incorrect password',
            );
          case 'user-disabled':
            throw FirebaseAuthException(
              code: 'user-disabled',
              message: 'This account has been disabled',
            );
          default:
            rethrow;
        }
      }
      rethrow;
    }
  }

  /// Enhanced sign up with better validation
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String orgId,
    required String role, // ADMIN / EMPLOYEE
    String? mobile,
    String? designation,
  }) async {
    // Validate inputs
    _validateUserData(name, email, mobile ?? '', password);

    if (!['ADMIN', 'EMPLOYEE'].contains(role.toUpperCase())) {
      throw Exception('Invalid role. Must be ADMIN or EMPLOYEE');
    }

    // Verify organization exists
    final orgDoc = await _orgs.doc(orgId).get();
    if (!orgDoc.exists) {
      throw Exception('Organization not found');
    }

    // Check for duplicates
    await _checkDuplicateCredentials(mobile ?? '', email);

    UserCredential? userCredential;

    try {
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = userCredential.user!.uid;

      await _users.doc(uid).set({
        'org_id': orgId,
        'role': role.toUpperCase(),
        'name': name.trim(),
        'email': email.trim(),
        'mobile': mobile?.trim() ?? '',
        'designation': designation?.trim() ?? '',
        'created_at': FieldValue.serverTimestamp(),
        'active': true,
        'email_verified': false,
        'last_login': null,
      });

      // Update display name
      try {
        await userCredential.user!.updateDisplayName(name.trim());
      } catch (e) {
        print('Warning: Could not update display name: $e');
      }

      // Send verification email
      try {
        await userCredential.user!.sendEmailVerification();
      } catch (e) {
        print('Warning: Could not send verification email: $e');
      }
    } catch (e) {
      // Rollback user creation if Firestore operation fails
      if (userCredential?.user != null) {
        try {
          await userCredential!.user!.delete();
        } catch (deleteError) {
          print('Error rolling back user creation: $deleteError');
        }
      }
      rethrow;
    }
  }

  /// Enhanced invite user with better security practices
  Future<void> inviteUser({
    required String orgId,
    required String name,
    required String email,
    required String role, // ADMIN | EMPLOYEE
    String? mobile,
    String? designation,
  }) async {
    // Validate inputs
    if (name.trim().isEmpty) throw Exception('Name is required');
    if (!_isValidEmail(email)) throw Exception('Invalid email format');
    if (!['ADMIN', 'EMPLOYEE'].contains(role.toUpperCase())) {
      throw Exception('Invalid role. Must be ADMIN or EMPLOYEE');
    }

    // Verify organization exists and get org data
    final orgDoc = await _orgs.doc(orgId).get();
    if (!orgDoc.exists) {
      throw Exception('Organization not found');
    }

    // Check for duplicate email
    final dupEmail = await _users
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();
    if (dupEmail.docs.isNotEmpty) {
      throw FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'Email address is already registered',
      );
    }

    // Check mobile if provided
    if (mobile != null && mobile.trim().isNotEmpty) {
      if (!_isValidMobile(mobile)) {
        throw Exception('Invalid mobile number format');
      }
      final dupMobile = await _users
          .where('mobile', isEqualTo: mobile.trim())
          .limit(1)
          .get();
      if (dupMobile.docs.isNotEmpty) {
        throw FirebaseAuthException(
          code: 'mobile-already-in-use',
          message: 'Mobile number is already registered',
        );
      }
    }

    // Generate a secure temporary password
    final tempPassword = _generateSecureTempPassword();
    UserCredential? userCredential;

    try {
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: tempPassword,
      );

      final uid = userCredential.user!.uid;

      await _users.doc(uid).set({
        'org_id': orgId,
        'role': role.toUpperCase(),
        'name': name.trim(),
        'email': email.trim(),
        'mobile': mobile?.trim() ?? '',
        'designation': designation?.trim() ?? '',
        'created_at': FieldValue.serverTimestamp(),
        'invited': true,
        'invited_at': FieldValue.serverTimestamp(),
        'active': true,
        'email_verified': false,
        'temp_password_used': false,
        'last_login': null,
      });

      // Update display name
      try {
        await userCredential.user!.updateDisplayName(name.trim());
      } catch (e) {
        print('Warning: Could not update display name: $e');
      }

      // Send password reset email immediately so they can set their own password
      await _auth.sendPasswordResetEmail(email: email.trim());

      // TODO: In production, send a custom welcome email with company info
      // This could include company name, role information, and next steps
    } catch (e) {
      // Rollback user creation
      if (userCredential?.user != null) {
        try {
          await userCredential!.user!.delete();
        } catch (deleteError) {
          print('Error rolling back user creation: $deleteError');
        }
      }
      rethrow;
    }
  }

  /// Generate a more secure temporary password
  String _generateSecureTempPassword() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
    final random = Random.secure();
    final buffer = StringBuffer();

    // Ensure at least one of each required character type
    buffer.write('A'); // Uppercase
    buffer.write('a'); // Lowercase
    buffer.write('1'); // Number
    buffer.write('!'); // Special char

    // Add random characters to make it 16 characters total
    for (int i = 4; i < 16; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }

    // Shuffle the string
    final list = buffer.toString().split('');
    list.shuffle(random);
    return list.join();
  }

  /// Enhanced user profile fetching with error handling
  Future<Map<String, dynamic>> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user',
      );
    }

    final doc = await _users.doc(user.uid).get();
    if (!doc.exists) {
      throw FirebaseAuthException(
        code: 'profile-not-found',
        message: 'User profile not found',
      );
    }

    final data = doc.data() as Map<String, dynamic>;

    // Check if user is active
    if (data['active'] != true) {
      throw FirebaseAuthException(
        code: 'user-disabled',
        message: 'User account has been disabled',
      );
    }

    return data;
  }

  /// Enhanced profile update with validation
  Future<void> updateUserProfile({
    String? company,
    String? designation,
    String? name,
    String? mobile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user',
      );
    }

    final updateData = <String, dynamic>{
      'updated_at': FieldValue.serverTimestamp(),
    };

    if (company != null && company.trim().isNotEmpty) {
      updateData['company'] = company.trim();
    }
    if (designation != null && designation.trim().isNotEmpty) {
      updateData['designation'] = designation.trim();
    }
    if (name != null && name.trim().isNotEmpty) {
      if (name.trim().length < 2) {
        throw Exception('Name must be at least 2 characters long');
      }
      updateData['name'] = name.trim();

      // Also update Firebase Auth display name
      try {
        await user.updateDisplayName(name.trim());
      } catch (e) {
        print('Warning: Could not update display name: $e');
      }
    }
    if (mobile != null && mobile.trim().isNotEmpty) {
      if (!_isValidMobile(mobile)) {
        throw Exception('Invalid mobile number format');
      }

      // Check for duplicate mobile
      final dupQuery = await _users
          .where('mobile', isEqualTo: mobile.trim())
          .where(FieldPath.documentId, isNotEqualTo: user.uid)
          .limit(1)
          .get();
      if (dupQuery.docs.isNotEmpty) {
        throw Exception('Mobile number is already in use');
      }

      updateData['mobile'] = mobile.trim();
    }

    if (updateData.length > 1) {
      // More than just updated_at
      await _users.doc(user.uid).update(updateData);
    }
  }

  /// Standard sign in with email & password (enhanced)
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (!_isValidEmail(email)) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Invalid email format',
      );
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update last login timestamp
      if (credential.user != null) {
        await _users.doc(credential.user!.uid).update({
          'last_login': FieldValue.serverTimestamp(),
        });
      }

      return credential.user;
    } catch (e) {
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            throw FirebaseAuthException(
              code: 'user-not-found',
              message: 'No account found with this email',
            );
          case 'wrong-password':
            throw FirebaseAuthException(
              code: 'wrong-password',
              message: 'Incorrect password',
            );
          case 'user-disabled':
            throw FirebaseAuthException(
              code: 'user-disabled',
              message: 'This account has been disabled',
            );
          case 'too-many-requests':
            throw FirebaseAuthException(
              code: 'too-many-requests',
              message: 'Too many failed attempts. Please try again later',
            );
          default:
            rethrow;
        }
      }
      rethrow;
    }
  }

  /// Sign out with cleanup
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error during sign out: $e');
      rethrow;
    }
  }

  /// Send password reset email with validation
  Future<void> sendPasswordReset(String email) async {
    if (!_isValidEmail(email)) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Invalid email format',
      );
    }

    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            throw FirebaseAuthException(
              code: 'user-not-found',
              message: 'No account found with this email',
            );
          default:
            rethrow;
        }
      }
      rethrow;
    }
  }

  /// Fetch current user role and organization info
  Future<Map<String, dynamic>> fetchCurrentUserRoleOrg() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user',
      );
    }

    final userDoc = await _users.doc(user.uid).get();
    if (!userDoc.exists) {
      throw FirebaseAuthException(
        code: 'profile-not-found',
        message: 'User profile not found',
      );
    }

    final userData = userDoc.data() as Map<String, dynamic>;

    // Check if user is active
    if (userData['active'] != true) {
      throw FirebaseAuthException(
        code: 'user-disabled',
        message: 'User account has been disabled',
      );
    }

    // Fetch organization info
    final orgId = userData['org_id'];
    if (orgId != null) {
      final orgDoc = await _orgs.doc(orgId).get();
      if (orgDoc.exists) {
        final orgData = orgDoc.data() as Map<String, dynamic>;
        userData['organization'] = {
          'id': orgId,
          'name': orgData['name'],
          'status': orgData['status'],
        };
      }
    }

    return {
      'user_id': user.uid,
      'org_id': userData['org_id'],
      'role': userData['role'],
      'name': userData['name'],
      'email': userData['email'],
      'mobile': userData['mobile'],
      'designation': userData['designation'],
      'organization': userData['organization'],
      'email_verified': user.emailVerified,
    };
  }

  /// Create or update subscription (for webhook handlers)
  Future<void> createOrUpdateSubscription(
    String orgId,
    Map<String, dynamic> payload,
  ) async {
    try {
      // Update subscription document
      await _subscriptions.doc(orgId).set({
        ...payload,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update organization document
      final updateData = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (payload.containsKey('plan_id')) {
        updateData['plan_id'] = payload['plan_id'];
      }
      if (payload.containsKey('status')) {
        updateData['status'] = payload['status'];
      }
      if (payload.containsKey('subscription_id')) {
        updateData['subscription_id'] = payload['subscription_id'];
      }

      if (updateData.length > 1) {
        await _orgs.doc(orgId).update(updateData);
      }
    } catch (e) {
      print('Error updating subscription: $e');
      rethrow;
    }
  }

  /// Check if current user is admin or owner
  Future<bool> isAdminOrOwner() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _users.doc(user.uid).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      if (data['active'] != true) return false;

      final role = data['role']?.toString().toUpperCase();
      return role == 'OWNER' || role == 'ADMIN';
    } catch (e) {
      print('Error checking admin/owner status: $e');
      return false;
    }
  }

  /// Check if current user is owner
  Future<bool> isOwner() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _users.doc(user.uid).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      if (data['active'] != true) return false;

      return data['role']?.toString().toUpperCase() == 'OWNER';
    } catch (e) {
      print('Error checking owner status: $e');
      return false;
    }
  }

  /// Get organization members (for admin/owner)
  Future<List<Map<String, dynamic>>> getOrganizationMembers(
    String orgId,
  ) async {
    try {
      final query = await _users
          .where('org_id', isEqualTo: orgId)
          .where('active', isEqualTo: true)
          .orderBy('created_at', descending: false)
          .get();

      return query.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'],
          'email': data['email'],
          'mobile': data['mobile'],
          'role': data['role'],
          'designation': data['designation'],
          'created_at': data['created_at'],
          'last_login': data['last_login'],
          'invited': data['invited'] ?? false,
        };
      }).toList();
    } catch (e) {
      print('Error fetching organization members: $e');
      rethrow;
    }
  }

  /// Deactivate user (soft delete)
  Future<void> deactivateUser(String userId) async {
    try {
      await _users.doc(userId).update({
        'active': false,
        'deactivated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error deactivating user: $e');
      rethrow;
    }
  }

  /// Reactivate user
  Future<void> reactivateUser(String userId) async {
    try {
      await _users.doc(userId).update({
        'active': true,
        'reactivated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error reactivating user: $e');
      rethrow;
    }
  }

  /// Update user role (admin/owner only)
  Future<void> updateUserRole(String userId, String newRole) async {
    if (!['ADMIN', 'EMPLOYEE', 'OWNER'].contains(newRole.toUpperCase())) {
      throw Exception('Invalid role');
    }

    try {
      await _users.doc(userId).update({
        'role': newRole.toUpperCase(),
        'role_updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user role: $e');
      rethrow;
    }
  }

  /// Get current user stream for real-time updates
  Stream<Map<String, dynamic>?> getCurrentUserStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _users.doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      return {...data, 'id': doc.id, 'email_verified': user.emailVerified};
    });
  }

  /// Get authentication state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get current user
  User? get currentUser => _auth.currentUser;
}
