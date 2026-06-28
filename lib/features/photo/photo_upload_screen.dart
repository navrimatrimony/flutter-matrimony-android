import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';

enum _PhotoUploadStage {
  idle,
  selected,
  uploading,
  processing,
  approved,
  pending,
  rejected,
  error,
}

class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({
    super.key,
    this.returnToPreviousOnSuccess = false,
    this.verifyProfileBeforeUpload = true,
    this.initialSource,
    this.onUploaded,
  });

  final bool returnToPreviousOnSuccess;
  final bool verifyProfileBeforeUpload;
  final ImageSource? initialSource;
  final VoidCallback? onUploaded;

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  String? _approvedPhotoUrl;
  String? _fileInfo;
  String? _detailMessage;
  bool _uploading = false;
  bool _checkingStatus = false;
  _PhotoUploadStage _stage = _PhotoUploadStage.idle;

  @override
  void initState() {
    super.initState();
    _applyProfileSnapshot(ApiClient.currentUserProfile, notify: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProfileStatus(silent: true);
      final source = widget.initialSource;
      if (source != null) {
        _pickImage(source);
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 1600,
        maxHeight: 2134,
        requestFullMetadata: false,
      );

      if (pickedFile == null) {
        _showMessage('Photo selection cancelled.', _NoticeTone.info);
        return;
      }

      final file = File(pickedFile.path);
      final fileSize = await file.length();
      final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

      if (!mounted) return;
      setState(() {
        _selectedImage = file;
        _fileInfo = '$fileSizeMB MB';
        _detailMessage =
            'Photo selected. It will be checked for quality and safety after upload.';
        _stage = _PhotoUploadStage.selected;
      });
    } catch (error) {
      _showMessage(
        'Photo निवडताना problem आला. कृपया पुन्हा प्रयत्न करा.',
        _NoticeTone.error,
      );
      if (!mounted) return;
      setState(() {
        _detailMessage = error.toString();
        _stage = _PhotoUploadStage.error;
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) {
      _showMessage('कृपया आधी photo निवडा.', _NoticeTone.warning);
      return;
    }

    if (widget.verifyProfileBeforeUpload) {
      final canUpload = await _verifyProfileExists();
      if (!canUpload) return;
    }

    if (!mounted) return;
    setState(() {
      _uploading = true;
      _stage = _PhotoUploadStage.uploading;
      _detailMessage = 'Photo upload होत आहे. कृपया थांबा.';
    });

    try {
      final response = await ApiClient.uploadProfilePhoto(_selectedImage!);
      if (!mounted) return;

      final statusCode = response['statusCode'];
      if (statusCode == 401) {
        _setFailure('Session expired. कृपया पुन्हा login करा.');
        return;
      }
      if (statusCode == 403) {
        _setFailure(
          response['message']?.toString() ??
              'Photo upload सध्या तुमच्या account साठी allowed नाही.',
        );
        return;
      }
      if (statusCode == 404) {
        _setFailure(
          response['message']?.toString() ??
              'Profile सापडली नाही. कृपया आधी profile तयार करा.',
        );
        return;
      }
      if (statusCode == 422) {
        _setFailure(
          response['message']?.toString() ??
              'Photo valid नाही. कृपया clear image निवडा.',
        );
        return;
      }

      if (response['success'] == true && response['data'] is Map) {
        final uploadData = Map<String, dynamic>.from(response['data'] as Map);
        final status = uploadData['status']?.toString().trim().toLowerCase();
        final uploadedUrl = ApiClient.resolveProfilePhotoUrl({
          'profile_photo': uploadData['profile_photo'],
          'photo_status': status,
        });

        setState(() {
          _approvedPhotoUrl = uploadedUrl ?? _approvedPhotoUrl;
          _stage = _stageFromUploadStatus(status);
          _detailMessage =
              'Photo backend ला मिळाला आहे. Quality आणि safety check चालू आहे.';
        });

        await _refreshProfileStatus(silent: true);
        widget.onUploaded?.call();
        _showMessage(
          'Photo upload झाला. Status इथे update होईल.',
          _NoticeTone.success,
        );

        if (widget.returnToPreviousOnSuccess) {
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted) Navigator.pop(context, true);
          });
        }
        return;
      }

      _setFailure(
        response['message']?.toString() ??
            'Photo upload fail झाला. कृपया पुन्हा प्रयत्न करा.',
      );
    } catch (_) {
      _setFailure('Photo upload करताना problem आला. कृपया पुन्हा प्रयत्न करा.');
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<bool> _verifyProfileExists() async {
    setState(() {
      _checkingStatus = true;
      _detailMessage = 'Profile तपासत आहे.';
    });

    try {
      final profileCheck = await ApiClient.getMyProfile();
      if (!mounted) return false;

      final profileStatusCode = profileCheck['statusCode'];
      if (profileStatusCode == 404 || profileCheck['success'] != true) {
        _showMessage(
          'Profile सापडली नाही. कृपया आधी profile तयार करा.',
          _NoticeTone.error,
        );
        Navigator.pushReplacementNamed(context, '/smart-onboarding');
        return false;
      }

      _applyProfileSnapshot(ApiClient.currentUserProfile);
      return true;
    } catch (_) {
      _showMessage('Profile तपासता आली नाही.', _NoticeTone.error);
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _checkingStatus = false;
        });
      }
    }
  }

  Future<void> _refreshProfileStatus({bool silent = false}) async {
    if (ApiClient.authToken == null) return;

    if (!silent && mounted) {
      setState(() {
        _checkingStatus = true;
      });
    }

    try {
      final response = await ApiClient.getMyProfile();
      if (!mounted) return;
      if (response['success'] == true) {
        _applyProfileSnapshot(ApiClient.currentUserProfile);
      } else if (!silent) {
        _showMessage(
          'Photo status refresh करता आला नाही.',
          _NoticeTone.warning,
        );
      }
    } catch (_) {
      if (!silent) {
        _showMessage(
          'Photo status refresh करता आला नाही.',
          _NoticeTone.warning,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _checkingStatus = false;
        });
      }
    }
  }

  void _applyProfileSnapshot(
    Map<String, dynamic>? profile, {
    bool notify = true,
  }) {
    if (profile == null) return;

    void apply() {
      final hasDraftSelection =
          _selectedImage != null && _stage == _PhotoUploadStage.selected;
      final approvedUrl = ApiClient.resolveProfilePhotoUrl(profile);
      final rawStatus = _firstNonEmpty(profile, const [
        'photo_status',
        'approval_status',
        'approved_status',
        'moderation_status',
      ])?.toLowerCase();
      final rejectedReason = _firstNonEmpty(profile, const [
        'photo_rejection_reason',
        'rejection_reason',
        'reject_reason',
      ]);
      final rejectedAt = _firstNonEmpty(profile, const [
        'photo_rejected_at',
        'rejected_at',
      ]);
      final approved =
          _boolValue(profile['photo_approved']) == true ||
          rawStatus == 'approved' ||
          approvedUrl != null;
      final rejected =
          rejectedReason != null ||
          rejectedAt != null ||
          (rawStatus?.contains('reject') ?? false);
      final hasUploaded = _hasUploadedPhoto(profile);

      if (approved) {
        if (approvedUrl != null) {
          _approvedPhotoUrl = approvedUrl;
        }
        if (hasDraftSelection) return;
        _selectedImage = null;
        _stage = _PhotoUploadStage.approved;
        _detailMessage =
            'Approved photo profile वर दिसत आहे. नवीन photo निवडून replace करू शकता.';
        return;
      }

      if (hasDraftSelection) return;

      if (rejected) {
        _stage = _PhotoUploadStage.rejected;
        _detailMessage =
            rejectedReason ??
            'हा photo approve होऊ शकला नाही. कृपया दुसरा clear photo upload करा.';
        return;
      }

      if (hasUploaded && _stage != _PhotoUploadStage.selected) {
        _stage = _PhotoUploadStage.pending;
        _detailMessage =
            'Photo uploaded आहे. Approval किंवा safety check pending आहे.';
      }
    }

    if (notify && mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _setFailure(String message) {
    if (!mounted) return;
    setState(() {
      _stage = _PhotoUploadStage.error;
      _detailMessage = message;
    });
    _showMessage(message, _NoticeTone.error);
  }

  _PhotoUploadStage _stageFromUploadStatus(String? status) {
    if (status == null || status.isEmpty) return _PhotoUploadStage.processing;
    if (status.contains('approved')) return _PhotoUploadStage.approved;
    if (status.contains('reject')) return _PhotoUploadStage.rejected;
    if (status == 'pending' || status.contains('review')) {
      return _PhotoUploadStage.pending;
    }
    if (status == 'error') return _PhotoUploadStage.error;
    return _PhotoUploadStage.processing;
  }

  bool _hasUploadedPhoto(Map<String, dynamic> profile) {
    if (_boolValue(profile['photo_uploaded']) == true) return true;
    final profilePhoto = profile['profile_photo']?.toString().trim();
    if (profilePhoto != null && profilePhoto.isNotEmpty) return true;

    for (final key in const ['photos', 'profile_photos']) {
      final rows = profile[key];
      if (rows is List && rows.isNotEmpty) return true;
    }

    return false;
  }

  bool? _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    if (['1', 'true', 'yes', 'approved'].contains(normalized)) return true;
    if (['0', 'false', 'no', 'rejected', 'pending'].contains(normalized)) {
      return false;
    }
    return null;
  }

  String? _firstNonEmpty(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  void _showMessage(String message, _NoticeTone tone) {
    if (!mounted) return;
    final colors = Theme.of(context).colorScheme;
    final background = switch (tone) {
      _NoticeTone.success => const Color(0xFF15803D),
      _NoticeTone.warning => const Color(0xFFB45309),
      _NoticeTone.error => colors.error,
      _NoticeTone.info => const Color(0xFF2563EB),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Profile Photo'),
        actions: [
          IconButton(
            tooltip: 'Refresh status',
            onPressed: _checkingStatus ? null : () => _refreshProfileStatus(),
            icon: _checkingStatus
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusHeader(stage: _stage),
              const SizedBox(height: 16),
              Center(child: _buildPreview(theme)),
              const SizedBox(height: 18),
              _buildPickerActions(),
              const SizedBox(height: 14),
              _buildUploadAction(),
              const SizedBox(height: 18),
              _buildStatusPanel(theme),
              const SizedBox(height: 14),
              _buildGuidelines(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final colors = theme.colorScheme;
    final image = _selectedImage != null
        ? Image.file(_selectedImage!, fit: BoxFit.cover)
        : (_approvedPhotoUrl != null
              ? Image.network(
                  _approvedPhotoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _emptyPreview(colors),
                )
              : _emptyPreview(colors));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                image,
                Positioned(
                  left: 12,
                  top: 12,
                  child: _StageBadge(stage: _stage),
                ),
                if (_uploading)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(minHeight: 4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyPreview(ColorScheme colors) {
    return ColoredBox(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 62, color: colors.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            'Clear profile photo',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '3:4 portrait works best',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerActions() {
    final disabled = _uploading;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: disabled ? null : () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Camera'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: disabled ? null : () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Gallery'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadAction() {
    final canUpload = _selectedImage != null && !_uploading;

    return FilledButton.icon(
      onPressed: canUpload ? _uploadImage : null,
      icon: _uploading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cloud_upload_outlined),
      label: Text(_uploading ? 'Uploading photo' : 'Upload selected photo'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    );
  }

  Widget _buildStatusPanel(ThemeData theme) {
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_stageIcon(_stage), color: _stageColor(_stage, colors)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _stageTitle(_stage),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _detailMessage ?? _stageDescription(_stage),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  if (_fileInfo != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Selected file: $_fileInfo',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidelines(ThemeData theme) {
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Photo guidelines',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _GuidelineChip(
                  icon: Icons.face_retouching_natural_outlined,
                  label: 'Clear face',
                ),
                _GuidelineChip(
                  icon: Icons.person_outline,
                  label: 'Single person',
                ),
                _GuidelineChip(
                  icon: Icons.light_mode_outlined,
                  label: 'Good light',
                ),
                _GuidelineChip(
                  icon: Icons.verified_user_outlined,
                  label: 'Safe photo',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _stageTitle(_PhotoUploadStage stage) {
    return switch (stage) {
      _PhotoUploadStage.idle => 'Add your profile photo',
      _PhotoUploadStage.selected => 'Ready to upload',
      _PhotoUploadStage.uploading => 'Uploading photo',
      _PhotoUploadStage.processing => 'Quality check in progress',
      _PhotoUploadStage.approved => 'Photo approved',
      _PhotoUploadStage.pending => 'Approval pending',
      _PhotoUploadStage.rejected => 'Photo not approved',
      _PhotoUploadStage.error => 'Upload needs attention',
    };
  }

  String _stageDescription(_PhotoUploadStage stage) {
    return switch (stage) {
      _PhotoUploadStage.idle =>
        'Camera किंवा gallery मधून clear portrait photo निवडा.',
      _PhotoUploadStage.selected =>
        'हा photo backend moderation engine कडे upload होईल.',
      _PhotoUploadStage.uploading =>
        'Upload complete होईपर्यंत screen बंद करू नका.',
      _PhotoUploadStage.processing =>
        'Photo received आहे. Backend quality आणि safety check करत आहे.',
      _PhotoUploadStage.approved =>
        'हा approved photo तुमच्या profile वर दिसत आहे.',
      _PhotoUploadStage.pending =>
        'Photo review मध्ये आहे. Approved झाल्यावर profile वर दिसेल.',
      _PhotoUploadStage.rejected =>
        'कृपया clear, safe आणि single-person photo upload करा.',
      _PhotoUploadStage.error => 'कृपया पुन्हा प्रयत्न करा.',
    };
  }

  IconData _stageIcon(_PhotoUploadStage stage) {
    return switch (stage) {
      _PhotoUploadStage.idle => Icons.add_photo_alternate_outlined,
      _PhotoUploadStage.selected => Icons.check_circle_outline,
      _PhotoUploadStage.uploading => Icons.cloud_upload_outlined,
      _PhotoUploadStage.processing => Icons.hourglass_top_outlined,
      _PhotoUploadStage.approved => Icons.verified_outlined,
      _PhotoUploadStage.pending => Icons.pending_actions_outlined,
      _PhotoUploadStage.rejected => Icons.report_gmailerrorred_outlined,
      _PhotoUploadStage.error => Icons.error_outline,
    };
  }

  Color _stageColor(_PhotoUploadStage stage, ColorScheme colors) {
    return switch (stage) {
      _PhotoUploadStage.approved => const Color(0xFF15803D),
      _PhotoUploadStage.rejected || _PhotoUploadStage.error => colors.error,
      _PhotoUploadStage.pending ||
      _PhotoUploadStage.processing ||
      _PhotoUploadStage.uploading => const Color(0xFFB45309),
      _ => colors.primary,
    };
  }
}

enum _NoticeTone { success, warning, error, info }

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.stage});

  final _PhotoUploadStage stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile photo',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          stage == _PhotoUploadStage.approved
              ? 'Approved photo currently visible on your profile.'
              : 'Upload a clear photo. We will optimize it and check it before it appears on your profile.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.stage});

  final _PhotoUploadStage stage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = switch (stage) {
      _PhotoUploadStage.approved => const Color(0xFF15803D),
      _PhotoUploadStage.rejected || _PhotoUploadStage.error => colors.error,
      _PhotoUploadStage.pending ||
      _PhotoUploadStage.processing ||
      _PhotoUploadStage.uploading => const Color(0xFFB45309),
      _ => colors.primary,
    };

    final label = switch (stage) {
      _PhotoUploadStage.approved => 'Approved',
      _PhotoUploadStage.rejected => 'Rejected',
      _PhotoUploadStage.error => 'Needs retry',
      _PhotoUploadStage.pending => 'Pending',
      _PhotoUploadStage.processing => 'Checking',
      _PhotoUploadStage.uploading => 'Uploading',
      _PhotoUploadStage.selected => 'Selected',
      _PhotoUploadStage.idle => 'Photo',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _GuidelineChip extends StatelessWidget {
  const _GuidelineChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
