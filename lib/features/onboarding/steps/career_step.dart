import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import '../widgets/onboarding_picker_field.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';

class CareerStep extends StatefulWidget {
  const CareerStep({
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
  State<CareerStep> createState() => _CareerStepState();
}

class _CareerStepState extends State<CareerStep> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _workLocationController = TextEditingController();

  OnboardingOption? _workingWith;
  OnboardingOption? _occupation;
  OnboardingOption? _period;
  OnboardingOption? _valueType;
  List<OnboardingOption> _periods = <OnboardingOption>[];
  List<OnboardingOption> _valueTypes = <OnboardingOption>[];
  int? _currencyId;
  String _currencySymbol = '₹';
  bool _incomePrivate = true;
  int _page = 0;

  bool get _mr => widget.locale == 'mr';

  @override
  void initState() {
    super.initState();
    _prefill();
    _loadIncomeOptions();
  }

  @override
  void didUpdateWidget(covariant CareerStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _prefill();
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

  void _prefill() {
    final data = widget.data;
    _workingWith =
        optionFromData(data['working_with_option']) ??
        _workingWithPlaceholder(data['working_with']);
    _occupation =
        optionFromData(data['occupation_option']) ??
        _placeholder(data['occupation_master_id'], 'Occupation');
    _companyController.text = onboardingText(data['company_name']) ?? '';
    _workLocationController.text =
        onboardingText(data['work_location_text']) ?? '';
    _amountController.text =
        onboardingText(data['income_amount'] ?? data['annual_income']) ?? '';
    _minAmountController.text = onboardingText(data['income_min_amount']) ?? '';
    _maxAmountController.text = onboardingText(data['income_max_amount']) ?? '';
    _incomePrivate = onboardingBool(data['income_private']) ?? true;
  }

  String _t(String en, String mr) => _mr ? mr : en;

  OnboardingOption? _placeholder(dynamic id, String label) {
    final intId = onboardingInt(id);
    if (intId == null) return null;
    return OnboardingOption(id: intId, label: '$label #$intId');
  }

  OnboardingOption? _workingWithPlaceholder(dynamic key) {
    final text = onboardingText(key);
    if (text == null) return null;
    return OnboardingOption(key: text, label: text);
  }

  bool get _notWorking {
    final text = '${_workingWith?.key ?? ''} ${_workingWith?.label ?? ''}'
        .toLowerCase()
        .replaceAll('-', ' ');
    return text.contains('not working') ||
        text.contains('unemployed') ||
        text.contains('काम करत नाही');
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
            optionByKey(periods, widget.data['income_period']) ??
            optionByKey(periods, 'annual') ??
            (periods.isNotEmpty ? periods.first : null);
        _valueType ??=
            optionByKey(valueTypes, widget.data['income_value_type']) ??
            optionByKey(valueTypes, 'approximate') ??
            (valueTypes.isNotEmpty ? valueTypes.first : null);
        _incomePrivate =
            onboardingBool(widget.data['income_private']) ??
            (data['privacy_default']?.toString() == 'private');
      });
    } catch (_) {
      return;
    }
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

  Future<PagedLookupResponse> _staticPage(
    List<OnboardingOption> options,
    String query,
    int page,
    int limit,
  ) async {
    final q = query.trim().toLowerCase();
    final rows = options.where((option) {
      return q.isEmpty ||
          option.label.toLowerCase().contains(q) ||
          (option.key?.toLowerCase().contains(q) ?? false);
    }).toList();
    final start = (page - 1) * limit;
    return PagedLookupResponse.fromOptions(
      start >= rows.length ? const [] : rows.skip(start).take(limit).toList(),
    );
  }

  Future<void> _save() async {
    final valueType = _valueType?.key;
    final amount = onboardingInt(_amountController.text);
    final minAmount = onboardingInt(_minAmountController.text);
    final maxAmount = onboardingInt(_maxAmountController.text);
    final incomeEnabled = !_notWorking && valueType != null;

    final payload = compactPayload({
      'working_with': _workingWith?.key ?? _workingWith?.id?.toString(),
      'occupation_master_id': _notWorking ? null : _occupation?.intId,
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

    await widget.onSave('career', payload, saveProfile: true);
  }

  Future<void> _continue() async {
    if (_page == 0 && _workingWith == null) {
      widget.onMessage(_t('Choose work details.', 'कामाची माहिती निवडा.'));
      return;
    }

    if (_notWorking) {
      await _save();
      return;
    }

    if (_page == 1 && _occupation == null) {
      widget.onMessage(_t('Choose occupation.', 'व्यवसाय निवडा.'));
      return;
    }

    if (_page < 2) {
      setState(() => _page += 1);
      return;
    }

    await _save();
  }

  void _back() {
    if (_page > 0) {
      setState(() => _page -= 1);
      return;
    }

    widget.onBack();
  }

  String get _pageTitle {
    switch (_page) {
      case 0:
        return _t('Work details', 'कामाची माहिती');
      case 1:
        return _t('Occupation', 'व्यवसाय');
      default:
        return _t('Annual income', 'वार्षिक उत्पन्न');
    }
  }

  String? get _pageSubtitle {
    switch (_page) {
      case 0:
        return _t(
          'Select the current work type.',
          'सध्याचा कामाचा प्रकार निवडा.',
        );
      case 1:
        return _t(
          'Add occupation and optional work info.',
          'व्यवसाय आणि कामाची optional माहिती भरा.',
        );
      default:
        return _t('Income can be kept private.', 'उत्पन्न private ठेवू शकता.');
    }
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

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: _pageTitle,
      subtitle: _pageSubtitle,
      loading: widget.loading,
      onBack: _back,
      onContinue: _continue,
      continueLabel: _page < 2 && !_notWorking
          ? _t('Continue', 'पुढे जा')
          : _t('Save and continue', 'Save करून पुढे जा'),
      secondary: _page == 1
          ? OutlinedButton.icon(
              onPressed: widget.loading || _workingWith == null
                  ? null
                  : _showSuggestionDialog,
              icon: const Icon(Icons.add),
              label: Text(
                _t('Not found? Request occupation', 'Occupation request करा'),
              ),
            )
          : null,
      children: switch (_page) {
        0 => [
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
            const SizedBox(height: 12),
            Text(
              _t(
                'Occupation and income are optional when not working.',
                'काम करत नसल्यास व्यवसाय आणि उत्पन्न optional आहे.',
              ),
            ),
          ],
        ],
        1 => [
          OnboardingPickerField(
            label: _t('Working as', 'व्यवसाय'),
            selectedItems: _occupation == null ? const [] : [_occupation!],
            enabled: _workingWith != null,
            placeholder: _t('Select occupation', 'व्यवसाय निवडा'),
            searchHint: _t('Search occupation', 'व्यवसाय शोधा'),
            loadPage: _occupationPage,
            itemSubtitleBuilder: (option) => option.metaText('category_label'),
            allowRequestToAdd: true,
            onRequestToAdd: _showSuggestionDialog,
            onChanged: (items) => setState(() {
              _occupation = items.isEmpty ? null : items.first;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _companyController,
            decoration: InputDecoration(
              labelText: _t('Company optional', 'Company optional'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _workLocationController,
            decoration: InputDecoration(
              labelText: _t('Work location optional', 'Work location optional'),
            ),
          ),
        ],
        _ => [
          Row(
            children: [
              Expanded(
                child: OnboardingPickerField(
                  label: _t('Income period', 'Income period'),
                  selectedItems: _period == null ? const [] : [_period!],
                  loadPage: (query, page, limit) =>
                      _staticPage(_periods, query, page, limit),
                  onChanged: (items) => setState(() {
                    _period = items.isEmpty ? null : items.first;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OnboardingPickerField(
                  label: _t('Income type', 'Income type'),
                  selectedItems: _valueType == null ? const [] : [_valueType!],
                  loadPage: (query, page, limit) =>
                      _staticPage(_valueTypes, query, page, limit),
                  onChanged: (items) => setState(() {
                    _valueType = items.isEmpty ? null : items.first;
                  }),
                ),
              ),
            ],
          ),
          if (_valueType?.key != 'undisclosed') ...[
            const SizedBox(height: 12),
            if (_valueType?.key == 'range')
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minAmountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _t('Min income', 'Min income'),
                        prefixText: _currencySymbol,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _maxAmountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _t('Max income', 'Max income'),
                        prefixText: _currencySymbol,
                      ),
                    ),
                  ),
                ],
              )
            else
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _t('Income amount', 'Income amount'),
                  prefixText: _currencySymbol,
                ),
              ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_t('Keep income private', 'Income private ठेवा')),
            value: _incomePrivate,
            onChanged: (value) => setState(() => _incomePrivate = value),
          ),
        ],
      },
    );
  }
}
