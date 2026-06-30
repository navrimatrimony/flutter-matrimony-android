import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/app_strings.dart';

class PhotoGalleryScreen extends StatefulWidget {
  const PhotoGalleryScreen({super.key});

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _photos = <Map<String, dynamic>>[];
  Map<String, dynamic> _meta = <String, dynamic>{};
  Map<String, dynamic> _verification = <String, dynamic>{};
  final Set<int> _busyPhotoIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.getProfilePhotos();
      if (!mounted) return;

      if (_responseSuccess(response)) {
        setState(() {
          _applyResponse(response);
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _errorMessage = _responseMessage(response, 'Photos load झाल्या नाहीत.');
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUpload() async {
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 90,
        maxWidth: 1600,
        maxHeight: 2134,
        requestFullMetadata: false,
      );
      if (picked.isEmpty) return;

      if (!mounted) return;
      setState(() => _isUploading = true);

      final files = picked.map((item) => File(item.path)).toList();
      final response = await ApiClient.uploadProfilePhotos(files);
      if (!mounted) return;

      if (_responseSuccess(response)) {
        setState(() {
          _applyResponse(response);
          _isUploading = false;
        });
        _showMessage(_responseMessage(response, 'Photo upload झाला.'));
        return;
      }

      setState(() => _isUploading = false);
      _showMessage(_responseMessage(response, 'Photo upload fail झाला.'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showMessage(e.toString());
    }
  }

  Future<void> _setPrimary(Map<String, dynamic> photo) async {
    final id = _photoId(photo);
    if (id == null) return;

    setState(() => _busyPhotoIds.add(id));
    try {
      final response = await ApiClient.setPrimaryProfilePhoto(id);
      if (!mounted) return;
      _handleActionResponse(response, id, 'Primary photo updated.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyPhotoIds.remove(id));
      _showMessage(e.toString());
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> photo) async {
    final id = _photoId(photo);
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.deletePhoto),
        content: const Text('This photo will be removed from your profile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyPhotoIds.add(id));
    try {
      final response = await ApiClient.deleteProfilePhoto(id);
      if (!mounted) return;
      _handleActionResponse(response, id, 'Photo deleted.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyPhotoIds.remove(id));
      _showMessage(e.toString());
    }
  }

  Future<void> _movePhoto(int index, int direction) async {
    final target = index + direction;
    if (target < 0 || target >= _photos.length) return;

    final next = List<Map<String, dynamic>>.from(_photos);
    final current = next.removeAt(index);
    next.insert(target, current);
    final ids = next.map(_photoId).whereType<int>().toList();
    if (ids.length != _photos.map(_photoId).whereType<int>().length) return;

    setState(() => _photos = next);

    try {
      final response = await ApiClient.reorderProfilePhotos(ids);
      if (!mounted) return;
      if (_responseSuccess(response)) {
        setState(() => _applyResponse(response));
        _showMessage(_responseMessage(response, 'Photo order updated.'));
        return;
      }

      _showMessage(_responseMessage(response, 'Photo reorder fail झाला.'));
      await _loadGallery();
    } catch (e) {
      _showMessage(e.toString());
      await _loadGallery();
    }
  }

  void _handleActionResponse(
    Map<String, dynamic> response,
    int photoId,
    String fallback,
  ) {
    if (_responseSuccess(response)) {
      setState(() {
        _applyResponse(response);
        _busyPhotoIds.remove(photoId);
      });
      _showMessage(_responseMessage(response, fallback));
      return;
    }

    setState(() => _busyPhotoIds.remove(photoId));
    _showMessage(_responseMessage(response, fallback));
  }

  void _applyResponse(Map<String, dynamic> response) {
    _photos = _safeMapList(response['photos']);
    _meta = _safeMap(response['meta']) ?? <String, dynamic>{};
    _verification = _safeMap(response['verification']) ?? _verification;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.photosVerification),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadGallery,
            icon: const Icon(Icons.refresh),
          ),
        ],
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
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadGallery,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGallery,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildVerificationCard(),
          const SizedBox(height: 14),
          _buildUploadCard(),
          const SizedBox(height: 14),
          if (_photos.isEmpty)
            _buildEmptyState()
          else
            ..._photos.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildPhotoRow(entry.key, entry.value),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard() {
    final profile = _safeMap(_verification['profile']) ?? <String, dynamic>{};
    final account = _safeMap(_verification['account']) ?? <String, dynamic>{};
    final kyc = _safeMap(_verification['kyc']) ?? <String, dynamic>{};
    final tags =
        _safeMap(_verification['verification_tags']) ?? <String, dynamic>{};
    final verified = _safeMapList(tags['verified']);

    return _panel(
      title: AppStrings.verificationStatus,
      icon: Icons.verified_user_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statusLine('Profile', _displayValue(profile['lifecycle_state'])),
          _statusLine('Photo', _displayValue(profile['photo_status'])),
          _statusLine('Email', _boolText(account['email_verified'])),
          _statusLine('Mobile', _boolText(account['mobile_verified'])),
          _statusLine('KYC', _displayValue(kyc['status'])),
          if ((kyc['message']?.toString().trim() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                kyc['message'].toString(),
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          if (verified.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: verified
                  .map(
                    (row) => Chip(
                      avatar: const Icon(Icons.check_circle, size: 16),
                      label: Text(row['label']?.toString() ?? ''),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    final remaining = _intValue(_meta['remaining_slots']);
    final canUpload = _meta['can_upload'] != false && (remaining ?? 1) > 0;

    return _panel(
      title: AppStrings.photosVerification,
      icon: Icons.photo_library_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            remaining == null
                ? AppStrings.photosVerificationSubtitle
                : '$remaining photo slots remaining',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: canUpload && !_isUploading ? _pickAndUpload : null,
            icon: _isUploading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_isUploading ? 'Uploading...' : AppStrings.addPhotos),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return _panel(
      title: AppStrings.photoGalleryEmpty,
      icon: Icons.image_not_supported_outlined,
      child: Text(
        'Clear profile photo upload करा. Backend approval नंतरच approved status दिसेल.',
        style: TextStyle(color: Colors.grey.shade700),
      ),
    );
  }

  Widget _buildPhotoRow(int index, Map<String, dynamic> photo) {
    final id = _photoId(photo);
    final busy = id != null && _busyPhotoIds.contains(id);
    final status = (photo['status']?.toString() ?? 'pending').toLowerCase();
    final isPrimary = photo['is_primary'] == true;
    final url = ApiClient.normalizeProfilePhotoUrl(
      photo['thumbnail_url'] ?? photo['url'],
    );
    final reason = photo['rejection_reason']?.toString().trim();
    final message = photo['message']?.toString().trim();
    final canReorder =
        _meta['can_reorder'] == true && photo['can_reorder'] == true;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 94,
                height: 118,
                child: url == null
                    ? _photoPlaceholder(status)
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _photoPlaceholder(status),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _statusChip(status),
                      if (isPrimary) _primaryChip(),
                    ],
                  ),
                  if (reason != null && reason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      reason,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else if (message != null && message.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(message),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy || photo['can_set_primary'] != true
                            ? null
                            : () => _setPrimary(photo),
                        icon: const Icon(Icons.star_border),
                        label: Text(AppStrings.setPrimary),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy || photo['can_delete'] != true
                            ? null
                            : () => _confirmDelete(photo),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(AppStrings.deletePhoto),
                      ),
                      if (canReorder)
                        IconButton.outlined(
                          tooltip: 'Move up',
                          onPressed: index == 0
                              ? null
                              : () => _movePhoto(index, -1),
                          icon: const Icon(Icons.keyboard_arrow_up),
                        ),
                      if (canReorder)
                        IconButton.outlined(
                          tooltip: 'Move down',
                          onPressed: index == _photos.length - 1
                              ? null
                              : () => _movePhoto(index, 1),
                          icon: const Icon(Icons.keyboard_arrow_down),
                        ),
                    ],
                  ),
                  if (busy) const LinearProgressIndicator(minHeight: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder(String status) {
    return ColoredBox(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          status == 'pending'
              ? Icons.hourglass_top
              : Icons.image_not_supported_outlined,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'approved' => const Color(0xFF15803D),
      'rejected' => Theme.of(context).colorScheme.error,
      _ => const Color(0xFFB45309),
    };

    return Chip(
      label: Text(status),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: color,
      side: BorderSide.none,
    );
  }

  Widget _primaryChip() {
    return const Chip(
      avatar: Icon(Icons.star, size: 16, color: Colors.white),
      label: Text('Primary'),
      labelStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      backgroundColor: Color(0xFF2563EB),
      side: BorderSide.none,
    );
  }

  Widget _statusLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  bool _responseSuccess(Map<String, dynamic> response) {
    final status = response['statusCode'];
    return status is int &&
        status >= 200 &&
        status < 300 &&
        response['success'] != false;
  }

  String _responseMessage(Map<String, dynamic> response, String fallback) {
    final message = response['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;
    return fallback;
  }

  Map<String, dynamic>? _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  List<Map<String, dynamic>> _safeMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  int? _photoId(Map<String, dynamic> photo) {
    final value = photo['id'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _boolText(dynamic value) {
    return value == true ? 'Verified' : 'Not verified';
  }

  String _displayValue(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return AppStrings.settingsNotAvailable;
    return text;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
