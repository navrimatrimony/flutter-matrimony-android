import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api_client.dart';
import '../models/onboarding_status.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';

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
  _PhotoStepState _stage = _PhotoStepState.missing;

  bool get _mr => widget.locale == 'mr';

  String _t(String en, String mr) => _mr ? mr : en;

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
        _t(
          'Upload a profile photo before continuing.',
          'पुढे जाण्याआधी profile photo upload करा.',
        ),
        _NoticeTone.warning,
      );
      setState(() {
        _stage = _PhotoStepState.missing;
        _detailMessage = _t(
          'Add a profile photo from camera or gallery.',
          'Camera or gallery मधून profile photo add करा.',
        );
      });
      return;
    }

    if (_stage == _PhotoStepState.selected) {
      _showMessage(
        _t(
          'Upload the selected photo before continuing.',
          'पुढे जाण्याआधी selected photo upload करा.',
        ),
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
          _t('Photo selection cancelled.', 'Photo selection cancel झाले.'),
          _NoticeTone.info,
        );
        return;
      }

      await _setSelectedImage(File(pickedFile.path), cropped: false);
    } catch (error) {
      _showMessage(
        _t(
          'There was a problem selecting the photo. Please try again.',
          'Photo निवडताना problem आला. कृपया पुन्हा प्रयत्न करा.',
        ),
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
          ? _t(
              'Cropped photo is ready. Upload it to continue.',
              'Cropped photo ready आहे. पुढे जाण्यासाठी upload करा.',
            )
          : _t(
              'Photo selected. Crop it if needed, then upload.',
              'Photo निवडला आहे. गरज असल्यास crop करा आणि upload करा.',
            );
      _stage = _PhotoStepState.selected;
    });
  }

  Future<void> _cropSelectedImage() async {
    final file = _selectedImage;
    if (file == null) {
      _showMessage(
        _t('Please select a photo first.', 'कृपया आधी photo निवडा.'),
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
        _t(
          'Photo crop करता आला नाही. कृपया दुसरा photo निवडा.',
          'Photo crop करता आला नाही. कृपया दुसरा photo निवडा.',
        ),
        _NoticeTone.error,
      );
    } finally {
      sourceImage?.dispose();
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) {
      _showMessage(
        _t('Please select a photo first.', 'कृपया आधी photo निवडा.'),
        _NoticeTone.warning,
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _uploading = true;
      _stage = _PhotoStepState.uploading;
      _detailMessage = _t(
        'Photo is uploading. Please wait.',
        'Photo upload होत आहे. कृपया थांबा.',
      );
    });

    try {
      final response = await ApiClient.uploadProfilePhoto(_selectedImage!);
      if (!mounted) return;

      final statusCode = response['statusCode'];
      if (statusCode == 401) {
        _setFailure(
          _t(
            'Session expired. Please login again.',
            'Session expired. कृपया पुन्हा login करा.',
          ),
        );
        return;
      }
      if (statusCode == 403) {
        _setFailure(
          response['message']?.toString() ??
              _t(
                'Photo upload is not allowed for this account.',
                'Photo upload सध्या तुमच्या account साठी allowed नाही.',
              ),
        );
        return;
      }
      if (statusCode == 404) {
        _setFailure(
          response['message']?.toString() ??
              _t(
                'Profile was not found. Please complete profile first.',
                'Profile सापडली नाही. कृपया आधी profile तयार करा.',
              ),
        );
        return;
      }
      if (statusCode == 422) {
        _setFailure(
          response['message']?.toString() ??
              _t(
                'Photo is not valid. Please select a clear image.',
                'Photo valid नाही. कृपया clear image निवडा.',
              ),
        );
        return;
      }

      if (response['success'] == true && response['data'] is Map) {
        final uploadData = Map<String, dynamic>.from(response['data'] as Map);
        final status = uploadData['status']?.toString().trim().toLowerCase();

        setState(() {
          _stage = _stageFromUploadStatus(status);
          _detailMessage = _t(
            'Photo reached backend. Quality and safety check is in progress.',
            'Photo backend ला मिळाला आहे. Quality आणि safety check चालू आहे.',
          );
        });

        await _refreshProfileStatus(silent: true);
        await widget.onRefresh();
        if (!mounted) return;

        _showMessage(
          _t(
            'Photo uploaded. Status will update here.',
            'Photo upload झाला. Status इथे update होईल.',
          ),
          _NoticeTone.success,
        );
        return;
      }

      _setFailure(
        response['message']?.toString() ??
            _t(
              'Photo upload failed. Please try again.',
              'Photo upload fail झाला. कृपया पुन्हा प्रयत्न करा.',
            ),
      );
    } catch (_) {
      _setFailure(
        _t(
          'There was a problem uploading the photo. Please try again.',
          'Photo upload करताना problem आला. कृपया पुन्हा प्रयत्न करा.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
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
        _applyProfileSnapshot(_profileSnapshot());
        if (!silent) {
          await widget.onRefresh();
        }
      } else if (!silent) {
        _showMessage(
          _t(
            'Photo status could not be refreshed.',
            'Photo status refresh करता आला नाही.',
          ),
          _NoticeTone.warning,
        );
      }
    } catch (_) {
      if (!silent) {
        _showMessage(
          _t(
            'Photo status could not be refreshed.',
            'Photo status refresh करता आला नाही.',
          ),
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
        _detailMessage = _t(
          'Approved photo is visible on your profile. You can replace it with a new photo.',
          'Approved photo profile वर दिसत आहे. नवीन photo निवडून replace करू शकता.',
        );
        return;
      }

      if (hasDraftSelection) return;

      if (rejected) {
        _stage = _PhotoStepState.rejected;
        _detailMessage =
            rejectionReason ??
            _t(
              'This photo could not be approved. Please upload another clear photo.',
              'हा photo approve होऊ शकला नाही. कृपया दुसरा clear photo upload करा.',
            );
        return;
      }

      if (uploaded) {
        _stage = _PhotoStepState.pending;
        _detailMessage = _t(
          'Photo is uploaded. Approval or safety check is pending.',
          'Photo uploaded आहे. Approval किंवा safety check pending आहे.',
        );
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

  _PhotoStepState _stageFromUploadStatus(String? status) {
    if (status == null || status.isEmpty) return _PhotoStepState.pending;
    if (status.contains('approved')) return _PhotoStepState.approved;
    if (status.contains('reject')) return _PhotoStepState.rejected;
    if (status == 'error') return _PhotoStepState.error;
    return _PhotoStepState.pending;
  }

  @override
  Widget build(BuildContext context) {
    final rawProfile = _profileSnapshot();
    final photoUrl =
        _approvedPhotoUrl ?? ApiClient.resolveProfilePhotoUrl(rawProfile);
    final currentStage = _stage;
    final approved = currentStage == _PhotoStepState.approved;
    final busy = widget.loading || _uploading || _checkingStatus;

    return OnboardingStepScaffold(
      title: _t('Profile Photo', 'Profile Photo'),
      subtitle: _t(
        'Add a clear photo. Crop it if needed, then upload it for approval.',
        'Clear photo add करा. गरज असल्यास crop करा आणि approval साठी upload करा.',
      ),
      loading: busy,
      continueEnabled: !_uploading,
      onBack: widget.onBack,
      onContinue: _continue,
      continueLabel: _t(
        'Continue to partner preference',
        'Partner preference कडे जा',
      ),
      secondary: TextButton.icon(
        onPressed: busy ? null : () async => _refreshProfileStatus(),
        icon: _checkingStatus
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        label: Text(_t('Refresh photo status', 'Photo status refresh करा')),
      ),
      children: [
        _PhotoHero(
          photoUrl: photoUrl,
          selectedImage: _selectedImage,
          state: currentStage,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(_t('Camera', 'Camera')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(_t('Gallery', 'Gallery')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
        if (_selectedImage != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : _cropSelectedImage,
            icon: const Icon(Icons.crop),
            label: Text(_t('Crop / adjust photo', 'Photo crop/adjust करा')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: busy ? null : _uploadImage,
            icon: _uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(
              _uploading
                  ? _t('Uploading photo', 'Photo upload होत आहे')
                  : _t('Upload selected photo', 'Selected photo upload करा'),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ] else ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: busy ? null : () => _pickImage(ImageSource.gallery),
            icon: Icon(
              approved
                  ? Icons.swap_horiz_outlined
                  : Icons.add_photo_alternate_outlined,
            ),
            label: Text(
              approved
                  ? _t('Replace approved photo', 'Approved photo बदला')
                  : _t('Select photo', 'Photo निवडा'),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
        const SizedBox(height: 14),
        _PhotoStatusPanel(
          state: currentStage,
          title: _statusTitle(currentStage),
          message: _detailMessage ?? _statusMessage(currentStage),
          fileInfo: _fileInfo,
        ),
        const SizedBox(height: 12),
        _PhotoGuidelines(
          labels: [
            _t('Clear face', 'Clear face'),
            _t('Single person', 'Single person'),
            _t('Good light', 'Good light'),
            _t('Safe photo', 'Safe photo'),
          ],
        ),
      ],
    );
  }

  String _statusTitle(_PhotoStepState state) {
    return switch (state) {
      _PhotoStepState.approved => _t('Photo approved', 'Photo approved आहे'),
      _PhotoStepState.pending => _t('Approval pending', 'Approval pending आहे'),
      _PhotoStepState.rejected => _t(
        'Photo not approved',
        'Photo approve झाला नाही',
      ),
      _PhotoStepState.uploading => _t(
        'Uploading photo',
        'Photo upload होत आहे',
      ),
      _PhotoStepState.error => _t(
        'Upload needs attention',
        'Upload मध्ये problem आहे',
      ),
      _PhotoStepState.selected => _t('Ready to upload', 'Upload साठी ready'),
      _PhotoStepState.missing => _t(
        'Photo not uploaded',
        'Photo upload केलेला नाही',
      ),
    };
  }

  String _statusMessage(_PhotoStepState state) {
    return switch (state) {
      _PhotoStepState.approved => _t(
        'This approved photo is visible on your profile.',
        'हा approved photo तुमच्या profile वर दिसत आहे.',
      ),
      _PhotoStepState.pending => _t(
        'Photo uploaded आहे. Backend quality आणि safety check नंतर तो visible होईल.',
        'Photo uploaded आहे. Backend quality आणि safety check नंतर तो visible होईल.',
      ),
      _PhotoStepState.rejected => _t(
        'Please upload a clear, safe, single-person photo.',
        'कृपया clear, safe, single-person photo upload करा.',
      ),
      _PhotoStepState.uploading => _t(
        'Upload complete होईपर्यंत screen बंद करू नका.',
        'Upload complete होईपर्यंत screen बंद करू नका.',
      ),
      _PhotoStepState.error => _t(
        'Please try again with a clear photo.',
        'कृपया clear photo निवडून पुन्हा प्रयत्न करा.',
      ),
      _PhotoStepState.selected => _t(
        'Crop the selected photo if needed, then upload it.',
        'Selected photo गरज असल्यास crop करा आणि upload करा.',
      ),
      _PhotoStepState.missing => _t(
        'Camera किंवा gallery मधून profile photo add करा.',
        'Camera किंवा gallery मधून profile photo add करा.',
      ),
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

            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 420,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.86,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _t('Crop photo', 'Photo crop करा'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      AspectRatio(
                        aspectRatio: aspectRatio,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CustomPaint(
                              painter: _CropPreviewPainter(
                                image: image,
                                sourceRect: cropRect,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _CropSlider(
                        label: _t('Zoom', 'Zoom'),
                        value: zoom,
                        min: 1,
                        max: 3,
                        onChanged: saving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  zoom = value;
                                });
                              },
                      ),
                      _CropSlider(
                        label: _t('Left / right', 'Left / right'),
                        value: centerX,
                        min: 0,
                        max: 1,
                        onChanged: saving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  centerX = value;
                                });
                              },
                      ),
                      _CropSlider(
                        label: _t('Up / down', 'Up / down'),
                        value: centerY,
                        min: 0,
                        max: 1,
                        onChanged: saving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  centerY = value;
                                });
                              },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              child: Text(_t('Cancel', 'Cancel')),
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
                              label: Text(_t('Apply crop', 'Crop apply करा')),
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
      throw StateError('Crop encoding failed.');
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
  });

  final String? photoUrl;
  final File? selectedImage;
  final _PhotoStepState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
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
                  if (selectedImage != null)
                    Image.file(selectedImage!, fit: BoxFit.cover)
                  else if (photoUrl == null)
                    _PhotoPlaceholder(state: state)
                  else
                    Image.network(
                      photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _PhotoPlaceholder(state: state),
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
                ? 'Photo approved'
                : state == _PhotoStepState.pending
                ? 'Review in progress'
                : 'Profile photo',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
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
      _PhotoStepState.approved => 'Approved',
      _PhotoStepState.rejected => 'Rejected',
      _PhotoStepState.error => 'Retry',
      _PhotoStepState.pending => 'Pending',
      _PhotoStepState.uploading => 'Uploading',
      _PhotoStepState.selected => 'Selected',
      _PhotoStepState.missing => 'Photo',
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
                      'Selected file: $fileInfo',
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

class _CropSlider extends StatelessWidget {
  const _CropSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
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
