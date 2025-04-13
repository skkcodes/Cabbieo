import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddMoneyScreen extends StatefulWidget {
  const AddMoneyScreen({Key? key}) : super(key: key);

  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  final TextEditingController _amountController = TextEditingController();
  double? _selectedAmount;
  String _selectedPaymentMethod = 'UPI';
  bool _isProcessing = false;

  final List<double> _quickAmounts = [100, 200, 300, 400, 500];
  final List<String> _paymentMethods = ['UPI', 'Credit Card', 'Debit Card', 'Net Banking'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Money to Wallet'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Amount',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.currency_rupee),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                hintText: 'Enter amount',
              ),
              onChanged: (value) {
                setState(() {
                  _selectedAmount = double.tryParse(value);
                });
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Quick Select',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: _quickAmounts.map((amount) {
                return ChoiceChip(
                  label: Text('₹$amount'),
                  selected: _selectedAmount == amount,
                  onSelected: (selected) {
                    setState(() {
                      _selectedAmount = selected ? amount : null;
                      _amountController.text = amount.toString();
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedPaymentMethod,
              items: _paymentMethods.map((method) {
                return DropdownMenuItem(
                  value: method,
                  child: Text(method),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethod = value!;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _selectedAmount != null ? _processPayment : null,
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('MAKE PAYMENT'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (_selectedAmount == null || _selectedAmount! <= 0) return;

    setState(() => _isProcessing = true);

    try {
      await Future.delayed(const Duration(seconds: 2));

      final userId = FirebaseAuth.instance.currentUser!.uid;
      final walletRef = FirebaseDatabase.instance.ref()
          .child('users')
          .child(userId)
          .child('wallet');

      final currentBalance = (await walletRef.once()).snapshot.value as num? ?? 0;
      final newBalance = currentBalance + _selectedAmount!;

      await walletRef.set(newBalance);

      if (!mounted) return;

      Navigator.pop(context, newBalance);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('₹$_selectedAmount added to wallet successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
