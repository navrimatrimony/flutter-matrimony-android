import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../models/activation_checklist.dart';
import '../models/onboarding_status.dart';
import 'onboarding_step_helpers.dart';

class ActivationChecklistStep extends StatefulWidget {
  const ActivationChecklistStep({
    super.key,
    required this.status,
    required this.locale,
    required this.loading,
    required this.onRefresh,
    required this.onBack,
  });

  final OnboardingStatus? status;
  final String locale;
  final bool loading;
  final Future<void> Function() onRefresh;
  final VoidCallback onBack;

  @override
  State<ActivationChecklistStep> createState() =>
      _ActivationChecklistStepState();
}

class _ActivationChecklistStepState extends State<ActivationChecklistStep> {
  bool _preferenceLoading = false;
  String? _preferenceMessage;

  bool get _mr => widget.locale == 'mr';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPreferences());
  }

  String _t(String en, String mr) => _mr ? mr : en;

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
            'Partner preferences have been auto-created from your profile.',
            'Partner preferences profile वरून auto-create झाल्या आहेत.',
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
              ? _t(
                  'Partner preferences have been auto-created from your profile.',
                  'Partner preferences profile वरून auto-create झाल्या आहेत.',
                )
              : readableApiError(
                  generated,
                  _t(
                    'Partner preferences will be auto-created later.',
                    'Partner preferences नंतर auto-create होतील.',
                  ),
                );
        });
      } else {
        setState(() {
          _preferenceLoading = false;
          _preferenceMessage = readableApiError(
            preview,
            _t(
              'Partner preferences will be auto-created after required profile data is complete.',
              'Required profile data पूर्ण झाल्यावर partner preferences auto-create होतील.',
            ),
          );
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preferenceLoading = false;
        _preferenceMessage = _t(
          'Partner preferences will be auto-created automatically.',
          'Partner preferences automatically auto-create होतील.',
        );
      });
    }
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
          _t('Activation Checklist', 'Activation Checklist'),
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
                      ? _t('Profile searchable', 'Profile searchable आहे')
                      : _t(
                          'Profile not searchable yet',
                          'Profile अजून searchable नाही',
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
              'Checklist is not available yet. Refresh status.',
              'Checklist अजून उपलब्ध नाही. Status refresh करा.',
            ),
          )
        else
          ...items.map(_itemTile),
        const SizedBox(height: 14),
        _preferenceCard(context),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.loading ? null : widget.onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: widget.loading ? null : widget.onRefresh,
                icon: const Icon(Icons.refresh),
                label: Text(_t('Refresh checklist', 'Checklist refresh करा')),
              ),
            ),
          ],
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
                    'Partner preferences will be auto-created from onboarding data.',
                    'Onboarding data वरून partner preferences auto-create होतील.',
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
