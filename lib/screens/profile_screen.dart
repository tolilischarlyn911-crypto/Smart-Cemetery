import 'package:flutter/material.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatelessWidget {
  final UserModel user;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=12'),
            ),
            const SizedBox(height: 12),
            Text(user.name,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(user.email, style: const TextStyle(color: Colors.grey)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                onPressed: onLogout,
                child:
                    const Text('LOGOUT', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
