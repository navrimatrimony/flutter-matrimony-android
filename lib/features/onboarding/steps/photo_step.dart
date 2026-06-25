import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../photo/photo_upload_screen.dart';
import '../models/onboarding_status.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';

class PhotoStep extends StatelessWidget {
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

  bool get _mr => locale == 'mr';

  String _t(String en, String mr) => _mr ? mr : en;

  Future<void> _continue() async {
    final profile = status?.profile;
    await onSave(
      'photo',
      compactPayload({
        'photo_uploaded': profile?.photoUploaded,
        'photo_approved': profile?.photoApproved,
        'photo_status': profile?.photoApproved == true
            ? 'approved'
            : profile?.photoUploaded == true
            ? 'pending'
            : 'missing',
      }),
      saveProfile: false,
    );
  }

  Future<void> _openUpload(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const PhotoUploadScreen(returnToPreviousOnSuccess: true),
      ),
    );
    await onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final profile = status?.profile;
    final photoUrl = ApiClient.resolveProfilePhotoUrl(
      profile?.raw ?? ApiClient.currentUserProfile,
    );
    final uploaded = profile?.photoUploaded == true || photoUrl != null;
    final approved = profile?.photoApproved == true;

    return OnboardingStepScaffold(
      title: _t('Profile Photo', 'Profile Photo'),
      subtitle: _t(
        'You can skip now, but the profile will be visible after photo upload and approval.',
        'सध्या skip करू शकता, पण photo upload आणि approval नंतरच profile दिसेल.',
      ),
      loading: loading,
      onBack: onBack,
      onContinue: _continue,
      continueLabel: _t('Continue to checklist', 'Checklist कडे जा'),
      secondary: OutlinedButton.icon(
        onPressed: loading ? null : () => _openUpload(context),
        icon: const Icon(Icons.photo_camera_outlined),
        label: Text(_t('Upload / manage photo', 'Photo upload/manage करा')),
      ),
      children: [
        Row(
          children: [
            ClipOval(
              child: Container(
                width: 72,
                height: 72,
                color: Colors.grey.shade100,
                child: photoUrl == null
                    ? Icon(
                        Icons.person_outline,
                        color: Colors.grey.shade600,
                        size: 36,
                      )
                    : Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.person_outline,
                          color: Colors.grey.shade600,
                          size: 36,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                approved
                    ? _t('Photo approved.', 'Photo approved आहे.')
                    : uploaded
                    ? _t(
                        'Photo uploaded. Awaiting approval.',
                        'Photo uploaded आहे. Approval pending आहे.',
                      )
                    : _t(
                        'No photo uploaded yet.',
                        'Photo अजून upload केलेला नाही.',
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
