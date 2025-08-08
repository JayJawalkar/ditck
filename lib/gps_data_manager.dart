// Add this new file: lib/services/gps_data_manager.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ditck/gps_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GpsDataManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection references
  static CollectionReference get _locationsCollection => 
      _firestore.collection('user_locations');
  static CollectionReference get _dailySummaryCollection => 
      _firestore.collection('daily_summaries');
  static CollectionReference get _monthlySummaryCollection => 
      _firestore.collection('monthly_summaries');
  static CollectionReference get _sessionEventsCollection => 
      _firestore.collection('session_events');

  // Current session tracking
  static String? _currentDateKey;
  static String? _currentMonthKey;
  static DateTime? _sessionStartTime;
  static Timer? _summaryUpdateTimer;

  /// Initialize data manager and start session
  static Future<void> startSession() async {
    try {
      final now = DateTime.now();
      _sessionStartTime = now;
      _currentDateKey = _formatDateKey(now);
      _currentMonthKey = _formatMonthKey(now);

      print('📊 Starting GPS data session: $_currentDateKey');

      // Record session start event
      await _recordSessionEvent(
        eventType: 'start',
        timestamp: now,
        reason: 'User initiated tracking',
        metadata: {
          'app_version': '1.0.0',
          'device_info': await _getDeviceInfo(),
        },
      );

      // Create/update daily summary
      await _initializeDailySummary();

      // Start periodic summary updates
      _startSummaryUpdates();

    } catch (e) {
      print('❌ Error starting GPS data session: $e');
    }
  }

  /// End current session
  static Future<void> endSession({String? reason}) async {
    try {
      if (_sessionStartTime == null) return;

      final now = DateTime.now();
      print('📊 Ending GPS data session: $_currentDateKey');

      // Record session end event
      await _recordSessionEvent(
        eventType: 'stop',
        timestamp: now,
        reason: reason ?? 'User stopped tracking',
        metadata: {
          'session_duration': now.difference(_sessionStartTime!).inSeconds,
        },
      );

      // Final summary update
      await _updateDailySummary(isSessionEnd: true);

      // Stop periodic updates
      _summaryUpdateTimer?.cancel();

      // Clear session data
      _sessionStartTime = null;
      _currentDateKey = null;
      _currentMonthKey = null;

    } catch (e) {
      print('❌ Error ending GPS data session: $e');
    }
  }

  /// Record session restart
  static Future<void> recordRestart({String? reason}) async {
    try {
      final now = DateTime.now();
      
      // Record restart event
      await _recordSessionEvent(
        eventType: 'restart',
        timestamp: now,
        reason: reason ?? 'Automatic service restart',
        metadata: {
          'previous_session_duration': _sessionStartTime != null 
              ? now.difference(_sessionStartTime!).inSeconds 
              : 0,
        },
      );

      // Update restart time
      _sessionStartTime = now;

      print('🔄 Recorded session restart: $reason');

    } catch (e) {
      print('❌ Error recording restart: $e');
    }
  }

  /// Record crash recovery
  static Future<void> recordCrashRecovery() async {
    try {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final lastHeartbeat = prefs.getInt('last_heartbeat') ?? 0;
      final crashDuration = now.millisecondsSinceEpoch - lastHeartbeat;

      await _recordSessionEvent(
        eventType: 'crash_recovery',
        timestamp: now,
        reason: 'Service recovered from unexpected termination',
        metadata: {
          'crash_duration_seconds': (crashDuration / 1000).round(),
          'last_heartbeat': DateTime.fromMillisecondsSinceEpoch(lastHeartbeat).toIso8601String(),
        },
      );

      print('🚑 Recorded crash recovery - downtime: ${(crashDuration/1000/60).toStringAsFixed(1)} minutes');

    } catch (e) {
      print('❌ Error recording crash recovery: $e');
    }
  }

  /// Save location with enhanced metadata
  static Future<void> saveLocationWithMetadata({
    required double latitude,
    required double longitude,
    required double accuracy,
    required double speed,
    required double heading,
    required double altitude,
    required double totalDistance,
    required int locationCount,
    required bool isMoving,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final now = DateTime.now();
      final dateKey = _formatDateKey(now);
      final monthKey = _formatMonthKey(now);

      final locationData = {
        'timestamp': FieldValue.serverTimestamp(),
        'dateKey': dateKey,
        'monthKey': monthKey,
        'lat': latitude,
        'lng': longitude,
        'accuracy': accuracy,
        'speed': speed,
        'heading': heading,
        'altitude': altitude,
        'totalDistance': totalDistance,
        'locationCount': locationCount,
        'isMoving': isMoving,
        'sessionId': _generateSessionId(),
        ...?additionalData,
      };

      await _locationsCollection.add(locationData);

      // Update current session keys if changed
      if (dateKey != _currentDateKey) {
        await _handleDateChange(dateKey, monthKey);
      }

    } catch (e) {
      print('❌ Error saving location with metadata: $e');
    }
  }

  /// Get locations for a specific date
  static Future<List<Map<String, dynamic>>> getLocationsByDate(String dateKey) async {
    try {
      final query = await _locationsCollection
          .where('dateKey', isEqualTo: dateKey)
          .orderBy('timestamp')
          .get();

      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();

    } catch (e) {
      print('❌ Error getting locations by date: $e');
      return [];
    }
  }

  /// Get locations for a date range
  static Future<List<Map<String, dynamic>>> getLocationsByDateRange(
    DateTime startDate, 
    DateTime endDate,
  ) async {
    try {
      final startTimestamp = Timestamp.fromDate(startDate);
      final endTimestamp = Timestamp.fromDate(endDate);

      final query = await _locationsCollection
          .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
          .where('timestamp', isLessThanOrEqualTo: endTimestamp)
          .orderBy('timestamp')
          .limit(5000) // Prevent excessive data loading
          .get();

      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();

    } catch (e) {
      print('❌ Error getting locations by date range: $e');
      return [];
    }
  }

  /// Get daily summary
  static Future<Map<String, dynamic>?> getDailySummary(String dateKey) async {
    try {
      final doc = await _dailySummaryCollection.doc(dateKey).get();
      return doc.exists ? doc.data() as Map<String, dynamic> : null;
    } catch (e) {
      print('❌ Error getting daily summary: $e');
      return null;
    }
  }

  /// Get monthly summary
  static Future<Map<String, dynamic>?> getMonthlySummary(String monthKey) async {
    try {
      final doc = await _monthlySummaryCollection.doc(monthKey).get();
      return doc.exists ? doc.data() as Map<String, dynamic> : null;
    } catch (e) {
      print('❌ Error getting monthly summary: $e');
      return null;
    }
  }

  /// Get session events for a date
  static Future<List<Map<String, dynamic>>> getSessionEvents(String dateKey) async {
    try {
      final startOfDay = DateTime.parse('$dateKey 00:00:00');
      final endOfDay = DateTime.parse('$dateKey 23:59:59');

      final query = await _sessionEventsCollection
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('timestamp')
          .get();

      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();

    } catch (e) {
      print('❌ Error getting session events: $e');
      return [];
    }
  }

  /// Get all tracking days for a month
  static Future<List<String>> getTrackingDaysInMonth(String monthKey) async {
    try {
      final query = await _dailySummaryCollection
          .where('monthKey', isEqualTo: monthKey)
          .orderBy('dateKey')
          .get();

      return query.docs.map((doc) => doc.id).toList();

    } catch (e) {
      print('❌ Error getting tracking days: $e');
      return [];
    }
  }

  /// Private helper methods
  static String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatMonthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  static String _generateSessionId() {
    return '${_currentDateKey}_${DateTime.now().millisecondsSinceEpoch}';
  }

  static Future<Map<String, dynamic>> _getDeviceInfo() async {
    // Add device info collection here
    return {
      'platform': 'android', // You can use device_info_plus package
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  static Future<void> _recordSessionEvent({
    required String eventType,
    required DateTime timestamp,
    String? reason,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final eventData = GpsDataModels.createSessionEvent(
        eventType: eventType,
        timestamp: timestamp,
        reason: reason,
        metadata: metadata,
      );

      await _sessionEventsCollection.add({
        'dateKey': _formatDateKey(timestamp),
        'monthKey': _formatMonthKey(timestamp),
        ...eventData,
      });

    } catch (e) {
      print('❌ Error recording session event: $e');
    }
  }

  static Future<void> _initializeDailySummary() async {
    try {
      if (_currentDateKey == null) return;

      final existingSummary = await getDailySummary(_currentDateKey!);
      
      if (existingSummary == null) {
        // Create new daily summary
        final summaryData = GpsDataModels.createDailySummary(
          dateKey: _currentDateKey!,
          monthKey: _currentMonthKey!,
          dailyDistance: 0.0,
          dailyPoints: 0,
          startTime: _sessionStartTime!,
          endTime: null,
          trackingDuration: Duration.zero,
          sessionEvents: [],
          maxSpeed: 0.0,
          avgSpeed: 0.0,
        );

        await _dailySummaryCollection.doc(_currentDateKey!).set(summaryData);
        print('📊 Created new daily summary: $_currentDateKey');
      } else {
        print('📊 Daily summary already exists: $_currentDateKey');
      }

    } catch (e) {
      print('❌ Error initializing daily summary: $e');
    }
  }

  static Future<void> _updateDailySummary({bool isSessionEnd = false}) async {
    try {
      if (_currentDateKey == null) return;

      // Get current day's locations
      final locations = await getLocationsByDate(_currentDateKey!);
      if (locations.isEmpty) return;

      // Calculate daily statistics
      final dailyStats = _calculateDailyStats(locations);
      
      // Get session events for the day
      final sessionEvents = await getSessionEvents(_currentDateKey!);

      final updateData = {
        'dailyDistance': dailyStats['totalDistance'],
        'dailyPoints': dailyStats['totalPoints'],
        'trackingDuration': dailyStats['trackingDuration'],
        'maxSpeed': dailyStats['maxSpeed'],
        'avgSpeed': dailyStats['avgSpeed'],
        'sessionEvents': sessionEvents,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isSessionEnd) {
        updateData['endTime'] = FieldValue.serverTimestamp();
        updateData['isActive'] = false;
      }

      await _dailySummaryCollection.doc(_currentDateKey!).update(updateData);

      // Also update monthly summary
      await _updateMonthlySummary();

      print('📊 Updated daily summary: $_currentDateKey');

    } catch (e) {
      print('❌ Error updating daily summary: $e');
    }
  }

  static Future<void> _updateMonthlySummary() async {
    try {
      if (_currentMonthKey == null) return;

      // Get all days in current month
      final monthDays = await getTrackingDaysInMonth(_currentMonthKey!);
      
      double totalDistance = 0.0;
      int totalPoints = 0;
      int restartCount = 0;
      DateTime? firstDate;
      DateTime? lastDate;
      Duration totalTrackingTime = Duration.zero;

      // Aggregate data from all days
      for (final dateKey in monthDays) {
        final dailySummary = await getDailySummary(dateKey);
        if (dailySummary != null) {
          totalDistance += (dailySummary['dailyDistance'] as num).toDouble();
          totalPoints += (dailySummary['dailyPoints'] as num).toInt();
          
          final date = DateTime.parse(dateKey);
          if (firstDate == null || date.isBefore(firstDate)) firstDate = date;
          if (lastDate == null || date.isAfter(lastDate)) lastDate = date;
          
          final duration = Duration(seconds: (dailySummary['trackingDuration'] as num).toInt());
          totalTrackingTime += duration;

          // Count restarts from session events
          final events = dailySummary['sessionEvents'] as List<dynamic>? ?? [];
          restartCount += events.where((e) => e['eventType'] == 'restart').length;
        }
      }

      if (firstDate != null && lastDate != null) {
        final summaryData = GpsDataModels.createMonthlySummary(
          monthKey: _currentMonthKey!,
          totalDistance: totalDistance,
          totalDays: monthDays.length,
          totalPoints: totalPoints,
          firstTrackingDate: firstDate,
          lastTrackingDate: lastDate,
          totalTrackingTime: totalTrackingTime,
          restartCount: restartCount,
        );

        await _monthlySummaryCollection.doc(_currentMonthKey!).set(summaryData, SetOptions(merge: true));
        print('📊 Updated monthly summary: $_currentMonthKey');
      }

    } catch (e) {
      print('❌ Error updating monthly summary: $e');
    }
  }

  static Map<String, dynamic> _calculateDailyStats(List<Map<String, dynamic>> locations) {
    if (locations.isEmpty) {
      return {
        'totalDistance': 0.0,
        'totalPoints': 0,
        'trackingDuration': 0,
        'maxSpeed': 0.0,
        'avgSpeed': 0.0,
      };
    }

    double totalDistance = 0.0;
    double maxSpeed = 0.0;
    double totalSpeed = 0.0;
    int speedCount = 0;

    // Find max distance from locations
    for (final location in locations) {
      final distance = (location['totalDistance'] as num?)?.toDouble() ?? 0.0;
      if (distance > totalDistance) totalDistance = distance;

      final speed = (location['speed'] as num?)?.toDouble() ?? 0.0;
      if (speed > maxSpeed) maxSpeed = speed;
      if (speed > 0) {
        totalSpeed += speed;
        speedCount++;
      }
    }

    // Calculate duration from first to last timestamp
    final firstTimestamp = locations.first['timestamp'] as Timestamp?;
    final lastTimestamp = locations.last['timestamp'] as Timestamp?;
    int duration = 0;
    
    if (firstTimestamp != null && lastTimestamp != null) {
      duration = lastTimestamp.seconds - firstTimestamp.seconds;
    }

    return {
      'totalDistance': totalDistance,
      'totalPoints': locations.length,
      'trackingDuration': duration,
      'maxSpeed': maxSpeed,
      'avgSpeed': speedCount > 0 ? totalSpeed / speedCount : 0.0,
    };
  }

  static void _startSummaryUpdates() {
    _summaryUpdateTimer?.cancel();
    _summaryUpdateTimer = Timer.periodic(Duration(minutes: 5), (_) async {
      await _updateDailySummary();
    });
  }

  static Future<void> _handleDateChange(String newDateKey, String newMonthKey) async {
    try {
      // End previous day's summary
      if (_currentDateKey != null) {
        await _updateDailySummary(isSessionEnd: true);
      }

      // Update current keys
      _currentDateKey = newDateKey;
      _currentMonthKey = newMonthKey;

      // Initialize new day's summary
      await _initializeDailySummary();

      print('📅 Date changed to: $newDateKey');

    } catch (e) {
      print('❌ Error handling date change: $e');
    }
  }
}