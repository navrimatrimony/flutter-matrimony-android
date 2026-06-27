import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import '../widgets/onboarding_picker_field.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';

class FamilyOptionalStep extends StatefulWidget {
  const FamilyOptionalStep({
    super.key,
    required this.data,
    required this.locale,
    required this.loading,
    required this.onSave,
    required this.onBack,
  });

  final Map<String, dynamic> data;
  final String locale;
  final bool loading;
  final OnboardingStepSaver onSave;
  final VoidCallback onBack;

  @override
  State<FamilyOptionalStep> createState() => _FamilyOptionalStepState();
}

class _FamilyOptionalStepState extends State<FamilyOptionalStep> {
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _fatherInfoController = TextEditingController();
  final TextEditingController _motherNameController = TextEditingController();
  final TextEditingController _motherInfoController = TextEditingController();
  final TextEditingController _brothersCountController =
      TextEditingController();
  final TextEditingController _sistersCountController = TextEditingController();

  OnboardingOption? _fatherOccupation;
  OnboardingOption? _motherOccupation;
  bool _showParentDetails = false;
  bool get _mr => widget.locale == 'mr';
  int get _brothersCount => onboardingInt(_brothersCountController.text) ?? 0;
  int get _sistersCount => onboardingInt(_sistersCountController.text) ?? 0;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void didUpdateWidget(covariant FamilyOptionalStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.data, widget.data)) _prefill();
  }

  @override
  void dispose() {
    _fatherNameController.dispose();
    _fatherInfoController.dispose();
    _motherNameController.dispose();
    _motherInfoController.dispose();
    _brothersCountController.dispose();
    _sistersCountController.dispose();
    super.dispose();
  }

  void _prefill() {
    final data = widget.data;
    _fatherNameController.text = onboardingText(data['father_name']) ?? '';
    _fatherInfoController.text =
        onboardingText(data['father_extra_info']) ?? '';
    _motherNameController.text = onboardingText(data['mother_name']) ?? '';
    _motherInfoController.text =
        onboardingText(data['mother_extra_info']) ?? '';
    _brothersCountController.text =
        onboardingInt(data['brothers_count'])?.toString() ?? '';
    _sistersCountController.text =
        onboardingInt(data['sisters_count'])?.toString() ?? '';
    _fatherOccupation =
        optionFromData(data['father_occupation_option']) ??
        _placeholder(data['father_occupation_master_id']);
    _motherOccupation =
        optionFromData(data['mother_occupation_option']) ??
        _placeholder(data['mother_occupation_master_id']);
    _showParentDetails = _hasParentDetails;
  }

  String _t(String en, String mr) => _mr ? mr : en;

  bool get _hasParentDetails {
    return _fatherNameController.text.trim().isNotEmpty ||
        _fatherInfoController.text.trim().isNotEmpty ||
        _motherNameController.text.trim().isNotEmpty ||
        _motherInfoController.text.trim().isNotEmpty ||
        _fatherOccupation != null ||
        _motherOccupation != null;
  }

  void _changeCount(TextEditingController controller, int delta) {
    final current = onboardingInt(controller.text) ?? 0;
    final next = (current + delta).clamp(0, 20);
    if (next == current) return;
    setState(() => controller.text = next == 0 ? '' : next.toString());
  }

  String _siblingSummary() {
    final parts = <String>[];
    if (_brothersCount > 0) {
      parts.add(
        _t(
          '$_brothersCount brother${_brothersCount == 1 ? '' : 's'}',
          '$_brothersCount भाऊ',
        ),
      );
    }
    if (_sistersCount > 0) {
      parts.add(
        _t(
          '$_sistersCount sister${_sistersCount == 1 ? '' : 's'}',
          '$_sistersCount बहिणी',
        ),
      );
    }
    return parts.isEmpty
        ? _t('No siblings selected', 'भावंडे निवडलेली नाहीत')
        : parts.join(' • ');
  }

  OnboardingOption? _placeholder(dynamic id) {
    return selectedValuePlaceholderOption(id, widget.locale, failed: true);
  }

  Future<PagedLookupResponse> _occupationPage(
    String query,
    int page,
    int limit,
  ) async {
    return PagedLookupResponse.fromJson(
      await ApiClient.searchOccupations(
        query: query,
        page: page,
        limit: limit,
        locale: widget.locale,
      ),
    );
  }

  Future<void> _save() async {
    await widget.onSave(
      'family',
      compactPayload({
        'father_name': _fatherNameController.text.trim(),
        'father_occupation_master_id': _fatherOccupation?.intId,
        if (_fatherOccupation?.intId != null)
          'father_occupation_option': _fatherOccupation!.toJson(),
        'father_extra_info': _fatherInfoController.text.trim(),
        'mother_name': _motherNameController.text.trim(),
        'mother_occupation_master_id': _motherOccupation?.intId,
        if (_motherOccupation?.intId != null)
          'mother_occupation_option': _motherOccupation!.toJson(),
        'mother_extra_info': _motherInfoController.text.trim(),
        'brothers_count': onboardingInt(_brothersCountController.text),
        'sisters_count': onboardingInt(_sistersCountController.text),
      }),
      saveProfile: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: _t('Family details', 'कुटुंब माहिती'),
      subtitle: _t(
        'Add a quick family summary now. Detailed rows can come later.',
        'आता थोडक्यात family माहिती भरा. सविस्तर माहिती नंतर देता येईल.',
      ),
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: _save,
      continueLabel: _t('Save and continue', 'सेव्ह करून पुढे जा'),
      secondary: TextButton(
        onPressed: widget.loading
            ? null
            : () => widget.onSave('family', const {}, saveProfile: false),
        child: Text(_t('Skip family info', 'Family माहिती skip करा')),
      ),
      children: [
        _siblingsCard(context),
        const SizedBox(height: 16),
        _parentsCard(context),
      ],
    );
  }

  Widget _siblingsCard(BuildContext context) {
    return _FamilySectionCard(
      title: _t('Siblings', 'भावंडे'),
      subtitle: _siblingSummary(),
      child: Column(
        children: [
          _SiblingCounter(
            label: _t('Brothers', 'भाऊ'),
            value: _brothersCount,
            onDecrement: () => _changeCount(_brothersCountController, -1),
            onIncrement: () => _changeCount(_brothersCountController, 1),
          ),
          const SizedBox(height: 10),
          _SiblingCounter(
            label: _t('Sisters', 'बहिणी'),
            value: _sistersCount,
            onDecrement: () => _changeCount(_sistersCountController, -1),
            onIncrement: () => _changeCount(_sistersCountController, 1),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _t(
                'Names and married status can be added later from Edit Profile.',
                'नावे आणि लग्नाची स्थिती नंतर Edit Profile मधून भरता येईल.',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _parentsCard(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () =>
                setState(() => _showParentDetails = !_showParentDetails),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('Parent details', 'आई-वडिलांची माहिती'),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: Colors.grey.shade900,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _hasParentDetails
                              ? _t('Some details added', 'काही माहिती भरली आहे')
                              : _t('Optional', 'Optional'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showParentDetails ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            crossFadeState: _showParentDetails
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  TextField(
                    controller: _fatherNameController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _t(
                        'Father name optional',
                        'वडिलांचे नाव optional',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _occupationPicker(
                    label: _t('Father occupation', 'वडिलांचा व्यवसाय'),
                    selected: _fatherOccupation,
                    onChanged: (option) =>
                        setState(() => _fatherOccupation = option),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _fatherInfoController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _t(
                        'Father notes optional',
                        'वडिलांची माहिती optional',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _motherNameController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _t(
                        'Mother name optional',
                        'आईचे नाव optional',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _occupationPicker(
                    label: _t('Mother occupation', 'आईचा व्यवसाय'),
                    selected: _motherOccupation,
                    onChanged: (option) =>
                        setState(() => _motherOccupation = option),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _motherInfoController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _t(
                        'Mother notes optional',
                        'आईची माहिती optional',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _occupationPicker({
    required String label,
    required OnboardingOption? selected,
    required ValueChanged<OnboardingOption?> onChanged,
  }) {
    return OnboardingPickerField(
      label: label,
      selectedItems: selected == null ? const [] : [selected],
      placeholder: _t('Search occupation', 'Occupation शोधा'),
      loadPage: _occupationPage,
      itemSubtitleBuilder: (option) => option.metaText('category_label'),
      onChanged: (items) => onChanged(items.isEmpty ? null : items.first),
    );
  }
}

class _FamilySectionCard extends StatelessWidget {
  const _FamilySectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SiblingCounter extends StatelessWidget {
  const _SiblingCounter({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade900,
                ),
              ),
            ),
            _CounterButton(
              icon: Icons.remove_rounded,
              enabled: value > 0,
              onTap: onDecrement,
            ),
            SizedBox(
              width: 46,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                child: Text(
                  value.toString(),
                  key: ValueKey(value),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: value > 0
                        ? onboardingSelectedGreen
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
            _CounterButton(
              icon: Icons.add_rounded,
              enabled: value < 20,
              onTap: onIncrement,
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? onboardingSelectedGreen : Colors.grey.shade300;

    return Material(
      color: color.withValues(alpha: enabled ? 0.12 : 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
