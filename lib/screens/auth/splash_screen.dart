import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:waygo/screens/rider/home_rider_screen.dart';
import 'package:waygo/screens/rider/rider_navigation.dart';
import 'package:waygo/screens/welcome_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.delayed(Duration(milliseconds: 30)), // 1-second delay
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.white, // Optional: Set a plain background
          );
        }
        return AnimatedSplashScreen(
          splash: Center(
            child: FittedBox(
              child: LottieBuilder.asset("assets/lottie/splash_screen.json"),
            ),
          ),
          nextScreen: FirebaseAuth.instance.currentUser == null? WelcomePage(): RiderNavigation(),
          splashIconSize: 300,
          animationDuration: Duration(seconds: 2),
        );
      },
    );
  }
}
