import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthServiceClient {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper: normalize phone (very simple). You should replace with libphonenumber parsing for production.
  String? normalizePhoneSimple(String raw, {String countryPrefix = '+91'}) {
    // naive: strip non-digits, ensure leading +
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) return null;
    if (digits.startsWith('0')) return '+$digits'.replaceFirst('+0', '+'); // crude
    if (!digits.startsWith(countryPrefix.replaceAll('+',''))) {
      return '$countryPrefix$digits'.replaceAll('++', '+');
    }
    return '+$digits';
  }

  /// Reserve a phone in phones/<phone> using a Firestore transaction.
  /// Returns true if reserved successfully (document created). Throws on failure.
  Future<void> reservePhone(String e164Phone, String reservedByUid) async {
    final docRef = _firestore.collection('phones').doc(e164Phone);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      if (snapshot.exists) {
        throw FirebaseException(
            plugin: 'AuthServiceClient',
            message: 'Phone already reserved or in use.');
      }
      tx.set(docRef, {
        'reservedBy': reservedByUid,
        'reservedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Release a reserved phone (best-effort).
  Future<void> releasePhone(String e164Phone) async {
    final docRef = _firestore.collection('phones').doc(e164Phone);
    try {
      await docRef.delete();
    } catch (e) {
      // ignore - best effort
    }
  }

  /// Check phone exists in users collection (extra guard).
  Future<bool> phoneExists(String e164Phone) async {
    final q = await _firestore.collection('users').where('phone', isEqualTo: e164Phone).limit(1).get();
    return q.docs.isNotEmpty;
  }

  /// Create new user (admin/employee) *from client*.
  ///
  /// IMPORTANT: This will sign out the current user and sign in as the newly created one,
  /// then sign back in the original user using their email+password (superAdminPassword).
  ///
  /// Params:
  /// - creatorEmail/creatorPassword = super admin credentials used to sign back in
  /// - newEmail/newPassword = credentials for new user (we will create using these)
  /// - role = 'admin' or 'employee'
  /// - phone = E.164 normalized phone
  /// - department = optional
  ///
  /// Returns: Map { success: bool, message: String }
  Future<Map<String, dynamic>> createUserClientSide({
    required String creatorEmail,
    required String creatorPassword,
    required String newEmail,
    required String newPassword,
    required String newName,
    required String e164Phone,
    required String role, // 'admin' or 'employee'
    String department = '',
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return {'success': false, 'message': 'No authenticated user.'};
    }

    // 1) Double-check phone not already present
    final exists = await phoneExists(e164Phone);
    if (exists) {
      return {'success': false, 'message': 'Phone already in use.'};
    }

    // 2) Reserve phone doc
    try {
      await reservePhone(e164Phone, currentUser.uid);
    } catch (e) {
      return {'success': false, 'message': 'Phone reservation failed: ${e.toString()}.'};
    }

    String? newUid;
    UserCredential? newlyCreatedCredential;

    // store current user's email to sign back later (we need it)
    final String signedInEmail = currentUser.email ?? creatorEmail;

    try {
      // 3) Sign out current (super admin) user
      await _auth.signOut();

      // 4) Create new user using Firebase Auth
      newlyCreatedCredential = await _auth.createUserWithEmailAndPassword(
        email: newEmail,
        password: newPassword,
      );
      final createdUser = newlyCreatedCredential.user;
      newUid = createdUser!.uid;

      // Optional: set display name
      await createdUser.updateDisplayName(newName);

      // 5) Create Firestore user doc
      final doc = {
        'email': newEmail,
        'phone': e164Phone,
        'name': newName,
        'role': role,
        'department': role == 'admin' ? department : '',
        'createdBy': currentUser.uid, // NOTE: currentUser is null now (we signed out). We'll set createdBy to reservedByUid instead:
        'createdAt': FieldValue.serverTimestamp(),
      };

      // To avoid losing `createdBy`, use the reserve doc reservedBy value's UID as creator.
      final phoneDoc = await _firestore.collection('phones').doc(e164Phone).get();
      final reservedBy = phoneDoc.exists ? phoneDoc.get('reservedBy') as String? : null;
      if (reservedBy != null) {
        doc['createdBy'] = reservedBy;
      }

      await _firestore.collection('users').doc(newUid).set(doc);

      // 6) Update phone reservation to indicate it is now owned
      await _firestore.collection('phones').doc(e164Phone).set({
        'ownerUid': newUid,
        'ownerEmail': newEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 7) Sign out newly created user
      await _auth.signOut();

      // 8) Sign back in as original Super Admin using provided credentials
      final signBack = await _auth.signInWithEmailAndPassword(
        email: creatorEmail,
        password: creatorPassword,
      );

      // success
      return {'success': true, 'message': 'User created successfully', 'uid': newUid};
    } catch (e) {
      // Rollback attempts
      try {
        // if auth user created but we are not able to create Firestore doc etc., try deleting the auth user
        if (newUid != null) {
          // Signing in as the created user to delete themselves isn't allowed in client SDK.
          // But we can attempt to sign in as that user (we currently are signed out or signed back in).
          // If we are still signed out, try to sign in as newly created to delete - but this is best-effort.
          try {
            await _auth.signInWithEmailAndPassword(email: newEmail, password: newPassword);
            final u = _auth.currentUser;
            if (u != null && u.uid == newUid) {
              await u.delete(); // delete the created user
            }
            // sign out again
            await _auth.signOut();
          } catch (_) {
            // ignore - cannot force delete if not possible from client
          }
        }
        // delete phone reservation / ownership doc
        await releasePhone(e164Phone);
      } catch (_) {}

      // try to sign back in as creator
      try {
        await _auth.signInWithEmailAndPassword(email: creatorEmail, password: creatorPassword);
      } catch (_) {
        // If this fails, the admin will need to sign in manually — we can't restore password.
      }

      return {'success': false, 'message': 'Creation failed: ${e.toString()}'};
    }
  }
}
