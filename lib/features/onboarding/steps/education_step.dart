import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import '../widgets/onboarding_picker_field.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';
import '../../../core/app_language.dart';

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

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void didUpdateWidget(covariant EducationStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.data, widget.data)) _prefill();
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
                label:
                    onboardingText(row['label']) ??
                    onboardingSelectedFailureLabel(widget.locale),
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
          .map(
            (id) => selectedValuePlaceholderOption(
              id,
              widget.locale,
              failed: true,
            )!,
          )
          .toList();
    }
  }


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
            title: Text(appText.requestEducation),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: label,
                    decoration: InputDecoration(
                      labelText: appText.educationLabel,
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
                      labelText: appText.notesOptional,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appText.pendingSuggestionsAreNotSelectedAs2,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(appText.cancel2),
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
                        ? appText.educationRequestSubmitted
                        : readableApiError(
                            response,
                            appText.couldNotSubmitRequest,
                          ),
                  );
                },
                child: Text(appText.submit),
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
      title: appText.education,
      subtitle: appText.chooseTheHighestOrRelevantEducation,
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: _save,
      secondary: OutlinedButton.icon(
        onPressed: widget.loading ? null : _showSuggestionDialog,
        icon: const Icon(Icons.add),
        label: Text(
          appText.notFoundRequestToAdd,
        ),
      ),
      children: [
        OnboardingPickerField(
          label: appText.education,
          selectedItems: _selected,
          multiSelect: true,
          placeholder: appText.searchAndSelectEducation,
          searchHint: appText.searchEducation,
          loadPage: _educationPage,
          itemSubtitleBuilder: (option) => option.metaText('category_label'),
          allowRequestToAdd: true,
          onRequestToAdd: _showSuggestionDialog,
          onChanged: (items) => setState(() => _selected = items),
        ),
        if (highest.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            appText.highestSelected +
                highest.first.label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
