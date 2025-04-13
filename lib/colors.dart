import 'package:flutter/material.dart';

class AppColors {
  static const Color yellowAccent = Colors.yellow;  // Color for buttons/icons
  static const Color unhighlightedText = Color(0xFF888888);  // Dark gray for unhighlighted text

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.white,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(color: Colors.white, iconTheme: IconThemeData(color: Colors.black)),
    iconTheme: IconThemeData(color: yellowAccent),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: Colors.black),  // Regular text in black
      bodySmall: TextStyle(color: unhighlightedText),  // Unhighlighted text in dark gray
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: yellowAccent,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.black,
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: AppBarTheme(color: Colors.black, iconTheme: IconThemeData(color: Colors.white)),
    iconTheme: IconThemeData(color: yellowAccent),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: Colors.white),  // Regular text in white
      bodySmall: TextStyle(color: unhighlightedText),  // Unhighlighted text in dark gray
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: yellowAccent,
    ),
  );
}
