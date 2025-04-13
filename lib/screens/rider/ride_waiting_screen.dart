// ride_waiting_screen.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waygo/global/global_var.dart';
import 'package:waygo/screens/costom%20widgets/custom_google_map.dart';
import 'package:waygo/screens/rider/ride_tracking_screen.dart';
import 'package:waygo/screens/rider/payment_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RideWaitingScreen extends StatefulWidget {
  final String rideId;
  final LatLng pickupLocation;
  final LatLng destination;
  final VoidCallback? onRideCancelled;

  const RideWaitingScreen({
    Key? key,
    required this.rideId,
    required this.pickupLocation,
    required this.destination,
    this.onRideCancelled,
  }) : super(key: key);

  @override
  State<RideWaitingScreen> createState() => _RideWaitingScreenState();
}

class _RideWaitingScreenState extends State<RideWaitingScreen> {
  late DatabaseReference _rideRequestRef;
  late DatabaseReference _driverStatusRef;
  late DatabaseReference _activeRidesRef;
  StreamSubscription<DatabaseEvent>? _rideSubscription;
  StreamSubscription<DatabaseEvent>? _driverStatusSubscription;
  StreamSubscription<DatabaseEvent>? _activeRideSubscription;
  BitmapDescriptor? _driverIcon;

  String? _driverId;
  String? _driverName;
  String? _driverPhoto;
  String? _carDetails;
  LatLng? _driverLocation;
  bool _isCancelling = false;
  bool _driverAccepted = false;
  bool _isDisposed = false;
  Timer? _distanceCheckTimer;
  String _statusMessage = "Searching for nearby drivers...";
  double? _distanceToPickup;
  
  // Route variables
  List<LatLng> _driverToPickupRoute = [];
  List<LatLng> _pickupToDestinationRoute = [];
  bool _isRouteLoading = false;
  String _routeError = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeFirebaseReferences();
        _loadDriverIcon();
        _listenForRideUpdates();
        _listenForRideRequestUpdates(); // Add this separate listener
      }
    });
  }

  Future<void> _loadDriverIcon() async {
    try {
      _driverIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/logo/car.png',
      );
    } catch (e) {
      debugPrint("Error loading driver icon: $e");
      _driverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }
void _startDriverLocationUpdates(String driverId) {
    _driverStatusSubscription?.cancel(); // Cancel previous if exists
    
    _driverStatusSubscription = _driverStatusRef.child(driverId).onValue.listen((event) {
      if (_isDisposed || !mounted) return;
      
      final locationData = event.snapshot.value as Map?;
      if (locationData == null) return;

      final lat = locationData['latitude'] as double?;
      final lng = locationData['longitude'] as double?;
      if (lat == null || lng == null) return;

      setState(() {
        _driverLocation = LatLng(lat, lng);
      });
      
      _calculateDistanceToPickup(_driverLocation!);
    }, onError: (error) {
      debugPrint('Driver location listener error: $error');
    });
  }

  void _initializeFirebaseReferences() {
    _rideRequestRef = FirebaseDatabase.instance.ref("ride_requests/${widget.rideId}");
    _driverStatusRef = FirebaseDatabase.instance.ref("drivers_status");
    _activeRidesRef = FirebaseDatabase.instance.ref("active_rides/${widget.rideId}");
  }

    void _listenForRideUpdates() {
    _activeRideSubscription = _activeRidesRef.onValue.listen((event) {
      if (_isDisposed || !mounted) return;
      
      final rideData = event.snapshot.value as Map?;
      if (rideData == null) return;

      final status = rideData['status'];
      
      if (status == "in_progress") {
        if (_driverId == null && rideData['driver_id'] != null) {
          setState(() {
            _driverId = rideData['driver_id'].toString();
            _driverAccepted = true;
          });
        }
        _navigateToRideTrackingScreen();
      } else if (status == "completed") {
        _navigateToPaymentScreen(rideData);
      }
    }, onError: (error) {
      debugPrint('Active rides listener error: $error');
    });
  }

  void _handleDriverAccepted(Map rideData) {
  if (_isDisposed || !mounted) return;

  final driverId = rideData['driver_id']?.toString();
  if (driverId == null) return;

  setState(() {
    _driverId = driverId;
    _driverAccepted = true;
    _statusMessage = "Driver is on the way";
  });

  // Load driver details
  FirebaseDatabase.instance.ref("drivers/$driverId").once().then((snapshot) {
    if (_isDisposed || !mounted) return;
    
    final driverData = snapshot.snapshot.value as Map?;
    if (driverData == null) return;

    setState(() {
      _driverName = driverData['name']?.toString();
      _driverPhoto = driverData['photo']?.toString();
      _carDetails = _parseCarDetails(driverData['car_details']);
    });
  });

  // Start listening to driver location
  _driverStatusSubscription = _driverStatusRef.child(driverId).onValue.listen((event) {
    if (_isDisposed || !mounted) return;
    
    final locationData = event.snapshot.value as Map?;
    if (locationData == null) return;

    final lat = locationData['latitude'] as double?;
    final lng = locationData['longitude'] as double?;
    if (lat == null || lng == null) return;

    final newDriverLocation = LatLng(lat, lng);
    
    setState(() {
      _driverLocation = newDriverLocation;
    });

    // ======== CRITICAL FIX ======== 
    // Re-add the polyline generation when driver location updates
    if (_driverLocation != null) {
      _getFullRoute(); // This generates the polyline
    }
    // ==============================

    _calculateDistanceToPickup(newDriverLocation);
  });
}

// Ensure this polyline method exists (from your original code)
Future<void> _getFullRoute() async {
  if (_driverLocation == null) return;

  try {
    final driverToPickup = await _getRoutePoints(_driverLocation!, widget.pickupLocation);
    final pickupToDestination = await _getRoutePoints(widget.pickupLocation, widget.destination);

    setState(() {
      _driverToPickupRoute = driverToPickup;
      _pickupToDestinationRoute = pickupToDestination;
    });
  } catch (e) {
    debugPrint("Route generation failed: $e");
  }
}


  Future<List<LatLng>> _getRoutePoints(LatLng origin, LatLng destination) async {
    final apiKey = googleMapKey;
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?'
      'origin=${origin.latitude},${origin.longitude}&'
      'destination=${destination.latitude},${destination.longitude}&'
      'key=$apiKey&mode=driving',
    );

    final response = await http.get(url);
    final data = json.decode(response.body);

    if (data['status'] == 'OK') {
      final points = data['routes'][0]['overview_polyline']['points'];
      return _decodePoly(points);
    }
    throw Exception('Failed to get route: ${data['status']}');
  }

  List<LatLng> _decodePoly(String encoded) {
    final List<LatLng> poly = [];
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

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  Future<void> _calculateDistanceToPickup(LatLng driverLocation) async {
    final distanceInMeters = await Geolocator.distanceBetween(
      driverLocation.latitude,
      driverLocation.longitude,
      widget.pickupLocation.latitude,
      widget.pickupLocation.longitude,
    );

    setState(() {
      _distanceToPickup = distanceInMeters;
      
      if (distanceInMeters < 50) {
        _statusMessage = "Driver has arrived at pickup location";
      } else if (distanceInMeters < 200) {
        _statusMessage = "Driver is approaching pickup location";
      } else {
        _statusMessage = "Driver is on the way";
      }
    });
  }

  String _parseCarDetails(dynamic carData) {
    if (carData is! Map) return '';
    return "${carData['carModel'] ?? 'Car'} (${carData['carNumber'] ?? ''})";
  }

void _listenForRideRequestUpdates() {
    _rideSubscription = _rideRequestRef.onValue.listen((event) {
      if (_isDisposed || !mounted) return;
      
      final rideData = event.snapshot.value as Map?;
      if (rideData == null) return;

      final status = rideData['status'];
      
      if (status == "driver_accepted" && !_driverAccepted) {
        _handleDriverAccepted(rideData);
      } else if (status == "cancelled") {
        _handleRideCancelled();
      }
    }, onError: (error) {
      debugPrint('Ride request listener error: $error');
    });
  }
  
  void _navigateToRideTrackingScreen() {
  // Immediate checks
  if (_isDisposed || !mounted || _driverId == null || context == null) {
    debugPrint('Navigation blocked - Disposed: $_isDisposed, Mounted: $mounted, Driver: $_driverId');
    return;
  }

  // Use a navigator key to avoid context issues
  final navigatorKey = Navigator.of(context);
  if (!navigatorKey.mounted) return;

  // Clear any pending navigation
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      // Check if we're already on tracking screen
      if (ModalRoute.of(context)?.settings.name == '/tracking') return;

      navigatorKey.pushReplacement(
        MaterialPageRoute(
          settings: RouteSettings(name: '/tracking'),
          builder: (context) => RideTrackingScreen(
            googleApiKey: googleMapKey,
            rideId: widget.rideId,
            driverId: _driverId!,
            pickupLocation: widget.pickupLocation,
            destination: widget.destination,
          ),
        ),
      );
      debugPrint('Navigation to tracking successful');
    } catch (e, stack) {
      debugPrint('Navigation failed: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please wait...')),
        );
        // Retry after delay
        Future.delayed(Duration(seconds: 1), _navigateToRideTrackingScreen);
      }
    }
  });
}
  
  void _navigateToPaymentScreen(Map rideData) {
  if (_isDisposed || !mounted) return;
  
  final fare = rideData['fare']?.toDouble() ?? 0.0;
  final distance = rideData['distance']?.toDouble() ?? 0.0;
  final riderId = FirebaseAuth.instance.currentUser?.uid ?? "";

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => PaymentScreen(
        rideId: widget.rideId,
        fare: fare,
        distance: distance,
        driverName: _driverName ?? 'Driver',
        driverId: _driverId ?? "",
        riderId: riderId, // Added this line
      ),
    ),
  );
}

  void _handleRideCancelled() {
    if (_isDisposed || !mounted) return;
    
    Navigator.pop(context);
    widget.onRideCancelled?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Ride was cancelled")),
    );
  }

  Future<void> _cancelRide() async {
    if (_isCancelling || _isDisposed || !mounted) return;
    
    setState(() => _isCancelling = true);

    try {
      await _rideRequestRef.update({
        "status": "cancelled",
        "cancelled_at": ServerValue.timestamp,
        "cancelled_by": "rider",
      }).timeout(const Duration(seconds: 10));

      if (!mounted || _isDisposed) return;
      
      widget.onRideCancelled?.call();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted || _isDisposed) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to cancel ride: ${e.toString()}")),
      );
      setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ride Status"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Cancel Ride?"),
                content: const Text("Do you want to cancel this ride request?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("No"),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _cancelRide();
                    },
                    child: const Text("Yes", style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_driverAccepted && _driverLocation != null && _driverIcon != null) {
      return _buildDriverFoundUI();
    } else if (_driverAccepted) {
      return _buildDriverAcceptedUI();
    } else {
      return _buildSearchingUI();
    }
  }

  Widget _buildSearchingUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(_statusMessage),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _isCancelling ? null : _cancelRide,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: _isCancelling
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Cancel Ride"),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverAcceptedUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(_statusMessage),
          if (_distanceToPickup != null) 
            Text("Distance: ${_distanceToPickup!.toStringAsFixed(0)} meters"),
          const SizedBox(height: 10),
          Text("Driver: ${_driverName ?? ''}"),
          Text(_carDetails ?? ''),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _isCancelling ? null : _cancelRide,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: _isCancelling
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Cancel Ride"),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverFoundUI() {
    return Column(
      children: [
        if (_isRouteLoading)
          const LinearProgressIndicator(minHeight: 2),
        if (_routeError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _routeError,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ListTile(
          leading: CircleAvatar(
            backgroundImage: _driverPhoto != null 
                ? NetworkImage(_driverPhoto!) 
                : const AssetImage('assets/logo/car.png') as ImageProvider,
            radius: 30,
          ),
          title: Text(_driverName ?? 'Driver'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_carDetails ?? ''),
              if (_distanceToPickup != null)
                Text("${_distanceToPickup!.toStringAsFixed(0)} meters away"),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            _statusMessage,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: CustomGoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.pickupLocation,
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('pickup'),
                position: widget.pickupLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                infoWindow: const InfoWindow(title: "Pickup Location"),
              ),
              Marker(
                markerId: const MarkerId('destination'),
                position: widget.destination,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: const InfoWindow(title: "Destination"),
              ),
              Marker(
                markerId: const MarkerId('driver'),
                position: _driverLocation!,
                icon: _driverIcon!,
                infoWindow: InfoWindow(title: "Driver: ${_driverName ?? ''}"),
              ),
            },
            polylines: {
              if (_driverToPickupRoute.isNotEmpty)
                Polyline(
                  polylineId: const PolylineId('driver_to_pickup'),
                  points: _driverToPickupRoute,
                  color: Colors.blue,
                  width: 4,
                ),
              if (_pickupToDestinationRoute.isNotEmpty)
                Polyline(
                  polylineId: const PolylineId('pickup_to_destination'),
                  points: _pickupToDestinationRoute,
                  color: Colors.green,
                  width: 4,
                ),
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.red,
            ),
            onPressed: _isCancelling ? null : _cancelRide,
            child: _isCancelling
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Cancel Ride", style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }

  
  @override
 @override
  void dispose() {
    _isDisposed = true;
    _rideSubscription?.cancel();
    _driverStatusSubscription?.cancel();
    _activeRideSubscription?.cancel();
    _distanceCheckTimer?.cancel();
    super.dispose();
  }
}