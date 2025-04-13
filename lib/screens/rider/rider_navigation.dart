// rider_navigation.dart
import 'package:flutter/material.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

import 'package:waygo/screens/rider/home_rider_screen.dart';
import 'package:waygo/screens/rider/payment_history.dart';
import 'package:waygo/screens/rider/profile.dart';
import 'package:waygo/screens/rider/ride_history_screen.dart';

class RiderNavigation extends StatefulWidget {
  const RiderNavigation({super.key});

  @override
  State<RiderNavigation> createState() => _RiderNavigationState();
}

class _RiderNavigationState extends State<RiderNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeRiderScreen(),
    const PaymentHistoryScreen(),
    const RideHistoryScreen(),
    const RiderProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: SalomonBottomBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        curve: Curves.easeInCirc,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items:  [
          SalomonBottomBarItem(
            icon: Icon(Icons.home),
            title: Text("Home"),
            selectedColor: Colors.blue,
            unselectedColor: Colors.grey,
          ),
          SalomonBottomBarItem(
            icon: Icon(Icons.payment),
            title: Text("Payments"),
            selectedColor: Colors.green,
            unselectedColor: Colors.grey,
          ),
          SalomonBottomBarItem(
            icon: Icon(Icons.history),
            title: Text("History"),
            selectedColor: Colors.purple,
            unselectedColor: Colors.grey,
          ),
          SalomonBottomBarItem(
            icon: Icon(Icons.person),
            title: Text("Profile"),
            selectedColor: Colors.amber,
            unselectedColor: Colors.grey,
          ),
        ],
      ),
    );
  }
}