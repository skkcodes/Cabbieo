
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:waygo/colors.dart';

import 'package:waygo/screens/auth/splash_screen.dart';



Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Add this to your app initialization
  FirebaseDatabase.instance.setPersistenceEnabled(true);
  FirebaseDatabase.instance.setLoggingEnabled(true); // For debug

  await Permission.locationWhenInUse.isDenied.then((valueOfPermission){
    if(valueOfPermission){
      Permission.locationWhenInUse.request();
    }
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppColors.lightTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
