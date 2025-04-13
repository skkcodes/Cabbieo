import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:waygo/screens/rider/ride_history_screen.dart';
import 'package:waygo/screens/rider/rider_navigation.dart';

class PaymentScreen extends StatefulWidget {
  final String rideId;
  final double fare;
  final double distance;
  final String driverId;
  final String driverName;
  final String riderId;

  const PaymentScreen({
    Key? key,
    required this.rideId,
    required this.fare,
    required this.distance,
    required this.driverId,
    required this.driverName,
    required this.riderId,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  double _walletBalance = 0;
  bool _isProcessing = false;
  bool _showRatingDialog = false;
  int _rating = 0;
  final TextEditingController _feedbackController = TextEditingController();
  StreamSubscription<DatabaseEvent>? _walletSubscription;

  @override
  void initState() {
    super.initState();
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId != widget.riderId) return;

    _walletSubscription = _dbRef.child('users/$userId/wallet')
        .onValue.listen((event) {
          if (mounted) {
            setState(() {
              _walletBalance = (event.snapshot.value as num?)?.toDouble() ?? 0;
            });
          }
        });
  }

  Future<void> _processPayment() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId != widget.riderId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Authentication failed")),
      );
      return;
    }

    if (_walletBalance < widget.fare) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insufficient balance. Please add ₹${(widget.fare - _walletBalance).toStringAsFixed(2)}')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // First verify the ride is in correct state
      final rideSnapshot = await _dbRef.child('active_rides/${widget.rideId}').get();
      if (!rideSnapshot.exists || rideSnapshot.child('status').value.toString() != 'completed') {
        throw Exception('Ride not in completed state');
      }

      // Verify the current user is the rider
      if (rideSnapshot.child('rider_id').value.toString() != userId) {
        throw Exception('Permission denied: Not the rider of this ride');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final Map<String, dynamic> updates = {};

      // 1. Deduct from rider's wallet (follows users/$userId/wallet rules)
      updates['users/${widget.riderId}/wallet'] = ServerValue.increment(-widget.fare);

      // 2. Add payment record (follows payments/$rideId rules)
      updates['payments/${widget.rideId}'] = {
        'amount': widget.fare,
        'driver_id': widget.driverId,
        'rider_id': widget.riderId,
        'timestamp': timestamp,
        'ride_id': widget.rideId,
      };

      // 3. Update driver earnings (follows earnings/$driverId rules)
      updates['earnings/${widget.driverId}/total_earnings'] = ServerValue.increment(widget.fare);
      updates['earnings/${widget.driverId}/last_updated'] = timestamp;

      // Execute all updates atomically
      await _dbRef.update(updates);

      if (!mounted) return;
      setState(() => _showRatingDialog = true);
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

  Future<void> _submitRating(bool skip) async {
    if (!skip && _rating > 0) {
      try {
        // Verify ride is completed before allowing rating
        final rideSnapshot = await _dbRef.child('active_rides/${widget.rideId}').get();
        if (rideSnapshot.exists && rideSnapshot.child('status').value.toString() == 'completed') {
          await _dbRef.child('driver_ratings/${widget.driverId}/${widget.rideId}').set({
            'rating': _rating,
            'feedback': _feedbackController.text,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'ride_id': widget.rideId,
            'rider_id': widget.riderId,
          });
        }
      } catch (e) {
        debugPrint('Error submitting rating: $e');
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => RiderNavigation()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPay = _walletBalance >= widget.fare;
    final balanceColor = canPay ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Summary')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'Ride Details',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow('Driver:', widget.driverName),
                        _buildDetailRow('Distance:', '${widget.distance.toStringAsFixed(2)} km'),
                        _buildDetailRow(
                          'Wallet Balance:', 
                          '₹${_walletBalance.toStringAsFixed(2)}',
                          valueColor: balanceColor,
                        ),
                        const Divider(height: 24),
                        _buildDetailRow(
                          'Total Fare:', 
                          '₹${widget.fare.toStringAsFixed(2)}',
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: canPay ? _processPayment : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canPay ? Colors.blue : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(canPay ? 'PAY NOW' : 'INSUFFICIENT BALANCE'),
                ),
              ],
            ),
          ),
          if (_showRatingDialog) _buildRatingDialog(),
        ],
      ),
    );
  }

  Widget _buildRatingDialog() {
    return AlertDialog(
      title: const Text('Rate Your Experience'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('How was your ride with ${widget.driverName}?'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) => IconButton(
              icon: Icon(
                index < _rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 32,
              ),
              onPressed: () => setState(() => _rating = index + 1),
            )),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _feedbackController,
            decoration: const InputDecoration(
              labelText: 'Optional feedback',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _submitRating(true),
          child: const Text('SKIP'),
        ),
        ElevatedButton(
          onPressed: () => _submitRating(false),
          child: const Text('SUBMIT'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    _feedbackController.dispose();
    super.dispose();
  }
}