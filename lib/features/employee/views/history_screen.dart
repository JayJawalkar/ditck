import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _attendanceHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceHistory();
  }

  Future<void> _fetchAttendanceHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('attendance')
            .doc(user.uid)
            .collection('records')
            .orderBy('date', descending: true)
            .limit(30)
            .get();

        setState(() {
          _attendanceHistory = querySnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'date': data['date']?.toDate(),
              'mark_in_time': data['mark_in_time']?.toDate(),
              'mark_out_time': data['mark_out_time']?.toDate(),
              'distance_traveled': data['distance_traveled'] ?? 0.0,
              'mark_in_selfie': data['mark_in_selfie'],
              'mark_out_selfie': data['mark_out_selfie'],
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching attendance history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _attendanceHistory.isEmpty
          ? const Center(child: Text('No attendance records found'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _attendanceHistory.length,
              itemBuilder: (context, index) {
                final record = _attendanceHistory[index];
                return _buildHistoryCard(record);
              },
            ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> record) {
    final date = record['date'] as DateTime;
    final markInTime = record['mark_in_time'] as DateTime?;
    final markOutTime = record['mark_out_time'] as DateTime?;
    final distance = record['distance_traveled'] as double;
    final markInSelfie = record['mark_in_selfie'] as String?;
    final markOutSelfie = record['mark_out_selfie'] as String?;

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
            Text(
              DateFormat('EEEE, MMMM d, y').format(date),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Iconsax.clock, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'In: ${markInTime != null ? DateFormat('hh:mm a').format(markInTime) : 'N/A'}',
                  style: const TextStyle(fontSize: 14),
                ),
                const Spacer(),
                const Icon(Iconsax.clock, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Out: ${markOutTime != null ? DateFormat('hh:mm a').format(markOutTime) : 'N/A'}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Iconsax.map, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Distance: ${distance.toStringAsFixed(2)} km',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (markInSelfie != null || markOutSelfie != null) ...[
              const Text(
                'Selfies:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (markInSelfie != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            _showImageDialog(markInSelfie, 'Mark In Selfie'),
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(markInSelfie),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (markOutSelfie != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            _showImageDialog(markOutSelfie, 'Mark Out Selfie'),
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(markOutSelfie),
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
