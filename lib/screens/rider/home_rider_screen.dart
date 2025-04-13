import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:waygo/global/global_var.dart';
import 'package:waygo/screens/auth/login_screen.dart';
import 'package:waygo/screens/costom%20widgets/custom_google_map.dart';
import 'package:waygo/screens/methods/common_methods.dart';
import 'package:waygo/screens/rider/Payment_history.dart';
import 'package:waygo/screens/rider/add_money_screen.dart';
import 'package:waygo/screens/rider/profile.dart';
import 'package:waygo/screens/rider/ride_booking_screen.dart';
import 'package:waygo/screens/rider/ride_history_screen.dart';
import 'package:waygo/screens/rider/rider_navigation.dart';

class HomeRiderScreen extends StatefulWidget {
  const HomeRiderScreen({super.key});

  @override
  State<HomeRiderScreen> createState() => _HomeRiderScreenState();
}

class _HomeRiderScreenState extends State<HomeRiderScreen> {
  CommonMethods cMethods = CommonMethods();
  GoogleMapController? _googleMapController;
  LatLng? currentPosition;
  bool showSearchContainer = false;
  TextEditingController pickupController = TextEditingController();
  TextEditingController destinationController = TextEditingController();
  final GlobalKey<ScaffoldState> skey = GlobalKey<ScaffoldState>();

  // Driver tracking variables
  BitmapDescriptor? _driverIcon;
  final Set<Marker> _driverMarkers = {};
  StreamSubscription<DatabaseEvent>? _driversStream;
  DatabaseReference driversStatusRef = FirebaseDatabase.instance.ref("drivers_status");
  StreamSubscription<Position>? _positionStream;

  final PageController _eventController = PageController();
  int _currentEventIndex = 0;
  Timer? _eventTimer;
  List<Map<String, dynamic>> events = [
    {'title': 'Festival Discount', 'subtitle': 'Get 20% off on all rides'},
    {'title': 'Weekend Special', 'subtitle': 'Free upgrade to Premium'},
    {'title': 'Referral Bonus', 'subtitle': 'Earn ₹100 per referral'},
  ];
  double _walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    getUserInfoAndCheckBlockStatus();
    _startEventTimer();
    _loadWalletBalance();
    _loadCustomDriverIcon().then((_) {
      _initializeLocation();
      _listenToNearbyDrivers();
    });
  }

  Future<void> _loadCustomDriverIcon() async {
    try {
      final ByteData data = await rootBundle.load('assets/logo/car.png');
      final Uint8List bytes = data.buffer.asUint8List();
      _driverIcon = await BitmapDescriptor.fromBytes(bytes);
    } catch (e) {
      _driverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
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
            currentPosition = LatLng(position.latitude, position.longitude);
          });
          _updateMapCamera(position);
        }
      });

      // Get initial position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      
      if (mounted) {
        setState(() {
          currentPosition = LatLng(position.latitude, position.longitude);
        });
        _updateMapCamera(position);
      }
    } catch (e) {
      _showSnackBar("Error getting location: ${e.toString()}");
    }
  }

  void _listenToNearbyDrivers() {
    _driversStream = driversStatusRef
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
          currentPosition != null) {
        
        double distance = Geolocator.distanceBetween(
          currentPosition!.latitude,
          currentPosition!.longitude,
          driverData['latitude'],
          driverData['longitude'],
        );
        
        if (distance <= 5000) { // 5km radius
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
      )
    );
  }

  Future<void> _loadWalletBalance() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final walletRef = FirebaseDatabase.instance.ref()
        .child('users')
        .child(userId)
        .child('wallet');

    walletRef.onValue.listen((event) {
      if (mounted) {
        setState(() {
          _walletBalance = (event.snapshot.value as num?)?.toDouble() ?? 0.0;
        });
      }
    });
  }

  void _startEventTimer() {
    _eventTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentEventIndex < events.length - 1) {
        _currentEventIndex++;
      } else {
        _currentEventIndex = 0;
      }
      _eventController.animateToPage(
        _currentEventIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeIn,
      );
    });
  }

  Future<void> _navigateToAddMoney() async {
    final updatedBalance = await Navigator.push<double>(
      context,
      MaterialPageRoute(builder: (context) => const AddMoneyScreen()),
    );
    
    if (updatedBalance != null) {
      setState(() {
        _walletBalance = updatedBalance;
      });
    }
  }

  getUserInfoAndCheckBlockStatus() async {
    DatabaseReference userRef = FirebaseDatabase.instance.ref()
        .child("users")
        .child(FirebaseAuth.instance.currentUser!.uid);
    
    await userRef.once().then((snap) {
      if (snap.snapshot.value != null) {
        if ((snap.snapshot.value as Map)["blockStatus"] == "no") {
          setState(() {
            userName = (snap.snapshot.value as Map)["name"];
            email = (snap.snapshot.value as Map)["email"];
          });
        } else {
          FirebaseAuth.instance.signOut();
          Navigator.push(context, MaterialPageRoute(builder: (builder) => LoginScreen()));
          cMethods.displaySnackBar("You are blocked. Please contact support team: cabbieo.support@gmail.com", context);
        }
      } else {
        FirebaseAuth.instance.signOut();
        cMethods.displaySnackBar("Record not found. Please sign up first.", context);
        Navigator.push(context, MaterialPageRoute(builder: (builder) => LoginScreen()));
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _driversStream?.cancel();
    _eventTimer?.cancel();
    _eventController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: skey,
      drawer: CustomDrawer(),
      body: Stack(
        children: [
          SvgPicture.asset("assets/logo/rider_home.svg", fit: BoxFit.cover,height: double.infinity,width: double.infinity,),
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 50),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            skey.currentState?.openDrawer();
                          });
                        },
                        child: const Icon(Icons.menu, size: 30, color: Colors.black),
                      ),
                      const SizedBox(width: 20),
                      const Text("Ready to ride", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 22)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RideBookingScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search, color: Colors.grey),
                          SizedBox(width: 10),
                          Text("Where to?", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
                Stack(
  children: [
    SizedBox(
      height: 250, // Set your card image height here
      width: double.infinity,
      child: Image.asset(
        "assets/logo/card.png",
        fit: BoxFit.cover,
      ),
    ),
    Positioned(
      bottom: 35, // 50 pixels from the bottom of the image
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            children: [
              Image.asset("assets/logo/inr.png", height: 32, width: 32),
              Text(
                _walletBalance.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _navigateToAddMoney,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              backgroundColor: Colors.indigoAccent,
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              shadowColor: Colors.indigo.withOpacity(0.4),
            ),
            child: const Text(
              "Add Money",
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  ],
),

                
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(15)),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.topLeft,
                          child: Text("Suggestions", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Image.asset("assets/logo/ride.png"),
                            Image.asset("assets/logo/pachage.png"),
                            Image.asset("assets/logo/rental.png"),          
                            Image.asset("assets/logo/reserve.png"),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  height: 200,
                  child: PageView.builder(
                    controller: _eventController,
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          boxShadow: const [BoxShadow(color: Colors.white)],
                          image: const DecorationImage(image: AssetImage("assets/logo/payment .png"), fit: BoxFit.cover),
                          borderRadius: BorderRadius.circular(15)),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(events[index]['title'], 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 5),
                            Text(events[index]['subtitle'], 
                              style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left:20.0),
                      child: Align(
                        alignment: Alignment.topLeft,
                        
                        child: Text("Around you",style: TextStyle(fontSize: 20, color: Colors.black, fontWeight: FontWeight.bold),textAlign: TextAlign.start,)),
                    ),
                    
                    Container(
                      height: 500,
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(15)),
                      padding: const EdgeInsets.all(10),
                      child: CustomGoogleMap(
                        onMapCreated: (controller) {
                          _googleMapController = controller;
                        },
                        markers: _driverMarkers,
                        initialPosition: currentPosition ?? const LatLng(0, 0),
                        polylines: const {},
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      
    );
  }
}
class CustomDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                userName,
                style: const TextStyle(color: Colors.black),
              ),
              accountEmail: Text(
                email,
                style: const TextStyle(color: Colors.black),
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundImage: AssetImage('assets/logo/man.png'),
              ),
              decoration: const BoxDecoration(
                color: Colors.amber,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home, color: Colors.black),
              title: const Text('Home', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (builder) => const HomeRiderScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.black),
              title: const Text('Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (builder) => const RiderProfileScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.credit_card, color: Colors.black),
              title: const Text('Payment History', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (builder) => const PaymentHistoryScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.car_repair, color: Colors.black),
              title: const Text('Ride History', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (builder) => const RideHistoryScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.black),
              title: const Text('Settings', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              onTap: () {},
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                FirebaseAuth.instance.signOut();
                Navigator.push(context, MaterialPageRoute(builder: (builder) => LoginScreen()));
              },
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Version 1.0.0',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
