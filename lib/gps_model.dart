// Add this new file: lib/models/gps_data_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class GpsDataModels {
  // Monthly summary model
  static Map<String, dynamic> createMonthlySummary({
    required String monthKey, // Format: "2024-08"
    required double totalDistance,
    required int totalDays,
    required int totalPoints,
    required DateTime firstTrackingDate,
    required DateTime lastTrackingDate,
    required Duration totalTrackingTime,
    required int restartCount,
  }) {
    return {
      'monthKey': monthKey,
      'totalDistance': totalDistance,
      'totalDays': totalDays,
      'totalPoints': totalPoints,
      'firstTrackingDate': Timestamp.fromDate(firstTrackingDate),
      'lastTrackingDate': Timestamp.fromDate(lastTrackingDate),
      'totalTrackingTime': totalTrackingTime.inSeconds,
      'restartCount': restartCount,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Daily summary model
  static Map<String, dynamic> createDailySummary({
    required String dateKey, // Format: "2024-08-07"
    required String monthKey, // Format: "2024-08"
    required double dailyDistance,
    required int dailyPoints,
    required DateTime startTime,
    required DateTime? endTime,
    required Duration trackingDuration,
    required List<Map<String, dynamic>> sessionEvents,
    required double maxSpeed,
    required double avgSpeed,
  }) {
    return {
      'dateKey': dateKey,
      'monthKey': monthKey,
      'dailyDistance': dailyDistance,
      'dailyPoints': dailyPoints,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime) : null,
      'trackingDuration': trackingDuration.inSeconds,
      'sessionEvents': sessionEvents,
      'maxSpeed': maxSpeed,
      'avgSpeed': avgSpeed,
      'isActive': endTime == null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Session event model (for tracking starts/stops)
  static Map<String, dynamic> createSessionEvent({
    required String eventType, // 'start', 'stop', 'restart', 'crash_recovery'
    required DateTime timestamp,
    String? reason,
    Map<String, dynamic>? metadata,
  }) {
    return {
      'eventType': eventType,
      'timestamp': Timestamp.fromDate(timestamp),
      'reason': reason,
      'metadata': metadata ?? {},
    };
  }
}