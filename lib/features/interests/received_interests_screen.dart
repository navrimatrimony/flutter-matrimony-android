import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_routes.dart';
import '../matrimony_profile/profile_detail_screen.dart';

/// ===============================
/// RECEIVED INTERESTS SCREEN
/// ===============================
class ReceivedInterestsScreen extends StatefulWidget {
  const ReceivedInterestsScreen({super.key});

  @override
  State<ReceivedInterestsScreen> createState() => _ReceivedInterestsScreenState();
}

class _ReceivedInterestsScreenState extends State<ReceivedInterestsScreen> {
  List<dynamic> _interests = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchReceivedInterests();
  }

  Future<void> _fetchReceivedInterests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.getReceivedInterests();
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
        final receivedList = data['received'] as List?;
        setState(() {
          _interests = receivedList ?? [];
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

  Future<void> _acceptInterest(int interestId) async {
    try {
      final response = await ApiClient.acceptInterest(interestId);
      if (!mounted) return;

      final statusCode = response['statusCode'];

      if (statusCode == 200 && response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Interest accepted.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Refresh the list
        _fetchReceivedInterests();
      } else {
        final errorMessage = response['message'] ?? 'Interest accept करता आला नाही.';
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

  Future<void> _rejectInterest(int interestId) async {
    try {
      final response = await ApiClient.rejectInterest(interestId);
      if (!mounted) return;

      final statusCode = response['statusCode'];

      if (statusCode == 200 && response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Interest rejected.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Refresh the list
        _fetchReceivedInterests();
      } else {
        final errorMessage = response['message'] ?? 'Interest reject करता आला नाही.';
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
        title: const Text('Received Interests'),
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
                onPressed: _fetchReceivedInterests,
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
          'No received interests.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchReceivedInterests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _interests.length,
        itemBuilder: (context, index) {
          final interest = _interests[index] as Map<String, dynamic>;
          final senderProfile = interest['sender_profile'] as Map<String, dynamic>?;
          final status = interest['status']?.toString();
          final interestId = interest['id'] as int?;

          if (senderProfile == null || interestId == null) {
            return const SizedBox.shrink();
          }

          final photoUrl = _constructPhotoUrl(senderProfile);
          final senderName = senderProfile['full_name']?.toString() ?? 'Unknown';
          final senderProfileId = senderProfile['id'] as int?;

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
                    onTap: senderProfileId != null
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileDetailScreen(profileId: senderProfileId),
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
                          onTap: senderProfileId != null
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProfileDetailScreen(profileId: senderProfileId),
                                    ),
                                  );
                                }
                              : null,
                          child: Text(
                            senderName,
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
                        // Accept/Reject buttons for pending interests
                        if (status == 'pending')
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    _acceptInterest(interestId);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  child: const Text('Accept'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    _rejectInterest(interestId);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ),
                            ],
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
