import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:waygo/global/global_var.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:waygo/screens/costom%20widgets/custom_google_map.dart';
import 'package:waygo/screens/rider/ride_waiting_screen.dart';

class RideBookingScreen extends StatefulWidget {
  const RideBookingScreen({Key? key}) : super(key: key);

  @override
  State<RideBookingScreen> createState() => _RideBookingScreenState();
}

class _RideBookingScreenState extends State<RideBookingScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  
  Position? _currentPosition;
  GoogleMapController? _googleMapController;
  LatLng? _sourceLocation;
  LatLng? _destinationLocation;
  bool _useCurrentLocation = true;
  
  // Map elements
  final Set<Marker> _markers = {};
  final Set<Marker> _driverMarkers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _polylineCoordinates = [];
  
  // Firebase references
  late DatabaseReference _rideRequestRef;
  late DatabaseReference _driversStatusRef;
  late DatabaseReference _usersRef;
  bool _isRequesting = false;
  String? _currentRideId;
  
  // Stream subscriptions
  StreamSubscription<DatabaseEvent>? _driversStream;
  StreamSubscription<Position>? _positionStream;

  // Driver icon
  BitmapDescriptor? _driverIcon;

  @override
  void initState() {
    super.initState();
    _rideRequestRef = FirebaseDatabase.instance.ref().child("ride_requests");
    _driversStatusRef = FirebaseDatabase.instance.ref("drivers_status");
    _usersRef = FirebaseDatabase.instance.ref("users");
    _loadCustomDriverIcon().then((_) {
      _initializeLocation();
      _listenToNearbyDrivers();
    });
  }

  @override
  void dispose() {
    // Cancel any pending ride request if navigating away
    if (_currentRideId != null && _isRequesting) {
      _rideRequestRef.child(_currentRideId!).remove();
    }
    
    _positionStream?.cancel();
    _driversStream?.cancel();
    _sourceController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomDriverIcon() async {
    _driverIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/logo/car.png',
    );
  }

  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar("Please enable location services");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar("Location permissions are denied");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar("Location permissions are permanently denied");
        return;
      }

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
            if (_useCurrentLocation) {
              _sourceLocation = LatLng(position.latitude, position.longitude);
              _sourceController.text = "Current Location";
              _updateMapCamera(position);
            }
          });
          _updateMarkers();
        }
      });

      // Get initial position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
          if (_useCurrentLocation) {
            _sourceLocation = LatLng(position.latitude, position.longitude);
            _sourceController.text = "Current Location";
          }
        });
        _updateMapCamera(position);
        _updateMarkers();
      }
    } catch (e) {
      _showSnackBar("Error getting location: ${e.toString()}");
    }
  }

  void _listenToNearbyDrivers() {
    _driversStream = _driversStatusRef
        .orderByChild("status")
        .equalTo("online")
        .onValue
        .listen((event) {
      if (event.snapshot.value != null && mounted) {
        Map<dynamic, dynamic> drivers = event.snapshot.value as Map;
        _updateDriverMarkers(drivers);
      }
    });
  }

  void _updateDriverMarkers(Map<dynamic, dynamic> drivers) {
    Set<Marker> newMarkers = {};
    
    drivers.forEach((driverId, driverData) {
      if (driverData['latitude'] != null && 
          driverData['longitude'] != null &&
          _currentPosition != null) {
        
        double distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          driverData['latitude'],
          driverData['longitude'],
        );
        
        if (distance <= 5000) {
          newMarkers.add(
            Marker(
              markerId: MarkerId(driverId),
              position: LatLng(
                driverData['latitude'],
                driverData['longitude'],
              ),
              icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: const InfoWindow(title: "Available Driver"),
              rotation: driverData['heading']?.toDouble() ?? 0,
            ),
          );
        }
      }
    });
    
    if (mounted) {
      setState(() {
        _driverMarkers.clear();
        _driverMarkers.addAll(newMarkers);
      });
    }
  }

  void _updateMapCamera(Position position) {
    _googleMapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15,
        ),
    ));
  }

  void _updateMarkers() {
    Set<Marker> markers = {};
    
    if (_sourceLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("source"),
          position: _sourceLocation!,
          infoWindow: const InfoWindow(title: "Pickup Location"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }
    
    if (_destinationLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("destination"),
          position: _destinationLocation!,
          infoWindow: const InfoWindow(title: "Destination"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
    
    if (mounted) {
      setState(() {
        _markers.clear();
        _markers.addAll(markers);
        
        if (_sourceLocation != null && _destinationLocation != null) {
          _drawRoute();
        }
      });
    }
  }

  Future<void> _drawRoute() async {
    if (_sourceLocation == null || _destinationLocation == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${_sourceLocation!.latitude},${_sourceLocation!.longitude}'
          '&destination=${_destinationLocation!.latitude},${_destinationLocation!.longitude}'
          '&mode=driving'
          '&key=$googleMapKey',
        ),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      
      if (data['status'] != 'OK') {
        throw Exception('Failed to get directions: ${data['status']}');
      }

      final points = data['routes'][0]['overview_polyline']['points'];
      final route = _decodePolyline(points);

      if (mounted) {
        setState(() {
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: route,
              color: Colors.blue,
              width: 5,
            ),
          );
          
          // Adjust camera to show both locations
          _googleMapController?.animateCamera(
            CameraUpdate.newLatLngBounds(
              _calculateBounds(route),
              100,
            ),
          );
        });
      }
    } catch (e) {
      _showSnackBar('Failed to draw route: ${e.toString()}');
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

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    
    for (var point in points) {
      minLat = minLat == null ? point.latitude : (point.latitude < minLat ? point.latitude : minLat);
      maxLat = maxLat == null ? point.latitude : (point.latitude > maxLat ? point.latitude : maxLat);
      minLng = minLng == null ? point.longitude : (point.longitude < minLng ? point.longitude : minLng);
      maxLng = maxLng == null ? point.longitude : (point.longitude > maxLng ? point.longitude : maxLng);
    }
    
    if (_currentPosition != null) {
      minLat = minLat == null ? _currentPosition!.latitude : (_currentPosition!.latitude < minLat ? _currentPosition!.latitude : minLat);
      maxLat = maxLat == null ? _currentPosition!.latitude : (_currentPosition!.latitude > maxLat ? _currentPosition!.latitude : maxLat);
      minLng = minLng == null ? _currentPosition!.longitude : (_currentPosition!.longitude < minLng ? _currentPosition!.longitude : minLng);
      maxLng = maxLng == null ? _currentPosition!.longitude : (_currentPosition!.longitude > maxLng ? _currentPosition!.longitude : maxLng);
    }
    
    return LatLngBounds(
      northeast: LatLng(maxLat!, maxLng!),
      southwest: LatLng(minLat!, minLng!),
    );
  }

  void _onSourcePlaceSelected(Prediction prediction) {
    if (prediction.lat == null || prediction.lng == null) return;
    
    setState(() {
      _sourceController.text = prediction.description ?? "";
      _sourceLocation = LatLng(
        double.parse(prediction.lat!),
        double.parse(prediction.lng!),
      );
      _updateMarkers();
    });
  }

  void _onDestinationPlaceSelected(Prediction prediction) {
    if (prediction.lat == null || prediction.lng == null) return;
    
    setState(() {
      _destinationController.text = prediction.description ?? "";
      _destinationLocation = LatLng(
        double.parse(prediction.lat!),
        double.parse(prediction.lng!),
      );
      _updateMarkers();
    });
  }

  Future<void> _updateToCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      
      setState(() {
        _sourceLocation = LatLng(position.latitude, position.longitude);
        _sourceController.text = "Current Location";
        _updateMarkers();
      });
      
    } catch (e) {
      _showSnackBar("Couldn't fetch current location");
    }
  }

  Widget _buildSourceLocationField() {
    return Column(
      children: [
        Row(
          children: [
            Checkbox(
              value: _useCurrentLocation,
              onChanged: (value) {
                setState(() {
                  _useCurrentLocation = value!;
                  if (_useCurrentLocation) {
                    _updateToCurrentLocation();
                  } else {
                    _sourceController.clear();
                    _sourceLocation = null;
                    _updateMarkers();
                  }
                });
              },
            ),
            const Text('Use Current Location'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.map),
              onPressed: _toggleMapTheme,
              tooltip: 'Change Map Theme',
            ),
          ],
        ),
        if (!_useCurrentLocation)
          GooglePlaceAutoCompleteTextField(
            textEditingController: _sourceController,
            googleAPIKey: googleMapKey,
            inputDecoration: const InputDecoration(
              hintText: "Pickup Location",
              border: InputBorder.none,
              prefixIcon: Icon(Icons.location_on, color: Colors.green),
            ),
            debounceTime: 800,
            countries: ["in"],
            isLatLngRequired: true,
            getPlaceDetailWithLatLng: _onSourcePlaceSelected,
            itemClick: _onSourcePlaceSelected,
          ),
      ],
    );
  }

  void _toggleMapTheme() {
    if (_googleMapController != null) {
      _updateMapTheme(_googleMapController!);
    }
  }

  Future<void> _updateMapTheme(GoogleMapController controller) async {
    String style = await rootBundle.loadString("assets/themes/standard_style.json");
    controller.setMapStyle(style);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _confirmRide() async {
    if (_sourceLocation == null || _destinationLocation == null) {
      _showSnackBar("Please select both pickup and drop locations");
      return;
    }

    final distance = Geolocator.distanceBetween(
      _sourceLocation!.latitude,
      _sourceLocation!.longitude,
      _destinationLocation!.latitude,
      _destinationLocation!.longitude,
    ) / 1000;

    final fare = _calculateFare(distance);

    // Get user details from Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar("Please login to request a ride");
      return;
    }

    final userSnapshot = await _usersRef.child(user.uid).once();
    if (!userSnapshot.snapshot.exists) {
      _showSnackBar("User profile not found");
      return;
    }

    final userData = userSnapshot.snapshot.value as Map<dynamic, dynamic>;
    final userName = userData['name'] ?? "Rider";
    final userPhone = userData['phone'] ?? "";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Your Ride"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Route Details:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildLocationRow(Icons.location_on, _sourceController.text),
            const Icon(Icons.arrow_downward, size: 20),
            _buildLocationRow(Icons.flag, _destinationController.text),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Distance:"),
                Text("${distance.toStringAsFixed(1)} km"),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Approx. Fare:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("₹$fare", style: const TextStyle(color: Colors.green, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "${_driverMarkers.length} drivers available nearby",
              style: TextStyle(color: Colors.blue[800], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _sendRideRequest(fare, distance, userName, userPhone);
            },
            child: const Text("Confirm Ride", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(text, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  /// Calculates the total fare based on distance, with customizable parameters.
/// Returns the final fare as a double (rounded to 2 decimal places).
double _calculateFare(double distanceKm) {
  const double baseFare = 30.0;           // Base fare in ₹
  const double perKmRate = 12.0;          // Cost per km in ₹
  const double minimumFare = 50.0;        // Ensure a minimum charge

  double fare = baseFare + (distanceKm * perKmRate);

  // Ensure minimum fare is always charged
  if (fare < minimumFare) {
    fare = minimumFare;
  }

  return double.parse(fare.toStringAsFixed(2));
}


Future<void> _sendRideRequest(double fare, double distanceKm, String userName, String userPhone) async {
  if (_isRequesting) return;
  
  setState(() => _isRequesting = true);
  
  try {
    // ========== 1. PRE-VALIDATION ==========
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar("Please login to request a ride");
      return;
    }

    if (_sourceLocation == null || _destinationLocation == null) {
      _showSnackBar("Please select pickup and destination locations");
      return;
    }

    if (_sourceController.text.isEmpty || _destinationController.text.isEmpty) {
      _showSnackBar("Please ensure addresses are properly loaded");
      return;
    }

    if (!RegExp(r'^\d{10}$').hasMatch(userPhone)) {
      _showSnackBar("Please enter a valid 10-digit phone number");
      return;
    }

    // ========== 2. DATA PREPARATION ==========
    final rideId = _rideRequestRef.push().key!;
    _currentRideId = rideId;

    final rideData = {
      "source": {
        "latitude": _sourceLocation!.latitude,
        "longitude": _sourceLocation!.longitude,
        "address": _sourceController.text,
      },
      "destination": {
        "latitude": _destinationLocation!.latitude,
        "longitude": _destinationLocation!.longitude,
        "address": _destinationController.text,
      },
      "status": "pending",
      "rider_id": user.uid,
      "rider_name": userName,
      "rider_phone": userPhone,
      "created_at": ServerValue.timestamp,
      "fare": fare,
      "distance": distanceKm,
      // Note: driver_id intentionally omitted initially
    };

    final activeRideData = {
      ...rideData,
      "driver_id": "", // Added for active_rides
      "completed_at": null,
    };

    // ========== 3. DEBUG OUTPUT ==========
    debugPrint("""
    ======= ATTEMPTING TO WRITE =======
    Ride Request Data:
    ${jsonEncode(rideData)}
    
    Active Ride Data:
    ${jsonEncode(activeRideData)}
    
    User UID: ${user.uid}
    """);

    // ========== 4. DATABASE WRITES ==========
    // First write to ride_requests
    await _rideRequestRef.child(rideId).set(rideData);

    // Then write to active_rides
    await FirebaseDatabase.instance.ref("active_rides/$rideId").set(activeRideData);

    // ========== 5. NAVIGATION HANDLING ==========
    if (!mounted) return;
    
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RideWaitingScreen(
          rideId: rideId,
          pickupLocation: _sourceLocation!,
          destination: _destinationLocation!,
          onRideCancelled: () {
            // Optional: Handle cancellation cleanup
            if (mounted) setState(() => _isRequesting = false);
          },
        ),
      ),
    );

  } on FirebaseException catch (e) {
    if (!mounted) return;
    _showSnackBar("Failed to create ride request");
    debugPrint("""
    ======= FIREBASE ERROR =======
    Code: ${e.code}
    Message: ${e.message}
    Stack: ${e.stackTrace}
    """);
  } catch (e) {
    if (!mounted) return;
    _showSnackBar("An unexpected error occurred");
    debugPrint("""
    ======= UNEXPECTED ERROR =======
    Error: $e
    Stack: ${StackTrace.current}
    """);
  } finally {
    if (mounted) {
      setState(() => _isRequesting = false);
    }
  }
}
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("Let's Ride", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          CustomGoogleMap(
            markers: {..._markers, ..._driverMarkers},
            polylines: _polylines,
            onMapCreated: (GoogleMapController controller) {
              _googleMapController = controller;
              _mapController.complete(controller);
              _updateMapTheme(controller);
            },
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        _buildSourceLocationField(),
                        const Divider(),
                        GooglePlaceAutoCompleteTextField(
                          textEditingController: _destinationController,
                          googleAPIKey: googleMapKey,
                          inputDecoration: const InputDecoration(
                            hintText: "Where to?",
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.location_on, color: Colors.red),
                          ),
                          debounceTime: 800,
                          countries: ["in"],
                          isLatLngRequired: true,
                          getPlaceDetailWithLatLng: _onDestinationPlaceSelected,
                          itemClick: _onDestinationPlaceSelected,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _confirmRide,
              child: const Text(
                "Request a ride",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          
          Positioned(
            top: 80,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    "${_driverMarkers.length} drivers nearby",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}