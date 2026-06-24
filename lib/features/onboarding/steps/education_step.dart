import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import '../widgets/onboarding_picker_field.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';

class EducationStep extends StatefulWidget {
  const EducationStep({
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
  State<EducationStep> createState() => _EducationStepState();
}

class _EducationStepState extends State<EducationStep> {
  List<OnboardingOption> _selected = <OnboardingOption>[];
  bool get _mr => widget.locale == 'mr';

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void didUpdateWidget(covariant EducationStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _prefill();
  }

  void _prefill() {
    final slots = widget.data['education_slots'];
    if (slots is List) {
      _selected = slots
          .map((slot) {
            if (slot is Map) {
              final row = Map<String, dynamic>.from(slot);
              return OnboardingOption(
                id: row['id'],
                key: row['key']?.toString(),
                label: row['label']?.toString() ?? 'Education #${row['id']}',
                meta: row['meta'] is Map
                    ? Map<String, dynamic>.from(row['meta'])
                    : <String, dynamic>{},
                raw: row,
              );
            }
            return null;
          })
          .whereType<OnboardingOption>()
          .toList();
      return;
    }

    final ids = widget.data['education_degree_ids'];
    if (ids is List) {
      _selected = ids
          .map(onboardingInt)
          .whereType<int>()
          .map((id) => OnboardingOption(id: id, label: 'Education #$id'))
          .toList();
    }
  }

  String _t(String en, String mr) => _mr ? mr : en;

  Future<PagedLookupResponse> _educationPage(
    String query,
    int page,
    int limit,
  ) async {
    return PagedLookupResponse.fromJson(
      await ApiClient.searchEducation(
        query: query,
        page: page,
        limit: limit,
        locale: widget.locale,
      ),
    );
  }

  Future<void> _save() async {
    final degreeIds = _selected
        .map((option) => option.intId)
        .whereType<int>()
        .toList();
    final slots = _selected
        .where((option) => option.intId != null)
        .map(
          (option) => <String, dynamic>{
            't': 'd',
            'id': option.intId,
            'label': option.label,
            if (option.key != null) 'key': option.key,
            if (option.meta.isNotEmpty) 'meta': option.meta,
          },
        )
        .toList();

    await widget.onSave('education', {
      'education_slots': slots,
      'education_degree_ids': degreeIds,
    }, saveProfile: true);
  }

  Future<void> _showSuggestionDialog() async {
    final label = TextEditingController();
    final categoryId = TextEditingController();
    final notes = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(_t('Request education', 'Education request')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: label,
                    decoration: InputDecoration(
                      labelText: _t('Education label', 'Education label'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: categoryId,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'category_id'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notes,
                    decoration: InputDecoration(
                      labelText: _t('Notes optional', 'Notes optional'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(
                      'Pending suggestions are not selected as education until approved.',
                      'Pending suggestion approved होईपर्यंत education म्हणून select होत नाही.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_t('Cancel', 'Cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  final response = await ApiClient.submitEducationSuggestion(
                    compactPayload({
                      'label': label.text.trim(),
                      'category_id': onboardingInt(categoryId.text),
                      'notes': notes.text.trim(),
                    }),
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  widget.onMessage(
                    response['success'] == true
                        ? _t(
                            'Education request submitted.',
                            'Education request submit झाली.',
                          )
                        : readableApiError(
                            response,
                            _t(
                              'Could not submit request.',
                              'Request submit झाली नाही.',
                            ),
                          ),
                  );
                },
                child: Text(_t('Submit', 'Submit')),
              ),
            ],
          );
        },
      );
    } finally {
      label.dispose();
      categoryId.dispose();
      notes.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final highest = [..._selected]
      ..sort(
        (a, b) => (b.metaInt('level_rank') ?? 0).compareTo(
          a.metaInt('level_rank') ?? 0,
        ),
      );

    return OnboardingStepScaffold(
      title: _t('Education', 'शिक्षण'),
      subtitle: _t(
        'Select approved backend education options only.',
        'फक्त backend approved education options निवडा.',
      ),
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: _save,
      secondary: OutlinedButton.icon(
        onPressed: widget.loading ? null : _showSuggestionDialog,
        icon: const Icon(Icons.add),
        label: Text(
          _t('Not found? Request to add', 'सापडले नाही? Request करा'),
        ),
      ),
      children: [
        OnboardingPickerField(
          label: _t('Education', 'शिक्षण'),
          selectedItems: _selected,
          multiSelect: true,
          placeholder: _t(
            'Search and select education',
            'Education शोधून निवडा',
          ),
          searchHint: _t('Search education', 'Education शोधा'),
          loadPage: _educationPage,
          itemSubtitleBuilder: (option) => option.metaText('category_label'),
          allowRequestToAdd: true,
          onRequestToAdd: _showSuggestionDialog,
          onChanged: (items) => setState(() => _selected = items),
        ),
        if (highest.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _t('Highest selected: ', 'सर्वात उच्च निवड: ') +
                highest.first.label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
