import 'dart:ui';
import 'package:flutter/material.dart';
import '../matrimony_profile/edit_full_profile_screen.dart';
import '../photo/photo_upload_screen.dart';
import '../interests/sent_interests_screen.dart';
import '../interests/received_interests_screen.dart';
import '../browse/browse_profiles_screen.dart';
import '../../core/app_strings.dart';
import '../../core/api_client.dart';
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

      final sentData = results[0];
      final receivedData = results[1];

      // Process sent interests
      if (sentData['statusCode'] == 200 &&
          sentData['success'] == true &&
          sentData['data'] != null) {
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
      if (receivedData['statusCode'] == 200 &&
          receivedData['success'] == true &&
          receivedData['data'] != null) {
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
    final photoUrl = ApiClient.resolveProfilePhotoUrl(profile);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.dashboard),
        automaticallyImplyLeading: true,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            // Drawer Header - Custom Container with blurred background effect
            SafeArea(
              bottom: false,
              child: Container(
                height: 190,
                width: double.infinity,
                color: Theme.of(context).primaryColor,
                child: photoUrl != null
                    // If user image exists: Show HERO with blurred background
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background layer: Blurred image (fills empty space)
                          ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: 10,
                              sigmaY: 10,
                            ),
                            child: Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback: solid color if image fails
                                return Container(
                                  color: Theme.of(context).primaryColor,
                                );
                              },
                            ),
                          ),
                          // Foreground layer: Clear image (full photo, no crop)
                          Center(
                            child: Image.network(
                              photoUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback to brand logo if image fails to load
                                return Image.asset(
                                  'assets/images/brand_logo.png',
                                  height: 190,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.favorite,
                                      size: 60,
                                      color: Colors.white,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      )
                    // If user image does NOT exist: Show brand logo as HERO
                    : Image.asset(
                        'assets/images/brand_logo.png',
                        height: 190,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.favorite,
                              size: 60,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
              ),
            ),
            // Drawer Body - Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Menu Items
                  ListTile(
                    leading: const Icon(Icons.home),
                    title: Text(
                      AppStrings.dashboard,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    selected: true,
                    selectedTileColor: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.search),
                    title: Text(AppStrings.browseProfiles),
                    dense: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
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
                    title: Text(AppStrings.myProfile),
                    dense: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.pushNamed(context, '/view-profile');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.workspace_premium),
                    title: Text(AppStrings.plansUpgradeMenu),
                    dense: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.pushNamed(context, '/plans');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: Text(AppStrings.editProfile),
                    dense: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
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
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '✅ Profile load केले. Edit करण्यासाठी ready आहे...',
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditFullProfileScreen(
                            initialProfile: ApiClient.currentUserProfile,
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_camera),
                    title: Text(AppStrings.uploadPhoto),
                    dense: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
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
                    title: Text(AppStrings.sentInterests),
                    dense: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
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
                    title: Text(AppStrings.receivedInterests),
                    dense: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
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
                    title: Text(
                      AppStrings.logout,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    dense: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    onTap: () async {
                      Navigator.pop(context); // Close drawer
                      await ApiClient.logout();
                      if (!context.mounted) return;
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ],
              ),
            ),
            // Drawer Footer - Brand Logo (decorative)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/brand_logo.png',
                  height: 36,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.favorite,
                      size: 36,
                      color: Colors.grey,
                    );
                  },
                ),
              ),
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
            AppStrings.dashboardHeadline,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.dashboardSubtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Interest Statistics Section
          _buildInterestStatisticsSection(),
          const SizedBox(height: 24),
          // Browse Profiles Card
          _buildDashboardCard(
            icon: Icons.search,
            title: AppStrings.browseProfiles,
            subtitle: AppStrings.browseProfilesSubtitle,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BrowseProfilesScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          // Sent Interests Card
          _buildDashboardCard(
            icon: Icons.send,
            title: AppStrings.sentInterests,
            subtitle: AppStrings.sentInterestsSubtitle,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SentInterestsScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          // Received Interests Card
          _buildDashboardCard(
            icon: Icons.inbox,
            title: AppStrings.receivedInterests,
            subtitle: AppStrings.receivedInterestsSubtitle,
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
            title: AppStrings.myProfile,
            subtitle: AppStrings.myProfileSubtitle,
            onTap: () {
              Navigator.pushNamed(context, '/view-profile');
            },
          ),
          const SizedBox(height: 16),
          _buildDashboardCard(
            icon: Icons.photo_camera,
            title: AppStrings.uploadPhoto,
            subtitle: AppStrings.uploadPhotoSubtitle,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PhotoUploadScreen()),
              );
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
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
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
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
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
          AppStrings.interestStatistics,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // Sent Interests Stats Card
        _buildStatsCard(
          title: AppStrings.sentInterests,
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
              MaterialPageRoute(builder: (_) => const SentInterestsScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        // Received Interests Stats Card
        _buildStatsCard(
          title: AppStrings.receivedInterests,
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
                      color: color.withValues(alpha: 0.1),
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
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      AppStrings.loading,
                      style: const TextStyle(color: Colors.grey),
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
                      child: _buildStatItem(
                        AppStrings.total,
                        total.toString(),
                        Colors.grey.shade700,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        AppStrings.pending,
                        pending.toString(),
                        Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        AppStrings.accepted,
                        accepted.toString(),
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        AppStrings.rejected,
                        rejected.toString(),
                        Colors.red,
                      ),
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
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
