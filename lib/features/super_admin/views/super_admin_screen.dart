import 'dart:math';
import 'dart:ui';
import 'package:ditck/features/auth/views/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen>
    with SingleTickerProviderStateMixin {
  final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  late CollectionReference adminsRef;
  Map<String, dynamic>? ownerData;
  bool isLoading = true;
  bool showAddButton = true;
  final Map<String, bool> _passwordVisibility = {};
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    adminsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('admins');

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _fetchOwnerDetails();
      _checkAdminCount();
    });
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    }
  }

  // Password generation function
  String _generatePassword() {
    const length = 12;
    const letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    const symbols = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

    String chars = '$letters$numbers$symbols';
    Random random = Random.secure();

    return List.generate(length, (index) {
      final index = random.nextInt(chars.length);
      return chars[index];
    }).join('');
  }

  Future<void> _fetchOwnerDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        setState(() {
          ownerData = doc.data();
        });
      }
    } catch (e) {
      _showError('Failed to load owner details: ${e.toString()}');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _checkAdminCount() async {
    try {
      final snapshot = await adminsRef.get();
      setState(() => showAddButton = snapshot.size < 3);
    } catch (e) {
      _showError('Failed to check admin count: ${e.toString()}');
    }
  }

  Future<void> _shareCredentialsWhatsApp(
    String phone,
    String email,
    String password,
    String role,
  ) async {
    final message = Uri.encodeComponent(
      "Hello,\nHere are your admin credentials:\n"
      "Email: $email\n"
      "Password: $password\n"
      "Role: $role\n"
      "Please keep them safe.",
    );

    // Direct WhatsApp scheme
    final uri = Uri.parse("whatsapp://send?phone=$phone&text=$message");

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showError(
        "Could not open WhatsApp. Please make sure it’s installed and logged in.",
      );
    }
  }

  void _showAdminForm({String? docId, Map<String, dynamic>? adminData}) {
    if (!mounted) return;

    final nameController = TextEditingController(text: adminData?['name']);
    final phoneController = TextEditingController(text: adminData?['phone']);
    final emailController = TextEditingController(text: adminData?['email']);
    final departmentController = TextEditingController(
      text: adminData?['department'],
    );
    final roleController = TextEditingController(text: adminData?['role']);
    final passwordController = TextEditingController(
      text: adminData?['password'],
    );
    DateTime? employmentDate = adminData?['employmentDate']?.toDate();
    String status = adminData?['status'] ?? "Active";

    // Error states
    String? nameError;
    String? phoneError;
    String? emailError;
    String? departmentError;
    String? roleError;
    String? passwordError;
    String? dateError;
    bool obscurePassword = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        docId == null ? 'Add Admin' : 'Edit Admin',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Name
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.person,
                            color: Color(0xFF8B5CF6),
                          ),
                          labelText: 'Admin Name',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF8B5CF6),
                              width: 2,
                            ),
                          ),
                          errorText: nameError,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Phone
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                        ],
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.phone,
                            color: Color(0xFF8B5CF6),
                          ),
                          labelText: 'Phone Number (with country code)',
                          hintText: 'e.g. +919876543210',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF8B5CF6),
                              width: 2,
                            ),
                          ),
                          errorText: phoneError,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Email
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.email,
                            color: Color(0xFF8B5CF6),
                          ),
                          labelText: 'Email ID',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF8B5CF6),
                              width: 2,
                            ),
                          ),
                          errorText: emailError,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Department
                      TextField(
                        controller: departmentController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.work,
                            color: Color(0xFF8B5CF6),
                          ),
                          labelText: 'Department',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF8B5CF6),
                              width: 2,
                            ),
                          ),
                          errorText: departmentError,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Role
                      TextField(
                        controller: roleController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.security,
                            color: Color(0xFF8B5CF6),
                          ),
                          labelText: 'Role',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF8B5CF6),
                              width: 2,
                            ),
                          ),
                          errorText: roleError,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Password
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.lock,
                            color: Color(0xFF8B5CF6),
                          ),
                          labelText: 'Password',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF8B5CF6),
                              width: 2,
                            ),
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: const Color(0xFF8B5CF6),
                                ),
                                onPressed: () => setModalState(
                                  () => obscurePassword = !obscurePassword,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.autorenew,
                                  color: Color(0xFF8B5CF6),
                                ),
                                onPressed: () => passwordController.text =
                                    _generatePassword(),
                              ),
                            ],
                          ),
                          errorText: passwordError,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Employment Date
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.calendar_today,
                          color: Color(0xFF8B5CF6),
                        ),
                        title: Text(
                          employmentDate == null
                              ? "Select Employment Date"
                              : DateFormat(
                                  'dd/MM/yyyy',
                                ).format(employmentDate!),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: employmentDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setModalState(() {
                              employmentDate = picked;
                              dateError = null;
                            });
                          }
                        },
                      ),
                      if (dateError != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, top: 4),
                          child: Text(
                            dateError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Status
                      DropdownButtonFormField<String>(
                        value: status,
                        items: ["Active", "Inactive"]
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        decoration: InputDecoration(
                          labelText: "Status",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (val) => status = val!,
                      ),
                      const SizedBox(height: 24),

                      // Buttons
                      Row(
                        children: [
                          if (docId != null)
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Delete'),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _confirmDelete(docId);
                                },
                              ),
                            ),
                          if (docId != null) const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                docId == null ? 'Add Admin' : 'Update',
                              ),
                              onPressed: () async {
                                // Reset errors
                                setModalState(() {
                                  nameError = phoneError = emailError =
                                      departmentError = roleError =
                                          passwordError = dateError = null;
                                });

                                bool isValid = true;

                                // Validations
                                if (nameController.text.isEmpty) {
                                  nameError = "Name is required";
                                  isValid = false;
                                }
                                if (phoneController.text.isEmpty) {
                                  phoneError = "Phone is required";
                                  isValid = false;
                                } else {
                                  final cleanedPhone = phoneController.text
                                      .replaceAll(' ', '');
                                  if (!cleanedPhone.startsWith('+')) {
                                    phoneError =
                                        "Must include country code (e.g. +91)";
                                    isValid = false;
                                  } else if (!RegExp(
                                    r'^\+[0-9]{7,15}$',
                                  ).hasMatch(cleanedPhone)) {
                                    phoneError =
                                        "Invalid phone format. Example: +919876543210";
                                    isValid = false;
                                  }
                                }
                                if (emailController.text.isEmpty) {
                                  emailError = "Email is required";
                                  isValid = false;
                                } else if (!RegExp(
                                  r'^.+@[a-zA-Z]+\.[a-zA-Z]+(\.?[a-zA-Z]+)*$',
                                ).hasMatch(emailController.text.trim())) {
                                  emailError = "Invalid email format";
                                  isValid = false;
                                }
                                if (departmentController.text.isEmpty) {
                                  departmentError = "Department is required";
                                  isValid = false;
                                }
                                if (roleController.text.isEmpty) {
                                  roleError = "Role is required";
                                  isValid = false;
                                }
                                if (docId == null &&
                                    passwordController.text.isEmpty) {
                                  passwordError = "Password is required";
                                  isValid = false;
                                } else if (passwordController.text.isNotEmpty &&
                                    passwordController.text.length < 8) {
                                  passwordError =
                                      "Password must be at least 8 characters";
                                  isValid = false;
                                }
                                if (employmentDate == null) {
                                  dateError = "Employment date is required";
                                  isValid = false;
                                }

                                if (!isValid) {
                                  setModalState(() {});
                                  return;
                                }

                                try {
                                  final cleanedPhone = phoneController.text
                                      .replaceAll(' ', '');
                                  final now = Timestamp.now();

                                  if (docId == null) {
                                    // Limit
                                    final snapshot = await adminsRef.get();
                                    if (snapshot.size >= 3) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Maximum of 3 admins allowed.",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    // Unique phone
                                    final duplicate = await adminsRef
                                        .where('phone', isEqualTo: cleanedPhone)
                                        .get();
                                    if (duplicate.docs.isNotEmpty) {
                                      phoneError = "Phone already registered";
                                      setModalState(() {});
                                      return;
                                    }

                                    // Create Firebase Auth user
                                    UserCredential cred = await FirebaseAuth
                                        .instance
                                        .createUserWithEmailAndPassword(
                                          email: emailController.text.trim(),
                                          password: passwordController.text
                                              .trim(),
                                        );
                                    final uid = cred.user!.uid;

                                    // Admin data
                                    final adminDoc = {
                                      'name': nameController.text.trim(),
                                      'phone': cleanedPhone,
                                      'email': emailController.text.trim(),
                                      'department': departmentController.text
                                          .trim(),
                                      'role': roleController.text.trim(),
                                      'password': passwordController.text
                                          .trim(),
                                      'employmentDate': employmentDate,
                                      'status': status,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                      'uid': uid,
                                    };

                                    // Users data
                                    final userDoc = {
                                      'active': true,
                                      'created_at': now,
                                      'email': emailController.text.trim(),
                                      'email_verified': false,
                                      'last_login': null,
                                      'mobile': cleanedPhone,
                                      'name': nameController.text.trim(),
                                      'org_id': "DeCAOtmEHuRW9Av4UbMA",
                                      'role': "ADMIN",
                                      'uid': uid,
                                    };

                                    await adminsRef.doc(uid).set(adminDoc);
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(uid)
                                        .set(userDoc);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Admin added successfully',
                                        ),
                                        backgroundColor: Colors.green,
                                        action: SnackBarAction(
                                          label: 'COPY PASSWORD',
                                          textColor: Colors.white,
                                          onPressed: () {
                                            Clipboard.setData(
                                              ClipboardData(
                                                text: passwordController.text,
                                              ),
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Password copied',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  } else {
                                    // Update both collections
                                    final updateData = {
                                      'name': nameController.text.trim(),
                                      'phone': cleanedPhone,
                                      'email': emailController.text.trim(),
                                      'department': departmentController.text
                                          .trim(),
                                      'role': roleController.text.trim(),
                                      'password':
                                          passwordController.text.isNotEmpty
                                          ? passwordController.text.trim()
                                          : adminData?['password'],
                                      'employmentDate': employmentDate,
                                      'status': status,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    };

                                    await adminsRef
                                        .doc(docId)
                                        .update(updateData);
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(docId)
                                        .update({
                                          'email': emailController.text.trim(),
                                          'mobile': cleanedPhone,
                                          'name': nameController.text.trim(),
                                          'role': "ADMIN",
                                        });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Admin updated successfully',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }

                                  Navigator.pop(context);
                                  setState(() {});
                                  _checkAdminCount();
                                } catch (e) {
                                  _showError('Operation failed: $e');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await adminsRef.doc(docId).delete();
        setState(() {});
        _checkAdminCount();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        _showError('Delete failed: ${e.toString()}');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      body: Column(
        children: [
          _buildHeader(
            onTap: () {
              _logout(context);
            },
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Color(0xFF7C3AED)),
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: adminsRef.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error.toString()}'),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(
                              Color(0xFF7C3AED),
                            ),
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.group_off,
                                size: 60,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "No Admins Added",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Add up to 3 admins",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (showAddButton)
                                ElevatedButton.icon(
                                  onPressed: () => _showAdminForm(),
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: const Text('Add First Admin'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C3AED),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          final docId = docs[index].id;
                          return _buildAdminCard(data, docId);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: showAddButton
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF7C3AED),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add Admin'),
              onPressed: () => _showAdminForm(),
            )
          : null,
    );
  }

  Widget _buildHeader({required VoidCallback onTap}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Admin Management",
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.logout),
                  onPressed: onTap,
                  tooltip: 'Logout',
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (ownerData != null) ...[
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 30,
                    child: Text(
                      ownerData!['name']?.substring(0, 1).toUpperCase() ?? 'O',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Owner: ${_truncate(ownerData!['name'])}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Org ID: ${_maskOrgId(ownerData!['org_id'])}",
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: adminsRef.snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.size ?? 0;
                    return _buildStatCard(
                      count.toString(),
                      "Admins",
                      Icons.group,
                    );
                  },
                ),
                _buildStatCard("3", "Max Limit", Icons.lock),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _maskOrgId(String? orgId) {
    if (orgId == null || orgId.isEmpty) return '';
    final visiblePart = orgId.length > 5 ? orgId.substring(0, 5) : orgId;
    final hiddenPart = '*' * (orgId.length - visiblePart.length);
    return '$visiblePart$hiddenPart';
  }

  /// Helper to truncate to 5 characters or words
  String _truncate(String? text) {
    if (text == null) return '';
    // For words: take first 5 words
    final words = text.split(' ');
    if (words.length > 1) {
      return words.take(5).join(' ');
    }
    // For single long word (like org ID): take first 5 chars
    return text.length > 5 ? text.substring(0, 5) : text;
  }

  Widget _buildAdminCard(Map<String, dynamic> data, String docId) {
    final date = data['employmentDate'] != null
        ? (data['employmentDate'] as Timestamp).toDate()
        : null;
    final isVisible = _passwordVisibility[docId] ?? false;
    final isActive = data['status'] == 'Active';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status badge and action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green[50] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? Colors.green : Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    data['status'] ?? 'Inactive',
                    style: TextStyle(
                      color: isActive ? Colors.green[800] : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Row(
                  children: [
                    _buildActionButton(
                      icon: Icons.edit,
                      label: 'Edit',
                      color: const Color(0xFF7C3AED),
                      onPressed: () =>
                          _showAdminForm(docId: docId, adminData: data),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.share,
                      label: 'Share',
                      color: Colors.blue,
                      onPressed: () => _shareCredentialsWhatsApp(
                        data['phone'] ?? '',
                        data['email'] ?? '',
                        data['password'] ?? '',
                        data['role'] ?? '',
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.delete,
                      label: 'Delete',
                      color: Colors.red,
                      onPressed: () => _confirmDelete(docId),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Information Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.phone, data['phone'] ?? 'Not provided'),
                  const Divider(height: 20, thickness: 0.5),
                  _buildInfoRow(Icons.email, data['email'] ?? 'Not provided'),
                  const Divider(height: 20, thickness: 0.5),
                  _buildInfoRow(
                    Icons.work,
                    "Role: ${data['role'] ?? 'Unknown'}",
                  ),
                  if (date != null) ...[
                    const Divider(height: 20, thickness: 0.5),
                    _buildInfoRow(
                      Icons.calendar_today,
                      "Joined: ${DateFormat('dd MMM yyyy').format(date)}",
                    ),
                  ],
                ],
              ),
            ),

            // Password Section
            if (data['password'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, size: 20, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isVisible ? data['password'] : '••••••••',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isVisible ? Colors.black : Colors.grey[700],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isVisible ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF7C3AED),
                      ),
                      splashRadius: 20,
                      onPressed: () {
                        setState(() {
                          _passwordVisibility[docId] = !isVisible;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],

            // Footer Actions
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () =>
                      _showAdminForm(docId: docId, adminData: data),
                  child: const Text(
                    'EDIT DETAILS',
                    style: TextStyle(color: Color(0xFF7C3AED)),
                  ),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () => _confirmDelete(docId),
                  child: const Text(
                    'DELETE ACCOUNT',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for action buttons
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label, style: TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
    );
  }

  // Helper widget for info rows
  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
