import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import '../widgets/onboarding_error_highlight.dart';
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
    required this.groupKey,
  });

  final String key;
  final String label;
  final int min;
  final int max;
  final String groupKey;
}

const List<_IncomeBand> _annualIncomeBands = <_IncomeBand>[
  _IncomeBand(
    key: 'annual_1_125l',
    label: '1L - 1.25L',
    min: 100000,
    max: 125000,
    groupKey: 'annual_1_2l',
  ),
  _IncomeBand(
    key: 'annual_125_150l',
    label: '1.25L - 1.5L',
    min: 125000,
    max: 150000,
    groupKey: 'annual_1_2l',
  ),
  _IncomeBand(
    key: 'annual_150_175l',
    label: '1.5L - 1.75L',
    min: 150000,
    max: 175000,
    groupKey: 'annual_1_2l',
  ),
  _IncomeBand(
    key: 'annual_175_2l',
    label: '1.75L - 2L',
    min: 175000,
    max: 200000,
    groupKey: 'annual_1_2l',
  ),
  _IncomeBand(
    key: 'annual_2_250l',
    label: '2L - 2.5L',
    min: 200000,
    max: 250000,
    groupKey: 'annual_2_5l',
  ),
  _IncomeBand(
    key: 'annual_250_3l',
    label: '2.5L - 3L',
    min: 250000,
    max: 300000,
    groupKey: 'annual_2_5l',
  ),
  _IncomeBand(
    key: 'annual_3_350l',
    label: '3L - 3.5L',
    min: 300000,
    max: 350000,
    groupKey: 'annual_2_5l',
  ),
  _IncomeBand(
    key: 'annual_350_4l',
    label: '3.5L - 4L',
    min: 350000,
    max: 400000,
    groupKey: 'annual_2_5l',
  ),
  _IncomeBand(
    key: 'annual_4_450l',
    label: '4L - 4.5L',
    min: 400000,
    max: 450000,
    groupKey: 'annual_2_5l',
  ),
  _IncomeBand(
    key: 'annual_450_5l',
    label: '4.5L - 5L',
    min: 450000,
    max: 500000,
    groupKey: 'annual_2_5l',
  ),
  _IncomeBand(
    key: 'annual_5_6l',
    label: '5L - 6L',
    min: 500000,
    max: 600000,
    groupKey: 'annual_5_10l',
  ),
  _IncomeBand(
    key: 'annual_6_7l',
    label: '6L - 7L',
    min: 600000,
    max: 700000,
    groupKey: 'annual_5_10l',
  ),
  _IncomeBand(
    key: 'annual_7_8l',
    label: '7L - 8L',
    min: 700000,
    max: 800000,
    groupKey: 'annual_5_10l',
  ),
  _IncomeBand(
    key: 'annual_8_9l',
    label: '8L - 9L',
    min: 800000,
    max: 900000,
    groupKey: 'annual_5_10l',
  ),
  _IncomeBand(
    key: 'annual_9_10l',
    label: '9L - 10L',
    min: 900000,
    max: 1000000,
    groupKey: 'annual_5_10l',
  ),
  _IncomeBand(
    key: 'annual_10_15l',
    label: '10L - 15L',
    min: 1000000,
    max: 1500000,
    groupKey: 'annual_10_30l',
  ),
  _IncomeBand(
    key: 'annual_15_20l',
    label: '15L - 20L',
    min: 1500000,
    max: 2000000,
    groupKey: 'annual_10_30l',
  ),
  _IncomeBand(
    key: 'annual_20_25l',
    label: '20L - 25L',
    min: 2000000,
    max: 2500000,
    groupKey: 'annual_10_30l',
  ),
  _IncomeBand(
    key: 'annual_25_30l',
    label: '25L - 30L',
    min: 2500000,
    max: 3000000,
    groupKey: 'annual_10_30l',
  ),
  _IncomeBand(
    key: 'annual_30_40l',
    label: '30L - 40L',
    min: 3000000,
    max: 4000000,
    groupKey: 'annual_30_50l',
  ),
  _IncomeBand(
    key: 'annual_40_50l',
    label: '40L - 50L',
    min: 4000000,
    max: 5000000,
    groupKey: 'annual_30_50l',
  ),
  _IncomeBand(
    key: 'annual_50_75l',
    label: '50L - 75L',
    min: 5000000,
    max: 7500000,
    groupKey: 'annual_50l_plus',
  ),
  _IncomeBand(
    key: 'annual_75l_1cr',
    label: '75L - 1Cr',
    min: 7500000,
    max: 10000000,
    groupKey: 'annual_50l_plus',
  ),
  _IncomeBand(
    key: 'annual_1_2cr',
    label: '1Cr - 2Cr',
    min: 10000000,
    max: 20000000,
    groupKey: 'annual_50l_plus',
  ),
  _IncomeBand(
    key: 'annual_2_5cr',
    label: '2Cr - 5Cr',
    min: 20000000,
    max: 50000000,
    groupKey: 'annual_50l_plus',
  ),
  _IncomeBand(
    key: 'annual_5_10cr',
    label: '5Cr - 10Cr',
    min: 50000000,
    max: 100000000,
    groupKey: 'annual_50l_plus',
  ),
  _IncomeBand(
    key: 'annual_10cr_plus',
    label: '10Cr+',
    min: 100000000,
    max: 1000000000,
    groupKey: 'annual_50l_plus',
  ),
];

const List<_IncomeBand> _monthlyIncomeBands = <_IncomeBand>[
  _IncomeBand(
    key: 'monthly_10_15k',
    label: '10K - 15K',
    min: 10000,
    max: 15000,
    groupKey: 'monthly_10_30k',
  ),
  _IncomeBand(
    key: 'monthly_15_20k',
    label: '15K - 20K',
    min: 15000,
    max: 20000,
    groupKey: 'monthly_10_30k',
  ),
  _IncomeBand(
    key: 'monthly_20_25k',
    label: '20K - 25K',
    min: 20000,
    max: 25000,
    groupKey: 'monthly_10_30k',
  ),
  _IncomeBand(
    key: 'monthly_25_30k',
    label: '25K - 30K',
    min: 25000,
    max: 30000,
    groupKey: 'monthly_10_30k',
  ),
  _IncomeBand(
    key: 'monthly_30_40k',
    label: '30K - 40K',
    min: 30000,
    max: 40000,
    groupKey: 'monthly_30k_1l',
  ),
  _IncomeBand(
    key: 'monthly_40_50k',
    label: '40K - 50K',
    min: 40000,
    max: 50000,
    groupKey: 'monthly_30k_1l',
  ),
  _IncomeBand(
    key: 'monthly_50_60k',
    label: '50K - 60K',
    min: 50000,
    max: 60000,
    groupKey: 'monthly_30k_1l',
  ),
  _IncomeBand(
    key: 'monthly_60_70k',
    label: '60K - 70K',
    min: 60000,
    max: 70000,
    groupKey: 'monthly_30k_1l',
  ),
  _IncomeBand(
    key: 'monthly_70_80k',
    label: '70K - 80K',
    min: 70000,
    max: 80000,
    groupKey: 'monthly_30k_1l',
  ),
  _IncomeBand(
    key: 'monthly_80_90k',
    label: '80K - 90K',
    min: 80000,
    max: 90000,
    groupKey: 'monthly_30k_1l',
  ),
  _IncomeBand(
    key: 'monthly_90k_1l',
    label: '90K - 1L',
    min: 90000,
    max: 100000,
    groupKey: 'monthly_30k_1l',
  ),
  _IncomeBand(
    key: 'monthly_1_125l',
    label: '1L - 1.25L',
    min: 100000,
    max: 125000,
    groupKey: 'monthly_1_2l',
  ),
  _IncomeBand(
    key: 'monthly_125_150l',
    label: '1.25L - 1.5L',
    min: 125000,
    max: 150000,
    groupKey: 'monthly_1_2l',
  ),
  _IncomeBand(
    key: 'monthly_150_175l',
    label: '1.5L - 1.75L',
    min: 150000,
    max: 175000,
    groupKey: 'monthly_1_2l',
  ),
  _IncomeBand(
    key: 'monthly_175_2l',
    label: '1.75L - 2L',
    min: 175000,
    max: 200000,
    groupKey: 'monthly_1_2l',
  ),
  _IncomeBand(
    key: 'monthly_2_250l',
    label: '2L - 2.5L',
    min: 200000,
    max: 250000,
    groupKey: 'monthly_2_5l',
  ),
  _IncomeBand(
    key: 'monthly_250_3l',
    label: '2.5L - 3L',
    min: 250000,
    max: 300000,
    groupKey: 'monthly_2_5l',
  ),
  _IncomeBand(
    key: 'monthly_3_350l',
    label: '3L - 3.5L',
    min: 300000,
    max: 350000,
    groupKey: 'monthly_2_5l',
  ),
  _IncomeBand(
    key: 'monthly_350_4l',
    label: '3.5L - 4L',
    min: 350000,
    max: 400000,
    groupKey: 'monthly_2_5l',
  ),
  _IncomeBand(
    key: 'monthly_4_450l',
    label: '4L - 4.5L',
    min: 400000,
    max: 450000,
    groupKey: 'monthly_2_5l',
  ),
  _IncomeBand(
    key: 'monthly_450_5l',
    label: '4.5L - 5L',
    min: 450000,
    max: 500000,
    groupKey: 'monthly_2_5l',
  ),
  _IncomeBand(
    key: 'monthly_5_750l',
    label: '5L - 7.5L',
    min: 500000,
    max: 750000,
    groupKey: 'monthly_5l_plus',
  ),
  _IncomeBand(
    key: 'monthly_750_10l',
    label: '7.5L - 10L',
    min: 750000,
    max: 1000000,
    groupKey: 'monthly_5l_plus',
  ),
  _IncomeBand(
    key: 'monthly_10l_plus',
    label: '10L+',
    min: 1000000,
    max: 10000000,
    groupKey: 'monthly_5l_plus',
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
    this.educationError,
    this.educationErrorToken = 0,
  });

  final Map<String, dynamic> educationData;
  final Map<String, dynamic> careerData;
  final String locale;
  final bool loading;
  final OnboardingStepSaver onSave;
  final VoidCallback onBack;
  final ValueChanged<String> onMessage;
  final String? educationError;
  final int educationErrorToken;

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
  String? _educationError;
  String? _workingWithError;
  String? _occupationError;
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
    _educationError = widget.educationError;
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
    if (oldWidget.educationErrorToken != widget.educationErrorToken ||
        oldWidget.educationError != widget.educationError) {
      _educationError = widget.educationError;
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
  }) async {
    await SmartPickerPanel.show(
      context,
      title: title,
      selectedItems: selected == null ? const [] : [selected],
      showSearch: false,
      showOptionSubtitles: false,
      loadPage: (query, page, limit) async =>
          PagedLookupResponse.fromOptions(options),
      onChanged: (items) {
        if (items.isEmpty) return;
        onSelected(items.first);
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

  String _incomeGroupLabel(String key) {
    return switch (key) {
      'monthly_10_30k' => _t('10K to 30K', '10K ते 30K'),
      'monthly_30k_1l' => _t('30K to 1L', '30K ते 1L'),
      'monthly_1_2l' => _t('1L to 2L', '1L ते 2L'),
      'monthly_2_5l' => _t('2L to 5L', '2L ते 5L'),
      'monthly_5l_plus' => _t('5L and above', '5L आणि पुढे'),
      'annual_1_2l' => _t('1L to 2L', '1L ते 2L'),
      'annual_2_5l' => _t('2L to 5L', '2L ते 5L'),
      'annual_5_10l' => _t('5L to 10L', '5L ते 10L'),
      'annual_10_30l' => _t('10L to 30L', '10L ते 30L'),
      'annual_30_50l' => _t('30L to 50L', '30L ते 50L'),
      'annual_50l_plus' => _t('50L and above', '50L आणि पुढे'),
      _ => '',
    };
  }

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
    final midpoint = ((low + high) / 2).round();
    for (final band in _incomeBands) {
      if (midpoint >= band.min && midpoint <= band.max) return band;
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
    _minAmountController.text = band.min.toString();
    _maxAmountController.text = band.max.toString();
  }

  String _periodKeyForIncomeBand(_IncomeBand band) {
    return band.key.startsWith('monthly_') ? 'monthly' : 'annual';
  }

  List<_IncomeBand> _incomeBandsForPeriod(String periodKey) {
    return periodKey == 'monthly' ? _monthlyIncomeBands : _annualIncomeBands;
  }

  OnboardingOption _incomeBandOption(_IncomeBand band, String periodKey) {
    final periodLabel = periodKey == 'monthly'
        ? _t('per month', 'दर महिना')
        : _t('per year', 'दर वर्ष');
    return OnboardingOption(
      key: '${periodKey}_${band.key}',
      label: '$_currencySymbol${band.label}',
      meta: <String, dynamic>{
        'period_key': periodKey,
        'period_label': periodLabel,
        'group_label': _incomeGroupLabel(band.groupKey),
        'band_key': band.key,
      },
    );
  }

  List<OnboardingOption> _incomeRangeOptionsForPeriod(String periodKey) {
    return _incomeBandsForPeriod(
      periodKey,
    ).map((band) => _incomeBandOption(band, periodKey)).toList();
  }

  Future<PagedLookupResponse> _incomeRangePage(
    String query,
    int page,
    int limit,
  ) async {
    final periodKey = _incomeIsMonthly ? 'monthly' : 'annual';
    return _incomeRangeFilteredPage(query, page, limit, periodKey);
  }

  Future<PagedLookupResponse> _incomeRangeFilteredPage(
    String query,
    int page,
    int limit,
    String? filterKey,
  ) async {
    final periodKey = filterKey == 'monthly' ? 'monthly' : 'annual';
    final normalizedQuery = query.trim().toLowerCase();
    final options = _incomeRangeOptionsForPeriod(periodKey).where((option) {
      if (normalizedQuery.isEmpty) return true;
      return option.label.toLowerCase().contains(normalizedQuery) ||
          (option
                  .metaText('group_label')
                  ?.toLowerCase()
                  .contains(normalizedQuery) ??
              false);
    }).toList();
    return PagedLookupResponse.fromOptions(options);
  }

  OnboardingOption _selectedIncomeRangeOption() {
    final band = _currentIncomeBand;
    return _incomeBandOption(band, _periodKeyForIncomeBand(band));
  }

  void _applyIncomeRangeOption(OnboardingOption option) {
    final periodKey = option.metaText('period_key') ?? 'annual';
    final bandKey = option.metaText('band_key');
    _IncomeBand? band;
    for (final item in _incomeBandsForPeriod(periodKey)) {
      if (item.key == bandKey) {
        band = item;
        break;
      }
    }
    if (band == null) return;
    final selectedBand = band;

    setState(() {
      _clearIncomeErrorState();
      _period =
          optionByKey(_periodOptions, periodKey) ??
          _fallbackOption(
            periodKey,
            periodKey == 'monthly' ? 'Monthly' : 'Annual',
            periodKey == 'monthly' ? 'मासिक' : 'वार्षिक',
          );
      _valueType =
          optionByKey(_valueTypeOptions, 'range') ??
          _fallbackOption('range', 'Range', 'श्रेणी');
      _applyIncomeBand(selectedBand);
    });
  }

  Future<void> _showIncomeRangePicker(BuildContext context) async {
    final selected = _selectedIncomeRangeOption();
    await SmartPickerPanel.show(
      context,
      title: _t('Select income range', 'उत्पन्न श्रेणी निवडा'),
      selectedItems: [selected],
      showSearch: false,
      showDividers: true,
      groupOptions: true,
      initialFilterKey: _incomeIsMonthly ? 'monthly' : 'annual',
      filterOptions: [
        SmartPickerFilterOption(key: 'monthly', label: _t('Monthly', 'मासिक')),
        SmartPickerFilterOption(key: 'annual', label: _t('Annual', 'वार्षिक')),
      ],
      loadPage: _incomeRangePage,
      filteredLoadPage: _incomeRangeFilteredPage,
      itemSubtitleBuilder: (option) => option.metaText('period_label'),
      onChanged: (items) {
        if (items.isEmpty) return;
        _applyIncomeRangeOption(items.first);
      },
    );
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
    if (_selectedEducation.isEmpty) {
      final message = _t('Select education.', 'शिक्षण निवडा.');
      setState(() => _educationError = message);
      widget.onMessage(message);
      return;
    }

    if (_workingWith == null) {
      final message = _t('Choose work details.', 'कामाची माहिती निवडा.');
      setState(() => _workingWithError = message);
      widget.onMessage(message);
      return;
    }

    if (!_notWorking && _occupation == null) {
      final message = _t('Choose occupation.', 'व्यवसाय निवडा.');
      setState(() => _occupationError = message);
      widget.onMessage(message);
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

    return OnboardingErrorHighlight(
      hasError: _educationError != null,
      pulseKey: 'education:${widget.educationErrorToken}:$_educationError',
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
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
          onChanged: (items) => setState(() {
            _selectedEducation = items;
            _educationError = null;
          }),
        ),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: _t('Education *', 'शिक्षण *'),
            errorText: _educationError,
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
                              if (_selectedEducation.isNotEmpty) {
                                _educationError = null;
                              }
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
    final selectedRange = '$_currencySymbol${band.label}';
    final rangeError = _rangeIncomeError();
    final colorScheme = Theme.of(context).colorScheme;
    final privacyIcon = _incomePrivate
        ? Icons.lock_outline_rounded
        : Icons.lock_open_rounded;
    final privacyIconColor = _incomePrivate
        ? Colors.grey.shade700
        : colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showIncomeRangePicker(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: _t('Income range', 'उत्पन्न श्रेणी'),
          errorText: rangeError,
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 34,
            minHeight: 32,
          ),
          suffixIcon: Icon(Icons.chevron_right, color: colorScheme.primary),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: Row(
            key: ValueKey<String>(
              'income-range:$selectedRange:${_incomePeriodSuffix()}:$_incomePrivate',
            ),
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  selectedRange,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF111827),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _incomePeriodSuffix(),
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Icon(privacyIcon, size: 16, color: privacyIconColor),
            ],
          ),
        ),
      ),
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
        OnboardingErrorHighlight(
          hasError: _workingWithError != null,
          pulseKey: 'working_with:$_workingWithError:${_workingWith?.identity}',
          child: OnboardingPickerField(
            label: _t('Working with', 'कामाचा प्रकार'),
            selectedItems: _workingWith == null ? const [] : [_workingWith!],
            placeholder: _t('Select work type', 'कामाचा प्रकार निवडा'),
            searchHint: _t('Search work type', 'कामाचा प्रकार शोधा'),
            loadPage: _workingWithPage,
            errorText: _workingWithError,
            onChanged: (items) => setState(() {
              final next = items.isEmpty ? null : items.first;
              if (_workingWith?.identity != next?.identity) {
                _occupation = null;
                _amountController.clear();
                _minAmountController.clear();
                _maxAmountController.clear();
              }
              _workingWith = next;
              _workingWithError = null;
              _occupationError = null;
            }),
          ),
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
          OnboardingErrorHighlight(
            hasError: _occupationError != null,
            pulseKey: 'occupation:$_occupationError:${_occupation?.identity}',
            child: OnboardingPickerField(
              label: _t('Working as', 'व्यवसाय'),
              selectedItems: _occupation == null ? const [] : [_occupation!],
              enabled: _workingWith != null,
              placeholder: _t('Select occupation', 'व्यवसाय निवडा'),
              searchHint: _t('Search occupation', 'व्यवसाय शोधा'),
              loadPage: _occupationPage,
              itemSubtitleBuilder: (option) =>
                  option.metaText('category_label'),
              allowRequestToAdd: true,
              onRequestToAdd: _showOccupationSuggestionDialog,
              errorText: _occupationError,
              onChanged: (items) => setState(() {
                _occupation = items.isEmpty ? null : items.first;
                _occupationError = null;
              }),
            ),
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
