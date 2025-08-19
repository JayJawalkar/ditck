import 'dart:async';

import 'package:ditck/features/auth/views/sign_in_screen.dart';
import 'package:ditck/features/employee/views/history_screen.dart';
import 'package:ditck/features/employee/views/leave_application_screen.dart';
import 'package:ditck/features/employee/views/visit_screen.dart';
import 'package:ditck/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:io';

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key});

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen>
    with SingleTickerProviderStateMixin {
  // User data and state variables
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isMarkedIn = false;
  double _distanceTraveled = 0.0;
  int _visitsCompleted = 0;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  DateTime? _markInTime;
  List<Map<String, dynamic>> _activities = [];

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Camera variables
  CameraController? _cameraController;

  @override
  void initState() {
    super.initState();
    _initApp();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  Future<void> _initApp() async {
    await _requestPermissions();
    await _fetchUserData();
    await _checkCurrentStatus();
    await _initCamera();
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.location.request();
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          setState(() {
            _userData = doc.data()!;
          });
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkCurrentStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);

        final attendanceDoc = await FirebaseFirestore.instance
            .collection('attendance')
            .doc(user.uid)
            .collection('records')
            .where('date', isGreaterThanOrEqualTo: startOfDay)
            .where(
              'date',
              isLessThan: DateTime(today.year, today.month, today.day + 1),
            )
            .get();

        if (attendanceDoc.docs.isNotEmpty) {
          final record = attendanceDoc.docs.first.data();
          setState(() {
            _isMarkedIn = record['mark_out_time'] == null;
            _markInTime = record['mark_in_time']?.toDate();

            if (_isMarkedIn) {
              _startLocationTracking();
            }
          });
        }
      }
    } catch (e) {
      print('Error checking current status: $e');
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.medium,
        );
        await _cameraController!.initialize();
        setState(() {});
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _startLocationTracking() async {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            setState(() {
              _currentPosition = position;
            });
            _updateDistance(position);
          },
        );
  }

  void _updateDistance(Position newPosition) {
    if (_markInTime != null && _currentPosition != null) {
      // Calculate distance using Haversine formula
      double distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );

      setState(() {
        _distanceTraveled += distanceInMeters / 1000; // Convert to km
      });

      // Update Firestore with new distance
      _updateDistanceInFirestore();
    }
  }

  Future<void> _updateDistanceInFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);

        await FirebaseFirestore.instance
            .collection('attendance')
            .doc(user.uid)
            .collection('records')
            .where('date', isGreaterThanOrEqualTo: startOfDay)
            .where(
              'date',
              isLessThan: DateTime(today.year, today.month, today.day + 1),
            )
            .get()
            .then((querySnapshot) {
              if (querySnapshot.docs.isNotEmpty) {
                final docId = querySnapshot.docs.first.id;
                FirebaseFirestore.instance
                    .collection('attendance')
                    .doc(user.uid)
                    .collection('records')
                    .doc(docId)
                    .update({
                      'distance_traveled': _distanceTraveled,
                      'last_location': GeoPoint(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                    });
              }
            });
      }
    } catch (e) {
      print('Error updating distance: $e');
    }
  }

  Future<void> _markInWithSelfie() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Camera not ready')));
      return;
    }

    try {
      // Capture image
      final image = await _cameraController!.takePicture();
      setState(() {});

      // Upload image to Firebase Storage
      final String downloadUrl = await _uploadImage(image, 'mark_in_selfie');

      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Save to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('attendance')
            .doc(user.uid)
            .collection('records')
            .add({
              'user_id': user.uid,
              'mark_in_time': Timestamp.now(),
              'mark_in_selfie': downloadUrl,
              'mark_in_location': GeoPoint(
                position.latitude,
                position.longitude,
              ),
              'date': Timestamp.now(),
              'distance_traveled': 0.0,
            });

        setState(() {
          _isMarkedIn = true;
          _markInTime = DateTime.now();
          _distanceTraveled = 0.0;
        });

        _startLocationTracking();

        // Add to activity log
        _addActivity('Marked IN', 'You started your workday');

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Successfully marked IN')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error marking IN: $e')));
    }
  }

  Future<void> _markOutWithSelfie() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Camera not ready')));
      return;
    }

    try {
      // Capture image
      final image = await _cameraController!.takePicture();
      setState(() {});

      // Upload image to Firebase Storage
      final String downloadUrl = await _uploadImage(image, 'mark_out_selfie');

      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Update Firestore record
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);

        final attendanceDoc = await FirebaseFirestore.instance
            .collection('attendance')
            .doc(user.uid)
            .collection('records')
            .where('date', isGreaterThanOrEqualTo: startOfDay)
            .where(
              'date',
              isLessThan: DateTime(today.year, today.month, today.day + 1),
            )
            .get();

        if (attendanceDoc.docs.isNotEmpty) {
          final docId = attendanceDoc.docs.first.id;
          await FirebaseFirestore.instance
              .collection('attendance')
              .doc(user.uid)
              .collection('records')
              .doc(docId)
              .update({
                'mark_out_time': Timestamp.now(),
                'mark_out_selfie': downloadUrl,
                'mark_out_location': GeoPoint(
                  position.latitude,
                  position.longitude,
                ),
                'distance_traveled': _distanceTraveled,
              });
        }

        // Stop location tracking
        _positionStream?.cancel();

        setState(() {
          _isMarkedIn = false;
        });

        // Add to activity log
        _addActivity('Marked OUT', 'You ended your workday');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully marked OUT')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error marking OUT: $e')));
    }
  }

  Future<String> _uploadImage(XFile image, String type) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final Reference storageRef = FirebaseStorage.instance.ref().child(
        'users/${user.uid}/$type/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final UploadTask uploadTask = storageRef.putFile(File(image.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      throw e;
    }
  }

  void _addActivity(String title, String description) {
    setState(() {
      _activities.insert(0, {
        'title': title,
        'description': description,
        'time': DateTime.now(),
      });
    });
  }

  void _viewHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

  void _applyForLeave() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LeaveApplicationScreen()),
    );
  }

  void _startVisit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VisitScreen()),
    );
  }

  void _showMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );
  }

  Future<void> _logout() async {
    // Stop location tracking if active
    _positionStream?.cancel();

    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _cameraController?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    expandedHeight: 180.0,
                    floating: false,
                    pinned: true,
                    backgroundColor: const Color(0xFF1A237E),
                    flexibleSpace: FlexibleSpaceBar(
                      title: const Text(
                        'Employee Dashboard',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Iconsax.logout, color: Colors.white),
                        onPressed: _logout,
                        tooltip: 'Logout',
                      ),
                    ],
                  ),

                  // Welcome Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildWelcomeCard(),
                    ),
                  ),

                  // Stats Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildStatsOverview(),
                    ),
                  ),

                  // Mark In/Out Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildMarkInOutCard(),
                    ),
                  ),

                  // Quick Actions Title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        top: 16.0,
                        bottom: 8.0,
                      ),
                      child: Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ),

                  // Actions Grid
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildActionsGrid(),
                    ),
                  ),

                  // Recent Activity Title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        top: 24.0,
                        bottom: 8.0,
                      ),
                      child: Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ),

                  // Recent Activity List
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildRecentActivity(),
                    ),
                  ),

                  // Bottom Spacing
                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
                ],
              ),
            ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5C6BC0), Color(0xFF3949AB)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(Iconsax.user, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good ${_getTimeOfDay()},',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userData?['name'] ?? 'Employee',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userData?['role'] ?? 'Role not set',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.notification, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Distance Traveled',
            '${_distanceTraveled.toStringAsFixed(1)} km',
            Iconsax.map,
            const [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Visits Completed',
            '$_visitsCompleted',
            Iconsax.location,
            const [Color(0xFF66BB6A), Color(0xFF4CAF50)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Working Hours',
            _isMarkedIn ? _calculateWorkingHours() : '0.0 hrs',
            Iconsax.clock,
            const [Color(0xFFFFA726), Color(0xFFFF9800)],
          ),
        ),
      ],
    );
  }

  String _calculateWorkingHours() {
    if (_markInTime == null) return '0.0 hrs';

    final now = DateTime.now();
    final difference = now.difference(_markInTime!);
    final hours = difference.inMinutes / 60;
    return '${hours.toStringAsFixed(1)} hrs';
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    List<Color> colors,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors[1].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkInOutCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isMarkedIn ? Colors.green[50] : Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isMarkedIn ? Iconsax.login_1 : Iconsax.logout,
                    color: _isMarkedIn ? Colors.green : Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _isMarkedIn ? 'Currently Working' : 'Not Checked In',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isMarkedIn
                        ? _markOutWithSelfie
                        : _markInWithSelfie,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isMarkedIn
                          ? const Color(0xFFFF7043)
                          : const Color(0xFF66BB6A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isMarkedIn ? Iconsax.logout : Iconsax.login,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(_isMarkedIn ? 'Mark OUT' : 'Mark IN'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_isMarkedIn) ...[
              const SizedBox(height: 12),
              Text(
                'Marked in at ${DateFormat('hh:mm a').format(_markInTime!)}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionsGrid() {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      children: [
        _buildActionCard('Start Visit', Iconsax.location, const [
          Color(0xFF42A5F5),
          Color(0xFF1976D2),
        ], _startVisit),
        _buildActionCard('View Map', Iconsax.map_1, const [
          Color(0xFFAB47BC),
          Color(0xFF8E24AA),
        ], _showMap),
        _buildActionCard('Apply Leave', Iconsax.calendar_remove, const [
          Color(0xFFFFA726),
          Color(0xFFF57C00),
        ], _applyForLeave),
        _buildActionCard('View History', Iconsax.document_text, const [
          Color(0xFF66BB6A),
          Color(0xFF43A047),
        ], _viewHistory),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    List<Color> colors,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors[1].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (_activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'No activities yet',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: _activities
              .take(5)
              .map(
                (activity) => _buildActivityItem(
                  activity['title'],
                  activity['description'],
                  activity['time'],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String description, DateTime time) {
    IconData icon;
    Color color;

    switch (title) {
      case 'Marked IN':
        icon = Iconsax.login;
        color = Colors.green;
        break;
      case 'Marked OUT':
        icon = Iconsax.logout;
        color = Colors.blue;
        break;
      case 'Visit Started':
        icon = Iconsax.location;
        color = Colors.purple;
        break;
      case 'Visit Completed':
        icon = Iconsax.tick_circle;
        color = Colors.orange;
        break;
      default:
        icon = Iconsax.info_circle;
        color = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('hh:mm a').format(time),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}
