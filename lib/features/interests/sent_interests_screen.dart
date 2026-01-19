import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_routes.dart';
import '../matrimony_profile/profile_detail_screen.dart';

/// ===============================
/// SENT INTERESTS SCREEN
/// ===============================
class SentInterestsScreen extends StatefulWidget {
  const SentInterestsScreen({super.key});

  @override
  State<SentInterestsScreen> createState() => _SentInterestsScreenState();
}

class _SentInterestsScreenState extends State<SentInterestsScreen> {
  List<dynamic> _interests = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSentInterests();
  }

  Future<void> _fetchSentInterests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.getSentInterests();
      if (!mounted) return;

      final statusCode = response['statusCode'];

      if (statusCode == 401) {
        setState(() {
          _errorMessage = '🔒 Auth expired! पुन्हा login करा';
          _isLoading = false;
        });
        return;
      }

      if (statusCode == 403) {
        setState(() {
          _errorMessage = response['message'] ?? 'Unauthorized';
          _isLoading = false;
        });
        return;
      }

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final sentList = data['sent'] as List?;
        setState(() {
          _interests = sentList ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _interests = [];
          _errorMessage = response['message'] ?? 'Interests लोड होऊ शकले नाही.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'एक अनपेक्षित एरर आली: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _withdrawInterest(int interestId) async {
    try {
      final response = await ApiClient.withdrawInterest(interestId);
      if (!mounted) return;

      final statusCode = response['statusCode'];

      if (statusCode == 200 && response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Interest withdrawn successfully.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Refresh the list
        _fetchSentInterests();
      } else {
        final errorMessage = response['message'] ?? 'Interest withdraw करता आला नाही.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ एक अनपेक्षित एरर आली: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Construct photo URL
  String? _constructPhotoUrl(Map<String, dynamic>? profile) {
    if (profile == null) return null;

    if (profile['profile_photo_url'] != null && profile['profile_photo_url'].toString().isNotEmpty) {
      return profile['profile_photo_url'].toString();
    } else if (profile['url'] != null && profile['url'].toString().isNotEmpty) {
      return profile['url'].toString();
    } else if (profile['photo_url'] != null && profile['photo_url'].toString().isNotEmpty) {
      return profile['photo_url'].toString();
    } else if (profile['profile_photo'] != null && profile['profile_photo'].toString().isNotEmpty) {
      final filename = profile['profile_photo'].toString();
      final baseDomain = ApiRoutes.baseUrl.replaceAll('/api', '');
      return '$baseDomain/uploads/matrimony_photos/$filename';
    }

    return null;
  }

  // Get status text and color
  String _getStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sent Interests'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchSentInterests,
                child: const Text('पुन्हा प्रयत्न करा'),
              ),
            ],
          ),
        ),
      );
    }

    if (_interests.isEmpty) {
      return const Center(
        child: Text(
          'You have not sent any interests yet.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchSentInterests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _interests.length,
        itemBuilder: (context, index) {
          final interest = _interests[index] as Map<String, dynamic>;
          final receiverProfile = interest['receiver_profile'] as Map<String, dynamic>?;
          final status = interest['status']?.toString();
          final interestId = interest['id'] as int?;

          if (receiverProfile == null || interestId == null) {
            return const SizedBox.shrink();
          }

          final photoUrl = _constructPhotoUrl(receiverProfile);
          final receiverName = receiverProfile['full_name']?.toString() ?? 'Unknown';
          final receiverProfileId = receiverProfile['id'] as int?;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Photo
                  GestureDetector(
                    onTap: receiverProfileId != null
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileDetailScreen(profileId: receiverProfileId),
                              ),
                            );
                          }
                        : null,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null
                          ? const Icon(Icons.person, size: 40, color: Colors.grey)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Profile Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: receiverProfileId != null
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProfileDetailScreen(profileId: receiverProfileId),
                                    ),
                                  );
                                }
                              : null,
                          child: Text(
                            receiverName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              'Status: ',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            Text(
                              _getStatusText(status),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(status),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Withdraw button for pending interests
                        if (status == 'pending')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                _withdrawInterest(interestId);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Text('Withdraw Interest'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
