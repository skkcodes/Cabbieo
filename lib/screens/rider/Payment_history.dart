import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final DatabaseReference paymentsRef = FirebaseDatabase.instance.ref().child('payments');
  final String riderId = FirebaseAuth.instance.currentUser?.uid ?? "";

  List<Map<String, dynamic>> paymentHistory = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchPaymentHistory();
  }

  Future<void> fetchPaymentHistory() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final snapshot = await paymentsRef.get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map;
        final List<Map<String, dynamic>> loadedPayments = [];

        data.forEach((key, value) {
          final payment = Map<String, dynamic>.from(value);
          if (payment['rider_id'] == riderId) {
            loadedPayments.add(payment);
          }
        });

        loadedPayments.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

        setState(() {
          paymentHistory = loadedPayments;
          isLoading = false;
        });
      } else {
        setState(() {
          paymentHistory = [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error fetching data: ${e.toString()}";
        isLoading = false;
      });
    }
  }

  String formatTimestamp(dynamic timestamp) {
    try {
      final ts = timestamp is int ? timestamp : int.parse(timestamp.toString());
      final date = DateTime.fromMillisecondsSinceEpoch(ts);
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Payment History",style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh,color: Colors.white,),
            tooltip: "Refresh",
            onPressed: fetchPaymentHistory,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : paymentHistory.isEmpty
                  ? const Center(child: Text("No payments found yet."))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: paymentHistory.length,
                      itemBuilder: (context, index) {
                        final payment = paymentHistory[index];
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 5,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              "₹${payment['amount']}",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 5),
                                Text("Driver ID: ${payment['driver_id'] ?? 'N/A'}", style: const TextStyle(fontSize: 14)),
                                const SizedBox(height: 4),
                                Text("Ride ID: ${payment['ride_id'] ?? 'N/A'}", style: const TextStyle(fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(formatTimestamp(payment['timestamp']), style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
