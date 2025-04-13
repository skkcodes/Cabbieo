
import 'package:fluttertoast/fluttertoast.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class CommonMethods {
  final Connectivity _connectivity = Connectivity();

  checkConnectivity(BuildContext context) async {
    var connectionResult = await _connectivity.checkConnectivity();

    if (connectionResult != ConnectivityResult.mobile &&
        connectionResult != ConnectivityResult.wifi) {
      if (!context.mounted) return;
      else{
      displaySnackBar("Please check your internet connection and try again", context);}
    }

  }

  void displaySnackBar(String message, context) {
    Fluttertoast.showToast(
      msg: message,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black54,
      textColor: Colors.white,
    );
  }
}
