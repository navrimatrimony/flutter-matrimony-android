import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

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
  static const int _postUploadRefreshLimit = 2;
  static const Duration _postUploadRefreshDelay = Duration(seconds: 5);

  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _photos = <Map<String, dynamic>>[];
  Map<String, dynamic> _meta = <String, dynamic>{};
  int? _selectedPhotoId;
  final Set<int> _busyPhotoIds = <int>{};
  Timer? _postUploadRefreshTimer;
  int _postUploadRefreshAttempts = 0;

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  @override
  void dispose() {
    _postUploadRefreshTimer?.cancel();
    super.dispose();
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
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1600,
        maxHeight: 2134,
        requestFullMetadata: false,
      );
      if (picked == null) return;

      final cropped = await _cropPickedPhoto(File(picked.path));
      if (cropped == null) return;

      await _uploadFiles(<File>[cropped]);
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

      final cropped = await _cropPickedPhoto(File(picked.path));
      if (cropped == null) return;

      await _uploadFiles(<File>[cropped]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showMessage(e.toString());
    }
  }

  Future<File?> _cropPickedPhoto(File imageFile) async {
    final image = await _decodeImage(imageFile);
    try {
      if (!mounted) return null;
      return await showModalBottomSheet<File>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _PhotoCropSheet(image: image),
      );
    } finally {
      image.dispose();
    }
  }

  Future<ui.Image> _decodeImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
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
      _schedulePostUploadRefresh();
      return;
    }

    setState(() => _isUploading = false);
    _showMessage(_responseMessage(response, 'Photo upload fail झाला.'));
  }

  void _schedulePostUploadRefresh() {
    _postUploadRefreshTimer?.cancel();
    _postUploadRefreshAttempts = 0;

    _postUploadRefreshTimer = Timer(
      _postUploadRefreshDelay,
      _refreshPhotosAfterUpload,
    );
  }

  Future<void> _refreshPhotosAfterUpload() async {
    if (!mounted) return;
    if (_postUploadRefreshAttempts >= _postUploadRefreshLimit) {
      return;
    }

    _postUploadRefreshAttempts++;

    try {
      final response = await ApiClient.getProfilePhotos();
      if (!mounted) return;
      if (_responseSuccess(response)) {
        setState(() => _applyResponse(response));
      }
    } catch (_) {
      // Silent refresh should never interrupt the user's photo flow.
    }

    if (!mounted) return;
    if (_hasPendingApprovalPhotos &&
        _postUploadRefreshAttempts < _postUploadRefreshLimit) {
      _postUploadRefreshTimer = Timer(
        _postUploadRefreshDelay,
        _refreshPhotosAfterUpload,
      );
    } else {
      _postUploadRefreshTimer = null;
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
            tooltip: 'Dashboard',
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/home', (route) => false);
            },
            icon: const Icon(Icons.home_outlined),
          ),
          IconButton(
            tooltip: AppStrings.refresh,
            onPressed: _isLoading ? null : _loadGallery,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomActionStrip(),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 116),
        children: [
          if (_photos.isEmpty) _buildEmptyState() else _buildPhotoManager(),
          const SizedBox(height: 14),
          _buildUploadGuidanceCard(),
        ],
      ),
    );
  }

  Widget _buildBottomActionStrip() {
    final enabled = !_isLoading && _canUpload && !_isUploading;

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: enabled ? _pickCameraAndUpload : null,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(AppStrings.camera),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: enabled ? _pickAndUpload : null,
                  icon: _isUploading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined),
                  label: Text(_isUploading ? AppStrings.uploading : 'Upload'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadGuidanceCard() {
    final remaining = _intValue(_meta['remaining_slots']);

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
        if (!_isPrimaryPhoto(photo) || canSetPrimary) ...[
          FilledButton.icon(
            onPressed: canSetPrimary ? () => _setPrimary(photo) : null,
            icon: const Icon(Icons.star_border),
            label: Text(AppStrings.setPrimary),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 10),
        ],
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

  bool get _hasPendingApprovalPhotos {
    return _photos.any((photo) {
      final status = _photoStatus(photo);
      return status == 'pending' || status == 'pending_review';
    });
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

enum _PhotoCropDragMode {
  none,
  move,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class _PhotoCropSheet extends StatefulWidget {
  const _PhotoCropSheet({required this.image});

  final ui.Image image;

  @override
  State<_PhotoCropSheet> createState() => _PhotoCropSheetState();
}

class _PhotoCropSheetState extends State<_PhotoCropSheet> {
  static const double _targetAspectRatio = 3 / 4;
  static const int _outputWidth = 900;
  static const int _outputHeight = 1200;

  late Rect _cropRect;
  Rect? _dragStartRect;
  _PhotoCropDragMode _dragMode = _PhotoCropDragMode.none;
  bool _saving = false;

  Size get _imageSize =>
      Size(widget.image.width.toDouble(), widget.image.height.toDouble());

  @override
  void initState() {
    super.initState();
    _cropRect = _initialCropRect();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Adjust 3:4 crop',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.cancel,
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCropCanvas(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                const Icon(Icons.open_with, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Drag the frame. Pull corners to resize.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(AppStrings.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveCrop,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Use photo'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageAspect = widget.image.width / widget.image.height;
        var width = constraints.maxWidth;
        var height = width / imageAspect;
        if (height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * imageAspect;
        }

        final viewSize = Size(width, height);
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) =>
                  _startDrag(details.localPosition, viewSize),
              onPanUpdate: (details) =>
                  _updateDrag(details.localPosition, details.delta, viewSize),
              onPanEnd: (_) => _endDrag(),
              onPanCancel: _endDrag,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RawImage(image: widget.image, fit: BoxFit.fill),
                  CustomPaint(
                    painter: _PhotoCropOverlayPainter(
                      image: widget.image,
                      cropRect: _cropRect,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Rect _initialCropRect() {
    final size = _imageSize;
    var cropWidth = size.width;
    var cropHeight = cropWidth / _targetAspectRatio;

    if (cropHeight > size.height) {
      cropHeight = size.height;
      cropWidth = cropHeight * _targetAspectRatio;
    }

    return Rect.fromLTWH(
      (size.width - cropWidth) / 2,
      0,
      cropWidth,
      cropHeight,
    );
  }

  void _startDrag(Offset localPosition, Size viewSize) {
    final viewRect = _toViewRect(_cropRect, viewSize);
    _dragMode = _hitTest(localPosition, viewRect);
    _dragStartRect = _cropRect;
  }

  void _updateDrag(Offset localPosition, Offset delta, Size viewSize) {
    final startRect = _dragStartRect;
    if (startRect == null || _dragMode == _PhotoCropDragMode.none) return;

    setState(() {
      if (_dragMode == _PhotoCropDragMode.move) {
        final sourceDelta = Offset(
          delta.dx * widget.image.width / viewSize.width,
          delta.dy * widget.image.height / viewSize.height,
        );
        _cropRect = _clampRect(_cropRect.shift(sourceDelta));
        return;
      }

      final sourcePoint = _toSourcePoint(localPosition, viewSize);
      _cropRect = _resizeRect(startRect, sourcePoint, _dragMode);
    });
  }

  void _endDrag() {
    _dragMode = _PhotoCropDragMode.none;
    _dragStartRect = null;
  }

  _PhotoCropDragMode _hitTest(Offset localPosition, Rect viewRect) {
    const handleSize = 48.0;
    final corners = <_PhotoCropDragMode, Offset>{
      _PhotoCropDragMode.topLeft: viewRect.topLeft,
      _PhotoCropDragMode.topRight: viewRect.topRight,
      _PhotoCropDragMode.bottomLeft: viewRect.bottomLeft,
      _PhotoCropDragMode.bottomRight: viewRect.bottomRight,
    };

    for (final entry in corners.entries) {
      final handle = Rect.fromCenter(
        center: entry.value,
        width: handleSize,
        height: handleSize,
      );
      if (handle.contains(localPosition)) return entry.key;
    }

    if (viewRect.contains(localPosition)) return _PhotoCropDragMode.move;
    return _PhotoCropDragMode.none;
  }

  Rect _resizeRect(
    Rect startRect,
    Offset sourcePoint,
    _PhotoCropDragMode mode,
  ) {
    final point = _clampPoint(sourcePoint);

    return switch (mode) {
      _PhotoCropDragMode.topLeft => _rectFromBottomRight(
        startRect.bottomRight,
        point,
      ),
      _PhotoCropDragMode.topRight => _rectFromBottomLeft(
        startRect.bottomLeft,
        point,
      ),
      _PhotoCropDragMode.bottomLeft => _rectFromTopRight(
        startRect.topRight,
        point,
      ),
      _PhotoCropDragMode.bottomRight => _rectFromTopLeft(
        startRect.topLeft,
        point,
      ),
      _ => startRect,
    };
  }

  Rect _rectFromTopLeft(Offset origin, Offset point) {
    final maxWidth = _imageSize.width - origin.dx;
    final maxHeight = _imageSize.height - origin.dy;
    final size = _fitCropSize(point.dx - origin.dx, maxWidth, maxHeight);
    return Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height);
  }

  Rect _rectFromTopRight(Offset origin, Offset point) {
    final maxWidth = origin.dx;
    final maxHeight = _imageSize.height - origin.dy;
    final size = _fitCropSize(origin.dx - point.dx, maxWidth, maxHeight);
    return Rect.fromLTWH(
      origin.dx - size.width,
      origin.dy,
      size.width,
      size.height,
    );
  }

  Rect _rectFromBottomLeft(Offset origin, Offset point) {
    final maxWidth = _imageSize.width - origin.dx;
    final maxHeight = origin.dy;
    final size = _fitCropSize(point.dx - origin.dx, maxWidth, maxHeight);
    return Rect.fromLTWH(
      origin.dx,
      origin.dy - size.height,
      size.width,
      size.height,
    );
  }

  Rect _rectFromBottomRight(Offset origin, Offset point) {
    final maxWidth = origin.dx;
    final maxHeight = origin.dy;
    final size = _fitCropSize(origin.dx - point.dx, maxWidth, maxHeight);
    return Rect.fromLTWH(
      origin.dx - size.width,
      origin.dy - size.height,
      size.width,
      size.height,
    );
  }

  Size _fitCropSize(double rawWidth, double maxWidth, double maxHeight) {
    final maxRatioWidth = math.max(
      1.0,
      math.min(maxWidth, maxHeight * _targetAspectRatio),
    );
    final minWidth = math.min(maxRatioWidth, _minimumCropWidth);
    final width = rawWidth.abs().clamp(minWidth, maxRatioWidth);
    return Size(width, width / _targetAspectRatio);
  }

  double get _minimumCropWidth {
    final size = _imageSize;
    final fullRatioWidth = math.min(
      size.width,
      size.height * _targetAspectRatio,
    );
    return fullRatioWidth * 0.28;
  }

  Rect _clampRect(Rect rect) {
    final size = _imageSize;
    final left = rect.left
        .clamp(0.0, math.max(0.0, size.width - rect.width))
        .toDouble();
    final top = rect.top
        .clamp(0.0, math.max(0.0, size.height - rect.height))
        .toDouble();
    return Rect.fromLTWH(left, top, rect.width, rect.height);
  }

  Offset _clampPoint(Offset point) {
    return Offset(
      point.dx.clamp(0.0, _imageSize.width).toDouble(),
      point.dy.clamp(0.0, _imageSize.height).toDouble(),
    );
  }

  Offset _toSourcePoint(Offset localPosition, Size viewSize) {
    return _clampPoint(
      Offset(
        localPosition.dx * widget.image.width / viewSize.width,
        localPosition.dy * widget.image.height / viewSize.height,
      ),
    );
  }

  Rect _toViewRect(Rect sourceRect, Size viewSize) {
    return Rect.fromLTRB(
      sourceRect.left * viewSize.width / widget.image.width,
      sourceRect.top * viewSize.height / widget.image.height,
      sourceRect.right * viewSize.width / widget.image.width,
      sourceRect.bottom * viewSize.height / widget.image.height,
    );
  }

  Future<void> _saveCrop() async {
    setState(() => _saving = true);
    try {
      final file = await _writeCroppedImage();
      if (!mounted) return;
      Navigator.pop(context, file);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Photo crop करता आला नाही. कृपया पुन्हा try करा किंवा दुसरा photo निवडा.',
            ),
          ),
        );
    }
  }

  Future<File> _writeCroppedImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final outputRect = Rect.fromLTWH(
      0,
      0,
      _outputWidth.toDouble(),
      _outputHeight.toDouble(),
    );

    canvas.drawImageRect(
      widget.image,
      _cropRect,
      outputRect,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );

    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(_outputWidth, _outputHeight);
    picture.dispose();

    final byteData = await croppedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    croppedImage.dispose();

    if (byteData == null) {
      throw StateError('Crop encoding failed.');
    }

    final bytes = Uint8List.view(byteData.buffer);
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'matrimony_photo_crop_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}

class _PhotoCropOverlayPainter extends CustomPainter {
  const _PhotoCropOverlayPainter({required this.image, required this.cropRect});

  final ui.Image image;
  final Rect cropRect;

  @override
  void paint(Canvas canvas, Size size) {
    final viewRect = Rect.fromLTRB(
      cropRect.left * size.width / image.width,
      cropRect.top * size.height / image.height,
      cropRect.right * size.width / image.width,
      cropRect.bottom * size.height / image.height,
    );

    final overlayPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(viewRect, const Radius.circular(8)));

    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.46),
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(viewRect, const Radius.circular(8)),
      borderPaint,
    );

    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 1; i < 3; i++) {
      final dx = viewRect.left + viewRect.width * i / 3;
      canvas.drawLine(
        Offset(dx, viewRect.top),
        Offset(dx, viewRect.bottom),
        guidePaint,
      );
      final dy = viewRect.top + viewRect.height * i / 3;
      canvas.drawLine(
        Offset(viewRect.left, dy),
        Offset(viewRect.right, dy),
        guidePaint,
      );
    }

    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    for (final corner in <Offset>[
      viewRect.topLeft,
      viewRect.topRight,
      viewRect.bottomLeft,
      viewRect.bottomRight,
    ]) {
      canvas.drawCircle(corner, 8, handlePaint);
      canvas.drawCircle(
        corner,
        8,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PhotoCropOverlayPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.cropRect != cropRect;
  }
}
