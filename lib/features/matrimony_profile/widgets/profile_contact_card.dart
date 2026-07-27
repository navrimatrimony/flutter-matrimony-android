import 'package:flutter/material.dart';

import '../../../core/app_language.dart';
import '../../../core/profile_photo_view.dart';

class ProfileContactData {
  final String title;
  final String state;
  final String? message;
  final String? phone;
  final String? maskedPhone;
  final String? email;
  final ProfileContactCtaData? primaryCta;
  final ProfileContactRequestOptionsData requestOptions;
  final ProfileContactWhatsAppData whatsAppResponse;

  /// Present only for Suchak-routed profiles. When it is set, the candidate's
  /// own number does not exist on this card by design — the member reaches the
  /// candidate through this Suchak, and nothing else.
  final ProfileContactSuchakData? suchak;

  const ProfileContactData({
    required this.title,
    required this.state,
    required this.message,
    required this.phone,
    this.maskedPhone,
    required this.email,
    required this.primaryCta,
    this.requestOptions = const ProfileContactRequestOptionsData(),
    required this.whatsAppResponse,
    this.suchak,
  });

  bool get hasRevealedContact => phone != null || email != null;
}

/// Who manages a Suchak-routed profile, plus where this member's own request
/// with them stands. Mirrors `display.contact.suchak` from the backend.
class ProfileContactSuchakData {
  final int? representationId;
  final int? suchakAccountId;
  final String name;
  final String? subtitle;
  final String? initial;
  final String? photoUrl;
  final String? maskedPhone;
  final bool canRequest;
  final ProfileContactSuchakRequestData? request;

  const ProfileContactSuchakData({
    this.representationId,
    this.suchakAccountId,
    required this.name,
    this.subtitle,
    this.initial,
    this.photoUrl,
    this.maskedPhone,
    this.canRequest = false,
    this.request,
  });
}

class ProfileContactSuchakRequestData {
  final int? id;
  final String? status;
  final String? statusLabel;
  final String? message;
  final String? answeredByLabel;
  final int? chatConversationId;

  const ProfileContactSuchakRequestData({
    this.id,
    this.status,
    this.statusLabel,
    this.message,
    this.answeredByLabel,
    this.chatConversationId,
  });
}

class ProfileContactCtaData {
  final String label;
  final String style;
  final String action;
  final bool enabled;

  const ProfileContactCtaData({
    required this.label,
    required this.style,
    required this.action,
    required this.enabled,
  });
}

class ProfileContactWhatsAppData {
  final bool visible;
  final String label;
  final String? message;
  final bool enabled;

  const ProfileContactWhatsAppData({
    required this.visible,
    required this.label,
    required this.message,
    required this.enabled,
  });
}

class ProfileContactRequestOptionsData {
  final List<ProfileContactOptionData> reasons;
  final List<ProfileContactOptionData> scopes;
  final List<String> defaultScopes;

  const ProfileContactRequestOptionsData({
    this.reasons = const <ProfileContactOptionData>[],
    this.scopes = const <ProfileContactOptionData>[],
    this.defaultScopes = const <String>[],
  });

  bool get isUsable => reasons.isNotEmpty && scopes.isNotEmpty;
}

class ProfileContactOptionData {
  final String key;
  final String label;

  const ProfileContactOptionData({required this.key, required this.label});
}

class ProfileContactCard extends StatelessWidget {
  final ProfileContactData contact;
  final Future<void> Function(String label, String value) onCopy;
  final void Function(ProfileContactCtaData cta) onPrimaryAction;
  final VoidCallback onWhatsAppResponse;
  final bool primaryActionLoading;

  const ProfileContactCard({
    super.key,
    required this.contact,
    required this.onCopy,
    required this.onPrimaryAction,
    required this.onWhatsAppResponse,
    this.primaryActionLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final lockedPhone = contact.phone == null ? contact.maskedPhone : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE2DE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContactHeader(contact: contact),
          if (contact.message != null) ...[
            const SizedBox(height: 12),
            Text(
              contact.message!,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (contact.suchak != null) ...[
            const SizedBox(height: 14),
            _SuchakPanel(suchak: contact.suchak!),
          ],
          if (contact.phone != null ||
              lockedPhone != null ||
              contact.email != null) ...[
            const SizedBox(height: 14),
            if (contact.phone != null)
              _ContactValueRow(
                icon: Icons.phone_outlined,
                label: appText.contactMobileNumberLabel,
                value: contact.phone!,
                onCopy: () =>
                    onCopy(appText.contactMobileNumberLabel, contact.phone!),
              ),
            if (lockedPhone != null) _LockedContactNumber(value: lockedPhone),
            if (contact.email != null)
              _ContactValueRow(
                icon: Icons.mail_outline,
                label: appText.contactEmailLabel,
                value: contact.email!,
                onCopy: () =>
                    onCopy(appText.contactEmailLabel, contact.email!),
              ),
          ],
          if (contact.primaryCta != null) ...[
            const SizedBox(height: 14),
            _ContactActionButton(
              cta: contact.primaryCta!,
              isLoading: primaryActionLoading,
              onPressed: () => onPrimaryAction(contact.primaryCta!),
            ),
          ],
          if (contact.whatsAppResponse.visible) ...[
            const SizedBox(height: 10),
            _WhatsAppResponseAction(
              data: contact.whatsAppResponse,
              onPressed: onWhatsAppResponse,
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactHeader extends StatelessWidget {
  final ProfileContactData contact;

  const _ContactHeader({required this.contact});

  @override
  Widget build(BuildContext context) {
    final color = _stateColor(contact.state);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(_stateIcon(contact.state), color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            contact.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF2E2220),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _ContactStatePill(state: contact.state),
      ],
    );
  }
}

class _ContactStatePill extends StatelessWidget {
  final String state;

  const _ContactStatePill({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = _stateColor(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _stateLabel(state),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ContactValueRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _ContactValueRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF9F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE2DE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 19, color: const Color(0xFF9B1B46)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              tooltip: appText.copy,
              onPressed: onCopy,
              icon: const Icon(Icons.copy, size: 18),
            ),
        ],
      ),
    );
  }
}

class _LockedContactNumber extends StatelessWidget {
  final String value;

  const _LockedContactNumber({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF9F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE2DE)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFF171717),
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                height: 1.05,
              ),
            ),
            const SizedBox(width: 14),
            const Text(
              '🔒',
              maxLines: 1,
              style: TextStyle(fontSize: 29, height: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactActionButton extends StatelessWidget {
  final ProfileContactCtaData cta;
  final bool isLoading;
  final VoidCallback onPressed;

  const _ContactActionButton({
    required this.cta,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final action = cta.action.trim().toLowerCase();
    final enabledStyle = cta.enabled && cta.style != 'disabled';
    final canPress = !isLoading && (cta.enabled || action == 'upgrade');
    final foreground = enabledStyle ? Colors.white : Colors.grey.shade700;
    final background = enabledStyle
        ? const Color(0xFF9B1B46)
        : const Color(0xFFF1ECE9);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canPress ? onPressed : null,
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : Icon(_ctaIcon(cta.action), size: 18),
        label: Text(cta.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          elevation: enabledStyle ? 1 : 0,
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

class _WhatsAppResponseAction extends StatelessWidget {
  final ProfileContactWhatsAppData data;
  final VoidCallback onPressed;

  const _WhatsAppResponseAction({required this.data, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDEBDD)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            color: data.enabled ? const Color(0xFF2F9E67) : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF2E2220),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (data.message != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    data.message!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: onPressed,
            child: Text(data.enabled ? appText.open : appText.soon),
          ),
        ],
      ),
    );
  }
}

/// The Suchak identity block: who manages this profile, their own masked
/// number, and — once a request exists — where it stands.
///
/// This is the whole point of the Suchak-routed contact card: the member is not
/// looking at a failed contact reveal, they are looking at the person they must
/// go through. The privacy note says so in words rather than leaving an empty
/// number field to be read as a bug.
class _SuchakPanel extends StatelessWidget {
  final ProfileContactSuchakData suchak;

  const _SuchakPanel({required this.suchak});

  @override
  Widget build(BuildContext context) {
    final request = suchak.request;
    final statusLabel = request?.statusLabel;
    final answeredBy = request?.answeredByLabel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF9F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE2DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appText.suchakManagedProfileTitle,
            style: const TextStyle(
              color: Color(0xFF9B1B46),
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _SuchakAvatar(suchak: suchak),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suchak.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF2E2220),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      suchak.subtitle ?? appText.suchakContactSubtitleFallback,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (suchak.maskedPhone != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 18,
                  color: Color(0xFF9B1B46),
                ),
                const SizedBox(width: 8),
                Text(
                  '${appText.suchakContactNumberLabel}: ',
                  style: const TextStyle(
                    color: Color(0xFF594044),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Expanded(
                  child: Text(
                    suchak.maskedPhone!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF171717),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (statusLabel != null || answeredBy != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (statusLabel != null) _SuchakChip(label: statusLabel),
                if (answeredBy != null)
                  _SuchakChip(
                    label: appText.suchakRequestAnsweredByName(answeredBy),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            appText.suchakContactPrivacyNote,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuchakAvatar extends StatelessWidget {
  final ProfileContactSuchakData suchak;

  const _SuchakAvatar({required this.suchak});

  @override
  Widget build(BuildContext context) {
    final photoUrl = suchak.photoUrl;
    if (photoUrl != null) {
      return ProfilePhotoView(
        photoUrl: photoUrl,
        width: 46,
        height: 46,
        circle: true,
        backgroundColor: const Color(0xFFF1E7E3),
        placeholderColor: const Color(0xFF9B1B46),
        placeholderIcon: Icons.support_agent,
      );
    }

    final initial = suchak.initial?.trim();
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFF1E7E3),
        shape: BoxShape.circle,
      ),
      child: initial == null || initial.isEmpty
          ? const Icon(Icons.support_agent, color: Color(0xFF9B1B46), size: 22)
          : Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF9B1B46),
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}

class _SuchakChip extends StatelessWidget {
  final String label;

  const _SuchakChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF9B1B46).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF9B1B46),
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

IconData _stateIcon(String state) {
  switch (state) {
    case 'revealed':
      return Icons.phone_in_talk_outlined;
    case 'unlock_available':
      return Icons.lock_open_outlined;
    case 'upgrade_required':
      return Icons.workspace_premium_outlined;
    case 'whatsapp_response_available':
      return Icons.chat_bubble_outline;
    case 'contact_request_available':
      return Icons.mark_email_unread_outlined;
    case 'contact_request_pending':
      return Icons.hourglass_top_outlined;
    case 'contact_request_rejected':
      return Icons.block_outlined;
    case 'contact_request_unavailable':
      return Icons.mail_lock_outlined;
    // Suchak-routed profiles. The candidate's number is never the subject
    // here, the Suchak is — so none of these use a lock icon.
    case 'suchak_request_available':
      return Icons.support_agent;
    case 'suchak_request_pending':
      return Icons.hourglass_top_outlined;
    case 'suchak_request_answered':
      return Icons.mark_chat_read_outlined;
    case 'suchak_request_closed':
      return Icons.restart_alt;
    case 'locked':
      return Icons.lock_outline;
    default:
      return Icons.contact_phone_outlined;
  }
}

Color _stateColor(String state) {
  switch (state) {
    case 'revealed':
      return const Color(0xFF2F9E67);
    case 'unlock_available':
      return const Color(0xFF9B1B46);
    case 'upgrade_required':
      return const Color(0xFFC78318);
    case 'whatsapp_response_available':
      return const Color(0xFF237A57);
    case 'contact_request_available':
      return const Color(0xFF237A57);
    case 'contact_request_pending':
      return const Color(0xFFC78318);
    case 'contact_request_rejected':
      return const Color(0xFFC2410C);
    case 'contact_request_unavailable':
      return const Color(0xFF6E625F);
    case 'suchak_request_available':
      return const Color(0xFF237A57);
    case 'suchak_request_pending':
      return const Color(0xFFC78318);
    case 'suchak_request_answered':
      return const Color(0xFF2F9E67);
    case 'suchak_request_closed':
      return const Color(0xFF6E625F);
    case 'locked':
      return const Color(0xFF6E625F);
    default:
      return const Color(0xFF827775);
  }
}

String _stateLabel(String state) {
  switch (state) {
    case 'revealed':
      return appText.contactStateAvailableBadge;
    case 'unlock_available':
      return appText.contactStateLockedBadge;
    case 'upgrade_required':
      return appText.upgrade;
    case 'whatsapp_response_available':
      return appText.contactStateResponseBadge;
    case 'contact_request_available':
      return appText.contactStateRequestBadge;
    case 'contact_request_pending':
      return appText.pending;
    case 'contact_request_rejected':
      return appText.rejected;
    case 'contact_request_unavailable':
      return appText.contactStateInfoBadge;
    // Suchak-routed profiles. "Suchak" is the affordance, not "Locked" —
    // there is a next step here, it just runs through a person.
    case 'suchak_request_available':
      return appText.suchakStateAvailableBadge;
    case 'suchak_request_pending':
      return appText.pending;
    case 'suchak_request_answered':
      return appText.suchakStateAnsweredBadge;
    case 'suchak_request_closed':
      return appText.suchakStateClosedBadge;
    case 'locked':
      return appText.contactStateLockedBadge;
    default:
      return appText.contactStateInfoBadge;
  }
}

IconData _ctaIcon(String action) {
  switch (action.trim().toLowerCase()) {
    case 'upgrade':
      return Icons.workspace_premium_outlined;
    case 'view_contact':
      return Icons.lock_open_outlined;
    case 'send_contact_request':
      return Icons.mark_email_unread_outlined;
    case 'send_suchak_request':
      return Icons.support_agent;
    case 'open_suchak_chat':
      return Icons.chat_bubble_outline;
    default:
      return Icons.info_outline;
  }
}
