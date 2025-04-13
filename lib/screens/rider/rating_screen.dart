import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class RatingScreen extends StatefulWidget {
  final String rideId;
  final String driverId;

  const RatingScreen({required this.rideId, required this.driverId});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 5;
  final TextEditingController _feedbackController = TextEditingController();

  Future<void> _submitRating() async {
    try {
      // 1. Save rating to rides collection
      await FirebaseDatabase.instance
          .ref("ride_requests/${widget.rideId}")
          .update({
            "rating": _rating,
            "feedback": _feedbackController.text,
            "rated_at": ServerValue.timestamp,
          });

      // 2. Update driver's average rating
      await _updateDriverRating();

      // 3. Return to home
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting rating: ${e.toString()}")),
      );
    }
  }

  Future<void> _updateDriverRating() async {
    final driverRef = FirebaseDatabase.instance.ref("drivers/${widget.driverId}");
    final ratingsRef = FirebaseDatabase.instance.ref("ratings/${widget.driverId}");
    
    // Push new rating
    await ratingsRef.push().set({
      "ride_id": widget.rideId,
      "rating": _rating,
      "created_at": ServerValue.timestamp,
    });

    // Calculate new average
    final snapshot = await ratingsRef.once();
    if (snapshot.snapshot.value != null) {
      Map<dynamic, dynamic> ratings = snapshot.snapshot.value as Map;
      double total = 0;
      int count = 0;
      
      ratings.forEach((key, value) {
        total += value['rating'] as int;
        count++;
      });

      double average = total / count;
      await driverRef.update({"average_rating": average.toStringAsFixed(1)});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rate Your Ride")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("How was your ride?", style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 40,
                  ),
                  onPressed: () => setState(() => _rating = index + 1),
                );
              }),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                labelText: "Feedback (optional)",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _submitRating,
              child: const Text("Submit Rating"),
            ),
          ],
        ),
      ),
    );
  }
}