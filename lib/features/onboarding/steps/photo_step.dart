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

class _DraftPhoto {
  const _DraftPhoto({required this.file, required this.cropped});

  final File file;
  final bool cropped;
}

class _RemotePhoto {
  const _RemotePhoto({
    required this.id,
    required this.url,
    required this.isPrimary,
    required this.status,
  });

  final int? id;
  final String? url;
  final bool isPrimary;
  final String status;
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
  static const int _defaultMaxPhotos = 5;

  final ImagePicker _picker = ImagePicker();

  final List<_DraftPhoto> _drafts = <_DraftPhoto>[];
  List<_RemotePhoto> _remotePhotos = <_RemotePhoto>[];
  int _selectedDraftIndex = 0;
  int? _selectedRemoteId;
  int _maxPhotos = _defaultMaxPhotos;
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
      _refreshGallery(silent: true);
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

    if (_stage == _PhotoStepState.selected || _drafts.isNotEmpty) {
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
    final remaining = _remainingSlots;
    if (remaining <= 0) {
      _showMessage(
        appText.photoUploadIsNotAllowedFor,
        _NoticeTone.warning,
      );
      return;
    }

    try {
      final pickedFiles = <File>[];
      if (source == ImageSource.gallery) {
        final picked = await _picker.pickMultiImage(
          imageQuality: 92,
          maxWidth: 1600,
          maxHeight: 2134,
          requestFullMetadata: false,
          limit: remaining,
        );
        if (picked.isEmpty) {
          _showMessage(
            appText.photoSelectionCancelled,
            _NoticeTone.info,
          );
          return;
        }
        for (final item in picked.take(remaining)) {
          pickedFiles.add(File(item.path));
        }
      } else {
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
        pickedFiles.add(File(pickedFile.path));
      }

      for (final picked in pickedFiles) {
        if (!mounted) return;
        if (_remainingSlots <= 0) break;

        ui.Image? sourceImage;
        try {
          sourceImage = await _decodeUiImage(await picked.readAsBytes());
          if (!mounted) return;
          final croppedFile = await _showCropDialog(sourceImage);
          if (!mounted) return;
          if (croppedFile != null) {
            await _appendDraft(croppedFile, cropped: true);
          } else {
            await _appendDraft(picked, cropped: false);
          }
        } finally {
          sourceImage?.dispose();
        }
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

  Future<void> _appendDraft(File file, {required bool cropped}) async {
    final fileSize = await file.length();
    final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
    if (!mounted) return;

    setState(() {
      _drafts.add(_DraftPhoto(file: file, cropped: cropped));
      _selectedDraftIndex = _drafts.length - 1;
      _selectedRemoteId = null;
      _fileInfo = cropped
          ? '${_drafts.length} · $fileSizeMB MB, cropped'
          : '${_drafts.length} · $fileSizeMB MB';
      _detailMessage = cropped
          ? appText.croppedPhotoIsReadyUploadIt
          : appText.photoSelectedCropItIfNeeded;
      _stage = _PhotoStepState.selected;
    });
  }

  Future<void> _cropSelectedImage() async {
    final draft = _selectedDraft;
    if (draft == null) {
      _showMessage(
        appText.pleaseSelectAPhotoFirst,
        _NoticeTone.warning,
      );
      return;
    }

    ui.Image? sourceImage;
    try {
      final bytes = await draft.file.readAsBytes();
      sourceImage = await _decodeUiImage(bytes);
      if (!mounted) return;

      final croppedFile = await _showCropDialog(sourceImage);
      if (croppedFile == null) return;

      final fileSize = await croppedFile.length();
      final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
      if (!mounted) return;
      setState(() {
        _drafts[_selectedDraftIndex] = _DraftPhoto(
          file: croppedFile,
          cropped: true,
        );
        _fileInfo = '$fileSizeMB MB, cropped';
        _detailMessage = appText.croppedPhotoIsReadyUploadIt;
        _stage = _PhotoStepState.selected;
      });
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
    if (_drafts.isEmpty) {
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
      // First file is sent as profile_photo (main when gallery is empty).
      final response = await ApiClient.uploadProfilePhotos(
        _drafts.map((draft) => draft.file).toList(growable: false),
      );
      if (!mounted) return;

      if (_uploadSucceeded(response)) {
        final uploadStage = _stageFromUploadStatus(
          _uploadedPhotoStatus(response),
        );

        setState(() {
          _drafts.clear();
          _selectedDraftIndex = 0;
          _selectedRemoteId = null;
          _fileInfo = null;
          _stage = uploadStage;
          _detailMessage = appText.photoReachedBackendQualityAndSafety;
        });

        await _refreshGallery(silent: true);
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
        _drafts.clear();
        _selectedDraftIndex = 0;
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

  Future<void> _refreshGallery({bool silent = false}) async {
    if (ApiClient.authToken == null) return;

    try {
      final response = await ApiClient.getProfilePhotos();
      if (!mounted) return;
      if (!_uploadSucceeded(response) && response['success'] == false) {
        if (!silent) {
          _showMessage(
            appText.photoStatusCouldNotBeRefreshed,
            _NoticeTone.warning,
          );
        }
        return;
      }

      final meta = response['meta'];
      final maxPhotos = meta is Map
          ? int.tryParse(meta['max_photos']?.toString() ?? '')
          : null;
      final rows = response['photos'];
      final photos = <_RemotePhoto>[];
      if (rows is List) {
        for (final row in rows) {
          if (row is! Map) continue;
          final map = Map<String, dynamic>.from(row);
          final id = int.tryParse(map['id']?.toString() ?? '');
          final url = _firstNonEmpty(map, const [
            'thumbnail_url',
            'url',
            'photo_url',
            'profile_photo_url',
          ]);
          final status =
              map['status']?.toString().trim().toLowerCase() ?? 'pending';
          final isPrimary =
              map['is_primary'] == true ||
              map['primary'] == true ||
              map['is_main'] == true;
          photos.add(
            _RemotePhoto(
              id: id,
              url: url == null
                  ? null
                  : ApiClient.normalizeProfilePhotoUrl(url),
              isPrimary: isPrimary,
              status: status,
            ),
          );
        }
      }

      setState(() {
        _remotePhotos = photos;
        if (maxPhotos != null && maxPhotos > 0) {
          _maxPhotos = maxPhotos;
        }
        if (_selectedRemoteId != null &&
            photos.every((photo) => photo.id != _selectedRemoteId)) {
          _selectedRemoteId = null;
        }
      });
    } catch (_) {
      if (!silent && mounted) {
        _showMessage(
          appText.photoStatusCouldNotBeRefreshed,
          _NoticeTone.warning,
        );
      }
    }
  }

  void _applyProfileSnapshot(
    Map<String, dynamic>? profile, {
    bool notify = true,
  }) {
    if (profile == null) return;

    void apply() {
      final hasDraftSelection = _drafts.isNotEmpty;
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
          _hasUploaded(profile) ||
          _remotePhotos.isNotEmpty;

      if (approved) {
        if (photoUrl != null) {
          _approvedPhotoUrl = photoUrl;
        }
        if (hasDraftSelection) return;
        _fileInfo = null;
        _stage = _PhotoStepState.approved;
        _detailMessage = appText.approvedPhotoIsVisibleOnYour;
        return;
      }

      if (hasDraftSelection) return;

      if (rejected) {
        _stage = _PhotoStepState.rejected;
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
      _drafts.isNotEmpty &&
      (_stage == _PhotoStepState.selected ||
          _stage == _PhotoStepState.error ||
          _stage == _PhotoStepState.rejected ||
          _stage == _PhotoStepState.uploading);

  bool get _canProceedAfterUpload =>
      _drafts.isEmpty &&
      (_stage == _PhotoStepState.pending || _stage == _PhotoStepState.approved);

  int get _remainingSlots =>
      math.max(0, _maxPhotos - _remotePhotos.length - _drafts.length);

  _DraftPhoto? get _selectedDraft {
    if (_selectedRemoteId != null) return null;
    if (_drafts.isEmpty) return null;
    if (_selectedDraftIndex < 0 || _selectedDraftIndex >= _drafts.length) {
      return _drafts.first;
    }
    return _drafts[_selectedDraftIndex];
  }

  _RemotePhoto? get _selectedRemote {
    final id = _selectedRemoteId;
    if (id == null) return null;
    for (final photo in _remotePhotos) {
      if (photo.id == id) return photo;
    }
    return null;
  }

  String? get _heroPhotoUrl {
    final remote = _selectedRemote;
    if (remote?.url != null) return remote!.url;
    if (_selectedDraft != null) return null;
    if (_remotePhotos.isNotEmpty) {
      for (final photo in _remotePhotos) {
        if (photo.isPrimary && photo.url != null) return photo.url;
      }
      return _remotePhotos.first.url;
    }
    return _approvedPhotoUrl ??
        ApiClient.resolveProfilePhotoUrl(_profileSnapshot());
  }

  String get _uploadContinueLabel {
    if (_uploading) return appText.uploadingPhoto;
    final count = _drafts.length;
    if (isMarathiApp) {
      return count <= 1 ? 'फोटो अपलोड करा' : '$count फोटो अपलोड करा';
    }
    return count <= 1 ? 'Upload photo' : 'Upload $count photos';
  }

  String get _makeMainPhotoLabel =>
      isMarathiApp ? 'मुख्य फोटो करा' : 'Make main photo';

  void _selectDraft(int index) {
    if (index < 0 || index >= _drafts.length) return;
    setState(() {
      _selectedDraftIndex = index;
      _selectedRemoteId = null;
      if (_stage != _PhotoStepState.uploading) {
        _stage = _PhotoStepState.selected;
      }
    });
  }

  void _selectRemote(_RemotePhoto photo) {
    setState(() {
      _selectedRemoteId = photo.id;
    });
  }

  Future<void> _promptMakeMainDraft(int index) async {
    if (index < 0 || index >= _drafts.length) return;
    final alreadyMain = index == 0;
    if (alreadyMain) {
      _showMessage(
        isMarathiApp
            ? 'ही आधीच मुख्य फोटो आहे.'
            : 'This is already the main photo.',
        _NoticeTone.info,
      );
      return;
    }

    final confirmed = await _showMakeMainSheet();
    if (confirmed != true || !mounted) return;
    _makeDraftMain(index);
    _showMessage(appText.primaryPhotoUpdated, _NoticeTone.success);
  }

  Future<void> _promptMakeMainRemote(_RemotePhoto photo) async {
    if (photo.id == null) return;
    if (photo.isPrimary) {
      _showMessage(
        isMarathiApp
            ? 'ही आधीच मुख्य फोटो आहे.'
            : 'This is already the main photo.',
        _NoticeTone.info,
      );
      return;
    }

    final confirmed = await _showMakeMainSheet();
    if (confirmed != true || !mounted) return;

    try {
      final response = await ApiClient.setPrimaryProfilePhoto(photo.id!);
      if (!mounted) return;
      if (_uploadSucceeded(response) || response['success'] != false) {
        await _refreshGallery(silent: true);
        await _refreshProfileStatus(silent: true);
        if (!mounted) return;
        _showMessage(appText.primaryPhotoUpdated, _NoticeTone.success);
        return;
      }
      _showMessage(
        _uploadFailureMessage(response),
        _NoticeTone.error,
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        appText.thereWasAProblemUploadingThe,
        _NoticeTone.error,
      );
    }
  }

  Future<bool?> _showMakeMainSheet() {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: ListTile(
              leading: Icon(
                Icons.star,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                _makeMainPhotoLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onTap: () => Navigator.pop(context, true),
            ),
          ),
        );
      },
    );
  }

  void _removeDraft(int index) {
    if (index < 0 || index >= _drafts.length) return;
    setState(() {
      _drafts.removeAt(index);
      if (_drafts.isEmpty) {
        _selectedDraftIndex = 0;
        _fileInfo = null;
        if (_remotePhotos.isNotEmpty) {
          _stage = _PhotoStepState.pending;
          _detailMessage = appText.photoIsUploadedApprovalOrSafety;
        } else {
          _stage = _PhotoStepState.missing;
          _detailMessage = appText.cameraGalleryProfilePhotoAdd;
        }
      } else {
        _selectedDraftIndex = math.min(index, _drafts.length - 1);
        _stage = _PhotoStepState.selected;
        _detailMessage = appText.photoSelectedCropItIfNeeded;
      }
    });
  }

  void _makeDraftMain(int index) {
    if (index <= 0 || index >= _drafts.length) return;
    setState(() {
      final draft = _drafts.removeAt(index);
      _drafts.insert(0, draft);
      _selectedDraftIndex = 0;
      _selectedRemoteId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentStage = _stage;
    final busy =
        widget.loading || _uploading || _checkingStatus || _autoContinuing;
    final stickyUploads = _hasSelectedPendingUpload && _drafts.isNotEmpty;
    final stickyContinues = !stickyUploads && _canProceedAfterUpload;
    final selectedDraft = _selectedDraft;
    final heroUrl = _heroPhotoUrl;
    final showMainBadge =
        selectedDraft != null
            ? _selectedDraftIndex == 0
            : (_selectedRemote?.isPrimary ??
                  (_remotePhotos.isNotEmpty && _selectedRemoteId == null));

    return OnboardingStepScaffold(
      title: appText.profilePhoto2,
      subtitle: appText.addAClearPhotoCropIt,
      loading: busy,
      continueEnabled: !busy && (stickyUploads || stickyContinues),
      onBack: widget.onBack,
      onContinue: stickyUploads ? _uploadImage : _continue,
      continueLabel: stickyUploads || !_canProceedAfterUpload
          ? _uploadContinueLabel
          : appText.continueToPartnerPreference,
      titleAction: IconButton(
        tooltip: appText.refreshPhotoStatus,
        onPressed: busy
            ? null
            : () async {
                await _refreshProfileStatus();
                await _refreshGallery();
              },
        icon: _checkingStatus
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
      children: [
        _PhotoHero(
          photoUrl: heroUrl,
          selectedImage: selectedDraft?.file,
          state: currentStage,
          showMainBadge: showMainBadge &&
              (selectedDraft != null || heroUrl != null),
          onTap: busy ? null : () => _pickImage(ImageSource.gallery),
        ),
        const SizedBox(height: 10),
        _PhotoStatusPanel(
          state: currentStage,
          title: _statusTitle(currentStage),
          message: _detailMessage ?? _statusMessage(currentStage),
          fileInfo: _fileInfo ??
              (_drafts.isNotEmpty
                  ? appText.photosCounter(
                      _drafts.length + _remotePhotos.length,
                      _maxPhotos,
                    )
                  : null),
        ),
        const SizedBox(height: 12),
        _PhotoThumbnailStrip(
          drafts: _drafts,
          remotes: _remotePhotos,
          selectedDraftIndex:
              _selectedRemoteId == null ? _selectedDraftIndex : null,
          selectedRemoteId: _selectedRemoteId,
          canAdd: !busy && _remainingSlots > 0,
          onSelectDraft: _selectDraft,
          onSelectRemote: _selectRemote,
          onMakeMainDraft: busy ? null : _promptMakeMainDraft,
          onMakeMainRemote: busy ? null : _promptMakeMainRemote,
          onRemoveDraft: busy ? null : _removeDraft,
          onAdd: () => _pickImage(ImageSource.gallery),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy || _remainingSlots <= 0
                    ? null
                    : () => _pickImage(ImageSource.camera),
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
                onPressed: busy || _remainingSlots <= 0
                    ? null
                    : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(appText.gallery),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          ],
        ),
        if (selectedDraft != null) ...[
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

  Future<File?> _showCropDialog(ui.Image image) {
    return showModalBottomSheet<File?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OnboardingPhotoCropSheet(image: image),
    );
  }
}

enum _NoticeTone { success, warning, error, info }

enum _OnboardingCropDragMode {
  none,
  move,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class _OnboardingPhotoCropSheet extends StatefulWidget {
  const _OnboardingPhotoCropSheet({required this.image});

  final ui.Image image;

  @override
  State<_OnboardingPhotoCropSheet> createState() =>
      _OnboardingPhotoCropSheetState();
}

class _OnboardingPhotoCropSheetState extends State<_OnboardingPhotoCropSheet> {
  static const double _targetAspectRatio = 3 / 4;

  late Rect _cropRect;
  Rect? _dragStartRect;
  _OnboardingCropDragMode _dragMode = _OnboardingCropDragMode.none;
  bool _saving = false;

  Size get _imageSize =>
      Size(widget.image.width.toDouble(), widget.image.height.toDouble());

  @override
  void initState() {
    super.initState();
    _cropRect = _initialCropRect();
  }

  /// Largest 3:4 window, flush to the top of the photo (existing product rule).
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.92,
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
                    appText.adjustCrop34,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
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
                    appText.dragFramePullCorners,
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
                    child: Text(appText.cancel2),
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
                    label: Text(appText.applyCrop),
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
                    painter: _OnboardingCropOverlayPainter(
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

  void _startDrag(Offset localPosition, Size viewSize) {
    final viewRect = _toViewRect(_cropRect, viewSize);
    _dragMode = _hitTest(localPosition, viewRect);
    _dragStartRect = _cropRect;
  }

  void _updateDrag(Offset localPosition, Offset delta, Size viewSize) {
    final startRect = _dragStartRect;
    if (startRect == null || _dragMode == _OnboardingCropDragMode.none) {
      return;
    }

    setState(() {
      if (_dragMode == _OnboardingCropDragMode.move) {
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
    _dragMode = _OnboardingCropDragMode.none;
    _dragStartRect = null;
  }

  _OnboardingCropDragMode _hitTest(Offset localPosition, Rect viewRect) {
    const handleSize = 48.0;
    final corners = <_OnboardingCropDragMode, Offset>{
      _OnboardingCropDragMode.topLeft: viewRect.topLeft,
      _OnboardingCropDragMode.topRight: viewRect.topRight,
      _OnboardingCropDragMode.bottomLeft: viewRect.bottomLeft,
      _OnboardingCropDragMode.bottomRight: viewRect.bottomRight,
    };
    for (final entry in corners.entries) {
      final handle = Rect.fromCenter(
        center: entry.value,
        width: handleSize,
        height: handleSize,
      );
      if (handle.contains(localPosition)) return entry.key;
    }
    if (viewRect.contains(localPosition)) {
      return _OnboardingCropDragMode.move;
    }
    return _OnboardingCropDragMode.none;
  }

  Rect _resizeRect(
    Rect startRect,
    Offset sourcePoint,
    _OnboardingCropDragMode mode,
  ) {
    final point = _clampPoint(sourcePoint);
    return switch (mode) {
      _OnboardingCropDragMode.topLeft =>
        _rectFromBottomRight(startRect.bottomRight, point),
      _OnboardingCropDragMode.topRight =>
        _rectFromBottomLeft(startRect.bottomLeft, point),
      _OnboardingCropDragMode.bottomLeft =>
        _rectFromTopRight(startRect.topRight, point),
      _OnboardingCropDragMode.bottomRight =>
        _rectFromTopLeft(startRect.topLeft, point),
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(appText.couldNotCropPhoto)));
    }
  }

  Future<File> _writeCroppedImage() async {
    const targetSizes = <Size>[
      Size(720, 960),
      Size(600, 800),
      Size(480, 640),
    ];
    Uint8List? outputBytes;
    for (final size in targetSizes) {
      outputBytes = await _renderCroppedPng(size);
      if (outputBytes.lengthInBytes <= 1900 * 1024 ||
          size == targetSizes.last) {
        break;
      }
    }

    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'matrimony_photo_crop_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(outputBytes!, flush: true);
    return file;
  }

  Future<Uint8List> _renderCroppedPng(Size targetSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(
      widget.image,
      _cropRect,
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

class _OnboardingCropOverlayPainter extends CustomPainter {
  const _OnboardingCropOverlayPainter({
    required this.image,
    required this.cropRect,
  });

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
      ..addRect(viewRect);
    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawRect(viewRect, borderPaint);

    // Perfect circle guide: diameter = crop width, flush to top of 3:4 frame.
    final circleRadius = viewRect.width / 2;
    final circleCenter = Offset(
      viewRect.center.dx,
      viewRect.top + circleRadius,
    );
    canvas.drawCircle(
      circleCenter,
      circleRadius,
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      circleCenter,
      circleRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

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
  bool shouldRepaint(covariant _OnboardingCropOverlayPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.cropRect != cropRect;
  }
}

class _PhotoThumbnailStrip extends StatelessWidget {
  const _PhotoThumbnailStrip({
    required this.drafts,
    required this.remotes,
    required this.selectedDraftIndex,
    required this.selectedRemoteId,
    required this.canAdd,
    required this.onSelectDraft,
    required this.onSelectRemote,
    required this.onMakeMainDraft,
    required this.onMakeMainRemote,
    required this.onRemoveDraft,
    required this.onAdd,
  });

  final List<_DraftPhoto> drafts;
  final List<_RemotePhoto> remotes;
  final int? selectedDraftIndex;
  final int? selectedRemoteId;
  final bool canAdd;
  final ValueChanged<int> onSelectDraft;
  final ValueChanged<_RemotePhoto> onSelectRemote;
  final ValueChanged<int>? onMakeMainDraft;
  final ValueChanged<_RemotePhoto>? onMakeMainRemote;
  final ValueChanged<int>? onRemoveDraft;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final itemCount = remotes.length + drafts.length + (canAdd ? 1 : 0);
    if (itemCount == 0) return const SizedBox.shrink();

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index < remotes.length) {
            final photo = remotes[index];
            return _StripThumb(
              selected: photo.id != null && photo.id == selectedRemoteId,
              isMain: photo.isPrimary,
              onTap: () => onSelectRemote(photo),
              onLongPress: onMakeMainRemote == null
                  ? null
                  : () => onMakeMainRemote!(photo),
              child: photo.url == null
                  ? Icon(
                      Icons.image_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )
                  : ProfileNetworkImage(
                      url: photo.url!,
                      placeholder: Icon(
                        Icons.image_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
            );
          }

          final draftIndex = index - remotes.length;
          if (draftIndex < drafts.length) {
            final draft = drafts[draftIndex];
            final selected =
                selectedRemoteId == null && selectedDraftIndex == draftIndex;
            return _StripThumb(
              selected: selected,
              isMain: draftIndex == 0 && remotes.isEmpty,
              onTap: () => onSelectDraft(draftIndex),
              onLongPress: onMakeMainDraft == null
                  ? null
                  : () => onMakeMainDraft!(draftIndex),
              onRemove: onRemoveDraft == null
                  ? null
                  : () => onRemoveDraft!(draftIndex),
              child: Image.file(draft.file, fit: BoxFit.cover),
            );
          }

          return _StripThumb(
            selected: false,
            isMain: false,
            onTap: onAdd,
            dashed: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 2),
                Text(
                  appText.addPhotos,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StripThumb extends StatelessWidget {
  const _StripThumb({
    required this.selected,
    required this.isMain,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.onRemove,
    this.dashed = false,
  });

  final bool selected;
  final bool isMain;
  final VoidCallback onTap;
  final Widget child;
  final VoidCallback? onLongPress;
  final VoidCallback? onRemove;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borderColor = selected ? colors.primary : const Color(0xFFE7DDD8);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 64,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: dashed ? const Color(0xFFFFF8F4) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: dashed ? colors.primary.withValues(alpha: 0.55) : borderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (isMain)
                Positioned(
                  left: 4,
                  top: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      child: Text(
                        '1',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              if (onRemove != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onRemove,
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoHero extends StatelessWidget {
  const _PhotoHero({
    required this.photoUrl,
    required this.selectedImage,
    required this.state,
    required this.showMainBadge,
    this.onTap,
  });

  final String? photoUrl;
  final File? selectedImage;
  final _PhotoStepState state;
  final bool showMainBadge;
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
                    if (showMainBadge)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              appText.primaryPhoto,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
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
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _GuidelineChip(icon: icons[i], label: labels[i], compact: true),
          ],
        ],
      ),
    );
  }
}

class _GuidelineChip extends StatelessWidget {
  const _GuidelineChip({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 6 : 7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 14 : 16, color: colors.onSurfaceVariant),
            SizedBox(width: compact ? 4 : 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 11 : 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
