import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';

typedef FamilyAboutStepSaver =
    Future<bool> Function(Map<String, dynamic> familyData, String aboutText);

class AboutTemplateSuggestion {
  const AboutTemplateSuggestion({required this.label, required this.text});

  final String label;
  final String text;
}

class FamilyOptionalStep extends StatefulWidget {
  const FamilyOptionalStep({
    super.key,
    required this.data,
    required this.initialAbout,
    required this.aboutSuggestions,
    required this.locale,
    required this.loading,
    required this.onSaveFamilyAbout,
    required this.onBack,
  });

  final Map<String, dynamic> data;
  final String? initialAbout;
  final List<AboutTemplateSuggestion> aboutSuggestions;
  final String locale;
  final bool loading;
  final FamilyAboutStepSaver onSaveFamilyAbout;
  final VoidCallback onBack;

  @override
  State<FamilyOptionalStep> createState() => _FamilyOptionalStepState();
}

class _FamilyOptionalStepState extends State<FamilyOptionalStep> {
  final TextEditingController _aboutController = TextEditingController();

  List<_FamilyChoice> _statusOptions = _FamilyChoice.fallbackStatuses;
  List<_FamilyChoice> _valueOptions = _FamilyChoice.fallbackValues;
  String? _familyStatus;
  String? _familyValues;
  bool _optionsLoading = false;
  String? _localError;
  int? _selectedSuggestionIndex;

  bool get _mr => widget.locale == 'mr';
  bool get _canContinue =>
      _familyStatus != null && _aboutController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _prefill();
    _loadFamilyOptions();
  }

  @override
  void didUpdateWidget(covariant FamilyOptionalStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.data, widget.data) ||
        oldWidget.initialAbout != widget.initialAbout ||
        !listEquals(oldWidget.aboutSuggestions, widget.aboutSuggestions)) {
      _prefill();
    }
  }

  @override
  void dispose() {
    _aboutController.dispose();
    super.dispose();
  }

  String _t(String en, String mr) => _mr ? mr : en;

  void _prefill() {
    _familyStatus = onboardingText(widget.data['family_status']);
    _familyValues = onboardingText(widget.data['family_values']);
    final about = widget.initialAbout?.trim();
    if (about != null && about.isNotEmpty && _aboutController.text.isEmpty) {
      _aboutController.text = about;
    } else if (_aboutController.text.isEmpty && _aboutSuggestions.isNotEmpty) {
      _selectedSuggestionIndex = 0;
      _aboutController.text = _suggestionText(_aboutSuggestions.first);
    }
  }

  List<AboutTemplateSuggestion> get _aboutSuggestions {
    if (widget.aboutSuggestions.isNotEmpty) return widget.aboutSuggestions;
    return <AboutTemplateSuggestion>[
      AboutTemplateSuggestion(
        label: _t('Simple & family-first', 'साधी ओळख'),
        text:
            'Family values and mutual respect are important to me. I believe in a balanced life with clear communication, patience, and support from both families.',
      ),
      AboutTemplateSuggestion(
        label: _t('Career with balance', 'Career balance'),
        text:
            'I take responsibilities seriously and like keeping a healthy balance between work, family, and personal growth. I value honesty and steady understanding.',
      ),
      AboutTemplateSuggestion(
        label: _t('Tradition & open mind', 'परंपरा आणि विचार'),
        text:
            'I respect traditions while staying open to practical modern thinking. I am looking for a relationship built on trust, kindness, and shared decisions.',
      ),
    ];
  }

  String? _choiceLabel(List<_FamilyChoice> options, String? key) {
    if (key == null) return null;
    for (final option in options) {
      if (option.key == key) return option.label(widget.locale);
    }
    return null;
  }

  String _suggestionText(AboutTemplateSuggestion suggestion) {
    final additions = <String>[];
    final status = _choiceLabel(_statusOptions, _familyStatus);
    final values = _choiceLabel(_valueOptions, _familyValues);
    if (status != null) {
      additions.add('Family background is $status.');
    }
    if (values != null) {
      additions.add('Family values are $values.');
    }
    return [
      ...<String>[suggestion.text],
      ...additions,
    ].join(' ').trim();
  }

  void _applySuggestion(int index) {
    final suggestions = _aboutSuggestions;
    if (index < 0 || index >= suggestions.length) return;
    setState(() {
      _selectedSuggestionIndex = index;
      _aboutController.text = _suggestionText(suggestions[index]);
      _localError = null;
    });
  }

  void _maybePrefillAboutFromSuggestion() {
    final suggestions = _aboutSuggestions;
    final selectedIndex = _selectedSuggestionIndex;
    if (selectedIndex != null &&
        selectedIndex >= 0 &&
        selectedIndex < suggestions.length) {
      _aboutController.text = _suggestionText(suggestions[selectedIndex]);
      _localError = null;
      return;
    }
    if (_aboutController.text.trim().isNotEmpty || suggestions.isEmpty) {
      return;
    }
    _selectedSuggestionIndex = 0;
    _aboutController.text = _suggestionText(suggestions.first);
    _localError = null;
  }

  Future<void> _loadFamilyOptions() async {
    setState(() {
      _optionsLoading = true;
    });
    try {
      final results = await ApiClient.getProfileRemainingProfileOptions();
      if (!mounted) return;
      final statuses = _FamilyChoice.listFrom(
        results['family_statuses'],
        fallback: _FamilyChoice.fallbackStatuses,
      );
      final values = _FamilyChoice.listFrom(
        results['family_values'],
        fallback: _FamilyChoice.fallbackValues,
      );
      setState(() {
        _statusOptions = statuses;
        _valueOptions = values;
        _optionsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _optionsLoading = false;
      });
    }
  }

  Future<void> _save() async {
    final about = _aboutController.text.trim();
    if (_familyStatus == null || about.isEmpty) {
      setState(() {
        _localError = _t(
          'Select family status and write a short about section.',
          'कुटुंब स्थिती निवडा आणि थोडक्यात स्वतःबद्दल लिहा.',
        );
      });
      return;
    }

    setState(() {
      _localError = null;
    });

    await widget.onSaveFamilyAbout(
      compactPayload({
        'family_status': _familyStatus,
        'family_values': _familyValues,
      }),
      about,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: _t('Family and about', 'कुटुंब आणि ओळख'),
      subtitle: _t(
        'One final profile detail helps families understand the match better.',
        'शेवटची ही माहिती योग्य स्थळे सुचवण्यासाठी उपयोगी पडते.',
      ),
      loading: widget.loading,
      continueEnabled: _canContinue,
      onBack: widget.onBack,
      onContinue: _save,
      continueLabel: _t('Complete registration', 'नोंदणी पूर्ण करा'),
      children: [
        _FamilyPanel(
          title: _t('Family status', 'कुटुंब स्थिती'),
          subtitle: _t('Required', 'आवश्यक'),
          trailing: _optionsLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          child: _ChoiceWrap(
            options: _statusOptions,
            selectedKey: _familyStatus,
            locale: widget.locale,
            onChanged: widget.loading
                ? null
                : (key) => setState(() {
                    _familyStatus = key;
                    _localError = null;
                    _maybePrefillAboutFromSuggestion();
                  }),
          ),
        ),
        const SizedBox(height: 14),
        _FamilyPanel(
          title: _t('Family values', 'कुटुंब मूल्ये'),
          subtitle: _t(
            'Optional, but useful for better suggestions',
            'Optional',
          ),
          child: _ChoiceWrap(
            options: _valueOptions,
            selectedKey: _familyValues,
            locale: widget.locale,
            onChanged: widget.loading
                ? null
                : (key) => setState(() {
                    _familyValues = _familyValues == key ? null : key;
                    _localError = null;
                    _maybePrefillAboutFromSuggestion();
                  }),
          ),
        ),
        const SizedBox(height: 14),
        _FamilyPanel(
          title: _t('About profile', 'प्रोफाइलबद्दल'),
          subtitle: _t('Required', 'आवश्यक'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AboutSuggestionChips(
                suggestions: _aboutSuggestions,
                selectedIndex: _selectedSuggestionIndex,
                onSelected: widget.loading ? null : _applySuggestion,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _aboutController,
                enabled: !widget.loading,
                minLines: 4,
                maxLines: 7,
                maxLength: 500,
                textInputAction: TextInputAction.newline,
                onChanged: (_) => setState(() {
                  _selectedSuggestionIndex = null;
                  _localError = null;
                }),
                decoration: InputDecoration(
                  hintText: _t(
                    'Write a natural introduction, family background, and what makes this profile easy to understand.',
                    'स्वभाव, कुटुंब पार्श्वभूमी आणि profile समजायला मदत होईल अशी थोडक्यात माहिती लिहा.',
                  ),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        if (_localError != null) ...[
          const SizedBox(height: 10),
          Text(
            _localError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _FamilyChoice {
  const _FamilyChoice({
    required this.key,
    required this.labelEn,
    required this.labelMr,
  });

  final String key;
  final String labelEn;
  final String labelMr;

  String label(String locale) => locale == 'mr' ? labelMr : labelEn;

  static const List<_FamilyChoice> fallbackStatuses = <_FamilyChoice>[
    _FamilyChoice(key: 'simple', labelEn: 'Simple', labelMr: 'साधे'),
    _FamilyChoice(
      key: 'middle_class',
      labelEn: 'Middle Class',
      labelMr: 'मध्यम वर्ग',
    ),
    _FamilyChoice(
      key: 'upper_middle_class',
      labelEn: 'Upper Middle Class',
      labelMr: 'उच्च मध्यम वर्ग',
    ),
    _FamilyChoice(key: 'affluent', labelEn: 'Affluent', labelMr: 'सधन'),
  ];

  static const List<_FamilyChoice> fallbackValues = <_FamilyChoice>[
    _FamilyChoice(
      key: 'traditional',
      labelEn: 'Traditional',
      labelMr: 'परंपरागत',
    ),
    _FamilyChoice(key: 'moderate', labelEn: 'Moderate', labelMr: 'मध्यम'),
    _FamilyChoice(key: 'modern', labelEn: 'Modern', labelMr: 'आधुनिक'),
  ];

  static List<_FamilyChoice> listFrom(
    dynamic value, {
    required List<_FamilyChoice> fallback,
  }) {
    if (value is! List) return fallback;
    final rows = value
        .whereType<Map>()
        .map((row) => _FamilyChoice.fromMap(Map<String, dynamic>.from(row)))
        .whereType<_FamilyChoice>()
        .toList();
    return rows.isEmpty ? fallback : rows;
  }

  static _FamilyChoice? fromMap(Map<String, dynamic> row) {
    final key =
        onboardingText(row['key']) ??
        onboardingText(row['value']) ??
        onboardingText(row['slug']);
    if (key == null) return null;
    final label =
        onboardingText(row['label']) ??
        onboardingText(row['name']) ??
        onboardingText(row['display_label']) ??
        key;
    final labelMr =
        onboardingText(row['label_mr']) ??
        onboardingText(row['name_mr']) ??
        label;
    return _FamilyChoice(key: key, labelEn: label, labelMr: labelMr);
  }
}

class _FamilyPanel extends StatelessWidget {
  const _FamilyPanel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({
    required this.options,
    required this.selectedKey,
    required this.locale,
    required this.onChanged,
  });

  final List<_FamilyChoice> options;
  final String? selectedKey;
  final String locale;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 280
            ? (constraints.maxWidth - 8) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => SizedBox(
                  width: itemWidth,
                  child: OnboardingSelectablePill(
                    label: option.label(locale),
                    selected: selectedKey == option.key,
                    onTap: onChanged == null
                        ? null
                        : () => onChanged!(option.key),
                    minHeight: 48,
                    maxLines: 2,
                    horizontalPadding: 10,
                    verticalPadding: 10,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _AboutSuggestionChips extends StatelessWidget {
  const _AboutSuggestionChips({
    required this.suggestions,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<AboutTemplateSuggestion> suggestions;
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 320
            ? (constraints.maxWidth - 8) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < suggestions.length; i++)
              SizedBox(
                width: itemWidth,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onSelected == null ? null : () => onSelected!(i),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selectedIndex == i
                          ? onboardingSelectedGreen.withValues(alpha: 0.12)
                          : colors.surfaceContainerHighest.withValues(
                              alpha: 0.55,
                            ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selectedIndex == i
                            ? onboardingSelectedGreen
                            : colors.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_outlined,
                            size: 16,
                            color: selectedIndex == i
                                ? onboardingSelectedGreen
                                : colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              suggestions[i].label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selectedIndex == i
                                    ? onboardingSelectedGreen
                                    : colors.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
