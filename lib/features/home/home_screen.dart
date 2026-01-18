import 'package:flutter/material.dart';
import '../matrimony_profile/create_profile_screen.dart';
import '../photo/photo_upload_screen.dart';
import '../../core/api_client.dart';
import '../../core/api_routes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final profile = ApiClient.currentUserProfile;

    // Construct photo URL using same logic as view_profile_screen
    String? photoUrl;
    if (profile != null) {
      if (profile['profile_photo_url'] != null && profile['profile_photo_url'].toString().isNotEmpty) {
        photoUrl = profile['profile_photo_url'].toString();
      } else if (profile['url'] != null && profile['url'].toString().isNotEmpty) {
        photoUrl = profile['url'].toString();
      } else if (profile['photo_url'] != null && profile['photo_url'].toString().isNotEmpty) {
        photoUrl = profile['photo_url'].toString();
      } else if (profile['profile_photo'] != null && profile['profile_photo'].toString().isNotEmpty) {
        final filename = profile['profile_photo'].toString();
        final baseDomain = ApiRoutes.baseUrl.replaceAll('/api', '');
        photoUrl = '$baseDomain/uploads/matrimony_photos/$filename';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        automaticallyImplyLeading: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Drawer Header
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Profile Photo
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: Colors.white,
                    backgroundImage: photoUrl != null
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl == null
                        ? const Icon(Icons.person, size: 42, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  // Full Name
                  Text(
                    profile?['full_name']?.toString() ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Email (if available in profile, else show placeholder)
                  Text(
                    profile?['email']?.toString() ?? 'Email not available',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Menu Items
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text(
                'Home',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              selected: true,
              selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
              onTap: () {
                Navigator.pop(context); // Close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('माझे प्रोफाइल'),
              dense: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushNamed(context, '/view-profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Profile'),
              dense: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              onTap: () async {
                Navigator.pop(context); // Close drawer
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📡 Profile load करत आहे...'),
                    backgroundColor: Colors.blue,
                    duration: Duration(seconds: 1),
                  ),
                );
                
                await ApiClient.getMyProfile();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Profile load केले. Edit करण्यासाठी ready आहे...'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );

                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateMatrimonyProfileScreen(
                        existingProfile: ApiClient.currentUserProfile,
                      ),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Upload Photo'),
              dense: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PhotoUploadScreen(),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              dense: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              onTap: () {
                Navigator.pop(context); // Close drawer
                ApiClient.logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📡 Profile load करत आहे...'),
                    backgroundColor: Colors.blue,
                    duration: Duration(seconds: 1),
                  ),
                );
                
                await ApiClient.getMyProfile();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Profile load केले. Edit करण्यासाठी ready आहे...'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );

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
            const SizedBox(height: 12),
            // >>>>> येथे नवीन कोड सुरू होतो <<<<<
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/view-profile');
              },
              child: const Text("माझे प्रोफाइल पहा"),
            ),
            const SizedBox(height: 12),
            // >>>>> येथे नवीन कोड समाप्त होतो <<<<<
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PhotoUploadScreen(),
                  ),
                );
              },
              child: const Text("Upload Profile Photo"),
            ),
          ],
        ),
      ),

    );
  }
}
