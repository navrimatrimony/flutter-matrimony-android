import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../models/activation_checklist.dart';
import '../models/onboarding_status.dart';
import 'onboarding_step_helpers.dart';

class ActivationChecklistStep extends StatefulWidget {
  const ActivationChecklistStep({
    super.key,
    required this.status,
    required this.account,
    required this.locale,
    required this.loading,
    required this.onSaveEmail,
    required this.onRefresh,
    required this.onBack,
  });

  final OnboardingStatus? status;
  final Map<String, dynamic> account;
  final String locale;
  final bool loading;
  final Future<String?> Function(String email) onSaveEmail;
  final Future<void> Function() onRefresh;
  final VoidCallback onBack;

  @override
  State<ActivationChecklistStep> createState() =>
      _ActivationChecklistStepState();
}

class _ActivationChecklistStepState extends State<ActivationChecklistStep> {
  final TextEditingController _emailController = TextEditingController();

  bool _preferenceLoading = false;
  String? _preferenceMessage;
  bool _emailSaving = false;
  String? _emailMessage;

  bool get _mr => widget.locale == 'mr';

  @override
  void initState() {
    super.initState();
    _prefillEmail();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPreferences());
  }

  @override
  void didUpdateWidget(covariant ActivationChecklistStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account && _emailController.text.isEmpty) {
      _prefillEmail();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String _t(String en, String mr) => _mr ? mr : en;

  void _prefillEmail() {
    final email = widget.account['email']?.toString().trim();
    if (email != null && email.isNotEmpty) {
      _emailController.text = email;
    }
  }

  Future<void> _syncPreferences() async {
    if (_preferenceLoading || widget.status?.hasProfile != true) return;
    setState(() => _preferenceLoading = true);

    try {
      final status = await ApiClient.getAutoPreferenceDraftStatus(
        locale: widget.locale,
      );
      if (!mounted) return;
      final alreadyGenerated =
          onboardingBool(
            status['generated'] ??
                status['exists'] ??
                status['has_auto_draft'] ??
                status['has_preferences'],
          ) ??
          false;
      if (alreadyGenerated) {
        setState(() {
          _preferenceLoading = false;
          _preferenceMessage = _t(
            'Match preferences are ready.',
            'जोडीदार पसंती तयार आहे.',
          );
        });
        return;
      }

      final preview = await ApiClient.previewAutoPreferenceDraft(
        locale: widget.locale,
      );
      if (!mounted) return;
      if (preview['success'] == true && preview['can_persist'] != false) {
        final generated = await ApiClient.generateAutoPreferenceDraft();
        if (!mounted) return;
        setState(() {
          _preferenceLoading = false;
          _preferenceMessage = generated['success'] == true
              ? _t('Match preferences are ready.', 'जोडीदार पसंती तयार आहे.')
              : readableApiError(
                  generated,
                  _t(
                    'Match preferences will be prepared later.',
                    'जोडीदार पसंती नंतर तयार होईल.',
                  ),
                );
        });
      } else {
        setState(() {
          _preferenceLoading = false;
          _preferenceMessage = readableApiError(
            preview,
            _t(
              'Match preferences will be prepared after required details are complete.',
              'गरजेची माहिती पूर्ण झाल्यावर जोडीदार पसंती तयार होईल.',
            ),
          );
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preferenceLoading = false;
        _preferenceMessage = _t(
          'Match preferences will be prepared automatically.',
          'जोडीदार पसंती आपोआप तयार होईल.',
        );
      });
    }
  }

  Future<void> _saveEmail() async {
    if (_emailSaving) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _emailMessage = _t('Email skipped for now.', 'Email सध्या skip केला.');
      });
      return;
    }

    setState(() {
      _emailSaving = true;
      _emailMessage = null;
    });
    final error = await widget.onSaveEmail(email);
    if (!mounted) return;
    setState(() {
      _emailSaving = false;
      _emailMessage = error ?? _t('Email saved.', 'Email save झाला.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final items =
        status?.activationChecklist ?? const <ActivationChecklistItem>[];
    final color = status?.isSearchable == true ? Colors.green : Colors.orange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _t(
            'To make the profile visible',
            'प्रोफाइल दिसण्यासाठी अजून हे बाकी आहे',
          ),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                status?.isSearchable == true
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status?.isSearchable == true
                      ? _t('Profile is visible', 'प्रोफाइल दिसत आहे')
                      : _t(
                          'Profile is not visible yet',
                          'प्रोफाइल अजून दिसत नाही',
                        ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text(
            _t(
              'Details are not available yet. Refresh once.',
              'माहिती अजून उपलब्ध नाही. एकदा refresh करा.',
            ),
          )
        else
          ...items.map(_itemTile),
        const SizedBox(height: 14),
        _emailCard(context),
        const SizedBox(height: 14),
        _preferenceCard(context),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: widget.loading ? null : widget.onRefresh,
          icon: const Icon(Icons.refresh),
          label: Text(_t('Refresh', 'Refresh करा')),
        ),
      ],
    );
  }

  Widget _itemTile(ActivationChecklistItem item) {
    final color = item.complete
        ? Colors.green
        : item.blocking
        ? Colors.orange
        : Colors.grey;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        item.complete ? Icons.check_circle : Icons.radio_button_unchecked,
        color: color,
      ),
      title: Text(item.label),
      subtitle: item.message == null ? null : Text(item.message!),
      trailing: item.blocking && !item.complete
          ? const Icon(Icons.priority_high, color: Colors.orange)
          : null,
    );
  }

  Widget _preferenceCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _preferenceLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.tune),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _preferenceMessage ??
                  _t(
                    'Match preferences will be prepared from this profile.',
                    'या प्रोफाइलवरून जोडीदार पसंती तयार होईल.',
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emailCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t('Email optional', 'Email optional'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _t(
                'Add it for account updates, or skip for now.',
                'Account updates साठी email भरा किंवा सध्या skip करा.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: _t('Email', 'Email')),
            ),
            if (_emailMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _emailMessage!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _emailSaving
                        ? null
                        : () {
                            _emailController.clear();
                            setState(() {
                              _emailMessage = _t(
                                'Email skipped for now.',
                                'Email सध्या skip केला.',
                              );
                            });
                          },
                    child: Text(_t('Skip for now', 'सध्या skip करा')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _emailSaving ? null : _saveEmail,
                    child: _emailSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_t('Save email', 'Email save करा')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
