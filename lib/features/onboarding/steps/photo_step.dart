import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api_client.dart';
import '../../../core/profile_network_image.dart';
import '../models/onboarding_status.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';
import '../../../core/app_language.dart';

enum _PhotoStepState {
  missing,
  selected,
  uploading,
  pending,
  approved,
  rejected,
  error,
}

class PhotoStep extends StatefulWidget {
  const PhotoStep({
    super.key,
    required this.status,
    required this.locale,
    required this.loading,
    required this.onSave,
    required this.onBack,
    required this.onRefresh,
  });

  final OnboardingStatus? status;
  final String locale;
  final bool loading;
  final OnboardingStepSaver onSave;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;

  @override
  State<PhotoStep> createState() => _PhotoStepControllerState();
}

class _PhotoStepControllerState extends State<PhotoStep> {
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  String? _approvedPhotoUrl;
  String? _fileInfo;
  String? _detailMessage;
  bool _uploading = false;
  bool _checkingStatus = false;
  bool _autoContinuing = false;
  _PhotoStepState _stage = _PhotoStepState.missing;


  @override
  void initState() {
    super.initState();
    _applyProfileSnapshot(_profileSnapshot(), notify: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProfileStatus(silent: true);
    });
  }

  @override
  void didUpdateWidget(covariant PhotoStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _applyProfileSnapshot(_profileSnapshot());
    }
  }

  Map<String, dynamic>? _profileSnapshot() {
    final snapshot = <String, dynamic>{};
    final statusProfile = widget.status?.profile?.raw;
    if (statusProfile != null) {
      snapshot.addAll(statusProfile);
    }
    final currentProfile = ApiClient.currentUserProfile;
    if (currentProfile != null) {
      snapshot.addAll(currentProfile);
    }
    return snapshot.isEmpty ? null : snapshot;
  }

  Future<void> _continue() async {
    if (_stage == _PhotoStepState.rejected) {
      _showMessage(
        appText.thisPhotoWasNotApprovedPlease,
        _NoticeTone.warning,
      );
      return;
    }

    final profile = widget.status?.profile;
    final photoUrl =
        _approvedPhotoUrl ??
        ApiClient.resolveProfilePhotoUrl(_profileSnapshot());
    final approved =
        profile?.photoApproved == true ||
        _stage == _PhotoStepState.approved ||
        photoUrl != null;
    final uploaded =
        profile?.photoUploaded == true ||
        _stage == _PhotoStepState.selected ||
        _stage == _PhotoStepState.uploading ||
        _stage == _PhotoStepState.pending ||
        approved ||
        _hasUploaded(_profileSnapshot());

    if (!uploaded) {
      _showMessage(
        appText.uploadAProfilePhotoBeforeContinuing,
        _NoticeTone.warning,
      );
      setState(() {
        _stage = _PhotoStepState.missing;
        _detailMessage = appText.addAProfilePhotoFromCamera;
      });
      return;
    }

    if (_stage == _PhotoStepState.selected) {
      _showMessage(
        appText.uploadTheSelectedPhotoBeforeContinuing,
        _NoticeTone.warning,
      );
      return;
    }

    await widget.onSave(
      'photo',
      compactPayload({
        'photo_uploaded': uploaded,
        'photo_approved': approved,
        'photo_status': approved
            ? 'approved'
            : uploaded
            ? 'pending'
            : 'missing',
      }),
      saveProfile: false,
    );
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
        _showMessage(
          appText.photoSelectionCancelled,
          _NoticeTone.info,
        );
        return;
      }

      final picked = File(pickedFile.path);
      // Open crop immediately so adjustment happens on the photo, not via
      // later sliders on the main step.
      ui.Image? sourceImage;
      try {
        sourceImage = await _decodeUiImage(await picked.readAsBytes());
        if (!mounted) return;
        final croppedFile = await _showCropDialog(sourceImage);
        if (!mounted) return;
        if (croppedFile != null) {
          await _setSelectedImage(croppedFile, cropped: true);
        } else {
          await _setSelectedImage(picked, cropped: false);
        }
      } finally {
        sourceImage?.dispose();
      }
    } catch (error) {
      _showMessage(
        appText.thereWasAProblemSelectingThe,
        _NoticeTone.error,
      );
      if (!mounted) return;
      setState(() {
        _detailMessage = error.toString();
        _stage = _PhotoStepState.error;
      });
    }
  }

  Future<void> _setSelectedImage(File file, {required bool cropped}) async {
    final fileSize = await file.length();
    final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

    if (!mounted) return;
    setState(() {
      _selectedImage = file;
      _fileInfo = cropped ? '$fileSizeMB MB, cropped' : '$fileSizeMB MB';
      _detailMessage = cropped
          ? appText.croppedPhotoIsReadyUploadIt
          : appText.photoSelectedCropItIfNeeded;
      _stage = _PhotoStepState.selected;
    });
  }

  Future<void> _cropSelectedImage() async {
    final file = _selectedImage;
    if (file == null) {
      _showMessage(
        appText.pleaseSelectAPhotoFirst,
        _NoticeTone.warning,
      );
      return;
    }

    ui.Image? sourceImage;
    try {
      final bytes = await file.readAsBytes();
      sourceImage = await _decodeUiImage(bytes);
      if (!mounted) return;

      final croppedFile = await _showCropDialog(sourceImage);
      if (croppedFile == null) return;

      await _setSelectedImage(croppedFile, cropped: true);
    } catch (_) {
      _showMessage(
        appText.photoCropPhoto,
        _NoticeTone.error,
      );
    } finally {
      sourceImage?.dispose();
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) {
      _showMessage(
        appText.pleaseSelectAPhotoFirst,
        _NoticeTone.warning,
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _uploading = true;
      _stage = _PhotoStepState.uploading;
      _detailMessage = appText.photoIsUploadingPleaseWait;
    });

    try {
      // Gallery transport: enforces admin photo rules (max upload size,
      // max photos per profile, per-account upload suspension, lifecycle lock).
      final response = await ApiClient.uploadProfilePhotos([_selectedImage!]);
      if (!mounted) return;

      if (_uploadSucceeded(response)) {
        final uploadStage = _stageFromUploadStatus(
          _uploadedPhotoStatus(response),
        );

        setState(() {
          _stage = uploadStage;
          _detailMessage = appText.photoReachedBackendQualityAndSafety;
        });

        await _refreshProfileStatus(silent: true);
        await widget.onRefresh();
        if (!mounted) return;

        await _handlePostUploadFlow(uploadStage);
        return;
      }

      _setFailure(_uploadFailureMessage(response));
    } catch (_) {
      _setFailure(
        appText.thereWasAProblemUploadingThe,
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<void> _handlePostUploadFlow(_PhotoStepState uploadStage) async {
    if (!mounted) return;

    final effectiveStage = switch (_stage) {
      _PhotoStepState.approved ||
      _PhotoStepState.pending ||
      _PhotoStepState.rejected => _stage,
      _ => uploadStage,
    };

    if (effectiveStage != _stage) {
      setState(() {
        _stage = effectiveStage;
      });
    }

    if (effectiveStage == _PhotoStepState.rejected) {
      final message =
          _detailMessage ??
          appText.thisPhotoWasNotApprovedPlease;
      setState(() {
        _selectedImage = null;
        _fileInfo = null;
        _detailMessage = message;
      });
      _showMessage(message, _NoticeTone.warning);
      return;
    }

    final canContinue =
        effectiveStage == _PhotoStepState.approved ||
        effectiveStage == _PhotoStepState.pending;
    if (!canContinue) {
      _showMessage(
        appText.photoUploadedPleaseCheckTheStatus,
        _NoticeTone.info,
      );
      return;
    }

    final message = effectiveStage == _PhotoStepState.approved
        ? appText.photoApprovedMovingToPartnerPreference
        : appText.photoUploadedReviewIsPendingSo;

    setState(() {
      _detailMessage = message;
      _autoContinuing = true;
    });
    _showMessage(message, _NoticeTone.success);

    try {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      await _continue();
    } finally {
      if (mounted) {
        setState(() {
          _autoContinuing = false;
        });
      } else {
        _autoContinuing = false;
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
      final response = await ApiClient.getMyProfile(forceRefresh: true);
      if (!mounted) return;
      if (response['success'] == true) {
        _applyProfileSnapshot(_profileSnapshot());
        if (!silent) {
          await widget.onRefresh();
        }
      } else if (!silent) {
        _showMessage(
          appText.photoStatusCouldNotBeRefreshed,
          _NoticeTone.warning,
        );
      }
    } catch (_) {
      if (!silent) {
        _showMessage(
          appText.photoStatusCouldNotBeRefreshed,
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
          _selectedImage != null &&
          (_stage == _PhotoStepState.selected ||
              _stage == _PhotoStepState.uploading);
      final photoUrl = ApiClient.resolveProfilePhotoUrl(profile);
      final rawStatus = _firstNonEmpty(profile, const [
        'photo_status',
        'approval_status',
        'approved_status',
        'moderation_status',
      ])?.toLowerCase();
      final rejectionReason = _firstNonEmpty(profile, const [
        'photo_rejection_reason',
        'rejection_reason',
        'reject_reason',
      ]);
      final rejectedAt = _firstNonEmpty(profile, const [
        'photo_rejected_at',
        'rejected_at',
      ]);
      final approved =
          widget.status?.profile?.photoApproved == true ||
          _boolValue(profile['photo_approved']) == true ||
          rawStatus == 'approved' ||
          photoUrl != null;
      final rejected =
          rejectionReason != null ||
          rejectedAt != null ||
          (rawStatus?.contains('reject') ?? false);
      final uploaded =
          widget.status?.profile?.photoUploaded == true ||
          _hasUploaded(profile);

      if (approved) {
        if (photoUrl != null) {
          _approvedPhotoUrl = photoUrl;
        }
        if (hasDraftSelection) return;
        _selectedImage = null;
        _fileInfo = null;
        _stage = _PhotoStepState.approved;
        _detailMessage = appText.approvedPhotoIsVisibleOnYour;
        return;
      }

      if (hasDraftSelection) return;

      if (rejected) {
        _stage = _PhotoStepState.rejected;
        _selectedImage = null;
        _fileInfo = null;
        _detailMessage =
            rejectionReason ??
            appText.thisPhotoCouldNotBeApproved;
        return;
      }

      if (uploaded) {
        _stage = _PhotoStepState.pending;
        _detailMessage = appText.photoIsUploadedApprovalOrSafety;
        return;
      }

      _stage = _PhotoStepState.missing;
      _detailMessage = null;
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
      _stage = _PhotoStepState.error;
      _detailMessage = message;
    });
    _showMessage(message, _NoticeTone.error);
  }

  bool _uploadSucceeded(Map<String, dynamic> response) {
    final status = response['statusCode'];
    return status is int &&
        status >= 200 &&
        status < 300 &&
        response['success'] != false;
  }

  /// The gallery endpoint returns `photos` + `meta`, not `data`. A freshly
  /// queued photo is still being processed, so it may not be listed yet —
  /// treat anything short of a fully approved gallery as pending review.
  String? _uploadedPhotoStatus(Map<String, dynamic> response) {
    final rows = response['photos'];
    if (rows is! List || rows.isEmpty) return null;

    final statuses = <String>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final status = row['status']?.toString().trim().toLowerCase();
      if (status != null && status.isNotEmpty) statuses.add(status);
    }
    if (statuses.isEmpty) return null;
    if (statuses.every((status) => status == 'approved')) return 'approved';
    return 'pending';
  }

  /// Surfaces the real backend reason (file too large, photo limit reached,
  /// uploads suspended, profile locked) instead of a generic failure.
  String _uploadFailureMessage(Map<String, dynamic> response) {
    if (response['statusCode'] == 401) {
      return appText.sessionExpiredPleaseLoginAgain;
    }

    final serverMessage = _validationMessage(response) ?? _messageOf(response);
    if (serverMessage != null) return serverMessage;

    return switch (response['statusCode']) {
      401 => appText.sessionExpiredPleaseLoginAgain,
      403 => appText.photoUploadIsNotAllowedFor,
      404 => appText.profileWasNotFoundPleaseComplete,
      422 => appText.photoIsNotValidPleaseSelect,
      _ => appText.photoUploadFailedPleaseTryAgain,
    };
  }

  String? _messageOf(Map<String, dynamic> response) {
    final message = response['message']?.toString().trim();
    if (message == null || message.isEmpty) return null;
    return message;
  }

  String? _validationMessage(Map<String, dynamic> response) {
    final errors = response['errors'];
    if (errors is! Map) return null;
    for (final value in errors.values) {
      if (value is List) {
        for (final item in value) {
          final text = item?.toString().trim();
          if (text != null && text.isNotEmpty) return text;
        }
      }
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  _PhotoStepState _stageFromUploadStatus(String? status) {
    if (status == null || status.isEmpty) return _PhotoStepState.pending;
    if (status.contains('approved')) return _PhotoStepState.approved;
    if (status.contains('reject')) return _PhotoStepState.rejected;
    if (status == 'error') return _PhotoStepState.error;
    return _PhotoStepState.pending;
  }

  bool get _hasSelectedPendingUpload =>
      _selectedImage != null &&
      (_stage == _PhotoStepState.selected ||
          _stage == _PhotoStepState.error ||
          _stage == _PhotoStepState.rejected);

  bool get _canProceedAfterUpload =>
      _stage == _PhotoStepState.pending || _stage == _PhotoStepState.approved;

  @override
  Widget build(BuildContext context) {
    final rawProfile = _profileSnapshot();
    final photoUrl =
        _approvedPhotoUrl ?? ApiClient.resolveProfilePhotoUrl(rawProfile);
    final currentStage = _stage;
    final busy =
        widget.loading || _uploading || _checkingStatus || _autoContinuing;
    final stickyUploads = _hasSelectedPendingUpload;
    final stickyContinues = !stickyUploads && _canProceedAfterUpload;

    return OnboardingStepScaffold(
      title: appText.profilePhoto2,
      subtitle: appText.addAClearPhotoCropIt,
      loading: busy,
      continueEnabled: !busy && (stickyUploads || stickyContinues),
      onBack: widget.onBack,
      onContinue: stickyUploads ? _uploadImage : _continue,
      continueLabel: stickyUploads || !_canProceedAfterUpload
          ? (_uploading ? appText.uploadingPhoto : appText.uploadSelectedPhoto)
          : appText.continueToPartnerPreference,
      secondary: TextButton.icon(
        onPressed: busy ? null : () async => _refreshProfileStatus(),
        icon: _checkingStatus
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        label: Text(appText.refreshPhotoStatus),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      children: [
        _PhotoHero(
          photoUrl: photoUrl,
          selectedImage: _selectedImage,
          state: currentStage,
          onTap: busy
              ? null
              : () => _pickImage(ImageSource.gallery),
        ),
        const SizedBox(height: 10),
        _PhotoStatusPanel(
          state: currentStage,
          title: _statusTitle(currentStage),
          message: _detailMessage ?? _statusMessage(currentStage),
          fileInfo: _fileInfo,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(appText.camera),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(appText.gallery),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          ],
        ),
        if (_selectedImage != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: busy ? null : _cropSelectedImage,
            icon: const Icon(Icons.crop, size: 18),
            label: Text(appText.cropAdjustPhoto),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _PhotoGuidelines(
          labels: [
            appText.clearFace,
            appText.singlePerson,
            appText.goodLight,
            appText.safePhoto,
          ],
        ),
      ],
    );
  }

  String _statusTitle(_PhotoStepState state) {
    return switch (state) {
      _PhotoStepState.approved => appText.photoApproved,
      _PhotoStepState.pending => appText.approvalPending,
      _PhotoStepState.rejected => appText.photoNotApproved,
      _PhotoStepState.uploading => appText.uploadingPhoto,
      _PhotoStepState.error => appText.uploadNeedsAttention,
      _PhotoStepState.selected => appText.readyToUpload,
      _PhotoStepState.missing => appText.photoNotUploaded,
    };
  }

  String _statusMessage(_PhotoStepState state) {
    return switch (state) {
      _PhotoStepState.approved => appText.thisApprovedPhotoIsVisibleOn,
      _PhotoStepState.pending => appText.photoUploadedBackendQualitySafetyCheck,
      _PhotoStepState.rejected => appText.pleaseUploadAClearSafeSingle,
      _PhotoStepState.uploading => appText.uploadCompleteScreen,
      _PhotoStepState.error => appText.pleaseTryAgainWithAClear,
      _PhotoStepState.selected => appText.cropTheSelectedPhotoIfNeeded,
      _PhotoStepState.missing => appText.cameraGalleryProfilePhotoAdd,
    };
  }

  bool _hasUploaded(Map<String, dynamic>? profile) {
    if (profile == null) return false;
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

  String? _firstNonEmpty(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return null;
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

  Future<ui.Image> _decodeUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<File?> _showCropDialog(ui.Image image) async {
    var zoom = 1.0;
    var centerX = 0.5;
    var centerY = 0.5;
    var saving = false;
    var baseZoom = 1.0;
    var baseCenterX = 0.5;
    var baseCenterY = 0.5;
    var panAccumX = 0.0;
    var panAccumY = 0.0;
    const aspectRatio = 3 / 4;

    return showDialog<File?>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final cropRect = _sourceCropRect(
              image: image,
              aspectRatio: aspectRatio,
              zoom: zoom,
              centerX: centerX,
              centerY: centerY,
            );

            Future<void> applyCrop() async {
              setDialogState(() {
                saving = true;
              });
              try {
                final file = await _writeCroppedImage(image, cropRect);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(file);
                }
              } catch (_) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(null);
                }
              }
            }

            void onScaleStart(ScaleStartDetails details) {
              baseZoom = zoom;
              baseCenterX = centerX;
              baseCenterY = centerY;
              panAccumX = 0;
              panAccumY = 0;
            }

            void onScaleUpdate(ScaleUpdateDetails details) {
              if (saving) return;
              final boxWidth = math.max(MediaQuery.sizeOf(context).width, 1.0);
              final boxHeight = math.max(
                MediaQuery.sizeOf(context).height,
                1.0,
              );
              panAccumX += details.focalPointDelta.dx;
              panAccumY += details.focalPointDelta.dy;
              setDialogState(() {
                zoom = (baseZoom * details.scale).clamp(1.0, 3.0);
                centerX = (baseCenterX - panAccumX / boxWidth).clamp(0.0, 1.0);
                centerY = (baseCenterY - panAccumY / boxHeight).clamp(0.0, 1.0);
              });
            }

            return Dialog(
              insetPadding: const EdgeInsets.all(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 420,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.9,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        appText.cropPhoto,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        appText.photoSelectedCropItIfNeeded,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AspectRatio(
                        aspectRatio: aspectRatio,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: GestureDetector(
                              onScaleStart: onScaleStart,
                              onScaleUpdate: onScaleUpdate,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CustomPaint(
                                    painter: _CropPreviewPainter(
                                      image: image,
                                      sourceRect: cropRect,
                                    ),
                                  ),
                                  IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              child: Text(appText.cancel2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: saving ? null : applyCrop,
                              icon: saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check),
                              label: Text(appText.applyCrop),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Rect _sourceCropRect({
    required ui.Image image,
    required double aspectRatio,
    required double zoom,
    required double centerX,
    required double centerY,
  }) {
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();

    var cropWidth = imageWidth;
    var cropHeight = cropWidth / aspectRatio;
    if (cropHeight > imageHeight) {
      cropHeight = imageHeight;
      cropWidth = cropHeight * aspectRatio;
    }

    cropWidth = cropWidth / zoom;
    cropHeight = cropHeight / zoom;

    final maxLeft = math.max(0.0, imageWidth - cropWidth);
    final maxTop = math.max(0.0, imageHeight - cropHeight);
    final left = (centerX * imageWidth - cropWidth / 2).clamp(0.0, maxLeft);
    final top = (centerY * imageHeight - cropHeight / 2).clamp(0.0, maxTop);

    return Rect.fromLTWH(left, top, cropWidth, cropHeight);
  }

  Future<File> _writeCroppedImage(ui.Image image, Rect sourceRect) async {
    const targetSizes = <Size>[Size(720, 960), Size(600, 800), Size(480, 640)];
    Uint8List? outputBytes;

    for (final size in targetSizes) {
      outputBytes = await _renderCroppedPng(image, sourceRect, size);
      if (outputBytes.lengthInBytes <= 1900 * 1024 ||
          size == targetSizes.last) {
        break;
      }
    }

    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}matrimony_photo_crop_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(outputBytes!, flush: true);
    return file;
  }

  Future<Uint8List> _renderCroppedPng(
    ui.Image image,
    Rect sourceRect,
    Size targetSize,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(
      image,
      sourceRect,
      Rect.fromLTWH(0, 0, targetSize.width, targetSize.height),
      paint,
    );
    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(
      targetSize.width.round(),
      targetSize.height.round(),
    );
    final byteData = await croppedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    croppedImage.dispose();
    picture.dispose();
    if (byteData == null) {
      throw StateError(appText.cropEncodingFailed);
    }
    return byteData.buffer.asUint8List();
  }
}

enum _NoticeTone { success, warning, error, info }

class _PhotoHero extends StatelessWidget {
  const _PhotoHero({
    required this.photoUrl,
    required this.selectedImage,
    required this.state,
    this.onTap,
  });

  final String? photoUrl;
  final File? selectedImage;
  final _PhotoStepState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Material(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (selectedImage != null)
                      Image.file(selectedImage!, fit: BoxFit.cover)
                    else if (photoUrl == null)
                      _PhotoPlaceholder(state: state)
                    else
                      ProfileNetworkImage(
                        url: photoUrl!,
                        placeholder: _PhotoPlaceholder(state: state),
                        alignment: Alignment.center,
                      ),
                    if (selectedImage == null && photoUrl == null)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.photo_library_outlined,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    appText.gallery,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: _PhotoBadge(state: state),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.state});

  final _PhotoStepState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            state == _PhotoStepState.approved
                ? Icons.check_circle_outline
                : state == _PhotoStepState.rejected ||
                      state == _PhotoStepState.error
                ? Icons.report_gmailerrorred_outlined
                : Icons.person_outline,
            size: 62,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            state == _PhotoStepState.approved
                ? appText.dashboardPhotoApproved
                : state == _PhotoStepState.pending
                ? appText.reviewInProgress
                : appText.profilePhoto,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            appText.portrait34WorksBest,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge({required this.state});

  final _PhotoStepState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = switch (state) {
      _PhotoStepState.approved => const Color(0xFF15803D),
      _PhotoStepState.rejected || _PhotoStepState.error => colors.error,
      _PhotoStepState.pending ||
      _PhotoStepState.uploading => const Color(0xFFB45309),
      _PhotoStepState.selected || _PhotoStepState.missing => colors.primary,
    };
    final label = switch (state) {
      _PhotoStepState.approved => appText.photoApproved,
      _PhotoStepState.rejected => appText.photoNotApproved,
      _PhotoStepState.error => appText.retry,
      _PhotoStepState.pending => appText.approvalPending,
      _PhotoStepState.uploading => appText.badgeUploading,
      _PhotoStepState.selected => appText.readyToUpload,
      _PhotoStepState.missing => appText.photoNotUploaded,
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

class _PhotoStatusPanel extends StatelessWidget {
  const _PhotoStatusPanel({
    required this.state,
    required this.title,
    required this.message,
    this.fileInfo,
  });

  final _PhotoStepState state;
  final String title;
  final String message;
  final String? fileInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = switch (state) {
      _PhotoStepState.approved => const Color(0xFF15803D),
      _PhotoStepState.rejected || _PhotoStepState.error => colors.error,
      _PhotoStepState.pending ||
      _PhotoStepState.uploading => const Color(0xFFB45309),
      _ => colors.primary,
    };
    final icon = switch (state) {
      _PhotoStepState.approved => Icons.verified_outlined,
      _PhotoStepState.rejected ||
      _PhotoStepState.error => Icons.report_gmailerrorred_outlined,
      _PhotoStepState.pending => Icons.pending_actions_outlined,
      _PhotoStepState.uploading => Icons.cloud_upload_outlined,
      _PhotoStepState.selected => Icons.check_circle_outline,
      _PhotoStepState.missing => Icons.add_photo_alternate_outlined,
    };

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
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  if (fileInfo != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      appText.selectedFileName(fileInfo!),
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
}

class _CropPreviewPainter extends CustomPainter {
  const _CropPreviewPainter({required this.image, required this.sourceRect});

  final ui.Image image;
  final Rect sourceRect;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(image, sourceRect, Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _CropPreviewPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.sourceRect != sourceRect;
  }
}

class _PhotoGuidelines extends StatelessWidget {
  const _PhotoGuidelines({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.face_retouching_natural_outlined,
      Icons.person_outline,
      Icons.light_mode_outlined,
      Icons.verified_user_outlined,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          _GuidelineChip(icon: icons[i], label: labels[i]),
      ],
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
