import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

class VisitScreen extends StatefulWidget {
  const VisitScreen({Key? key}) : super(key: key);

  @override
  _VisitScreenState createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> {
  final TextEditingController _notesController = TextEditingController();
  List<Map<String, dynamic>> _visits = [];
  bool _isLoading = true;
  CameraController? _cameraController;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _fetchVisits();
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

  Future<void> _fetchVisits() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);

        final querySnapshot = await FirebaseFirestore.instance
            .collection('visits')
            .doc(user.uid)
            .collection('records')
            .where('date', isGreaterThanOrEqualTo: startOfDay)
            .where(
              'date',
              isLessThan: DateTime(today.year, today.month, today.day + 1),
            )
            .orderBy('check_in_time', descending: true)
            .get();

        setState(() {
          _visits = querySnapshot.docs.map((doc) => doc.data()).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching visits: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkIn() async {
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
      final String downloadUrl = await _uploadImage(image, 'visit_check_in');

      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Save to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('visits')
            .doc(user.uid)
            .collection('records')
            .add({
              'user_id': user.uid,
              'check_in_time': Timestamp.now(),
              'check_in_selfie': downloadUrl,
              'check_in_location': GeoPoint(
                position.latitude,
                position.longitude,
              ),
              'date': Timestamp.now(),
              'notes': _notesController.text,
              'status': 'checked_in',
            });

        _notesController.clear();
        await _fetchVisits();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully checked in')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error checking in: $e')));
    }
  }

  Future<void> _checkOut(String visitId) async {
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
      final String downloadUrl = await _uploadImage(image, 'visit_check_out');

      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Update Firestore record
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('visits')
            .doc(user.uid)
            .collection('records')
            .doc(visitId)
            .update({
              'check_out_time': Timestamp.now(),
              'check_out_selfie': downloadUrl,
              'check_out_location': GeoPoint(
                position.latitude,
                position.longitude,
              ),
              'status': 'completed',
            });

        await _fetchVisits();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully checked out')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error checking out: $e')));
    }
  }

  Future<String> _uploadImage(XFile image, String type) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final Reference storageRef = FirebaseStorage.instance.ref().child(
        'users/${user.uid}/visits/$type/${DateTime.now().millisecondsSinceEpoch}.jpg',
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

  @override
  void dispose() {
    _cameraController?.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visit Management'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _visits.isEmpty
                ? const Center(child: Text('No visits today'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _visits.length,
                    itemBuilder: (context, index) {
                      final visit = _visits[index];
                      return _buildVisitCard(visit);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Visit Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _checkIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF66BB6A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Check In to Visit'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> visit) {
    final checkInTime = visit['check_in_time']?.toDate();
    final checkOutTime = visit['check_out_time']?.toDate();
    final status = visit['status'];
    final notes = visit['notes'];
    final checkInSelfie = visit['check_in_selfie'];
    final checkOutSelfie = visit['check_out_selfie'];
    final visitId = visit['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  status == 'completed' ? Iconsax.tick_circle : Iconsax.clock,
                  color: status == 'completed' ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  status == 'completed' ? 'Completed' : 'In Progress',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: status == 'completed' ? Colors.green : Colors.orange,
                  ),
                ),
                const Spacer(),
                if (status == 'checked_in')
                  ElevatedButton(
                    onPressed: () => _checkOut(visitId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7043),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Check Out'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Check In: ${checkInTime != null ? DateFormat('hh:mm a').format(checkInTime) : 'N/A'}',
              style: const TextStyle(fontSize: 14),
            ),
            if (checkOutTime != null) ...[
              const SizedBox(height: 4),
              Text(
                'Check Out: ${DateFormat('hh:mm a').format(checkOutTime)}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: $notes',
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (checkInSelfie != null || checkOutSelfie != null) ...[
              const Text(
                'Visit Photos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (checkInSelfie != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            _showImageDialog(checkInSelfie, 'Check In Photo'),
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(checkInSelfie),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (checkOutSelfie != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            _showImageDialog(checkOutSelfie, 'Check Out Photo'),
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(checkOutSelfie),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showImageDialog(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Image.network(imageUrl),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
