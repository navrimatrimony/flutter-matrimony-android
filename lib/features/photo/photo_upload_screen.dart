import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';
import '../../core/api_routes.dart';

class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({super.key});

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  File? _selectedImage;
  String? _uploadedUrl;
  bool _uploading = false;

  // Helper method for showing success notifications
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Helper method for showing error messages
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Helper method for showing info messages
  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickImage() async {
    _showInfoMessage('📷 Gallery खोलत आहे...');

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) {
        _showInfoMessage('ℹ️ Photo select करणे cancel केले');
        return;
      }

      final file = File(pickedFile.path);
      final fileSize = await file.length();
      final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

      setState(() {
        _selectedImage = file;
        _uploadedUrl = null;
      });

      _showSuccessMessage(
        '✅ Photo यशस्वीरित्या select केले!\n📁 File: ${pickedFile.name}\n💾 Size: $fileSizeMB MB',
      );
    } catch (e) {
      _showErrorMessage(
        '❌ Error: Gallery access करताना problem!\n${e.toString()}',
      );
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) {
      _showErrorMessage('⚠️ पहिले photo select करा!');
      return;
    }

    // >>>>> येथे नवीन कोड सुरू होतो <<<<<
    _showInfoMessage('🔍 प्रोफाइल तपासत आहे...');

    // आधी प्रोफाइल तपासा
    try {
      final profileCheck = await ApiClient.getMyProfile();
      final profileStatusCode = profileCheck['statusCode'];

      if (profileStatusCode == 404 || profileCheck['success'] != true) {
        _showErrorMessage('❌ प्रोफाइल सापडली नाही! कृपया आधी प्रोफाइल तयार करा.');
        Navigator.pushReplacementNamed(context, '/create-profile');
        return; // इथेच थांबा
      }

      _showSuccessMessage('✅ प्रोफाइल सापडली. आता अपलोड सुरू करत आहे...');
    } catch (e) {
      _showErrorMessage('❌ प्रोफाइल तपासताना एरर: ${e.toString()}');
      return; // इथेच थांबा
    }

    // आता अपलोड सुरू करा
    setState(() {
      _uploading = true;
    });
    // >>>>> येथे नवीन कोड समाप्त होतो <<<<<

    try {
      _showInfoMessage('📡 API ला request पाठवत आहे...');

      final response = await ApiClient.uploadProfilePhoto(_selectedImage!);
      final statusCode = response['statusCode'];

      if (statusCode == 401) {
        _showErrorMessage('🔒 Auth expired! पुन्हा login करा');
        return;
        // >>>>> येथे नवीन कोड सुरू होतो <<<<<
      } else if (statusCode == 404) {
        // Profile आधीच verify केली आहे, पण photo upload API 404 देते
        // Backend issue असू शकते - detailed error message दाखवा
        final errorMsg = response['message']?.toString();
        final responseBody = response.toString();
        
        // Debugging साठी print
        print('=== PHOTO UPLOAD 404 ERROR ===');
        print('Status Code: $statusCode');
        print('Response: $responseBody');
        print('Error Message: $errorMsg');
        print('Profile verified: Yes (before upload)');
        print('Current Profile: ${ApiClient.currentUserProfile != null ? "Exists" : "Null"}');
        if (ApiClient.currentUserProfile != null) {
          print('Profile Data: ${ApiClient.currentUserProfile}');
        }
        print('Upload API URL: ${ApiRoutes.baseUrl}${ApiRoutes.matrimonyProfilePhoto}');
        print('=================================');
        
        if (errorMsg != null && errorMsg.isNotEmpty) {
          _showErrorMessage('❌ $errorMsg');
        } else {
          _showErrorMessage(
            '❌ Photo upload API ला profile सापडली नाही (404).\n'
            'Backend issue असू शकते. Profile आहे, पण upload endpoint 404 देते.\n'
            'कृपया backend verify करा. Console मध्ये details पहा.'
          );
        }
        return;
      } else if (statusCode == 422) {
        final errorMsg = response['message']?.toString() ?? 'Validation error';
        _showErrorMessage('❌ Validation Error: $errorMsg');
        return;
      } else if (response['success'] == true && response['data'] != null) {
        final uploadData = response['data'] as Map<String, dynamic>;
        final photoUrl = uploadData['url']?.toString();

        setState(() {
          _uploadedUrl = photoUrl;
        });

        // Profile refresh करा latest photo साठी
        await ApiClient.getMyProfile();

        _showSuccessMessage('🎉 Photo upload यशस्वी! Profile मध्ये photo update झाला आहे.');
        
        // 1.5 seconds नंतर home screen वर navigate करा
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, "/home");
          }
        });
      } else {
        _showErrorMessage(
          '❌ Upload fail झाला!\nStatus Code: $statusCode',
        );
      }
    } catch (e) {
      _showErrorMessage(
        '❌ Exception आली!\nError: ${e.toString()}',
      );
      print('Upload Error: $e');
    } finally {
      setState(() {
        _uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget preview = const Text('No photo selected');

    if (_uploadedUrl != null) {
      preview = Image.network(
        _uploadedUrl!,
        height: 180,
        width: 180,
        fit: BoxFit.cover,
      );
    } else if (_selectedImage != null) {
      preview = Image.file(
        _selectedImage!,
        height: 180,
        width: 180,
        fit: BoxFit.cover,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Profile Photo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 180,
              width: 180,
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: preview,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _uploading ? null : _pickImage,
              child: const Text('Pick From Gallery'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _uploading ? null : _uploadImage,
              child: _uploading
                  ? const CircularProgressIndicator()
                  : const Text('Upload Photo'),
            ),
          ],
        ),
      ),
    );
  }
}
