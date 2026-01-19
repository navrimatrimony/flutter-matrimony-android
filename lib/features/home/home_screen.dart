import 'package:flutter/material.dart';
import '../matrimony_profile/create_profile_screen.dart';
import '../photo/photo_upload_screen.dart';
import '../interests/sent_interests_screen.dart';
import '../interests/received_interests_screen.dart';
import '../browse/browse_profiles_screen.dart';
import '../../core/api_client.dart';
import '../../core/api_routes.dart';
import '../../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  // Interest statistics state
  bool _isLoadingStats = true;
  String? _statsError;
  
  // Sent interests counts
  int _sentTotal = 0;
  int _sentPending = 0;
  int _sentAccepted = 0;
  int _sentRejected = 0;
  
  // Received interests counts
  int _receivedTotal = 0;
  int _receivedPending = 0;
  int _receivedAccepted = 0;
  int _receivedRejected = 0;

  @override
  void initState() {
    super.initState();
    _fetchInterestStatistics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route observer for RouteAware lifecycle
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    // Unsubscribe from route observer
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Called when returning to this route (after Navigator.pop)
  @override
  void didPopNext() {
    super.didPopNext();
    // Refresh interest statistics when dashboard becomes visible again
    _fetchInterestStatistics();
  }

  Future<void> _fetchInterestStatistics() async {
    setState(() {
      _isLoadingStats = true;
      _statsError = null;
    });

    try {
      // Fetch both sent and received interests in parallel
      final sentResponse = ApiClient.getSentInterests();
      final receivedResponse = ApiClient.getReceivedInterests();
      
      final results = await Future.wait([sentResponse, receivedResponse]);
      if (!mounted) return;

      final sentData = results[0] as Map<String, dynamic>;
      final receivedData = results[1] as Map<String, dynamic>;

      // Process sent interests
      if (sentData['statusCode'] == 200 && sentData['success'] == true && sentData['data'] != null) {
        final data = sentData['data'] as Map<String, dynamic>;
        final sentList = data['sent'] as List? ?? [];
        
        int pending = 0;
        int accepted = 0;
        int rejected = 0;
        
        for (final interest in sentList) {
          final interestMap = interest as Map<String, dynamic>;
          final status = interestMap['status']?.toString().toLowerCase();
          if (status == 'pending') {
            pending++;
          } else if (status == 'accepted') {
            accepted++;
          } else if (status == 'rejected') {
            rejected++;
          }
        }
        
        _sentTotal = sentList.length;
        _sentPending = pending;
        _sentAccepted = accepted;
        _sentRejected = rejected;
      }

      // Process received interests
      if (receivedData['statusCode'] == 200 && receivedData['success'] == true && receivedData['data'] != null) {
        final data = receivedData['data'] as Map<String, dynamic>;
        final receivedList = data['received'] as List? ?? [];
        
        int pending = 0;
        int accepted = 0;
        int rejected = 0;
        
        for (final interest in receivedList) {
          final interestMap = interest as Map<String, dynamic>;
          final status = interestMap['status']?.toString().toLowerCase();
          if (status == 'pending') {
            pending++;
          } else if (status == 'accepted') {
            accepted++;
          } else if (status == 'rejected') {
            rejected++;
          }
        }
        
        _receivedTotal = receivedList.length;
        _receivedPending = pending;
        _receivedAccepted = accepted;
        _receivedRejected = rejected;
      }

      // Update UI after processing both responses
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statsError = 'Failed to load statistics';
        _isLoadingStats = false;
      });
    }
  }

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
        title: const Text('Dashboard'),
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
                mainAxisSize: MainAxisSize.min,
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
                  Flexible(
                    child: Text(
                      profile?['full_name']?.toString() ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Email (if available in profile, else show placeholder)
                  Flexible(
                    child: Text(
                      profile?['email']?.toString() ?? 'Email not available',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Menu Items
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text(
                'Dashboard',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              selected: true,
              selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
              onTap: () {
                Navigator.pop(context); // Close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Browse Profiles'),
              dense: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BrowseProfilesScreen(),
                  ),
                );
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
            ListTile(
              leading: const Icon(Icons.send),
              title: const Text('Sent Interests'),
              dense: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SentInterestsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.inbox),
              title: const Text('Received Interests'),
              dense: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReceivedInterestsScreen(),
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
      body: _buildDashboardBody(),
    );
  }

  // Build Dashboard body with action cards
  Widget _buildDashboardBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // Welcome message
          Text(
            'Welcome to Matrimony App',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose an action to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Interest Statistics Section
          _buildInterestStatisticsSection(),
          const SizedBox(height: 24),
          // Browse Profiles Card
          _buildDashboardCard(
            icon: Icons.search,
            title: 'Browse Profiles',
            subtitle: 'View and explore matrimony profiles',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BrowseProfilesScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Sent Interests Card
          _buildDashboardCard(
            icon: Icons.send,
            title: 'Sent Interests',
            subtitle: 'View interests you have sent',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SentInterestsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Received Interests Card
          _buildDashboardCard(
            icon: Icons.inbox,
            title: 'Received Interests',
            subtitle: 'View and respond to received interests',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReceivedInterestsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // My Profile Card
          _buildDashboardCard(
            icon: Icons.person,
            title: 'My Profile',
            subtitle: 'View your matrimony profile',
            onTap: () {
              Navigator.pushNamed(context, '/view-profile');
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Build a dashboard action card
  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build Interest Statistics Section
  Widget _buildInterestStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interest Statistics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        // Sent Interests Stats Card
        _buildStatsCard(
          title: 'Sent Interests',
          icon: Icons.send,
          color: Colors.blue,
          total: _sentTotal,
          pending: _sentPending,
          accepted: _sentAccepted,
          rejected: _sentRejected,
          isLoading: _isLoadingStats,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SentInterestsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // Received Interests Stats Card
        _buildStatsCard(
          title: 'Received Interests',
          icon: Icons.inbox,
          color: Colors.green,
          total: _receivedTotal,
          pending: _receivedPending,
          accepted: _receivedAccepted,
          rejected: _receivedRejected,
          isLoading: _isLoadingStats,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ReceivedInterestsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  // Build a statistics card
  Widget _buildStatsCard({
    required String title,
    required IconData icon,
    required Color color,
    required int total,
    required int pending,
    required int accepted,
    required int rejected,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    final hasError = _statsError != null;
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Loading...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else if (hasError)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      '--',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem('Total', total.toString(), Colors.grey.shade700),
                    ),
                    Expanded(
                      child: _buildStatItem('Pending', pending.toString(), Colors.orange),
                    ),
                    Expanded(
                      child: _buildStatItem('Accepted', accepted.toString(), Colors.green),
                    ),
                    Expanded(
                      child: _buildStatItem('Rejected', rejected.toString(), Colors.red),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Build a single stat item
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
