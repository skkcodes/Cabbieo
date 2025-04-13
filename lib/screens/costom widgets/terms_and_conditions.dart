import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

// Controller to access the onSignIn method
class TermsAndConditionsController {
  late _TermsAndConditionsCheckboxState _state;

  void attach(_TermsAndConditionsCheckboxState state) {
    _state = state;
  }

  bool onSignIn() {
    _state._onSignIn();
    return _state.isChecked;
  }
}

class TermsAndConditionsCheckbox extends StatefulWidget {
  final TermsAndConditionsController controller;

  TermsAndConditionsCheckbox({required this.controller});

  @override
  _TermsAndConditionsCheckboxState createState() =>
      _TermsAndConditionsCheckboxState();
}

class _TermsAndConditionsCheckboxState
    extends State<TermsAndConditionsCheckbox> {
  bool isChecked = false;

  @override
  void initState() {
    super.initState();
    widget.controller.attach(this);
  }

  void _showTermsPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Terms and Conditions'),
          content: SingleChildScrollView(
            child: Text(
              'Welcome to WayGo!\n\n'
              '1. Users must provide accurate information.\n'
              '2. Respect driver instructions.\n'
              '3. Cancellation fees may apply.\n'
              '4. WayGo is not responsible for lost items.\n'
              'By continuing, you agree to these terms.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black54,
      textColor: Colors.white,
    );
  }

  void _onSignIn() {
    if (!isChecked) {
      _showToast('Please accept the Terms and Conditions first.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: isChecked,
          onChanged: (bool? value) {
            setState(() {
              isChecked = value ?? false;
            });
          },
        ),
        GestureDetector(
          onTap: () => _showTermsPopup(context),
          child: Text.rich(
            TextSpan(
              text: 'I agree to the ',
              style: TextStyle(fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                  text: 'Terms and Conditions',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
