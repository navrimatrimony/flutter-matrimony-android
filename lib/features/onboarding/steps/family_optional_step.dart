import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../about_voice_ssot.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';
import '../../../core/app_language.dart';

typedef FamilyAboutStepSaver =
    Future<bool> Function(Map<String, dynamic> familyData, String aboutText);

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
    this.aboutVoice,
  });

  final Map<String, dynamic> data;
  final String? initialAbout;
  final List<AboutTemplateSuggestion> aboutSuggestions;
  final String locale;
  final bool loading;
  final FamilyAboutStepSaver onSaveFamilyAbout;
  final VoidCallback onBack;
  final AboutVoice? aboutVoice;

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
  int? _selectedSuggestionIndex;

  /// Set the moment the member touches anything on this step. Same guard
  /// `MaritalStatusStep` uses: once there is a human choice on screen, no
  /// incoming prop change may overwrite it. Props here are draft/server state,
  /// which is by definition older than the tap that has not been saved yet.
  bool _edited = false;

  @override
  void initState() {
    super.initState();
    _prefill();
    _loadFamilyOptions();
  }

  @override
  void didUpdateWidget(covariant FamilyOptionalStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_edited) return;
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


  void _prefill() {
    _familyStatus = onboardingText(widget.data['family_status']);
    _familyValues = onboardingText(widget.data['family_values']);
    final about = widget.initialAbout?.trim();
    // Optional step: never auto-pick a suggestion chip. Only restore saved text.
    if (about != null && about.isNotEmpty && _aboutController.text.isEmpty) {
      _aboutController.text = about;
    }
    _selectedSuggestionIndex = null;
  }

  List<AboutTemplateSuggestion> get _aboutSuggestions {
    if (widget.aboutSuggestions.isNotEmpty) return widget.aboutSuggestions;
    return widget.aboutVoice?.templates(factText: '') ??
        <AboutTemplateSuggestion>[
          AboutTemplateSuggestion(
            label: appText.simpleFamilyFirst2,
            text: appText.aboutFamilyTemplateFamilyFirstBody,
          ),
          AboutTemplateSuggestion(
            label: appText.careerWithBalance2,
            text: appText.aboutFamilyTemplateCareerBalanceBody,
          ),
          AboutTemplateSuggestion(
            label: appText.traditionOpenMind2,
            text: appText.aboutFamilyTemplateTraditionBody,
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
    final voice = widget.aboutVoice;
    if (status != null) {
      additions.add(
        voice?.familyBackgroundFact(status) ??
            appText.aboutFactFamilyBackground(status),
      );
    }
    if (values != null) {
      additions.add(
        voice?.familyValuesFact(values) ??
            appText.aboutFactFamilyValues(values),
      );
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
      _edited = true;
      _selectedSuggestionIndex = index;
      _aboutController.text = _suggestionText(suggestions[index]);
    });
  }

  void _maybePrefillAboutFromSuggestion() {
    final suggestions = _aboutSuggestions;
    final selectedIndex = _selectedSuggestionIndex;
    // Only refresh composed text when a chip is already chosen — never auto-select.
    if (selectedIndex != null &&
        selectedIndex >= 0 &&
        selectedIndex < suggestions.length) {
      _aboutController.text = _suggestionText(suggestions[selectedIndex]);
    }
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

  /// This step never blocks Continue.
  ///
  /// `SMART_ONBOARDING_BLUEPRINT.md` §11 marks Family Optional as optional —
  /// "These fields should not block onboarding" — and its Required Fields
  /// Policy forbids Flutter from hardcoding activation-required fields. The
  /// server says the same thing independently: every key of the `family` step
  /// is `sometimes|nullable` in `MobileProfileStepSnapshotService`, and
  /// `narrative_about_me` is not required to create a profile.
  ///
  /// So there is no client-side validator here on purpose. Making the step
  /// skippable must not become "skip the save": whatever the member did fill
  /// is still handed up exactly as before, and only the genuinely empty case
  /// travels as an empty payload.
  Future<void> _save() async {
    await widget.onSaveFamilyAbout(
      compactPayload({
        'family_status': _familyStatus,
        'family_values': _familyValues,
      }),
      _aboutController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: appText.familyAndAbout,
      // Said once, at the top. It used to sit under all three panels, and the
      // step still read like a form that had to be finished.
      subtitle: appText.lifestyleAllOptional,
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: _save,
      continueLabel: appText.continueLabel,
      children: [
        // Status and values share one box because they are not independent:
        // both feed the introduction underneath. Shown apart, that connection
        // was invisible, and answering them looked like unrelated work.
        _FamilyPanel(
          title: appText.familyStatus,
          accent: true,
          footnote: appText.familyFeedsAbout,
          trailing: _optionsLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChoiceWrap(
                options: _statusOptions,
                selectedKey: _familyStatus,
                locale: widget.locale,
                onChanged: widget.loading
                    ? null
                    : (key) => setState(() {
                        _edited = true;
                        _familyStatus = key;
                        _maybePrefillAboutFromSuggestion();
                      }),
              ),
              const SizedBox(height: 10),
              Text(
                appText.familyValues,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: 6),
              _ChoiceWrap(
                options: _valueOptions,
                selectedKey: _familyValues,
                locale: widget.locale,
                onChanged: widget.loading
                    ? null
                    : (key) => setState(() {
                        _edited = true;
                        _familyValues = _familyValues == key ? null : key;
                        _maybePrefillAboutFromSuggestion();
                      }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _FamilyPanel(
          title: appText.aboutProfile,
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
                minLines: 3,
                maxLines: 5,
                maxLength: 500,
                textInputAction: TextInputAction.newline,
                onChanged: (_) => setState(() {
                  _edited = true;
                  _selectedSuggestionIndex = null;
                }),
                decoration: InputDecoration(
                  hintText: appText.writeANaturalIntroductionFamilyBackground,
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
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
    required this.child,
    this.trailing,
    this.accent = false,
    this.footnote,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  /// Marks the box whose answers feed something else on the screen.
  final bool accent;

  /// One line under the box saying what those answers do.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent ? Colors.blue.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent
                          ? Colors.blue.shade800
                          : Colors.grey.shade900,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 6),
            child,
            if (footnote != null) ...[
              const SizedBox(height: 8),
              Text(
                footnote!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.blue.shade700,
                ),
              ),
            ],
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
        // Each pill takes the width of its own label instead of half the
        // row, so four short answers use one or two lines rather than four.
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: options
              .map(
                (option) => OnboardingSelectablePill(
                  label: option.label(locale),
                  selected: selectedKey == option.key,
                  onTap: onChanged == null ? null : () => onChanged!(option.key),
                  minHeight: 36,
                  fontSize: 13,
                  maxLines: 1,
                  horizontalPadding: 12,
                  verticalPadding: 6,
                  // Match about-suggestion chips (square-ish), not pill ovals.
                  cornerRadius: 8,
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
        // Three across, so six templates make two even rows instead of three
        // uneven ones. Falls back to two columns on a narrow phone, where three
        // would cut the labels.
        final columns = constraints.maxWidth >= 340 ? 3 : 2;
        final spacing = 6.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 6,
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
                        horizontal: 8,
                        vertical: 7,
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
