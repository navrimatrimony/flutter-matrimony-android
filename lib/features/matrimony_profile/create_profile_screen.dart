import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../photo/photo_upload_screen.dart';

class CreateMatrimonyProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? existingProfile;

  const CreateMatrimonyProfileScreen({
    super.key,
    this.existingProfile,
  });

  @override
  State<CreateMatrimonyProfileScreen> createState() =>
      _CreateMatrimonyProfileScreenState();
}

class _CreateMatrimonyProfileScreenState
    extends State<CreateMatrimonyProfileScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _casteController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  bool _loading = false;
  bool _locationSearching = false;
  int? _selectedLocationId;
  String? _selectedLocationLabel;
  int _locationSearchRequest = 0;
  List<Map<String, dynamic>> _locationSuggestions = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _prefillExistingProfile();
  }

  void _prefillExistingProfile() {
    final profile = widget.existingProfile;
    if (profile == null) return;

    _fullNameController.text = profile['full_name']?.toString() ?? '';
    _casteController.text = profile['caste']?.toString() ?? '';
    _educationController.text =
        ApiClient.profileEducationLabel(profile) ?? '';
    _dobController.text = profile['date_of_birth']?.toString() ?? '';

    final locationId = profile['location_id'];
    if (locationId is int) {
      _selectedLocationId = locationId;
    } else {
      _selectedLocationId = int.tryParse(locationId?.toString() ?? '');
    }

    final locationLabel = ApiClient.profileLocationLabel(profile);
    if (locationLabel != null) {
      _selectedLocationLabel = locationLabel;
      _locationController.text = locationLabel;
    } else if (_selectedLocationId != null) {
      _selectedLocationLabel = 'Location ID: $_selectedLocationId';
      _locationController.text = _selectedLocationLabel!;
    }
  }

  Future<void> _searchLocations(String query) async {
    final requestId = ++_locationSearchRequest;
    final trimmedQuery = query.trim();

    if (_selectedLocationLabel == null ||
        trimmedQuery != _selectedLocationLabel) {
      _selectedLocationId = null;
      _selectedLocationLabel = null;
    }

    if (trimmedQuery.length < 2) {
      setState(() {
        _locationSearching = false;
        _locationSuggestions = <Map<String, dynamic>>[];
      });
      return;
    }

    setState(() {
      _locationSearching = true;
    });

    final results = await ApiClient.searchLocations(trimmedQuery);
    if (!mounted || requestId != _locationSearchRequest) return;

    setState(() {
      _locationSuggestions = results;
      _locationSearching = false;
    });
  }

  void _selectLocation(Map<String, dynamic> location) {
    final locationId = ApiClient.locationIdFrom(location);
    if (locationId == null) return;

    final label = ApiClient.locationSuggestionLabel(location);
    setState(() {
      _selectedLocationId = locationId;
      _selectedLocationLabel = label;
      _locationController.text = label;
      _locationSuggestions = <Map<String, dynamic>>[];
      _locationSearching = false;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _submitProfile() async {
    if (_selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया suggestions मधून location निवडा.'),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    final payload = {
      'full_name': _fullNameController.text.trim(),
      'date_of_birth': _dobController.text.trim(),
      'caste': _casteController.text.trim(),
      'highest_education': _educationController.text.trim(),
      'location_id': _selectedLocationId,
    };

    final response = widget.existingProfile == null
        ? await ApiClient.createMatrimonyProfile(payload)
        : await ApiClient.updateMatrimonyProfile(payload);

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    if (response['success'] == true) {
      final isCreate = widget.existingProfile == null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCreate
                ? '✅ Profile create यशस्वी!'
                : '✅ Profile update यशस्वी!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PhotoUploadScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ?? 'Profile save failed',
          ),
        ),
      );
    }
  }

  Widget _buildLocationSuggestions() {
    if (_locationSearching) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(),
      );
    }

    if (_locationSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _locationSuggestions.length,
        itemBuilder: (context, index) {
          final location = _locationSuggestions[index];
          final label = ApiClient.locationSuggestionLabel(location);
          final hierarchy = location['hierarchy']?.toString().trim();

          return ListTile(
            dense: true,
            title: Text(label),
            subtitle: hierarchy != null &&
                    hierarchy.isNotEmpty &&
                    hierarchy != label
                ? Text(hierarchy)
                : null,
            onTap: () => _selectLocation(location),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingProfile == null ? 'Create Profile' : 'Edit Profile',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dobController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Date of Birth (YYYY-MM-DD)',
              ),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime(1995),
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                );

                if (pickedDate != null) {
                  final dateStr =
                      "${pickedDate.year.toString().padLeft(4, '0')}-"
                      "${pickedDate.month.toString().padLeft(2, '0')}-"
                      "${pickedDate.day.toString().padLeft(2, '0')}";
                  _dobController.text = dateStr;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Date select केले: $dateStr'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _casteController,
              decoration: const InputDecoration(
                labelText: 'Caste',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _educationController,
              decoration: const InputDecoration(
                labelText: 'Education',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
              ),
              onChanged: _searchLocations,
            ),
            _buildLocationSuggestions(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submitProfile,
                child: _loading
                    ? const CircularProgressIndicator()
                    : Text(
                        widget.existingProfile == null
                            ? 'Create Profile'
                            : 'Update Profile',
                      ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }
}
