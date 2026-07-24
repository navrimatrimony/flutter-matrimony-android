import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import '../widgets/onboarding_picker_field.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';
import '../../../core/app_language.dart';

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

  @override
  void initState() {
    super.initState();
    _prefill();
    _loadIncomeOptions();
  }

  @override
  void didUpdateWidget(covariant CareerStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.data, widget.data)) _prefill();
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
        _placeholder(data['occupation_master_id']);
    _companyController.text = onboardingText(data['company_name']) ?? '';
    _workLocationController.text =
        onboardingText(data['work_location_text']) ?? '';
    _amountController.text =
        onboardingText(data['income_amount'] ?? data['annual_income']) ?? '';
    _minAmountController.text = onboardingText(data['income_min_amount']) ?? '';
    _maxAmountController.text = onboardingText(data['income_max_amount']) ?? '';
    _incomePrivate = onboardingBool(data['income_private']) ?? true;
  }


  OnboardingOption? _placeholder(dynamic id) {
    return selectedValuePlaceholderOption(id, widget.locale, failed: true);
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

    await widget.onSave('career', payload, saveProfile: true);
  }

  Future<void> _continue() async {
    if (_page == 0 && _workingWith == null) {
      widget.onMessage(appText.chooseWorkDetails);
      return;
    }

    if (_notWorking) {
      await _save();
      return;
    }

    if (_page == 1 && _occupation == null) {
      widget.onMessage(appText.chooseOccupation);
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
        return appText.workDetails;
      case 1:
        return appText.occupation;
      default:
        return appText.annualIncome;
    }
  }

  String? get _pageSubtitle {
    switch (_page) {
      case 0:
        return appText.selectTheCurrentWorkType;
      case 1:
        return appText.addOccupationAndOptionalWorkInfo;
      default:
        return appText.incomeCanBeKeptPrivate;
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
            title: Text(appText.requestOccupation),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: label,
                    decoration: InputDecoration(
                      labelText: appText.occupationLabel,
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
                      labelText: appText.notesOptional,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appText.pendingSuggestionsAreNotSelectedAs,
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
                        ? appText.occupationRequestSubmitted
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
    return OnboardingStepScaffold(
      title: _pageTitle,
      subtitle: _pageSubtitle,
      loading: widget.loading,
      onBack: _back,
      onContinue: _continue,
      continueLabel: _page < 2 && !_notWorking
          ? appText.continueLabel
          : appText.saveAndContinue,
      secondary: _page == 1
          ? OutlinedButton.icon(
              onPressed: widget.loading || _workingWith == null
                  ? null
                  : _showSuggestionDialog,
              icon: const Icon(Icons.add),
              label: Text(
                appText.notFoundRequestOccupation,
              ),
            )
          : null,
      children: switch (_page) {
        0 => [
          OnboardingPickerField(
            label: appText.workingWith,
            selectedItems: _workingWith == null ? const [] : [_workingWith!],
            placeholder: appText.selectWorkType,
            searchHint: appText.searchWorkType,
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
              appText.occupationAndIncomeAreOptionalWhen,
            ),
          ],
        ],
        1 => [
          OnboardingPickerField(
            label: appText.workingAs,
            selectedItems: _occupation == null ? const [] : [_occupation!],
            enabled: _workingWith != null,
            placeholder: appText.selectOccupation,
            searchHint: appText.searchOccupation,
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
              labelText: appText.companyOptional,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _workLocationController,
            decoration: InputDecoration(
              labelText: appText.workLocationOptional,
            ),
          ),
        ],
        _ => [
          Row(
            children: [
              Expanded(
                child: OnboardingPickerField(
                  label: appText.incomePeriod,
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
                  label: appText.incomeType,
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
                        labelText: appText.minIncome,
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
                        labelText: appText.maxIncome,
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
                  labelText: appText.incomeAmount,
                  prefixText: _currencySymbol,
                ),
              ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(appText.keepIncomePrivate),
            value: _incomePrivate,
            onChanged: (value) => setState(() => _incomePrivate = value),
          ),
        ],
      },
    );
  }
}
