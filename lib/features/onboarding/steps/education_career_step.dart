import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import '../widgets/onboarding_picker_field.dart';
import '../widgets/smart_picker_panel.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';

class _IncomeBand {
  const _IncomeBand({
    required this.key,
    required this.label,
    required this.min,
    required this.max,
    required this.defaultMin,
    required this.defaultMax,
  });

  final String key;
  final String label;
  final int min;
  final int max;
  final int defaultMin;
  final int defaultMax;
}

const List<_IncomeBand> _annualIncomeBands = <_IncomeBand>[
  _IncomeBand(
    key: 'annual_1_10l',
    label: '1-10L',
    min: 100000,
    max: 1000000,
    defaultMin: 400000,
    defaultMax: 600000,
  ),
  _IncomeBand(
    key: 'annual_10_20l',
    label: '10-20L',
    min: 1000000,
    max: 2000000,
    defaultMin: 1200000,
    defaultMax: 1600000,
  ),
  _IncomeBand(
    key: 'annual_20_50l',
    label: '20-50L',
    min: 2000000,
    max: 5000000,
    defaultMin: 3000000,
    defaultMax: 4000000,
  ),
  _IncomeBand(
    key: 'annual_50l_1cr',
    label: '50L-1Cr',
    min: 5000000,
    max: 10000000,
    defaultMin: 6000000,
    defaultMax: 8000000,
  ),
  _IncomeBand(
    key: 'annual_1_10cr',
    label: '1-10Cr',
    min: 10000000,
    max: 100000000,
    defaultMin: 40000000,
    defaultMax: 60000000,
  ),
];

const List<_IncomeBand> _monthlyIncomeBands = <_IncomeBand>[
  _IncomeBand(
    key: 'monthly_10_50k',
    label: '10K-50K',
    min: 10000,
    max: 50000,
    defaultMin: 20000,
    defaultMax: 35000,
  ),
  _IncomeBand(
    key: 'monthly_50k_1l',
    label: '50K-1L',
    min: 50000,
    max: 100000,
    defaultMin: 60000,
    defaultMax: 80000,
  ),
  _IncomeBand(
    key: 'monthly_1_2l',
    label: '1-2L',
    min: 100000,
    max: 200000,
    defaultMin: 120000,
    defaultMax: 160000,
  ),
  _IncomeBand(
    key: 'monthly_2_5l',
    label: '2-5L',
    min: 200000,
    max: 500000,
    defaultMin: 300000,
    defaultMax: 400000,
  ),
  _IncomeBand(
    key: 'monthly_5l_plus',
    label: '5L+',
    min: 500000,
    max: 2000000,
    defaultMin: 600000,
    defaultMax: 1000000,
  ),
];

const Color _educationChipColor = Color(0xFF0F8F5F);
const Color _educationChipSurface = Color(0xFFE7F6ED);
const Color _incomeLinkColor = Color(0xFF1D4ED8);

class EducationCareerStep extends StatefulWidget {
  const EducationCareerStep({
    super.key,
    required this.educationData,
    required this.careerData,
    required this.locale,
    required this.loading,
    required this.onSave,
    required this.onBack,
    required this.onMessage,
  });

  final Map<String, dynamic> educationData;
  final Map<String, dynamic> careerData;
  final String locale;
  final bool loading;
  final OnboardingStepSaver onSave;
  final VoidCallback onBack;
  final ValueChanged<String> onMessage;

  @override
  State<EducationCareerStep> createState() => _EducationCareerStepState();
}

class _EducationCareerStepState extends State<EducationCareerStep> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _workLocationController = TextEditingController();

  List<OnboardingOption> _selectedEducation = <OnboardingOption>[];
  OnboardingOption? _workingWith;
  OnboardingOption? _occupation;
  OnboardingOption? _period;
  OnboardingOption? _valueType;
  List<OnboardingOption> _periods = <OnboardingOption>[];
  List<OnboardingOption> _valueTypes = <OnboardingOption>[];
  int? _currencyId;
  String _currencySymbol = '₹';
  bool _incomePrivate = true;
  String? _incomeError;
  String? _incomeErrorField;
  String? _incomeBandKey;
  bool _workExtrasExpanded = false;

  bool get _mr => widget.locale == 'mr';

  bool get _incomeIsRange => (_valueType?.key ?? 'range') == 'range';

  bool get _incomeIsUndisclosed => _valueType?.key == 'undisclosed';

  bool get _incomeIsMonthly => _period?.key == 'monthly';

  List<_IncomeBand> get _incomeBands =>
      _incomeIsMonthly ? _monthlyIncomeBands : _annualIncomeBands;

  bool get _notWorking {
    final text = '${_workingWith?.key ?? ''} ${_workingWith?.label ?? ''}'
        .toLowerCase()
        .replaceAll('-', ' ');
    return text.contains('not working') ||
        text.contains('unemployed') ||
        text.contains('काम करत नाही');
  }

  bool get _showOccupationSection => _workingWith != null && !_notWorking;

  bool get _showIncomeSection => _showOccupationSection && _occupation != null;

  @override
  void initState() {
    super.initState();
    _prefillEducation();
    _prefillCareer();
    _loadIncomeOptions();
  }

  @override
  void didUpdateWidget(covariant EducationCareerStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.educationData, widget.educationData)) {
      _prefillEducation();
    }
    if (!mapEquals(oldWidget.careerData, widget.careerData)) {
      _prefillCareer();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    _companyController.dispose();
    _workLocationController.dispose();
    super.dispose();
  }

  void _prefillEducation() {
    final data = widget.educationData;
    final slots = data['education_slots'];
    if (slots is List) {
      _selectedEducation = slots.whereType<Map>().map((row) {
        final json = Map<String, dynamic>.from(row);
        return OnboardingOption(
          id: json['id'],
          key: onboardingText(json['key']),
          label:
              onboardingText(json['label']) ??
              onboardingSelectedFailureLabel(widget.locale),
          meta: json['meta'] is Map
              ? Map<String, dynamic>.from(json['meta'] as Map)
              : const <String, dynamic>{},
          raw: json,
        );
      }).toList();
      return;
    }

    final ids = data['education_degree_ids'];
    _selectedEducation = ids is List
        ? ids
              .map(
                (id) => selectedValuePlaceholderOption(
                  id,
                  widget.locale,
                  failed: true,
                ),
              )
              .whereType<OnboardingOption>()
              .toList()
        : <OnboardingOption>[];
  }

  void _prefillCareer() {
    final data = widget.careerData;
    _workingWith =
        optionFromData(data['working_with_option']) ??
        _workingWithPlaceholder(data['working_with']);
    _occupation =
        optionFromData(data['occupation_option']) ??
        _placeholder(data['occupation_master_id']);
    _companyController.text = onboardingText(data['company_name']) ?? '';
    _workLocationController.text =
        onboardingText(data['work_location_text']) ?? '';
    _amountController.text =
        onboardingText(data['income_amount'] ?? data['annual_income']) ?? '';
    _minAmountController.text = onboardingText(data['income_min_amount']) ?? '';
    _maxAmountController.text = onboardingText(data['income_max_amount']) ?? '';
    _incomePrivate = onboardingBool(data['income_private']) ?? true;
    _workExtrasExpanded =
        _companyController.text.trim().isNotEmpty ||
        _workLocationController.text.trim().isNotEmpty;
    if (_periods.isNotEmpty) {
      _period = optionByKey(_periods, data['income_period']) ?? _period;
    }
    if (_valueTypes.isNotEmpty) {
      _valueType =
          optionByKey(_valueTypes, data['income_value_type']) ?? _valueType;
    }
    _syncRangeBandFromAmounts(applyDefaultIfEmpty: false);
  }

  String _t(String en, String mr) => _mr ? mr : en;

  OnboardingOption? _placeholder(dynamic id) {
    return selectedValuePlaceholderOption(id, widget.locale, failed: true);
  }

  OnboardingOption? _workingWithPlaceholder(dynamic key) {
    final text = onboardingText(key);
    if (text == null) return null;
    return OnboardingOption(key: text, label: text);
  }

  Future<void> _loadIncomeOptions() async {
    try {
      final data = await ApiClient.getIncomeOptions(locale: widget.locale);
      if (!mounted) return;
      final periods = OnboardingOption.listFrom(data['periods']);
      final valueTypes = OnboardingOption.listFrom(data['value_types']);
      setState(() {
        _periods = periods;
        _valueTypes = valueTypes;
        _currencyId = onboardingInt(data['currency_id']);
        _currencySymbol = onboardingText(data['currency_symbol']) ?? '₹';
        _period ??=
            optionByKey(periods, widget.careerData['income_period']) ??
            optionByKey(periods, 'annual') ??
            (periods.isNotEmpty ? periods.first : null);
        _valueType ??=
            optionByKey(valueTypes, widget.careerData['income_value_type']) ??
            optionByKey(valueTypes, 'range') ??
            (valueTypes.isNotEmpty ? valueTypes.first : null);
        _incomePrivate =
            onboardingBool(widget.careerData['income_private']) ??
            (data['privacy_default']?.toString() == 'private');
        _ensureIncomeSelectionDefaults();
      });
    } catch (_) {
      return;
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

  Future<PagedLookupResponse> _workingWithPage(
    String query,
    int page,
    int limit,
  ) async {
    return PagedLookupResponse.fromJson(
      await ApiClient.getWorkingWithOptions(
        query: query,
        page: page,
        limit: limit,
        locale: widget.locale,
      ),
    );
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
        workingWithId: _workingWith?.intId,
      ),
    );
  }

  OnboardingOption _fallbackOption(String key, String en, String mr) {
    return OnboardingOption(key: key, label: _t(en, mr));
  }

  void _ensureIncomeSelectionDefaults() {
    _period ??=
        optionByKey(_periods, widget.careerData['income_period']) ??
        optionByKey(_periods, 'annual') ??
        _fallbackOption('annual', 'Annual', 'वार्षिक');
    _valueType ??=
        optionByKey(_valueTypes, widget.careerData['income_value_type']) ??
        optionByKey(_valueTypes, 'range') ??
        _fallbackOption('range', 'Range', 'श्रेणी');
    _syncRangeBandFromAmounts(applyDefaultIfEmpty: _incomeIsRange);
  }

  List<OnboardingOption> get _periodOptions {
    if (_periods.isNotEmpty) return _periods;
    return <OnboardingOption>[
      _fallbackOption('annual', 'Annual', 'वार्षिक'),
      _fallbackOption('monthly', 'Monthly', 'मासिक'),
    ];
  }

  List<OnboardingOption> get _valueTypeOptions {
    if (_valueTypes.isNotEmpty) return _valueTypes;
    return <OnboardingOption>[
      _fallbackOption('exact', 'Exact', 'अचूक'),
      _fallbackOption('approximate', 'Approx', 'अंदाजे'),
      _fallbackOption('range', 'Range', 'श्रेणी'),
    ];
  }

  void _clearIncomeErrorState() {
    _incomeError = null;
    _incomeErrorField = null;
  }

  void _setIncomePeriod(OnboardingOption option) {
    setState(() {
      _clearIncomeErrorState();
      _period = option;
      if (_incomeIsRange) {
        _applyIncomeBand(_incomeBands.first);
      }
    });
  }

  void _setIncomeValueType(OnboardingOption option) {
    setState(() {
      _clearIncomeErrorState();
      final wasRange = _incomeIsRange;
      _valueType = option;
      if (_incomeIsRange && !wasRange) {
        _applyIncomeBand(_currentIncomeBand);
      } else if (_incomeIsRange) {
        _syncRangeBandFromAmounts(applyDefaultIfEmpty: true);
      }
    });
  }

  Future<void> _showIncomeOptionPicker({
    required String title,
    required List<OnboardingOption> options,
    required OnboardingOption? selected,
    required ValueChanged<OnboardingOption> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final active = selected?.identity == option.identity;
                    return ListTile(
                      dense: true,
                      title: Text(_incomeOptionLabel(option)),
                      trailing: active ? const Icon(Icons.check) : null,
                      onTap: () {
                        Navigator.pop(context);
                        onSelected(option);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _incomeOptionLabel(OnboardingOption option) {
    return switch (option.key) {
      'annual' => _t('Annual', 'वार्षिक'),
      'monthly' => _t('Monthly', 'मासिक'),
      'exact' => _t('Exact', 'अचूक'),
      'approximate' => _t('Approx', 'अंदाजे'),
      'range' => _t('Range', 'श्रेणी'),
      _ => option.label,
    };
  }

  String get _periodLabel => _incomeOptionLabel(
    _period ?? _fallbackOption('annual', 'Annual', 'वार्षिक'),
  );

  String get _valueTypeLabel => _incomeOptionLabel(
    _valueType ?? _fallbackOption('range', 'Range', 'श्रेणी'),
  );

  void _syncRangeBandFromAmounts({required bool applyDefaultIfEmpty}) {
    if (!_incomeIsRange) return;
    final minAmount = onboardingInt(_minAmountController.text);
    final maxAmount = onboardingInt(_maxAmountController.text);
    final band = _bandForAmounts(minAmount, maxAmount) ?? _incomeBands.first;
    _incomeBandKey = band.key;
    if (applyDefaultIfEmpty && (minAmount == null || maxAmount == null)) {
      _applyIncomeBand(band);
    }
  }

  _IncomeBand? _bandForAmounts(int? minAmount, int? maxAmount) {
    if (minAmount == null && maxAmount == null) return null;
    final low = minAmount ?? maxAmount!;
    final high = maxAmount ?? minAmount!;
    for (final band in _incomeBands) {
      if (low >= band.min && high <= band.max) return band;
    }
    return null;
  }

  _IncomeBand get _currentIncomeBand {
    for (final band in _incomeBands) {
      if (band.key == _incomeBandKey) return band;
    }
    final minAmount = onboardingInt(_minAmountController.text);
    final maxAmount = onboardingInt(_maxAmountController.text);
    return _bandForAmounts(minAmount, maxAmount) ?? _incomeBands.first;
  }

  void _applyIncomeBand(_IncomeBand band) {
    _incomeBandKey = band.key;
    _minAmountController.text = band.defaultMin.toString();
    _maxAmountController.text = band.defaultMax.toString();
  }

  int _incomeStep(_IncomeBand band) {
    if (band.max <= 100000) return 5000;
    if (band.max <= 1000000) return 50000;
    if (band.max <= 10000000) return 100000;
    return 1000000;
  }

  int _roundIncomeValue(double value, _IncomeBand band) {
    final step = _incomeStep(band);
    final rounded = (value / step).round() * step;
    return rounded.clamp(band.min, band.max).toInt();
  }

  RangeValues _rangeValuesForBand(_IncomeBand band) {
    final start = onboardingInt(_minAmountController.text) ?? band.defaultMin;
    final end = onboardingInt(_maxAmountController.text) ?? band.defaultMax;
    final clampedStart = start.clamp(band.min, band.max).toDouble();
    final clampedEnd = end.clamp(band.min, band.max).toDouble();
    if (clampedEnd < clampedStart) {
      return RangeValues(clampedStart, clampedStart);
    }
    return RangeValues(clampedStart, clampedEnd);
  }

  String _formatIncomeAmount(num amount) {
    if (amount >= 10000000) {
      return '₹${_formatIncomeUnit(amount / 10000000)}Cr';
    }
    if (amount >= 100000) {
      return '₹${_formatIncomeUnit(amount / 100000)}L';
    }
    if (amount >= 1000) {
      return '₹${_formatIncomeUnit(amount / 1000)}K';
    }
    return '₹${amount.round()}';
  }

  String _formatIncomeUnit(num value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1);
  }

  String _incomeRangeSummary(RangeValues values) {
    return '${_formatIncomeAmount(values.start)} - ${_formatIncomeAmount(values.end)}';
  }

  String _incomePeriodSuffix() {
    return _incomeIsMonthly
        ? _t('per month', 'दर महिना')
        : _t('per year', 'दर वर्ष');
  }

  Map<String, dynamic> _educationPayload() {
    final degreeIds = _selectedEducation
        .map((option) => option.intId)
        .whereType<int>()
        .toList();
    final slots = _selectedEducation
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

    return <String, dynamic>{
      'education_slots': slots,
      'education_degree_ids': degreeIds,
    };
  }

  Map<String, dynamic> _careerPayload() {
    final valueType = _valueType?.key;
    final amount = onboardingInt(_amountController.text);
    final minAmount = onboardingInt(_minAmountController.text);
    final maxAmount = onboardingInt(_maxAmountController.text);
    final incomeEnabled = !_notWorking && valueType != null;

    return compactPayload({
      'working_with': _workingWith?.key ?? _workingWith?.id?.toString(),
      if (_workingWith != null) 'working_with_option': _workingWith!.toJson(),
      'occupation_master_id': _notWorking ? null : _occupation?.intId,
      if (!_notWorking && _occupation?.intId != null)
        'occupation_option': _occupation!.toJson(),
      'company_name': _notWorking ? null : _companyController.text.trim(),
      'work_location_text': _notWorking
          ? null
          : _workLocationController.text.trim(),
      'income_period': incomeEnabled ? _period?.key : null,
      'income_value_type': incomeEnabled ? valueType : null,
      'income_amount': incomeEnabled && valueType != 'range' ? amount : null,
      'annual_income': incomeEnabled && valueType != 'range' ? amount : null,
      'income_min_amount': incomeEnabled && valueType == 'range'
          ? minAmount
          : null,
      'income_max_amount': incomeEnabled && valueType == 'range'
          ? maxAmount
          : null,
      'income_currency_id': incomeEnabled ? _currencyId : null,
      'income_private': incomeEnabled ? _incomePrivate : null,
    });
  }

  void _clearIncomeError() {
    if (_incomeError == null) return;
    setState(_clearIncomeErrorState);
  }

  bool _validateIncome() {
    if (_notWorking || !_showIncomeSection) {
      return true;
    }

    final valueType = _valueType?.key;
    if (valueType == null || valueType == 'undisclosed') {
      return true;
    }

    String? error;
    String? field;
    if (valueType == 'range') {
      final minText = _minAmountController.text.trim();
      final maxText = _maxAmountController.text.trim();
      final minAmount = onboardingInt(minText);
      final maxAmount = onboardingInt(maxText);

      if (minText.isNotEmpty && minAmount == null) {
        field = 'min';
        error = _t('Enter a valid min income.', 'योग्य min income भरा.');
      } else if (maxText.isNotEmpty && maxAmount == null) {
        field = 'max';
        error = _t('Enter a valid max income.', 'योग्य max income भरा.');
      } else if (minText.isEmpty && maxText.isNotEmpty) {
        field = 'min';
        error = _t('Enter min income too.', 'Min income सुद्धा भरा.');
      } else if (minAmount != null &&
          maxAmount != null &&
          maxAmount < minAmount) {
        field = 'max';
        error = _t(
          'Max income must be more than min income.',
          'Max income min income पेक्षा जास्त असावे.',
        );
      }
    } else {
      final amountText = _amountController.text.trim();
      if (amountText.isNotEmpty && onboardingInt(amountText) == null) {
        field = 'amount';
        error = _t('Enter a valid income amount.', 'योग्य income amount भरा.');
      }
    }

    if (error == null) {
      if (_incomeError != null) {
        setState(() {
          _incomeError = null;
          _incomeErrorField = null;
        });
      }
      return true;
    }

    setState(() {
      _incomeError = error;
      _incomeErrorField = field;
    });
    widget.onMessage(error);
    return false;
  }

  String? _incomeFieldError(String field) {
    return _incomeErrorField == field ? _incomeError : null;
  }

  String? _rangeIncomeError() {
    return switch (_incomeErrorField) {
      'min' || 'max' || 'range' => _incomeError,
      _ => null,
    };
  }

  Future<void> _continue() async {
    if (_workingWith == null) {
      widget.onMessage(_t('Choose work details.', 'कामाची माहिती निवडा.'));
      return;
    }

    if (!_notWorking && _occupation == null) {
      widget.onMessage(_t('Choose occupation.', 'व्यवसाय निवडा.'));
      return;
    }

    if (_showIncomeSection) {
      _ensureIncomeSelectionDefaults();
    }

    if (!_validateIncome()) {
      return;
    }

    final educationSaved = await widget.onSave(
      'education',
      _educationPayload(),
      saveProfile: true,
      advance: false,
    );
    if (!mounted || !educationSaved) return;

    await widget.onSave(
      'career',
      _careerPayload(),
      saveProfile: true,
      advance: true,
    );
  }

  Future<void> _showEducationSuggestionDialog() async {
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

  Future<void> _showOccupationSuggestionDialog() async {
    final label = TextEditingController();
    final categoryId = TextEditingController();
    final notes = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(_t('Request occupation', 'Occupation request')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: label,
                    decoration: InputDecoration(
                      labelText: _t('Occupation label', 'Occupation label'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: categoryId,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'category_id optional',
                    ),
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
                      'Pending suggestions are not selected as occupation until approved.',
                      'Pending suggestion approved होईपर्यंत occupation म्हणून select होत नाही.',
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
                  final response = await ApiClient.submitOccupationSuggestion(
                    compactPayload({
                      'label': label.text.trim(),
                      'category_id': onboardingInt(categoryId.text),
                      'working_with_id': _workingWith?.intId,
                      'notes': notes.text.trim(),
                    }),
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  widget.onMessage(
                    response['success'] == true || response['statusCode'] == 201
                        ? _t(
                            'Occupation request submitted.',
                            'Occupation request submit झाली.',
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

  Widget _compactEducationPicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSelection = _selectedEducation.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => SmartPickerPanel.show(
        context,
        title: _t('Education', 'शिक्षण'),
        selectedItems: _selectedEducation,
        multiSelect: true,
        searchHint: _t('Search education', 'Education शोधा'),
        loadPage: _educationPage,
        itemSubtitleBuilder: (option) => option.metaText('category_label'),
        allowRequestToAdd: true,
        onRequestToAdd: _showEducationSuggestionDialog,
        onChanged: (items) => setState(() => _selectedEducation = items),
      ),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: _t('Education', 'शिक्षण'),
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 34,
            minHeight: 32,
          ),
          suffixIcon: Icon(Icons.chevron_right, color: colorScheme.primary),
        ),
        child: hasSelection
            ? SizedBox(
                height: 32,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < _selectedEducation.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        InputChip(
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              _selectedEducation[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          labelStyle: const TextStyle(
                            color: _educationChipColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          labelPadding: const EdgeInsets.only(left: 6),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: _educationChipSurface,
                          selectedColor: _educationChipSurface,
                          side: const BorderSide(color: _educationChipColor),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          deleteIconColor: _educationChipColor,
                          onDeleted: () => setState(() {
                            final item = _selectedEducation[i];
                            _selectedEducation = _selectedEducation
                                .where(
                                  (selected) =>
                                      selected.identity != item.identity,
                                )
                                .toList();
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : Text(
                _t('Search and select education', 'Education शोधून निवडा'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700),
              ),
      ),
    );
  }

  Widget _companyWorkLocationSection(BuildContext context) {
    if (!_workExtrasExpanded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => setState(() => _workExtrasExpanded = true),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            _t('+ Add company / work location', '+ कंपनी / कामाचे ठिकाण जोडा'),
          ),
        ),
      );
    }

    return Column(
      children: [
        TextField(
          controller: _companyController,
          decoration: InputDecoration(
            labelText: _t('Company optional', 'Company optional'),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _workLocationController,
          decoration: InputDecoration(
            labelText: _t('Work location optional', 'Work location optional'),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _incomeLink(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _incomeLinkColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              color: _incomeLinkColor,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _incomeHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _t('Income', 'उत्पन्न'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        _incomeLink(
          context,
          label: _periodLabel,
          onTap: () => _showIncomeOptionPicker(
            title: _t('Income period', 'Income period'),
            options: _periodOptions,
            selected: _period,
            onSelected: _setIncomePeriod,
          ),
        ),
        const SizedBox(width: 4),
        _incomeLink(
          context,
          label: _valueTypeLabel,
          onTap: () => _showIncomeOptionPicker(
            title: _t('Income type', 'Income type'),
            options: _valueTypeOptions,
            selected: _valueType,
            onSelected: _setIncomeValueType,
          ),
        ),
      ],
    );
  }

  Widget _rangeIncomeSection(BuildContext context) {
    final band = _currentIncomeBand;
    final values = _rangeValuesForBand(band);
    final selectedRange = _incomeRangeSummary(values);
    final rangeError = _rangeIncomeError();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: Column(
            key: ValueKey<String>(selectedRange),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedRange,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _incomePeriodSuffix(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        RangeSlider(
          values: values,
          min: band.min.toDouble(),
          max: band.max.toDouble(),
          divisions: 20,
          labels: RangeLabels(
            _formatIncomeAmount(values.start),
            _formatIncomeAmount(values.end),
          ),
          onChanged: (next) => setState(() {
            _clearIncomeErrorState();
            _incomeBandKey = band.key;
            _minAmountController.text = _roundIncomeValue(
              next.start,
              band,
            ).toString();
            _maxAmountController.text = _roundIncomeValue(
              next.end,
              band,
            ).toString();
          }),
        ),
        Row(
          children: [
            Text(
              _formatIncomeAmount(band.min),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              _formatIncomeAmount(band.max),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _incomeBands.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Builder(
                  builder: (context) {
                    final item = _incomeBands[i];
                    final selected = item.key == band.key;
                    return ChoiceChip(
                      label: Text(item.label),
                      selected: selected,
                      visualDensity: const VisualDensity(
                        horizontal: -4,
                        vertical: -4,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      padding: EdgeInsets.zero,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : Colors.grey.shade900,
                      ),
                      selectedColor: const Color(0xFF0F8F5F),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFF0F8F5F)
                            : Colors.grey.shade300,
                      ),
                      onSelected: (_) => setState(() {
                        _clearIncomeErrorState();
                        _applyIncomeBand(item);
                      }),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        if (rangeError != null) ...[
          const SizedBox(height: 6),
          Text(
            rangeError,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _amountIncomeSection() {
    return TextField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      onChanged: (_) => _clearIncomeError(),
      decoration: InputDecoration(
        isDense: true,
        labelText: _t('Income amount', 'उत्पन्न रक्कम'),
        prefixText: _currencySymbol,
        errorText: _incomeFieldError('amount'),
      ),
    );
  }

  Widget _incomePrivacySwitch(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: Text(
              _t('Keep income private', 'उत्पन्न खाजगी ठेवा'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Transform.scale(
            scale: 0.9,
            alignment: Alignment.centerRight,
            child: Switch(
              value: _incomePrivate,
              onChanged: (value) => setState(() => _incomePrivate = value),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: '',
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: _continue,
      continueLabel: _t('Save and continue', 'Save करून पुढे जा'),
      children: [
        _compactEducationPicker(context),
        const SizedBox(height: 12),
        OnboardingPickerField(
          label: _t('Working with', 'कामाचा प्रकार'),
          selectedItems: _workingWith == null ? const [] : [_workingWith!],
          placeholder: _t('Select work type', 'कामाचा प्रकार निवडा'),
          searchHint: _t('Search work type', 'कामाचा प्रकार शोधा'),
          loadPage: _workingWithPage,
          onChanged: (items) => setState(() {
            final next = items.isEmpty ? null : items.first;
            if (_workingWith?.identity != next?.identity) {
              _occupation = null;
              _amountController.clear();
              _minAmountController.clear();
              _maxAmountController.clear();
            }
            _workingWith = next;
          }),
        ),
        if (_notWorking) ...[
          const SizedBox(height: 8),
          Text(
            _t(
              'Occupation and income are optional when not working.',
              'काम करत नसल्यास व्यवसाय आणि उत्पन्न optional आहे.',
            ),
          ),
        ],
        if (_showOccupationSection) ...[
          const SizedBox(height: 12),
          OnboardingPickerField(
            label: _t('Working as', 'व्यवसाय'),
            selectedItems: _occupation == null ? const [] : [_occupation!],
            enabled: _workingWith != null,
            placeholder: _t('Select occupation', 'व्यवसाय निवडा'),
            searchHint: _t('Search occupation', 'व्यवसाय शोधा'),
            loadPage: _occupationPage,
            itemSubtitleBuilder: (option) => option.metaText('category_label'),
            allowRequestToAdd: true,
            onRequestToAdd: _showOccupationSuggestionDialog,
            onChanged: (items) => setState(() {
              _occupation = items.isEmpty ? null : items.first;
            }),
          ),
          if (_occupation != null) ...[
            const SizedBox(height: 8),
            _companyWorkLocationSection(context),
          ],
        ],
        if (_showIncomeSection) ...[
          const SizedBox(height: 14),
          _incomeHeader(context),
          const SizedBox(height: 8),
          if (!_incomeIsUndisclosed)
            _incomeIsRange
                ? _rangeIncomeSection(context)
                : _amountIncomeSection(),
          const SizedBox(height: 6),
          _incomePrivacySwitch(context),
        ],
      ],
    );
  }
}
