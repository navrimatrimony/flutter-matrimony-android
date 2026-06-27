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

class _MaritalStatusStepState extends State<MaritalStatusStep>
    with TickerProviderStateMixin {
  static const Color _selectedGreen = Color(0xFF0F8F5F);
  static const Color _selectedGreenSurface = Color(0xFFE7F6ED);

  OnboardingOption? _selected;
  bool _hasChildren = false;
  bool _edited = false;
  bool _selectionError = false;

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
        !listEquals(oldWidget.maritalStatuses, widget.maritalStatuses)) {
      _prefill(force: false);
    }
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
  }

  String _t(String english, String marathi) => _mr ? marathi : english;

  String _key(OnboardingOption? option) =>
      option?.key?.trim().toLowerCase() ?? '';

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
      if (!_showsChildrenQuestion(option)) {
        _hasChildren = false;
      }
    });
    widget.onFieldEdited();
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
    final payload = <String, dynamic>{
      'marital_status_id': selected.intId,
      'marital_status_option': selected.toJson(),
      if (widget.gender?.intId != null) 'gender_id': widget.gender!.intId,
      'has_children': hasChildren,
      if (!hasChildren) ...<String, dynamic>{
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
    final childrenError = widget.fieldErrors['has_children'];

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
                    padding: const EdgeInsets.only(top: 16),
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
                            onChanged: (value) {
                              setState(() {
                                _edited = true;
                                _hasChildren = value;
                              });
                              widget.onFieldEdited();
                            },
                          ),
                          if (childrenError != null) ...[
                            const SizedBox(height: 8),
                            _InlineError(text: childrenError),
                          ],
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
    final borderColor = selected
        ? _MaritalStatusStepState._selectedGreen
        : Colors.grey.shade300;
    final background = selected
        ? _MaritalStatusStepState._selectedGreenSurface
        : Colors.white;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(minHeight: prominent ? 56 : 52),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: prominent ? 16 : 10,
            vertical: prominent ? 14 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
          ),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: selected
                  ? _MaritalStatusStepState._selectedGreen
                  : Colors.grey.shade900,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      ),
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
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? _MaritalStatusStepState._selectedGreen
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade800,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
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
