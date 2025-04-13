import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:waygo/screens/auth/splash_screen.dart';


class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key});

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  final DatabaseReference usersRef = FirebaseDatabase.instance.ref().child('users');
  final String riderId = FirebaseAuth.instance.currentUser!.uid;

  bool isEditing = false;
  bool isLoading = true;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  void fetchProfile() async {
    final snapshot = await usersRef.child(riderId).get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      nameController.text = data['name'] ?? '';
      emailController.text = data['email'] ?? '';
      phoneController.text = data['phone'] ?? '';
    }
    setState(() {
      isLoading = false;
    });
  }

  void updateProfile() async {
    await usersRef.child(riderId).update({
      'name': nameController.text.trim(),
      'email': emailController.text.trim(),
      'phone': phoneController.text.trim(),
    });
    setState(() {
      isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber,
        title: const Text("Rider Profile"),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              if (isEditing) {
                updateProfile();
              } else {
                setState(() => isEditing = true);
              }
            },
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 60,
                    backgroundImage: AssetImage('assets/logo/man.png'),
                  ),
                  const SizedBox(height: 20),
                  buildTextField('Name', nameController),
                  const SizedBox(height: 16),
                  buildTextField('Email', emailController),
                  const SizedBox(height: 16),
                  buildTextField('Phone', phoneController),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SplashScreen()));
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text("Logout"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      readOnly: !isEditing,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: isEditing ? Colors.grey.shade100 : Colors.grey.shade200,
      ),
    );
  }
}
