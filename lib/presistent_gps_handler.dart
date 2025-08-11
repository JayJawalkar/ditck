// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ditck/gps_data_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersistentGpsHandler extends TaskHandler {
  Timer? _locationTimer;
  Timer? _notificationTimer;
  Position? _lastPosition;
  double _totalDistance = 0.0;
  int _locationCount = 0;
  Timer? _heartbeatTimer;
  bool _isMoving = false;
  int _stationaryCount = 0;
  int _currentInterval = 10;
  final List<Map<String, dynamic>> _locationBatch = [];
  DateTime? _lastLocationTime;
  double _currentSpeed = 0.0;
  DateTime _serviceStartTime = DateTime.now();
  static const double MIN_ACCURACY = 50.0;
  static const double MIN_DISTANCE_THRESHOLD = 3.0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('🚀 Enhanced GPS tracker started at: $timestamp');
    _serviceStartTime = timestamp;

    try {
      await _initializeFirebase();

      // Initialize GPS data manager
      await GpsDataManager.startSession();

      // Check for crash recovery
      final prefs = await SharedPreferences.getInstance();
      final wasRunning = prefs.getBool('service_running') ?? false;
      if (wasRunning && starter == TaskStarter.developer) {
        await GpsDataManager.recordCrashRecovery();
      }

      await _loadPersistedState();

      // Start location tracking and other timers
      await _trackLocation();
      _locationTimer = Timer.periodic(Duration(seconds: _currentInterval), (
        _,
      ) async {
        await _trackLocationWithAdaptiveInterval();
      });

      _notificationTimer = Timer.periodic(Duration(seconds: 30), (_) async {
        await _updateContinuousNotification();
      });

      _heartbeatTimer = Timer.periodic(Duration(minutes: 2), (_) async {
        await _sendHeartbeat();
      });

      print('✅ Enhanced GPS tracker fully initialized');
    } catch (e) {
      print('❌ Error initializing GPS tracker: $e');
      await _restartService();
    }
  }

  Future<void> _trackLocationWithAdaptiveInterval() async {
    try {
      await _trackLocation();

      // Adaptive interval based on movement and speed
      if (_currentSpeed > 1.0) {
        _currentInterval = 5; // Moving fast - 5 seconds
      } else if (_currentSpeed > 0.3) {
        _currentInterval = 10; // Moving slowly - 10 seconds
      } else {
        _currentInterval = 30; // Stationary - 30 seconds
      }

      _rescheduleTimer();
    } catch (e) {
      print('❌ Error in adaptive location tracking: $e');
    }
  }

  void _rescheduleTimer() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(Duration(seconds: _currentInterval), (
      _,
    ) async {
      await _trackLocationWithAdaptiveInterval();
    });
  }

  Future<void> _trackLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('❌ Location permission denied in background');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: Duration(seconds: 20),
      ).timeout(Duration(seconds: 25));

      if (position.accuracy > MIN_ACCURACY) {
        print('⚠️ GPS accuracy too low: ${position.accuracy}m, skipping...');
        return;
      }

      _locationCount++;
      _currentSpeed = position.speed;
      final currentTime = DateTime.now();

      final locationString =
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

      if (_lastPosition != null) {
        final distance = _calculatePreciseDistance(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        final timeDiff = _lastLocationTime != null
            ? currentTime.difference(_lastLocationTime!).inSeconds
            : 0;
        final maxPossibleDistance = timeDiff * 50;

        if (distance > MIN_DISTANCE_THRESHOLD &&
            distance < maxPossibleDistance &&
            position.accuracy <= MIN_ACCURACY) {
          _totalDistance += distance;
          _isMoving = true;
          _stationaryCount = 0;

          print(
            '🛣️ Distance added: ${distance.toStringAsFixed(2)}m, Total: ${(_totalDistance / 1000).toStringAsFixed(3)}km',
          );
        } else if (distance <= MIN_DISTANCE_THRESHOLD) {
          _stationaryCount++;
          if (_stationaryCount >= 3) {
            _isMoving = false;
          }
        }
      }

      _lastPosition = position;
      _lastLocationTime = currentTime;

      await _saveLocationToFirestore(position);
      await _savePersistedState();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_location', locationString);
      await prefs.setDouble('total_distance', _totalDistance);
      await prefs.setDouble('current_speed', _currentSpeed);
    } catch (e) {
      print('❌ Error tracking location: $e');
      await _updateErrorNotification(e.toString());
    }
  }

  Future<void> _updateContinuousNotification() async {
    try {
      final now = DateTime.now();
      final duration = now.difference(_serviceStartTime);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;

      final durationText = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

      final speedKmh = _currentSpeed * 3.6;
      final movementStatus = _isMoving ? '🚶 Moving' : '🛑 Stationary';

      String notificationTitle = '🌍 GPS Tracker Active • $durationText';
      String notificationText =
          '📏 ${(_totalDistance / 1000).toStringAsFixed(2)}km • '
          '🚀 ${speedKmh.toStringAsFixed(1)}km/h • '
          '$movementStatus • '
          '📍 ${_locationCount} points';

      // Update notification with current status
      FlutterForegroundTask.updateService(
        notificationTitle: notificationTitle,
        notificationText: notificationText,
      );

      print('📱 Notification updated: ${notificationText}');
    } catch (e) {
      print('⚠️ Error updating notification: $e');
    }
  }

  Future<void> _updateErrorNotification(String error) async {
    try {
      FlutterForegroundTask.updateService(
        notificationTitle: '⚠️ GPS Tracker - Connection Issue',
        notificationText:
            'Attempting to reconnect GPS... ${error.substring(0, min(30, error.length))}',
      );
    } catch (e) {
      print('⚠️ Error updating error notification: $e');
    }
  }

  double _calculatePreciseDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (pi / 180);

  Future<void> _saveLocationToFirestore(Position position) async {
    try {
      // Save using enhanced data manager
      await GpsDataManager.saveLocationWithMetadata(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        altitude: position.altitude,
        totalDistance: _totalDistance,
        locationCount: _locationCount,
        isMoving: _isMoving,
        additionalData: {
          'batteryLevel': await _getBatteryLevel(),
          'networkType': await _getNetworkType(),
        },
      );
    } catch (e) {
      print('⚠️ Error saving location: $e');
    }
  }

  // Dummy implementation for battery level
  Future<double> _getBatteryLevel() async {
    // TODO: Replace with actual battery level fetching logic
    return 100.0;
  }

  // Dummy implementation for network type
  Future<String> _getNetworkType() async {
    // TODO: Replace with actual network type fetching logic
    return 'unknown';
  }

  Future<void> _saveBatchToFirestore() async {
    if (_locationBatch.isEmpty) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final location in _locationBatch) {
        final docRef = FirebaseFirestore.instance
            .collection('user_locations')
            .doc();
        batch.set(docRef, location);
      }

      await batch.commit();
      print('✅ Batch of ${_locationBatch.length} locations saved');
      _locationBatch.clear();
    } catch (e) {
      print('⚠️ Error saving batch to Firestore: $e');
    }
  }

  Future<void> _sendHeartbeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_heartbeat',
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setDouble('total_distance', _totalDistance);
      await prefs.setInt('location_count', _locationCount);
      await prefs.setDouble('current_speed', _currentSpeed);
      await prefs.setBool('is_moving', _isMoving);
      await prefs.setBool('service_running', true);

      print(
        '💓 Heartbeat sent - ${(_totalDistance / 1000).toStringAsFixed(2)}km',
      );
    } catch (e) {
      print('⚠️ Error sending heartbeat: $e');
    }
  }

  Future<void> _initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      print('🔥 Firebase initialized in background');
    } catch (e) {
      print('⚠️ Error initializing Firebase: $e');
    }
  }

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _totalDistance = prefs.getDouble('total_distance') ?? 0.0;
      _locationCount = prefs.getInt('location_count') ?? 0;
      print(
        '📱 Loaded persisted state - ${(_totalDistance / 1000).toStringAsFixed(2)}km',
      );
    } catch (e) {
      print('⚠️ Error loading persisted state: $e');
    }
  }

  Future<void> _savePersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('total_distance', _totalDistance);
      await prefs.setInt('location_count', _locationCount);
      await prefs.setDouble('current_speed', _currentSpeed);
      await prefs.setBool('is_moving', _isMoving);
    } catch (e) {
      print('⚠️ Error saving persisted state: $e');
    }
  }

  Future<void> _restartService() async {
    try {
      await GpsDataManager.recordRestart(reason: 'Service error recovery');
      print('🔄 Attempting service restart...');
      await Future.delayed(Duration(seconds: 5));

      _locationTimer?.cancel();
      _heartbeatTimer?.cancel();
      _notificationTimer?.cancel();

      // Restart timers
      _locationTimer = Timer.periodic(Duration(seconds: _currentInterval), (
        _,
      ) async {
        await _trackLocationWithAdaptiveInterval();
      });

      _heartbeatTimer = Timer.periodic(Duration(minutes: 2), (_) async {
        await _sendHeartbeat();
      });

      _notificationTimer = Timer.periodic(Duration(seconds: 30), (_) async {
        await _updateContinuousNotification();
      });

      print('✅ Service restarted successfully');
    } catch (e) {
      print('❌ Error during restart: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    print('🛑 GPS tracker destroyed at: $timestamp');

    // End GPS data session
    await GpsDataManager.endSession(
      reason: isTimeout ? 'Service timeout' : 'User stopped tracking',
    );

    await _saveBatchToFirestore();
    await _savePersistedState();

    _locationTimer?.cancel();
    _heartbeatTimer?.cancel();
    _notificationTimer?.cancel();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('service_running', false);

      // Final notification
      FlutterForegroundTask.updateService(
        notificationTitle: '🛑 GPS Tracker Stopped',
        notificationText:
            'Total distance: ${(_totalDistance / 1000).toStringAsFixed(2)}km',
      );
    } catch (e) {
      print('⚠️ Error in cleanup: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    print(
      '🔄 Service heartbeat: ${(_totalDistance / 1000).toStringAsFixed(2)}km tracked',
    );
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop_tracking') {
      print('🛑 Stop button pressed from notification');
      FlutterForegroundTask.stopService();
    }
  }
}
