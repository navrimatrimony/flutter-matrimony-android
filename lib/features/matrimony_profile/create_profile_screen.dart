// Flutter UI library
import 'package:flutter/material.dart';

// API call साठी आपली custom client
import '../../core/api_client.dart';

/// ===============================
/// CREATE MATRIMONY PROFILE SCREEN
/// ===============================
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

  // -------------------------------
  // Text controllers (form fields)
  // -------------------------------
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _casteController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  @override
  void initState() {
    super.initState();

    if (widget.existingProfile != null) {
      _fullNameController.text =
          widget.existingProfile!['full_name'] ?? '';
      _casteController.text =
          widget.existingProfile!['caste'] ?? '';
      _educationController.text =
          widget.existingProfile!['education'] ?? '';
      _locationController.text =
          widget.existingProfile!['location'] ?? '';
      _dobController.text =
          widget.existingProfile!['date_of_birth'] ?? '';
    }
  }
  // Button loading state
  bool _loading = false;

  // =====================================
  // SUBMIT PROFILE FUNCTION (IMPORTANT)
  // =====================================
  Future<void> _submitProfile() async {
    // Button disable + loader ON
    setState(() {
      _loading = true;
    });

    // Backend API call
    final response = widget.existingProfile == null
        ? await ApiClient.createMatrimonyProfile({
      "full_name": _fullNameController.text,
      "date_of_birth": _dobController.text,
      "caste": _casteController.text,
      "education": _educationController.text,
      "location": _locationController.text,
    })
        : await ApiClient.updateMatrimonyProfile({
      "full_name": _fullNameController.text,
      "date_of_birth": _dobController.text,
      "caste": _casteController.text,
      "education": _educationController.text,
      "location": _locationController.text,
    });



    // Loader OFF
    setState(() {
      _loading = false;
    });

    // Success → Home
    if (response["success"] == true) {
      final isCreate = widget.existingProfile == null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCreate 
            ? '✅ Profile create यशस्वी!'
            : '✅ Profile update यशस्वी!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pushReplacementNamed(context, "/home");
    }
    // Failure → show backend error
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response["message"]?.toString() ?? "Profile create failed",
          ),
        ),
      );
    }
  }

  // ===============================
  // UI BUILD METHOD
  // ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingProfile == null
              ? "Create Profile"
              : "Edit Profile",
        ),
      ),

        body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [

            // -------------------------
            // Full Name
            // -------------------------
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
              ),
            ),

            const SizedBox(height: 12),

            // -------------------------
            // Date of Birth (Picker)
            // -------------------------
            TextField(
              controller: _dobController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: "Date of Birth (YYYY-MM-DD)",
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

            // -------------------------
            // Caste
            // -------------------------
            TextField(
              controller: _casteController,
              decoration: const InputDecoration(
                labelText: "Caste",
              ),
            ),

            const SizedBox(height: 12),

            // -------------------------
            // Education
            // -------------------------
            TextField(
              controller: _educationController,
              decoration: const InputDecoration(
                labelText: "Education",
              ),
            ),

            const SizedBox(height: 12),

            // -------------------------
            // Location
            // -------------------------
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: "Location",
              ),
            ),

            const SizedBox(height: 24),

            // -------------------------
            // Submit Button
            // -------------------------
            ElevatedButton(
              onPressed: _loading ? null : _submitProfile,
              child: _loading
                  ? const CircularProgressIndicator()
                  : Text(widget.existingProfile == null
                  ? "Create Profile"
                  : "Update Profile"),

            ),
          ],
        ),
      ),
    );
  }
}
