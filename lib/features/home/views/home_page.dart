import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final CollectionReference employeesRef = FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
      .collection('employees');

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTrialDialog());
  }

  Future<void> _checkTrialDialog() async {
    final snapshot = await employeesRef.get();
    if (snapshot.size < 3) {
      _showAddEmployeeDialog();
    }
  }

  Future<void> _showAddEmployeeDialog() async {
    if (!mounted) return;
    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    final emailController = TextEditingController();
    final cityController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Employee (Max 3)',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(height: 18),
              _buildTextField(nameController, 'Employee Name', Icons.person),
              const SizedBox(height: 12),
              _buildTextField(
                mobileController,
                'Mobile Number',
                Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                emailController,
                'Email ID',
                Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                cityController,
                'City of Working',
                Icons.location_city,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Add Employee',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () async {
                    if (nameController.text.isEmpty ||
                        mobileController.text.isEmpty ||
                        emailController.text.isEmpty ||
                        cityController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All fields are required'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    final snapshot = await employeesRef.get();
                    if (snapshot.size >= 3) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Trial allows max 3 employees'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      Navigator.of(context).pop();
                      return;
                    }
                    await employeesRef.add({
                      'name': nameController.text.trim(),
                      'mobile': mobileController.text.trim(),
                      'email': emailController.text.trim(),
                      'city': cityController.text.trim(),
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    Navigator.of(context).pop();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF8B5CF6)),
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
        ),
      ),
    );
  }

  Future<void> _deleteEmployee(String docId) async {
    await employeesRef.doc(docId).delete();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: const Color(0xFFF3F0FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Trial Employees',
          style: TextStyle(
            color: Color(0xFF7C3AED),
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Color(0xFF7C3AED)),
            tooltip: 'Add Employee',
            onPressed: () async {
              final snapshot = await employeesRef.get();
              if (snapshot.size < 3) {
                _showAddEmployeeDialog();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Trial allows max 3 employees'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF8B5CF6),
                  Color(0xFF7C3AED),
                  Color(0xFFF3F0FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          FutureBuilder<QuerySnapshot>(
            future: employeesRef.get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.group_add_rounded,
                        size: 80,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'No employees added yet.\nStart your trial by adding up to 3 employees.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF7C3AED),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        icon: const Icon(Icons.person_add),
                        label: const Text(
                          'Add Employee',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _showAddEmployeeDialog,
                      ),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 32,
                ),
                child: Builder(
                  builder: (context) {
                    // Start the animation when the list is built
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_controller.isAnimating &&
                          !_controller.isCompleted) {
                        _controller.forward();
                      }
                    });
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: Offset(1, 0),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: _controller,
                                  curve: Interval(
                                    0.1 * index,
                                    1.0,
                                    curve: Curves.easeOut,
                                  ),
                                ),
                              ),
                          child: Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF8B5CF6),
                                child: Text(
                                  data['name']?.substring(0, 1).toUpperCase() ??
                                      '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                data['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mobile: ${data['mobile'] ?? ''}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  Text(
                                    'Email: ${data['email'] ?? ''}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  Text(
                                    'City: ${data['city'] ?? ''}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteEmployee(doc.id),
                                tooltip: 'Remove',
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<QuerySnapshot>(
        future: employeesRef.get(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          if (docs.length < 3) {
            return FloatingActionButton.extended(
              backgroundColor: const Color(0xFF7C3AED),
              icon: const Icon(Icons.person_add),
              label: const Text('Add Employee'),
              onPressed: _showAddEmployeeDialog,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
