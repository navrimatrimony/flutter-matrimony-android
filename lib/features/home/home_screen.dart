import 'package:flutter/material.dart';
import '../matrimony_profile/create_profile_screen.dart';
import '../../core/api_client.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await ApiClient.getMyProfile();

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateMatrimonyProfileScreen(
                  existingProfile: ApiClient.currentUserProfile,
                ),
              ),
            );
          },

          child: const Text("Edit Matrimony Profile"),
        ),
      ),

    );
  }
}
