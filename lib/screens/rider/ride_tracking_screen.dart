import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waygo/screens/costom%20widgets/custom_google_map.dart';
import 'package:waygo/screens/rider/payment_screen.dart';

class RideTrackingScreen extends StatefulWidget {
  final String rideId;
  final String driverId;
  final LatLng pickupLocation;
  final LatLng destination;
  final String googleApiKey;

  const RideTrackingScreen({
    Key? key,
    required this.rideId,
    required this.driverId,
    required this.pickupLocation,
    required this.destination,
    required this.googleApiKey,
  }) : super(key: key);

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  late DatabaseReference _activeRidesRef;
  late DatabaseReference _driverStatusRef;
  StreamSubscription<DatabaseEvent>? _activeRideSubscription;
  StreamSubscription<DatabaseEvent>? _driverStatusSubscription;
  BitmapDescriptor? _carIcon;
  LatLng? _driverLocation;
  bool _isDisposed = false;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isLoading = true;
  GoogleMapController? _mapController;
  Timer? _locationUpdateTimer;
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _initializeResources();
  }

  Future<void> _initializeResources() async {
    await _loadCarIcon();
    _initializeFirebaseReferences();
    await _getRouteDirections();
    _listenForRideUpdates();
    _startLocationUpdates();
    setState(() => _isLoading = false);
  }

  Future<void> _loadCarIcon() async {
    try {
      _carIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/logo/car.png',
      );
    } catch (e) {
      debugPrint("Error loading car icon: $e");
      _carIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  void _initializeFirebaseReferences() {
    _activeRidesRef = FirebaseDatabase.instance.ref("active_rides/${widget.rideId}");
    _driverStatusRef = FirebaseDatabase.instance.ref("drivers_status/${widget.driverId}");
  }

  Future<void> _getRouteDirections() async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${widget.pickupLocation.latitude},${widget.pickupLocation.longitude}&'
        'destination=${widget.destination.latitude},${widget.destination.longitude}&'
        'key=${widget.googleApiKey}&mode=driving'
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        setState(() {
          _routePoints = _decodePolyline(data['routes'][0]['overview_polyline']['points']);
          _updatePolylines();
        });
      }
    } catch (e) {
      debugPrint("Error getting directions: $e");
      // Fallback to straight line
      setState(() {
        _routePoints = [widget.pickupLocation, widget.destination];
        _updatePolylines();
      });
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
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

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  void _updatePolylines() {
    _polylines.clear();
    _polylines.add(Polyline(
      polylineId: const PolylineId('route'),
      points: _routePoints,
      color: Colors.blue,
      width: 4,
      geodesic: true,
    ));
  }

  void _startLocationUpdates() {
    // Immediate first update
    _updateDriverLocation();
    
    // Then update every 5 seconds
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateDriverLocation();
    });
  }

  Future<void> _updateDriverLocation() async {
    try {
      final snapshot = await _driverStatusRef.get();
      if (_isDisposed || !mounted) return;

      final locationData = snapshot.value as Map?;
      if (locationData == null) return;

      final lat = locationData['latitude'] as double?;
      final lng = locationData['longitude'] as double?;
      if (lat == null || lng == null) return;

      setState(() {
        _driverLocation = LatLng(lat, lng);
        _updateMarkers();
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_driverLocation!),
      );
    } catch (e) {
      debugPrint("Error updating driver location: $e");
    }
  }

  void _updateMarkers() {
    _markers.clear();
    _markers.addAll([
      Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickupLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: widget.destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
      if (_driverLocation != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          icon: _carIcon!,
          rotation: _calculateBearing(),
        ),
    ]);
  }

  double _calculateBearing() {
    if (_routePoints.length < 2 || _driverLocation == null) return 0;
    
    // Find nearest point on route
    int nearestIndex = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < _routePoints.length; i++) {
      final distance = Geolocator.distanceBetween(
        _driverLocation!.latitude,
        _driverLocation!.longitude,
        _routePoints[i].latitude,
        _routePoints[i].longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }
    
    // Calculate bearing to next point
    if (nearestIndex < _routePoints.length - 1) {
      final p1 = _routePoints[nearestIndex];
      final p2 = _routePoints[nearestIndex + 1];
      
      final lat1 = p1.latitude * pi / 180;
      final lon1 = p1.longitude * pi / 180;
      final lat2 = p2.latitude * pi / 180;
      final lon2 = p2.longitude * pi / 180;
      
      final y = sin(lon2 - lon1) * cos(lat2);
      final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lon2 - lon1);
      return atan2(y, x) * 180 / pi;
    }
    return 0;
  }

  void _listenForRideUpdates() {
    _activeRideSubscription = _activeRidesRef.onValue.listen((event) {
      if (_isDisposed) return;
      
      final rideData = event.snapshot.value as Map?;
      if (rideData == null || rideData['status'] != "completed") return;

      _navigateToPaymentScreen(rideData);
    });
  }

 void _navigateToPaymentScreen(Map rideData) {
  if (_isDisposed || !mounted) return;
  
  final fare = rideData['fare']?.toDouble() ?? 0.0;
  final distance = rideData['distance']?.toDouble() ?? 0.0;
  final riderId = FirebaseAuth.instance.currentUser?.uid ?? "";
  
  // Get driver name from active ride data or fallback
  final driverName = rideData['driver_name']?.toString() ?? 'Driver';

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => PaymentScreen(
        rideId: widget.rideId,
        fare: fare,
        distance: distance,
        driverName: driverName,
        driverId: widget.driverId,
        riderId: riderId, // Added this line
      ),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ride Tracking"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomGoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.pickupLocation,
                zoom: 15,
              ),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (controller) {
                _mapController = controller;
                if (_driverLocation != null) {
                  controller.animateCamera(
                    CameraUpdate.newLatLng(_driverLocation!),
                  );
                }
              },
            ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _locationUpdateTimer?.cancel();
    _activeRideSubscription?.cancel();
    _driverStatusSubscription?.cancel();
    super.dispose();
  }
}