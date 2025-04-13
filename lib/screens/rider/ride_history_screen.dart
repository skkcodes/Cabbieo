import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  final DatabaseReference ridesRef = FirebaseDatabase.instance.ref().child('active_rides');
  final String riderId = FirebaseAuth.instance.currentUser!.uid;

  List<Map<dynamic, dynamic>> rideHistory = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRideHistory();
  }

  void fetchRideHistory() async {
    setState(() => isLoading = true);
    final snapshot = await ridesRef.orderByChild('rider_id').equalTo(riderId).get();
    final List<Map<dynamic, dynamic>> loadedRides = [];

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data.forEach((key, value) {
        final ride = Map<String, dynamic>.from(value);
        if (ride['status'] == 'completed') {
          loadedRides.add(ride);
        }
      });

      // Sort in descending order: newest first
      loadedRides.sort((a, b) => b['completed_at'].compareTo(a['completed_at']));
    }

    setState(() {
      rideHistory = loadedRides;
      isLoading = false;
    });
  }

  String formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Ride History",style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh,color: Colors.white,),
            tooltip: "Refresh",
            onPressed: fetchRideHistory,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : rideHistory.isEmpty
              ? const Center(child: Text("No completed rides yet."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rideHistory.length,
                  itemBuilder: (context, index) {
                    final ride = rideHistory[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Fare: ₹${ride['fare']}",
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                                Text(
                                  formatTimestamp(ride['completed_at']),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.circle, size: 10, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(child: Text("From: ${ride['source']['address']}")),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.flag, size: 10, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(child: Text("To: ${ride['destination']['address']}")),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text("Driver ID: ${ride['driver_id']}",
                                style: const TextStyle(fontSize: 14, color: Colors.black87)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
