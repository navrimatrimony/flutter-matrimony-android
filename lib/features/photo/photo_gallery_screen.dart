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
  int? _selectedPhotoId;
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

      await _uploadFiles(picked.map((item) => File(item.path)).toList());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showMessage(e.toString());
    }
  }

  Future<void> _pickCameraAndUpload() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 1600,
        maxHeight: 2134,
        requestFullMetadata: false,
      );
      if (picked == null) return;

      await _uploadFiles(<File>[File(picked.path)]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showMessage(e.toString());
    }
  }

  Future<void> _uploadFiles(List<File> files) async {
    if (files.isEmpty) return;

    if (!mounted) return;
    final previousIds = _photos.map(_photoId).whereType<int>().toSet();
    setState(() => _isUploading = true);

    final response = await ApiClient.uploadProfilePhotos(files);
    if (!mounted) return;

    if (_responseSuccess(response)) {
      final preferredPhotoId = _newPhotoIdFromResponse(response, previousIds);
      setState(() {
        _applyResponse(response, preferredPhotoId: preferredPhotoId);
        _isUploading = false;
      });
      _showMessage(_responseMessage(response, 'Photo upload झाला.'));
      return;
    }

    setState(() => _isUploading = false);
    _showMessage(_responseMessage(response, 'Photo upload fail झाला.'));
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
        content: Text(AppStrings.photoDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.delete),
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
        _applyResponse(response, preferredPhotoId: photoId);
        _busyPhotoIds.remove(photoId);
      });
      _showMessage(_responseMessage(response, fallback));
      return;
    }

    setState(() => _busyPhotoIds.remove(photoId));
    _showMessage(_responseMessage(response, fallback));
  }

  void _applyResponse(Map<String, dynamic> response, {int? preferredPhotoId}) {
    _photos = _safeMapList(response['photos']);
    _meta = _safeMap(response['meta']) ?? <String, dynamic>{};
    _verification = _safeMap(response['verification']) ?? _verification;
    _syncSelectedPhoto(preferredPhotoId: preferredPhotoId);
  }

  void _syncSelectedPhoto({int? preferredPhotoId}) {
    if (_photos.isEmpty) {
      _selectedPhotoId = null;
      return;
    }

    if (preferredPhotoId != null && _hasPhotoId(preferredPhotoId)) {
      _selectedPhotoId = preferredPhotoId;
      return;
    }

    final current = _selectedPhotoId;
    if (current != null && _hasPhotoId(current)) {
      return;
    }

    _selectedPhotoId = _photos.map(_photoId).whereType<int>().firstWhere((id) {
      final photo = _photoById(id);
      return photo != null && _isPrimaryPhoto(photo);
    }, orElse: () => _photoId(_photos.first) ?? -1);
    if (_selectedPhotoId == -1) {
      _selectedPhotoId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.photosVerification),
        actions: [
          IconButton(
            tooltip: AppStrings.refresh,
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
                label: Text(AppStrings.retry),
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
          _buildUploadCard(),
          const SizedBox(height: 14),
          if (_photos.isEmpty) _buildEmptyState() else _buildPhotoManager(),
          const SizedBox(height: 14),
          _buildVerificationCard(),
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    final remaining = _intValue(_meta['remaining_slots']);
    final canUpload = _canUpload;

    return _panel(
      title: AppStrings.uploadPhoto,
      icon: Icons.add_photo_alternate_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            remaining == null
                ? AppStrings.photoUploadHelp
                : AppStrings.photoSlotsRemaining(remaining),
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _guidelineChips(const [
            'Clear face',
            'Single person',
            'Good light',
            'Safe photo',
          ]),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canUpload && !_isUploading
                      ? _pickCameraAndUpload
                      : null,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(AppStrings.camera),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: canUpload && !_isUploading ? _pickAndUpload : null,
                  icon: _isUploading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined),
                  label: Text(
                    _isUploading ? AppStrings.uploading : AppStrings.gallery,
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoManager() {
    final selected = _selectedPhoto();
    if (selected == null) return _buildEmptyState();

    return _panel(
      title: AppStrings.yourPhotos,
      icon: Icons.photo_library_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.photoManagementHint,
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildSelectedPhotoPreview(selected),
          const SizedBox(height: 12),
          _buildThumbnailStrip(),
          const SizedBox(height: 14),
          _buildSelectedPhotoActions(selected),
        ],
      ),
    );
  }

  Widget _buildSelectedPhotoPreview(Map<String, dynamic> photo) {
    final status = _photoStatus(photo);
    final url = _photoUrl(photo);
    final reason = _photoReason(photo);
    final message = _photoMessage(photo);
    final busy = _photoBusy(photo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (url == null)
                        _photoPlaceholder(status)
                      else
                        Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _photoPlaceholder(status),
                        ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: _statusBadge(status),
                      ),
                      if (_isPrimaryPhoto(photo))
                        Positioned(right: 12, top: 12, child: _primaryBadge()),
                      if (busy)
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(minHeight: 3),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (reason != null || message != null) ...[
          const SizedBox(height: 10),
          Text(
            reason ?? message!,
            style: TextStyle(
              color: reason != null
                  ? Theme.of(context).colorScheme.error
                  : Colors.grey.shade700,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildThumbnailStrip() {
    final canUpload = _canUpload;

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _photos.length + (canUpload ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index >= _photos.length) {
            return _addPhotoThumbnail();
          }
          return _photoThumbnail(_photos[index]);
        },
      ),
    );
  }

  Widget _photoThumbnail(Map<String, dynamic> photo) {
    final id = _photoId(photo);
    final selected = id != null && id == _selectedPhotoId;
    final status = _photoStatus(photo);
    final url = _photoUrl(photo, thumbnail: true);
    final primary = _isPrimaryPhoto(photo);
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFFE7DDD8);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: id == null
          ? null
          : () {
              setState(() {
                _selectedPhotoId = id;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 64,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: selected ? 2 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url == null)
                _photoPlaceholder(status)
              else
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, _, _) => _photoPlaceholder(status),
                ),
              Positioned(left: 5, bottom: 5, child: _statusDot(status)),
              if (primary)
                const Positioned(
                  right: 5,
                  bottom: 5,
                  child: Icon(Icons.star, color: Colors.white, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addPhotoThumbnail() {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _isUploading ? null : _pickAndUpload,
      child: Container(
        width: 64,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE7DDD8)),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSelectedPhotoActions(Map<String, dynamic> photo) {
    final id = _photoId(photo);
    final busy = id != null && _busyPhotoIds.contains(id);
    final canSetPrimary =
        !busy && !_isPrimaryPhoto(photo) && photo['can_set_primary'] == true;
    final canDelete = !busy && photo['can_delete'] == true;
    final canReorder =
        _meta['can_reorder'] == true && photo['can_reorder'] == true;
    final selectedIndex = _selectedPhotoIndex();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _canUpload && !_isUploading ? _pickAndUpload : null,
                icon: const Icon(Icons.swap_horiz_outlined),
                label: Text(AppStrings.replacePhoto),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: canSetPrimary ? () => _setPrimary(photo) : null,
                icon: const Icon(Icons.star_border),
                label: Text(AppStrings.setPrimary),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (canReorder && selectedIndex != null) ...[
              IconButton.outlined(
                tooltip: AppStrings.moveLeft,
                onPressed: selectedIndex == 0
                    ? null
                    : () => _movePhoto(selectedIndex, -1),
                icon: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: AppStrings.moveRight,
                onPressed: selectedIndex == _photos.length - 1
                    ? null
                    : () => _movePhoto(selectedIndex, 1),
                icon: const Icon(Icons.chevron_right),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canDelete ? () => _confirmDelete(photo) : null,
                icon: const Icon(Icons.delete_outline),
                label: Text(AppStrings.deletePhoto),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
        if (busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2),
        ],
      ],
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

  Widget _guidelineChips(List<String> labels) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels
          .map(
            (label) => Chip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.check_circle_outline, size: 16),
              label: Text(label),
            ),
          )
          .toList(),
    );
  }

  Widget _photoPlaceholder(String status) {
    return ColoredBox(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
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

  Widget _statusBadge(String status) {
    final style = _photoStatusStyle(status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          style.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _primaryBadge() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              AppStrings.primaryPhoto,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusDot(String status) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: _photoStatusStyle(status).color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
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

  Map<String, dynamic>? _selectedPhoto() {
    final selectedId = _selectedPhotoId;
    if (selectedId != null) {
      final selected = _photoById(selectedId);
      if (selected != null) return selected;
    }
    return _photos.isNotEmpty ? _photos.first : null;
  }

  Map<String, dynamic>? _photoById(int id) {
    for (final photo in _photos) {
      if (_photoId(photo) == id) return photo;
    }
    return null;
  }

  int? _selectedPhotoIndex() {
    final selectedId = _selectedPhotoId;
    if (selectedId == null) return null;
    for (var i = 0; i < _photos.length; i++) {
      if (_photoId(_photos[i]) == selectedId) return i;
    }
    return null;
  }

  bool _hasPhotoId(int id) => _photoById(id) != null;

  int? _newPhotoIdFromResponse(
    Map<String, dynamic> response,
    Set<int> previousIds,
  ) {
    for (final photo in _safeMapList(response['photos']).reversed) {
      final id = _photoId(photo);
      if (id != null && !previousIds.contains(id)) {
        return id;
      }
    }
    return null;
  }

  bool get _canUpload {
    final remaining = _intValue(_meta['remaining_slots']);
    return _meta['can_upload'] != false && (remaining ?? 1) > 0;
  }

  bool _photoBusy(Map<String, dynamic> photo) {
    final id = _photoId(photo);
    return id != null && _busyPhotoIds.contains(id);
  }

  bool _isPrimaryPhoto(Map<String, dynamic> photo) {
    return photo['is_primary'] == true;
  }

  String _photoStatus(Map<String, dynamic> photo) {
    return (photo['status']?.toString().trim().toLowerCase() ?? 'pending')
        .replaceAll(' ', '_');
  }

  String? _photoReason(Map<String, dynamic> photo) {
    final reason = photo['rejection_reason']?.toString().trim();
    if (reason == null || reason.isEmpty) return null;
    return reason;
  }

  String? _photoMessage(Map<String, dynamic> photo) {
    final message = photo['message']?.toString().trim();
    if (message == null || message.isEmpty) return null;
    return message;
  }

  String? _photoUrl(Map<String, dynamic> photo, {bool thumbnail = false}) {
    return ApiClient.normalizeProfilePhotoUrl(
      thumbnail ? photo['thumbnail_url'] ?? photo['url'] : photo['url'],
    );
  }

  _PhotoStatusStyle _photoStatusStyle(String status) {
    return switch (status) {
      'approved' => const _PhotoStatusStyle('Approved', Color(0xFF15803D)),
      'rejected' => _PhotoStatusStyle(
        'Rejected',
        Theme.of(context).colorScheme.error,
      ),
      'pending' ||
      'pending_review' => const _PhotoStatusStyle('Pending', Color(0xFFB45309)),
      _ => _PhotoStatusStyle(status, const Color(0xFF6B7280)),
    };
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

class _PhotoStatusStyle {
  final String label;
  final Color color;

  const _PhotoStatusStyle(this.label, this.color);
}
