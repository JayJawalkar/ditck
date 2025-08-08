import 'dart:async';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  List<LatLng> _routeCoordinates = [];
  bool _isLoading = true;
  String _statusMessage = 'Loading route data...';
  LatLng? _currentPosition;
  double _totalDistance = 0.0;
  int _totalLocations = 0;
  bool _showRoadRoute = true;
  Timer? _refreshTimer;

  // Google Maps API Key - replace with your actual key
  static const String _googleMapsApiKey =
      "AIzaSyBfz-1RoLBgkCZvKy8Qx--RyGNB-NW3xmU";

  @override
  void initState() {
    super.initState();
    _loadRouteData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    // Auto-refresh map every 30 seconds when service is active
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _loadRouteData();
    });
  }

  Future<void> _loadRouteData() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Fetching latest GPS data...';
      });

      // Get latest location data with limit for performance
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('user_locations')
          .orderBy('timestamp', descending: false)
          .limit(1000) // Limit to last 1000 points for performance
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage =
              'No GPS data found. Start tracking to see your route!';
        });
        return;
      }

      List<LatLng> coordinates = [];
      LatLng? startPoint;
      LatLng? endPoint;

      // Process location data with filtering for better performance
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final lat = data['lat'] as double;
        final lng = data['lng'] as double;

        final coordinate = LatLng(lat, lng);

        // Filter out points that are too close together (< 10 meters)
        if (coordinates.isEmpty ||
            _calculateDistance(
                  coordinates.last.latitude,
                  coordinates.last.longitude,
                  lat,
                  lng,
                ) >
                10.0) {
          coordinates.add(coordinate);
        }

        if (startPoint == null) startPoint = coordinate;
        endPoint = coordinate;
      }

      // Calculate total distance
      double calculatedDistance = 0.0;
      for (int i = 1; i < coordinates.length; i++) {
        calculatedDistance += _calculateDistance(
          coordinates[i - 1].latitude,
          coordinates[i - 1].longitude,
          coordinates[i].latitude,
          coordinates[i].longitude,
        );
      }

      setState(() {
        _routeCoordinates = coordinates;
        _totalDistance = calculatedDistance;
        _totalLocations = snapshot.docs.length;
        _currentPosition = endPoint;
      });

      // Create road-based route if enabled
      if (_showRoadRoute && coordinates.length > 1) {
        await _createRoadBasedRoute(coordinates);
      } else if (coordinates.length > 1) {
        _createDirectRoute(coordinates);
      }

      // Add markers
      if (startPoint != null && endPoint != null) {
        _addMarkers(startPoint, endPoint);
      }

      setState(() {
        _isLoading = false;
        _statusMessage =
            'Route loaded - ${coordinates.length} points, ${(_totalDistance / 1000).toStringAsFixed(2)}km';
      });

      // Fit map to show route
      if (coordinates.isNotEmpty && _mapController != null) {
        Future.delayed(Duration(milliseconds: 500), () {
          _fitMapToRoute(coordinates);
        });
      }
    } catch (e) {
      print('❌ Error loading route data: $e');
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading route: $e';
      });
    }
  }

  Future<void> _createRoadBasedRoute(List<LatLng> coordinates) async {
    try {
      setState(() {
        _statusMessage = 'Creating road-based route...';
      });

      List<LatLng> roadRoute = [];

      // Process coordinates in chunks to avoid API limits
      for (int i = 0; i < coordinates.length - 1; i += 10) {
        int endIndex = math.min(i + 10, coordinates.length - 1);

        if (i < endIndex) {
          final chunkRoute = await _getDirectionsRoute(
            coordinates[i],
            coordinates[endIndex],
          );

          if (chunkRoute.isNotEmpty) {
            roadRoute.addAll(chunkRoute);

            // Add delay to respect API rate limits
            await Future.delayed(Duration(milliseconds: 200));
          }
        }
      }

      if (roadRoute.isNotEmpty) {
        setState(() {
        });
        _createRoadPolyline(roadRoute);
      } else {
        // Fallback to direct route
        _createDirectRoute(coordinates);
      }
    } catch (e) {
      print('⚠️ Error creating road route, using direct route: $e');
      _createDirectRoute(coordinates);
    }
  }

  Future<List<LatLng>> _getDirectionsRoute(LatLng start, LatLng end) async {
    try {
      final String url =
          'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${start.latitude},${start.longitude}&'
          'destination=${end.latitude},${end.longitude}&'
          'mode=driving&'
          'key=$_googleMapsApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final String encodedPolyline =
              data['routes'][0]['overview_polyline']['points'];
          return _decodePolyline(encodedPolyline);
        }
      }
    } catch (e) {
      print('⚠️ Error getting directions: $e');
    }

    return [];
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polylineCoordinates = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      LatLng position = LatLng(lat / 1E5, lng / 1E5);
      polylineCoordinates.add(position);
    }

    return polylineCoordinates;
  }

  void _createRoadPolyline(List<LatLng> coordinates) {
    final Polyline roadPolyline = Polyline(
      polylineId: const PolylineId('road_route'),
      points: coordinates,
      color: Colors.blue,
      width: 5,
      patterns: [],
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );

    // Add direct route as reference with different color
    final Polyline directPolyline = Polyline(
      polylineId: const PolylineId('direct_route'),
      points: _routeCoordinates,
      color: Colors.red.withOpacity(0.5),
      width: 2,
      patterns: [PatternItem.dash(10), PatternItem.gap(5)],
    );

    setState(() {
      _polylines.clear();
      _polylines.addAll([roadPolyline, directPolyline]);
    });
  }

  void _createDirectRoute(List<LatLng> coordinates) {
    final Polyline polyline = Polyline(
      polylineId: const PolylineId('direct_route'),
      points: coordinates,
      color: Colors.blue,
      width: 4,
      patterns: [],
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );

    setState(() {
      _polylines.clear();
      _polylines.add(polyline);
    });
  }

  void _addMarkers(LatLng startPoint, LatLng endPoint) {
    final Marker startMarker = Marker(
      markerId: const MarkerId('start_point'),
      position: startPoint,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(
        title: '🚀 Start Point',
        snippet: 'Journey started here',
      ),
    );

    final Marker endMarker = Marker(
      markerId: const MarkerId('end_point'),
      position: endPoint,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: '📍 Current Position',
        snippet: 'Distance: ${(_totalDistance / 1000).toStringAsFixed(2)}km',
      ),
    );

    // Add waypoint markers every 1km
    List<Marker> waypointMarkers = [];
    double accumulatedDistance = 0.0;
    int waypointNumber = 1;

    for (int i = 1; i < _routeCoordinates.length; i++) {
      double segmentDistance = _calculateDistance(
        _routeCoordinates[i - 1].latitude,
        _routeCoordinates[i - 1].longitude,
        _routeCoordinates[i].latitude,
        _routeCoordinates[i].longitude,
      );

      accumulatedDistance += segmentDistance;

      if (accumulatedDistance >= 1000 && waypointNumber <= 20) {
        // Max 20 waypoints
        waypointMarkers.add(
          Marker(
            markerId: MarkerId('waypoint_$waypointNumber'),
            position: _routeCoordinates[i],
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: InfoWindow(
              title: '📍 ${waypointNumber}km',
              snippet:
                  'Waypoint at ${(accumulatedDistance / 1000).toStringAsFixed(1)}km',
            ),
          ),
        );
        accumulatedDistance = 0.0;
        waypointNumber++;
      }
    }

    setState(() {
      _markers.clear();
      _markers.addAll([startMarker, endMarker, ...waypointMarkers]);
    });
  }

  void _fitMapToRoute(List<LatLng> coordinates) {
    if (coordinates.isEmpty || _mapController == null) return;

    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLng = coordinates.first.longitude;
    double maxLng = coordinates.first.longitude;

    for (LatLng coordinate in coordinates) {
      minLat = coordinate.latitude < minLat ? coordinate.latitude : minLat;
      maxLat = coordinate.latitude > maxLat ? coordinate.latitude : maxLat;
      minLng = coordinate.longitude < minLng ? coordinate.longitude : minLng;
      maxLng = coordinate.longitude > maxLng ? coordinate.longitude : maxLng;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100.0,
      ),
    );
  }

  double _calculateDistance(
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

  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🗺️ Travel Route'),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showRoadRoute ? Icons.stream : Icons.timeline),
            onPressed: () {
              setState(() {
                _showRoadRoute = !_showRoadRoute;
              });
              _loadRouteData();
            },
            tooltip: _showRoadRoute ? 'Show Direct Route' : 'Show Road Route',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRouteData,
            tooltip: 'Refresh Route',
          ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced Stats Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade100, Colors.blue.shade50],
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(
                      '📏 Distance',
                      '${(_totalDistance / 1000).toStringAsFixed(2)} km',
                      Colors.blue,
                    ),
                    _buildStatItem(
                      '📍 Points',
                      '$_totalLocations',
                      Colors.orange,
                    ),
                    _buildStatItem(
                      '🛣️ Route',
                      _showRoadRoute ? 'Road' : 'Direct',
                      Colors.green,
                    ),
                    _buildStatItem(
                      '⏱️ Status',
                      _isLoading ? 'Loading...' : 'Ready',
                      _isLoading ? Colors.grey : Colors.green,
                    ),
                  ],
                ),
                if (_statusMessage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _statusMessage,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),

          // Map
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading your travel route...'),
                      ],
                    ),
                  )
                : _routeCoordinates.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No route data available',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start GPS tracking to see your route!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : GoogleMap(
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                      print('🗺️ Map controller initialized');

                      if (_routeCoordinates.isNotEmpty) {
                        Future.delayed(Duration(milliseconds: 1000), () {
                          _fitMapToRoute(_routeCoordinates);
                        });
                      }
                    },
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition ?? const LatLng(0, 0),
                      zoom: 15,
                    ),
                    polylines: _polylines,
                    markers: _markers,
                    mapType: MapType.normal,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    compassEnabled: true,
                    trafficEnabled: true, // Show traffic for road routes
                  ),
          ),
        ],
      ),
      floatingActionButton: !_isLoading && _routeCoordinates.isNotEmpty
          ? FloatingActionButton(
              onPressed: () {
                if (_mapController != null) {
                  _fitMapToRoute(_routeCoordinates);
                }
              },
              backgroundColor: Colors.blue,
              child: const Icon(Icons.center_focus_strong),
              tooltip: 'Fit Route to Screen',
            )
          : null,
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }
}
