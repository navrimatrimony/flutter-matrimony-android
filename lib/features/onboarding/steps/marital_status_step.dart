import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/onboarding_option.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';

class MaritalStatusStep extends StatefulWidget {
  const MaritalStatusStep({
    super.key,
    required this.title,
    required this.data,
    required this.maritalStatuses,
    required this.childrenRules,
    required this.childLivingWithOptions,
    required this.childLivingWithLoading,
    required this.childLivingWithError,
    required this.profileForWhom,
    required this.gender,
    required this.fieldErrors,
    required this.locale,
    required this.loading,
    required this.onSave,
    required this.onBack,
    required this.onMessage,
    required this.onRetryLookups,
    required this.onFieldEdited,
  });

  final String title;
  final Map<String, dynamic> data;
  final List<OnboardingOption> maritalStatuses;
  final Map<String, dynamic> childrenRules;
  final List<OnboardingOption> childLivingWithOptions;
  final bool childLivingWithLoading;
  final String? childLivingWithError;
  final OnboardingOption? profileForWhom;
  final OnboardingOption? gender;
  final Map<String, String> fieldErrors;
  final String locale;
  final bool loading;
  final Future<bool> Function(Map<String, dynamic> payload) onSave;
  final VoidCallback onBack;
  final ValueChanged<String> onMessage;
  final Future<void> Function() onRetryLookups;
  final VoidCallback onFieldEdited;

  @override
  State<MaritalStatusStep> createState() => _MaritalStatusStepState();
}

class _ChildDetailRow {
  _ChildDetailRow({
    this.id,
    String? childName,
    this.gender,
    String? age,
    this.childLivingWithId,
    this.expanded = true,
    bool? nameVisible,
  }) : nameVisible = nameVisible ?? (childName?.trim().isNotEmpty ?? false),
       nameController = TextEditingController(text: childName ?? ''),
       ageController = TextEditingController(text: age ?? '');

  int? id;
  String? gender;
  int? childLivingWithId;
  bool expanded;
  bool nameVisible;
  final TextEditingController nameController;
  final TextEditingController ageController;

  bool get hasAnyInput {
    return nameController.text.trim().isNotEmpty ||
        (gender?.trim().isNotEmpty ?? false) ||
        ageController.text.trim().isNotEmpty ||
        childLivingWithId != null;
  }

  int? get age {
    final text = ageController.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  Map<String, dynamic> toPayload(int index) {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'child_name': _stringOrNull(nameController.text),
      'gender': _stringOrNull(gender),
      'age': age,
      'child_living_with_id': childLivingWithId,
      'sort_order': index,
    };
  }

  void dispose() {
    nameController.dispose();
    ageController.dispose();
  }

  static String? _stringOrNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class _MaritalStatusStepState extends State<MaritalStatusStep>
    with TickerProviderStateMixin {
  OnboardingOption? _selected;
  bool _hasChildren = false;
  bool _edited = false;
  bool _selectionError = false;
  String? _childrenError;
  final List<_ChildDetailRow> _childRows = <_ChildDetailRow>[];
  final Map<int, Map<String, String>> _childRowErrors =
      <int, Map<String, String>>{};

  bool get _mr => widget.locale == 'mr';

  @override
  void initState() {
    super.initState();
    _prefill(force: true);
  }

  @override
  void didUpdateWidget(covariant MaritalStatusStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_edited) return;
    if (!mapEquals(oldWidget.data, widget.data) ||
        !listEquals(oldWidget.maritalStatuses, widget.maritalStatuses) ||
        !listEquals(
          oldWidget.childLivingWithOptions,
          widget.childLivingWithOptions,
        )) {
      _prefill(force: false);
    }
  }

  @override
  void dispose() {
    _disposeChildRows();
    super.dispose();
  }

  void _prefill({required bool force}) {
    final selectedId = onboardingInt(widget.data['marital_status_id']);
    final selectedOption =
        optionById(widget.maritalStatuses, selectedId) ??
        optionByKey(widget.maritalStatuses, widget.data['marital_status_key']);
    final incoming =
        selectedOption ??
        (widget.maritalStatuses.isEmpty
            ? optionFromData(widget.data['marital_status_option'])
            : null);
    if (!force && incoming == null) return;

    _selected = incoming;
    _hasChildren = _showsChildrenQuestion(incoming)
        ? (onboardingBool(widget.data['has_children']) ?? false)
        : false;
    _prefillChildren();
    if (_hasChildren && _childRows.isEmpty) {
      _addChildRow(expanded: true);
    }
  }

  void _prefillChildren() {
    _disposeChildRows();
    final rows = widget.data['children'];
    if (rows is! List) return;

    for (final item in rows) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      _childRows.add(
        _ChildDetailRow(
          id: onboardingInt(row['id']),
          childName: onboardingText(row['child_name']),
          gender: _readChildGender(row['gender']),
          age: onboardingText(row['age']),
          childLivingWithId: onboardingInt(row['child_living_with_id']),
          expanded: _childRows.isEmpty,
        ),
      );
    }
    if (!_hasChildren && _childRows.isNotEmpty) {
      _hasChildren = true;
    }
  }

  void _disposeChildRows() {
    for (final row in _childRows) {
      row.dispose();
    }
    _childRows.clear();
  }

  void _addChildRow({bool expanded = true}) {
    _childRows.add(_ChildDetailRow(expanded: expanded));
  }

  String _t(String english, String marathi) => _mr ? marathi : english;

  String _key(OnboardingOption? option) =>
      option?.key?.trim().toLowerCase() ?? '';

  String? _readChildGender(dynamic value) {
    final text = onboardingText(value)?.toLowerCase();
    if (text == null) return null;
    return _childGenderValues.contains(text) ? text : null;
  }

  static const List<String> _childGenderValues = <String>['male', 'female'];

  String _childGenderLabel(String value) {
    return switch (value) {
      'male' => _t('Male', 'पुरुष'),
      'female' => _t('Female', 'स्त्री'),
      _ => value,
    };
  }

  String? _childGenderSummary(String? value) {
    final text = _readChildGender(value);
    return text == null ? null : _childGenderLabel(text);
  }

  OnboardingOption? _childLivingWithOption(int? id) {
    return optionById(widget.childLivingWithOptions, id);
  }

  String? _childLivingWithLabel(int? id) {
    if (id == null) return null;
    return _childLivingWithOption(id)?.label;
  }

  String _childRowSummary(int index, _ChildDetailRow row) {
    final parts = <String>[_t('Child ${index + 1}', 'मूल ${index + 1}')];
    final gender = _childGenderSummary(row.gender);
    if (gender != null) parts.add(gender);
    final age = row.age;
    if (age != null) {
      parts.add(_t('$age yrs', '$age वर्षे'));
    }
    final livingWith = _childLivingWithLabel(row.childLivingWithId);
    if (livingWith != null) parts.add(livingWith);
    return parts.join(' · ');
  }

  bool _isNeverMarried(OnboardingOption? option) {
    final key = _key(option);
    return key == 'never_married' || key == 'unmarried';
  }

  bool _showsChildrenQuestion(OnboardingOption? option) {
    final key = _key(option);
    if (key.isEmpty || _isNeverMarried(option)) return false;

    final configured = widget.childrenRules['show_for_keys'];
    final keys = configured is List
        ? configured
              .map((value) => value?.toString().trim().toLowerCase())
              .whereType<String>()
              .where((value) => value.isNotEmpty)
              .toSet()
        : <String>{'divorced', 'annulled', 'separated', 'widowed'};

    return keys.contains(key);
  }

  String _genderKey() {
    final key = widget.gender?.key?.trim().toLowerCase();
    if (key == 'male' || key == 'female') return key!;

    final label = widget.gender?.label.trim().toLowerCase() ?? '';
    if (label.contains('female') ||
        label.contains('स्त्री') ||
        label.contains('महिला') ||
        label.contains('मुलगी') ||
        label.contains('वधू')) {
      return 'female';
    }
    if (label.contains('male') ||
        label.contains('पुरुष') ||
        label.contains('मुलगा') ||
        label.contains('वर')) {
      return 'male';
    }
    return '';
  }

  String _labelFor(OnboardingOption option) {
    if (_mr && _key(option) == 'widowed') {
      final gender = _genderKey();
      if (gender == 'male') return 'विधुर';
      if (gender == 'female') return 'विधवा';
    }
    return option.label;
  }

  List<OnboardingOption> get _options {
    return widget.maritalStatuses
        .where((option) => option.intId != null && _key(option).isNotEmpty)
        .toList();
  }

  OnboardingOption? get _neverMarried {
    for (final option in _options) {
      if (_isNeverMarried(option)) return option;
    }
    return null;
  }

  List<OnboardingOption> get _otherOptions {
    return _options.where((option) => !_isNeverMarried(option)).toList();
  }

  void _select(OnboardingOption option) {
    setState(() {
      _edited = true;
      _selected = option;
      _selectionError = false;
      _childrenError = null;
      _childRowErrors.clear();
      if (!_showsChildrenQuestion(option)) {
        _hasChildren = false;
        _disposeChildRows();
      }
    });
    widget.onFieldEdited();
  }

  void _setHasChildren(bool value) {
    setState(() {
      _edited = true;
      _hasChildren = value;
      _childrenError = null;
      _childRowErrors.clear();
      if (value && _childRows.isEmpty) {
        _addChildRow(expanded: true);
      }
    });
    widget.onFieldEdited();
  }

  bool _validateChildren() {
    _childrenError = null;
    _childRowErrors.clear();

    if (!_hasChildren) return true;
    if (_childRows.isEmpty) {
      _addChildRow(expanded: true);
    }

    var validRows = 0;
    for (var index = 0; index < _childRows.length; index++) {
      final row = _childRows[index];
      if (!row.hasAnyInput && _childRows.length > 1) continue;

      final rowErrors = <String, String>{};
      if (_readChildGender(row.gender) == null) {
        rowErrors['gender'] = _t(
          'Select child gender.',
          'मुलाचे/मुलीचे लिंग निवडा.',
        );
      }

      final age = row.age;
      if (age == null || age < 1 || age > 30) {
        rowErrors['age'] = _t(
          'Select age between 1 and 30.',
          'वय 1 ते 30 मध्ये निवडा.',
        );
      }

      if (rowErrors.isEmpty) {
        validRows++;
      } else {
        row.expanded = true;
        _childRowErrors[index] = rowErrors;
      }
    }

    if (validRows == 0 && _childRowErrors.isEmpty) {
      _childRows.first.expanded = true;
      _childRowErrors[0] = <String, String>{
        'gender': _t('Select child gender.', 'मुलाचे/मुलीचे लिंग निवडा.'),
        'age': _t('Enter child age.', 'मुलाचे/मुलीचे वय भरा.'),
      };
    }

    if (_childRowErrors.isNotEmpty) {
      _childrenError = _t(
        'Complete at least one child detail.',
        'किमान एका मुलाची माहिती पूर्ण भरा.',
      );
      return false;
    }

    return true;
  }

  List<Map<String, dynamic>> _childPayloadRows() {
    final rows = <Map<String, dynamic>>[];
    for (final row in _childRows) {
      if (!row.hasAnyInput) continue;
      rows.add(row.toPayload(rows.length));
    }
    return rows;
  }

  int? _firstChildLivingWithId(List<Map<String, dynamic>> children) {
    for (final row in children) {
      final id = onboardingInt(row['child_living_with_id']);
      if (id != null) return id;
    }
    return null;
  }

  Future<void> _continue() async {
    final selected = _selected;
    if (selected == null || selected.intId == null) {
      setState(() => _selectionError = true);
      widget.onMessage(_t('Select marital status.', 'वैवाहिक स्थिती निवडा.'));
      return;
    }

    final showChildren = _showsChildrenQuestion(selected);
    final hasChildren = showChildren ? _hasChildren : false;
    if (hasChildren && !_validateChildren()) {
      setState(() {});
      widget.onMessage(
        _t(
          'Complete child details before continuing.',
          'पुढे जाण्यापूर्वी मुलांची माहिती पूर्ण भरा.',
        ),
      );
      return;
    }

    final children = hasChildren
        ? _childPayloadRows()
        : const <Map<String, dynamic>>[];
    final firstLivingWithId = _firstChildLivingWithId(children);
    final firstLivingWithLabel = _childLivingWithLabel(firstLivingWithId);
    final payload = <String, dynamic>{
      'marital_status_id': selected.intId,
      'marital_status_option': selected.toJson(),
      if (widget.gender?.intId != null) 'gender_id': widget.gender!.intId,
      'has_children': hasChildren,
      if (hasChildren) ...<String, dynamic>{
        'children': children,
        'children_count': children.length,
        'children_living_with': firstLivingWithLabel,
        'children_living_with_id': firstLivingWithId,
      } else ...<String, dynamic>{
        'children': <dynamic>[],
        'children_count': null,
        'children_living_with': null,
        'children_living_with_id': null,
      },
    };

    await widget.onSave(payload);
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final selected = _selected;
    final showChildren = _showsChildrenQuestion(selected);
    final maritalError =
        widget.fieldErrors['marital_status_id'] ??
        (_selectionError
            ? _t('Select marital status.', 'वैवाहिक स्थिती निवडा.')
            : null);
    final childrenError =
        widget.fieldErrors['has_children'] ??
        widget.fieldErrors['children'] ??
        _childrenError;

    return OnboardingStepScaffold(
      title: widget.title,
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: _continue,
      continueEnabled: selected != null && options.isNotEmpty,
      continueLabel: _t('Continue', 'पुढे जा'),
      children: [
        if (options.isEmpty)
          widget.loading
              ? const _MaritalStatusSkeleton()
              : _LookupFailure(
                  message: _t(
                    'Marital status options could not be loaded.',
                    'वैवाहिक स्थितीचे पर्याय लोड झाले नाहीत.',
                  ),
                  retryLabel: _t('Retry', 'पुन्हा प्रयत्न करा'),
                  onRetry: widget.onRetryLookups,
                )
        else ...[
          if (_neverMarried != null)
            _MaritalOptionCard(
              label: _labelFor(_neverMarried!),
              selected: selected?.identity == _neverMarried!.identity,
              prominent: true,
              onTap: () => _select(_neverMarried!),
            ),
          if (_otherOptions.isNotEmpty) ...[
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 10.0;
                final width = (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: _otherOptions
                      .map(
                        (option) => SizedBox(
                          width: width,
                          child: _MaritalOptionCard(
                            label: _labelFor(option),
                            selected: selected?.identity == option.identity,
                            onTap: () => _select(option),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
          if (maritalError != null) ...[
            const SizedBox(height: 8),
            _InlineError(text: maritalError),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 210),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: showChildren
                ? Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: showChildren ? 1 : 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _t('Children?', 'मुलं आहेत का?'),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          _YesNoSegment(
                            yesSelected: _hasChildren,
                            yesLabel: _t('Yes', 'हो'),
                            noLabel: _t('No', 'नाही'),
                            onChanged: _setHasChildren,
                          ),
                          if (childrenError != null) ...[
                            const SizedBox(height: 8),
                            _InlineError(text: childrenError),
                          ],
                          AnimatedSize(
                            duration: const Duration(milliseconds: 210),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: _hasChildren
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: _ChildrenDetailsPanel(
                                      rows: _childRows,
                                      rowErrors: _childRowErrors,
                                      fieldErrors: widget.fieldErrors,
                                      childGenderValues: _childGenderValues,
                                      childLivingWithOptions:
                                          widget.childLivingWithOptions,
                                      childLivingWithLoading:
                                          widget.childLivingWithLoading,
                                      childLivingWithError:
                                          widget.childLivingWithError,
                                      addLabel: _t('Add child', 'मूल जोडा'),
                                      addNameLabel: _t('Add name', 'नाव जोडा'),
                                      ageLabel: _t('Age', 'वय'),
                                      genderLabel: _t('Gender', 'लिंग'),
                                      livingWithLabel: _t(
                                        'Living with',
                                        'कोणासोबत राहते',
                                      ),
                                      nameLabel: _t(
                                        'Child name',
                                        'मुलाचे/मुलीचे नाव',
                                      ),
                                      optionalLabel: _t('Optional', 'ऐच्छिक'),
                                      loadingLabel: _t(
                                        'Loading...',
                                        'लोड होत आहे...',
                                      ),
                                      lessThanOneLabel: _t('<1', '<1'),
                                      retryLabel: _t(
                                        'Retry',
                                        'पुन्हा प्रयत्न करा',
                                      ),
                                      optionsUnavailableLabel: _t(
                                        'Living-with options unavailable.',
                                        'कोणासोबत राहते याचे पर्याय उपलब्ध नाहीत.',
                                      ),
                                      summaryBuilder: _childRowSummary,
                                      genderLabelBuilder: _childGenderLabel,
                                      livingWithLabelBuilder:
                                          _childLivingWithLabel,
                                      onRetry: widget.onRetryLookups,
                                      onUnsupportedInfantAge: () {
                                        widget.onMessage(
                                          _t(
                                            'Less than 1 year is not supported by the current save rules. Select 1 year for now.',
                                            'सध्याच्या save rules मध्ये 1 वर्षापेक्षा कमी वय support नाही. आत्ता 1 वर्ष निवडा.',
                                          ),
                                        );
                                      },
                                      onChanged: () {
                                        setState(() {
                                          _edited = true;
                                          _childrenError = null;
                                          _childRowErrors.clear();
                                        });
                                        widget.onFieldEdited();
                                      },
                                      onAdd: () {
                                        setState(() {
                                          _edited = true;
                                          _addChildRow(expanded: true);
                                          _childrenError = null;
                                          _childRowErrors.clear();
                                        });
                                        widget.onFieldEdited();
                                      },
                                      onRemove: (index) {
                                        setState(() {
                                          _edited = true;
                                          final removed = _childRows.removeAt(
                                            index,
                                          );
                                          removed.dispose();
                                          _childrenError = null;
                                          _childRowErrors.clear();
                                          if (_childRows.isEmpty) {
                                            _addChildRow(expanded: true);
                                          }
                                        });
                                        widget.onFieldEdited();
                                      },
                                      onToggleExpanded: (index) {
                                        setState(() {
                                          _childRows[index].expanded =
                                              !_childRows[index].expanded;
                                        });
                                      },
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

class _MaritalOptionCard extends StatelessWidget {
  const _MaritalOptionCard({
    required this.label,
    required this.selected,
    required this.onTap,
    this.prominent = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return OnboardingSelectablePill(
      label: label,
      selected: selected,
      onTap: onTap,
      prominent: prominent,
      minHeight: prominent ? 56 : 52,
      maxLines: 2,
      horizontalPadding: prominent ? 16 : 10,
      verticalPadding: prominent ? 14 : 12,
    );
  }
}

class _YesNoSegment extends StatelessWidget {
  const _YesNoSegment({
    required this.yesSelected,
    required this.yesLabel,
    required this.noLabel,
    required this.onChanged,
  });

  final bool yesSelected;
  final String yesLabel;
  final String noLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: noLabel,
              selected: !yesSelected,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: yesLabel,
              selected: yesSelected,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OnboardingSelectablePill(
      label: label,
      selected: selected,
      onTap: onTap,
      minHeight: 40,
      horizontalPadding: 10,
      verticalPadding: 8,
    );
  }
}

class _ChildrenDetailsPanel extends StatelessWidget {
  const _ChildrenDetailsPanel({
    required this.rows,
    required this.rowErrors,
    required this.fieldErrors,
    required this.childGenderValues,
    required this.childLivingWithOptions,
    required this.childLivingWithLoading,
    required this.childLivingWithError,
    required this.addLabel,
    required this.addNameLabel,
    required this.ageLabel,
    required this.genderLabel,
    required this.livingWithLabel,
    required this.nameLabel,
    required this.optionalLabel,
    required this.loadingLabel,
    required this.lessThanOneLabel,
    required this.retryLabel,
    required this.optionsUnavailableLabel,
    required this.summaryBuilder,
    required this.genderLabelBuilder,
    required this.livingWithLabelBuilder,
    required this.onRetry,
    required this.onUnsupportedInfantAge,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
    required this.onToggleExpanded,
  });

  final List<_ChildDetailRow> rows;
  final Map<int, Map<String, String>> rowErrors;
  final Map<String, String> fieldErrors;
  final List<String> childGenderValues;
  final List<OnboardingOption> childLivingWithOptions;
  final bool childLivingWithLoading;
  final String? childLivingWithError;
  final String addLabel;
  final String addNameLabel;
  final String ageLabel;
  final String genderLabel;
  final String livingWithLabel;
  final String nameLabel;
  final String optionalLabel;
  final String loadingLabel;
  final String lessThanOneLabel;
  final String retryLabel;
  final String optionsUnavailableLabel;
  final String Function(int index, _ChildDetailRow row) summaryBuilder;
  final String Function(String value) genderLabelBuilder;
  final String? Function(int? id) livingWithLabelBuilder;
  final Future<void> Function() onRetry;
  final VoidCallback onUnsupportedInfantAge;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onToggleExpanded;

  String? _fieldError(int index, String field) {
    return rowErrors[index]?[field] ?? fieldErrors['children.$index.$field'];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _ChildDetailCard(
              row: rows[index],
              canRemove: rows.length > 1,
              summary: summaryBuilder(index, rows[index]),
              genderValues: childGenderValues,
              livingWithOptions: childLivingWithOptions,
              childLivingWithLoading: childLivingWithLoading,
              childLivingWithError: childLivingWithError,
              addNameLabel: addNameLabel,
              ageLabel: ageLabel,
              genderLabel: genderLabel,
              livingWithLabel: livingWithLabel,
              nameLabel: nameLabel,
              optionalLabel: optionalLabel,
              loadingLabel: loadingLabel,
              lessThanOneLabel: lessThanOneLabel,
              retryLabel: retryLabel,
              optionsUnavailableLabel: optionsUnavailableLabel,
              genderLabelBuilder: genderLabelBuilder,
              livingWithLabelBuilder: livingWithLabelBuilder,
              genderError: _fieldError(index, 'gender'),
              ageError: _fieldError(index, 'age'),
              livingWithError: _fieldError(index, 'child_living_with_id'),
              onChanged: onChanged,
              onRetry: onRetry,
              onUnsupportedInfantAge: onUnsupportedInfantAge,
              onRemove: () => onRemove(index),
              onToggleExpanded: () => onToggleExpanded(index),
            ),
            if (index != rows.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(addLabel),
              style: TextButton.styleFrom(
                foregroundColor: onboardingSelectedGreen,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildDetailCard extends StatelessWidget {
  const _ChildDetailCard({
    required this.row,
    required this.canRemove,
    required this.summary,
    required this.genderValues,
    required this.livingWithOptions,
    required this.childLivingWithLoading,
    required this.childLivingWithError,
    required this.addNameLabel,
    required this.ageLabel,
    required this.genderLabel,
    required this.livingWithLabel,
    required this.nameLabel,
    required this.optionalLabel,
    required this.loadingLabel,
    required this.lessThanOneLabel,
    required this.retryLabel,
    required this.optionsUnavailableLabel,
    required this.genderLabelBuilder,
    required this.livingWithLabelBuilder,
    required this.genderError,
    required this.ageError,
    required this.livingWithError,
    required this.onChanged,
    required this.onRetry,
    required this.onUnsupportedInfantAge,
    required this.onRemove,
    required this.onToggleExpanded,
  });

  final _ChildDetailRow row;
  final bool canRemove;
  final String summary;
  final List<String> genderValues;
  final List<OnboardingOption> livingWithOptions;
  final bool childLivingWithLoading;
  final String? childLivingWithError;
  final String addNameLabel;
  final String ageLabel;
  final String genderLabel;
  final String livingWithLabel;
  final String nameLabel;
  final String optionalLabel;
  final String loadingLabel;
  final String lessThanOneLabel;
  final String retryLabel;
  final String optionsUnavailableLabel;
  final String Function(String value) genderLabelBuilder;
  final String? Function(int? id) livingWithLabelBuilder;
  final String? genderError;
  final String? ageError;
  final String? livingWithError;
  final VoidCallback onChanged;
  final Future<void> Function() onRetry;
  final VoidCallback onUnsupportedInfantAge;
  final VoidCallback onRemove;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedLivingWithId =
        livingWithOptions.any((option) => option.intId == row.childLivingWithId)
        ? row.childLivingWithId
        : null;
    final seenLivingIds = <int>{};
    final livingOptions = livingWithOptions.where((option) {
      final id = option.intId;
      return id != null && seenLivingIds.add(id);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        summary,
                        maxLines: 1,
                        softWrap: false,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                  if (canRemove)
                    IconButton(
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline, size: 20),
                    ),
                  Icon(
                    row.expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade700,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 160),
            crossFadeState: row.expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FieldLabel(label: genderLabel),
                  const SizedBox(height: 4),
                  _ChildGenderPills(
                    values: genderValues,
                    selectedValue: row.gender,
                    errorText: genderError,
                    labelBuilder: genderLabelBuilder,
                    onChanged: (value) {
                      row.gender = value;
                      onChanged();
                    },
                  ),
                  const SizedBox(height: 10),
                  _FieldLabel(label: ageLabel),
                  const SizedBox(height: 4),
                  _ChildAgePicker(
                    selectedAge: row.age,
                    lessThanOneLabel: lessThanOneLabel,
                    errorText: ageError,
                    onUnsupportedInfantAge: onUnsupportedInfantAge,
                    onChanged: (age) {
                      row.ageController.text = age.toString();
                      onChanged();
                    },
                  ),
                  const SizedBox(height: 10),
                  _FieldLabel(label: livingWithLabel),
                  const SizedBox(height: 4),
                  _ChildLivingWithChips(
                    options: livingOptions,
                    selectedId: selectedLivingWithId,
                    loading: childLivingWithLoading,
                    loadError: childLivingWithError,
                    fieldError: livingWithError,
                    loadingLabel: loadingLabel,
                    retryLabel: retryLabel,
                    optionsUnavailableLabel: optionsUnavailableLabel,
                    onRetry: onRetry,
                    onChanged: (value) {
                      row.childLivingWithId = value;
                      onChanged();
                    },
                  ),
                  if (row.childLivingWithId != null &&
                      selectedLivingWithId == null &&
                      livingWithLabelBuilder(row.childLivingWithId) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        livingWithLabelBuilder(row.childLivingWithId)!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (row.nameVisible)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FieldLabel(label: '$nameLabel ($optionalLabel)'),
                        const SizedBox(height: 4),
                        TextField(
                          controller: row.nameController,
                          textInputAction: TextInputAction.next,
                          decoration: _fieldDecoration(
                            icon: Icons.badge_outlined,
                          ),
                          onChanged: (_) => onChanged(),
                        ),
                      ],
                    )
                  else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          row.nameVisible = true;
                          onChanged();
                        },
                        icon: const Icon(Icons.badge_outlined, size: 18),
                        label: Text('$addNameLabel ($optionalLabel)'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required IconData icon,
    String? errorText,
  }) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 20),
      errorText: errorText,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: const OutlineInputBorder(),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
    );
  }
}

class _ChildGenderPills extends StatelessWidget {
  const _ChildGenderPills({
    required this.values,
    required this.selectedValue,
    required this.errorText,
    required this.labelBuilder,
    required this.onChanged,
  });

  final List<String> values;
  final String? selectedValue;
  final String? errorText;
  final String Function(String value) labelBuilder;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final visibleValues = values
        .where((value) => value == 'male' || value == 'female')
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var index = 0; index < visibleValues.length; index++) ...[
              if (index > 0) const SizedBox(width: 10),
              Expanded(
                child: OnboardingSelectablePill(
                  label: labelBuilder(visibleValues[index]),
                  selected: selectedValue == visibleValues[index],
                  onTap: () => onChanged(visibleValues[index]),
                  minHeight: 44,
                  fontSize: 14,
                  horizontalPadding: 10,
                  verticalPadding: 9,
                ),
              ),
            ],
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 5),
          _InlineError(text: errorText!),
        ],
      ],
    );
  }
}

class _ChildLivingWithChips extends StatelessWidget {
  const _ChildLivingWithChips({
    required this.options,
    required this.selectedId,
    required this.loading,
    required this.loadError,
    required this.fieldError,
    required this.loadingLabel,
    required this.retryLabel,
    required this.optionsUnavailableLabel,
    required this.onRetry,
    required this.onChanged,
  });

  final List<OnboardingOption> options;
  final int? selectedId;
  final bool loading;
  final String? loadError;
  final String? fieldError;
  final String loadingLabel;
  final String retryLabel;
  final String optionsUnavailableLabel;
  final Future<void> Function() onRetry;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loading ? loadingLabel : optionsUnavailableLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (loadError != null)
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(retryLabel),
                  ),
              ],
            ),
          ),
          if (fieldError != null) ...[
            const SizedBox(height: 5),
            _InlineError(text: fieldError!),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (var index = 0; index < options.length; index++) ...[
                _LivingWithChip(
                  label: options[index].label,
                  selected: selectedId == options[index].intId,
                  onTap: () => onChanged(options[index].intId),
                ),
                if (index != options.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        if (fieldError != null) ...[
          const SizedBox(height: 5),
          _InlineError(text: fieldError!),
        ],
      ],
    );
  }
}

class _LivingWithChip extends StatelessWidget {
  const _LivingWithChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OnboardingSelectablePill(
      label: label,
      selected: selected,
      onTap: onTap,
      minHeight: 44,
      maxLines: 1,
      fontSize: 14,
      horizontalPadding: 12,
      verticalPadding: 9,
    );
  }
}

class _ChildAgePicker extends StatelessWidget {
  const _ChildAgePicker({
    required this.selectedAge,
    required this.lessThanOneLabel,
    required this.errorText,
    required this.onUnsupportedInfantAge,
    required this.onChanged,
  });

  static const int _maxAge = 30;

  final int? selectedAge;
  final String lessThanOneLabel;
  final String? errorText;
  final VoidCallback onUnsupportedInfantAge;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _AgeChip(
                label: lessThanOneLabel,
                selected: false,
                muted: true,
                onTap: onUnsupportedInfantAge,
              ),
              const SizedBox(width: 6),
              for (var age = 1; age <= _maxAge; age++) ...[
                _AgeChip(
                  label: age.toString(),
                  selected: selectedAge == age,
                  onTap: () => onChanged(age),
                ),
                if (age != _maxAge) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _AgeChip extends StatelessWidget {
  const _AgeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return OnboardingSelectablePill(
      label: label,
      selected: selected,
      onTap: onTap,
      muted: muted,
      minHeight: 38,
      fontSize: 13,
      horizontalPadding: 12,
      verticalPadding: 8,
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LookupFailure extends StatelessWidget {
  const _LookupFailure({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(retryLabel),
        ),
      ],
    );
  }
}

class _MaritalStatusSkeleton extends StatelessWidget {
  const _MaritalStatusSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SkeletonBar(height: 56, width: double.infinity),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(child: _SkeletonBar(height: 52)),
            SizedBox(width: 10),
            Expanded(child: _SkeletonBar(height: 52)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: const [
            Expanded(child: _SkeletonBar(height: 52)),
            SizedBox(width: 10),
            Expanded(child: _SkeletonBar(height: 52)),
          ],
        ),
      ],
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
