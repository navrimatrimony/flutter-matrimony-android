import 'package:flutter/material.dart';

class ProfileContactData {
  final String title;
  final String state;
  final String? message;
  final String? phone;
  final String? email;
  final ProfileContactCtaData? primaryCta;
  final ProfileContactRequestOptionsData requestOptions;
  final ProfileContactWhatsAppData whatsAppResponse;

  const ProfileContactData({
    required this.title,
    required this.state,
    required this.message,
    required this.phone,
    required this.email,
    required this.primaryCta,
    this.requestOptions = const ProfileContactRequestOptionsData(),
    required this.whatsAppResponse,
  });

  bool get hasRevealedContact => phone != null || email != null;
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
          if (contact.phone != null || contact.email != null) ...[
            const SizedBox(height: 14),
            if (contact.phone != null)
              _ContactValueRow(
                icon: Icons.phone_outlined,
                label: 'Mobile Number',
                value: contact.phone!,
                onCopy: () => onCopy('Mobile Number', contact.phone!),
              ),
            if (contact.email != null)
              _ContactValueRow(
                icon: Icons.mail_outline,
                label: 'Email',
                value: contact.email!,
                onCopy: () => onCopy('Email', contact.email!),
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
  final VoidCallback onCopy;

  const _ContactValueRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onCopy,
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
          IconButton(
            tooltip: 'Copy',
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: 18),
          ),
        ],
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
            child: Text(data.enabled ? 'Open' : 'Soon'),
          ),
        ],
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
    case 'locked':
      return const Color(0xFF6E625F);
    default:
      return const Color(0xFF827775);
  }
}

String _stateLabel(String state) {
  switch (state) {
    case 'revealed':
      return 'Available';
    case 'unlock_available':
      return 'Locked';
    case 'upgrade_required':
      return 'Upgrade';
    case 'whatsapp_response_available':
      return 'Response';
    case 'contact_request_available':
      return 'Request';
    case 'contact_request_pending':
      return 'Pending';
    case 'contact_request_rejected':
      return 'Rejected';
    case 'contact_request_unavailable':
      return 'Info';
    case 'locked':
      return 'Locked';
    default:
      return 'Info';
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
    default:
      return Icons.info_outline;
  }
}
