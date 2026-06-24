import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import '../widgets/onboarding_picker_field.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';

class LocationStep extends StatefulWidget {
  const LocationStep({
    super.key,
    required this.data,
    required this.locale,
    required this.loading,
    required this.onSave,
    required this.onBack,
    required this.onMessage,
  });

  final Map<String, dynamic> data;
  final String locale;
  final bool loading;
  final OnboardingStepSaver onSave;
  final VoidCallback onBack;
  final ValueChanged<String> onMessage;

  @override
  State<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<LocationStep> {
  final TextEditingController _addressLineController = TextEditingController();
  OnboardingOption? _location;
  int? _pendingLocationRequestId;
  String? _pendingLocationLabel;
  String? _pendingLocationStatus;
  String? _pendingLocationType;

  bool get _mr => widget.locale == 'mr';
  bool get _hasPendingLocation =>
      _pendingLocationRequestId != null || _pendingLocationStatus == 'pending';

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void didUpdateWidget(covariant LocationStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _prefill();
  }

  @override
  void dispose() {
    _addressLineController.dispose();
    super.dispose();
  }

  void _prefill() {
    final data = widget.data;
    _addressLineController.text = onboardingText(data['address_line']) ?? '';
    _location =
        optionFromData(data['location_option']) ??
        _placeholder(data['location_id']);
    _pendingLocationRequestId = onboardingInt(
      data['pending_location_request_id'],
    );
    _pendingLocationLabel = onboardingText(data['pending_location_label']);
    _pendingLocationStatus = onboardingText(data['pending_location_status']);
    _pendingLocationType = onboardingText(data['pending_location_type']);
  }

  String _t(String en, String mr) => _mr ? mr : en;

  OnboardingOption? _placeholder(dynamic id) {
    final intId = onboardingInt(id);
    if (intId == null) return null;
    return OnboardingOption(id: intId, label: 'Location #$intId');
  }

  bool _locationEnabled(OnboardingOption option) {
    return option.metaBool('is_final_node') == true &&
        option.metaText('status') == 'approved';
  }

  Future<PagedLookupResponse> _locationPage(
    String query,
    int page,
    int limit,
  ) async {
    if (query.trim().length < 2) {
      return PagedLookupResponse.fromOptions(const []);
    }
    return PagedLookupResponse.fromJson(
      await ApiClient.searchLocationsForOnboarding(
        query: query,
        page: page,
        limit: limit,
        locale: widget.locale,
      ),
    );
  }

  Future<void> _save() async {
    final location = _location;
    if (location == null || !_locationEnabled(location)) {
      widget.onMessage(
        _t(
          'Choose an approved final location.',
          'Approved final location निवडा.',
        ),
      );
      return;
    }

    final payload = compactPayload({
      'location_id': location.intId,
      'address_line': _addressLineController.text.trim(),
    });
    payload.addAll(const {
      'pending_location_request_id': null,
      'pending_location_label': null,
      'pending_location_status': null,
      'pending_location_type': null,
    });

    await widget.onSave('location', payload, saveProfile: true);
  }

  Future<void> _showSuggestionDialog() async {
    final type = ValueNotifier<String>('village');
    final name = TextEditingController();
    final stateId = TextEditingController();
    final districtId = TextEditingController();
    final talukaId = TextEditingController();
    final cityId = TextEditingController();
    final pincode = TextEditingController();
    final notes = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(_t('Request new location', 'नवीन location request')),
            content: SingleChildScrollView(
              child: ValueListenableBuilder<String>(
                valueListenable: type,
                builder: (context, value, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: value,
                        decoration: InputDecoration(
                          labelText: _t('Type', 'Type'),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'village',
                            child: Text('Village'),
                          ),
                          DropdownMenuItem(value: 'city', child: Text('City')),
                          DropdownMenuItem(
                            value: 'suburb',
                            child: Text('Suburb'),
                          ),
                        ],
                        onChanged: (next) => type.value = next ?? 'village',
                      ),
                      const SizedBox(height: 10),
                      _dialogField(name, _t('Name', 'नाव')),
                      _dialogField(stateId, 'state_id'),
                      _dialogField(districtId, 'district_id'),
                      if (value == 'village')
                        _dialogField(talukaId, 'taluka_id'),
                      if (value == 'suburb') _dialogField(cityId, 'city_id'),
                      _dialogField(
                        pincode,
                        _t('Pincode optional', 'Pincode optional'),
                      ),
                      _dialogField(
                        notes,
                        _t('Notes optional', 'Notes optional'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          'This request stays pending until backend approval.',
                          'Backend approval होईपर्यंत request pending राहील.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_t('Cancel', 'Cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  final body = compactPayload({
                    'type': type.value,
                    'name': name.text.trim(),
                    'state_id': onboardingInt(stateId.text),
                    'district_id': onboardingInt(districtId.text),
                    'taluka_id': onboardingInt(talukaId.text),
                    'city_id': onboardingInt(cityId.text),
                    'pincode': pincode.text.trim(),
                    'notes': notes.text.trim(),
                  });
                  final response = await ApiClient.submitLocationSuggestion(
                    body,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  if (response['success'] != true) {
                    widget.onMessage(
                      readableApiError(
                        response,
                        _t(
                          'Could not submit request.',
                          'Request submit झाली नाही.',
                        ),
                      ),
                    );
                    return;
                  }

                  final request = response['request'];
                  final requestMap = request is Map
                      ? Map<String, dynamic>.from(request)
                      : <String, dynamic>{};
                  final submittedLabel =
                      onboardingText(requestMap['label']) ?? name.text.trim();
                  final draftPayload = <String, dynamic>{
                    'location_id': null,
                    'pending_location_request_id': onboardingInt(
                      requestMap['id'],
                    ),
                    'pending_location_label': submittedLabel,
                    'pending_location_status':
                        onboardingText(requestMap['status']) ?? 'pending',
                    'pending_location_type':
                        onboardingText(requestMap['type']) ?? type.value,
                  };
                  final saved = await widget.onSave(
                    'location',
                    draftPayload,
                    saveProfile: false,
                    advance: false,
                  );
                  if (!mounted || !saved) return;
                  setState(() {
                    _location = null;
                    _pendingLocationRequestId = onboardingInt(requestMap['id']);
                    _pendingLocationLabel = submittedLabel;
                    _pendingLocationStatus =
                        onboardingText(requestMap['status']) ?? 'pending';
                    _pendingLocationType =
                        onboardingText(requestMap['type']) ?? type.value;
                  });
                },
                child: Text(_t('Submit', 'Submit')),
              ),
            ],
          );
        },
      );
    } finally {
      type.dispose();
      name.dispose();
      stateId.dispose();
      districtId.dispose();
      talukaId.dispose();
      cityId.dispose();
      pincode.dispose();
      notes.dispose();
    }
  }

  Widget _dialogField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        controller: controller,
        keyboardType: label.endsWith('_id') ? TextInputType.number : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: _t('Location', 'ठिकाण'),
      subtitle: _t(
        'Only approved final locations can make a profile searchable.',
        'फक्त approved final location profile searchable करू शकते.',
      ),
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: _save,
      secondary: OutlinedButton.icon(
        onPressed: widget.loading ? null : _showSuggestionDialog,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(
          _t('Not found? Request to add', 'सापडले नाही? Request करा'),
        ),
      ),
      children: [
        if (_hasPendingLocation) ...[
          _pendingLocationCard(context),
          const SizedBox(height: 12),
        ],
        OnboardingPickerField(
          label: _t('Current location', 'सध्याचे ठिकाण'),
          selectedItems: _location == null ? const [] : [_location!],
          placeholder: _t(
            'Search city, village or suburb',
            'City, village किंवा suburb शोधा',
          ),
          searchHint: _t('Type at least 2 letters', 'किमान 2 अक्षरे टाइप करा'),
          loadPage: _locationPage,
          optionEnabled: _locationEnabled,
          itemSubtitleBuilder: (option) {
            final status = option.metaText('status');
            final type = option.metaText('type');
            final finalNode = option.metaBool('is_final_node') == true;
            return [
              if (type != null) type,
              if (!finalNode) _t('Not final node', 'Final node नाही'),
              if (status != null) status,
            ].join(' • ');
          },
          onChanged: (items) => setState(() {
            _location = items.isEmpty ? null : items.first;
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressLineController,
          decoration: InputDecoration(
            labelText: _t('Address line optional', 'Address line optional'),
          ),
        ),
      ],
    );
  }

  Widget _pendingLocationCard(BuildContext context) {
    final label =
        _pendingLocationLabel ?? _t('Requested location', 'Requested location');
    final type = _pendingLocationType;
    final requestId = _pendingLocationRequestId;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
        color: Colors.orange.shade50,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.pending_actions, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (type != null) type,
                    if (requestId != null) '#$requestId',
                    _t(
                      'Approval pending; profile will not be searchable until approved.',
                      'Approval pending आहे; approved होईपर्यंत profile searchable होणार नाही.',
                    ),
                  ].join(' • '),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
