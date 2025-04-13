

import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  String messangeText;
  LoadingScreen({super.key, required this.messangeText});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      backgroundColor: Colors.black38,
      child: Container(
        margin: EdgeInsets.all(15),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Padding(padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 5,
            ),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(width: 8,),
            Text(
              messangeText,style: TextStyle(
                fontSize: 16,
                color: Colors.white
              ),
            )
          ],
        ),
      ),
    ));
  }
}