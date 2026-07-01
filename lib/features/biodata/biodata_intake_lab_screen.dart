import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/app_strings.dart';

class BiodataIntakeLabScreen extends StatefulWidget {
  const BiodataIntakeLabScreen({super.key});

  @override
  State<BiodataIntakeLabScreen> createState() => _BiodataIntakeLabScreenState();
}

class _BiodataIntakeLabScreenState extends State<BiodataIntakeLabScreen> {
  static const Color _brand = Color(0xFFDC2626);
  static const Color _ink = Color(0xFF251D1D);
  static const Color _muted = Color(0xFF786A64);
  static const Color _surface = Color(0xFFFFFBF7);
  static const Color _border = Color(0xFFE7DAD4);
  static const Set<String> _integerCoreKeys = <String>{
    'gender_id',
    'height_cm',
    'marital_status_id',
    'mother_tongue_id',
    'religion_id',
    'caste_id',
    'sub_caste_id',
    'location_id',
    'working_with_type_id',
    'occupation_master_id',
    'annual_income',
    'income_amount',
    'income_min_amount',
    'income_max_amount',
    'income_currency_id',
    'diet_id',
    'smoking_status_id',
    'drinking_status_id',
    'physical_build_id',
  };

  final ImagePicker _picker = ImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Timer? _messageTimer;
  int _messageIndex = 0;
  bool _processing = false;
  bool _saving = false;
  String? _errorMessage;
  String? _rawText;
  Map<String, dynamic>? _intake;
  Map<String, dynamic> _snapshot = <String, dynamic>{};
  List<_DraftField> _fields = <_DraftField>[];

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickAndProcess(ImageSource source) async {
    if (_processing || _saving) return;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2000,
      maxHeight: 2600,
    );
    if (picked == null) return;

    setState(() {
      _processing = true;
      _saving = false;
      _errorMessage = null;
      _rawText = null;
      _intake = null;
      _snapshot = <String, dynamic>{};
      _fields = <_DraftField>[];
      _messageIndex = 0;
    });
    _startMessageRotation();

    try {
      final text = await _extractText(picked.path);
      final normalizedText = _cleanOcrText(text);
      if (normalizedText.length < 20) {
        _setProcessingError(AppStrings.biodataIntakeNoReadableText);
        return;
      }

      final response = await ApiClient.createBiodataIntakeFromText(
        rawText: normalizedText,
        parseNow: true,
      );
      if (!_responseOk(response)) {
        _setProcessingError(
          _responseMessage(response, AppStrings.biodataIntakeProcessFailed),
        );
        return;
      }

      final intake = _safeMap(response['intake']) ?? _safeMap(response['data']);
      Map<String, dynamic>? preview = _safeMap(response['preview']);
      final intakeId = _intValue(intake?['id']);

      if ((preview == null || preview['ready'] == false) && intakeId != null) {
        final previewResponse = await ApiClient.getBiodataIntakePreview(
          intakeId,
        );
        if (_responseOk(previewResponse)) {
          preview = _safeMap(previewResponse['preview']) ?? previewResponse;
        }
      }

      if (!mounted) return;
      setState(() {
        _rawText = normalizedText;
        _intake = intake;
        _snapshot = _snapshotFromPreview(preview);
        _fields = _onboardingFieldsFromPreview(preview);
        _errorMessage = !_hasSaveableDraft
            ? AppStrings.biodataIntakeFieldsEmpty
            : null;
      });
    } catch (error) {
      _setProcessingError(
        '${AppStrings.biodataIntakeProcessFailed} ${error.toString()}',
      );
    } finally {
      await _deleteTemporaryPickedFile(picked.path);
      _stopProcessing();
    }
  }

  Future<String> _extractText(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.devanagiri);
    try {
      final inputImage = InputImage.fromFilePath(path);
      final recognized = await recognizer.processImage(inputImage);
      return recognized.text;
    } finally {
      await recognizer.close();
    }
  }

  void _startMessageRotation() {
    _messageTimer?.cancel();
    _messageTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_processing) return;
      final messages = AppStrings.biodataIntakeProcessingMessages;
      setState(() {
        _messageIndex = (_messageIndex + 1) % messages.length;
      });
    });
  }

  void _stopProcessing() {
    _messageTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _processing = false;
      _messageIndex = 0;
    });
  }

  void _setProcessingError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
    });
  }

  Future<void> _approveSnapshot() async {
    if (_processing || _saving || !_hasSaveableDraft) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();

    final intakeId = _intValue(_intake?['id']);
    if (intakeId == null) {
      _showSnackBar(AppStrings.biodataIntakeProcessFailed);
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.approveBiodataIntake(
        intakeId: intakeId,
        snapshot: _editedSnapshot(),
      );
      if (!_responseOk(response)) {
        _showSnackBar(
          _responseMessage(response, AppStrings.biodataIntakeSaveFailed),
        );
        return;
      }

      await ApiClient.getMyProfile().catchError((_) => <String, dynamic>{});
      if (!mounted) return;

      final awaitingAdmin =
          _boolValue(response['awaiting_admin']) ||
          _boolValue(_safeMap(response['result'])?['awaiting_admin']);
      _showSnackBar(
        awaitingAdmin
            ? AppStrings.biodataIntakeSavePending
            : AppStrings.biodataIntakeSaveSuccess,
      );
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (error) {
      _showSnackBar(
        '${AppStrings.biodataIntakeSaveFailed} ${error.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Map<String, dynamic> _editedSnapshot() {
    final core = <String, dynamic>{};
    for (final field in _fields) {
      if (!field.saveEnabled) continue;

      final value = field.editable
          ? _coerceFieldValue(field.key, field.value.trim())
          : field.saveValue;
      if (!_isEmptyDraftValue(value)) {
        core[field.key] = value;
      }
    }

    return <String, dynamic>{
      'snapshot_schema_version':
          _intValue(_snapshot['snapshot_schema_version']) ?? 1,
      'core': core,
    };
  }

  dynamic _coerceFieldValue(String key, String value) {
    if (_integerCoreKeys.contains(key)) {
      return _cleanInteger(value) ?? value;
    }
    return value;
  }

  Map<String, dynamic> _snapshotFromPreview(Map<String, dynamic>? preview) {
    final approval = _safeMap(preview?['approval_snapshot']);
    if (approval != null && approval.isNotEmpty) return approval;

    final parsed = _safeMap(preview?['parsed_snapshot']);
    if (parsed != null && parsed.isNotEmpty) return parsed;

    final snapshot = _safeMap(preview?['snapshot']);
    if (snapshot != null && snapshot.isNotEmpty) return snapshot;

    return <String, dynamic>{'snapshot_schema_version': 1, 'core': {}};
  }

  bool get _hasSaveableDraft =>
      _fields.any((field) => field.saveEnabled && field.key.isNotEmpty);

  List<_DraftField> _onboardingFieldsFromPreview(
    Map<String, dynamic>? preview,
  ) {
    final snapshot = _snapshotFromPreview(preview);
    final rawDraft = _rawDraftFromPreview(preview);
    final core = _mergedCoreFromPreview(snapshot, rawDraft);
    final address = _firstCurrentAddress(snapshot, rawDraft);
    final fields = <_DraftField>[];

    void addText({
      required String section,
      required String key,
      required String label,
      required List<String> sourceKeys,
      TextInputType keyboardType = TextInputType.text,
      int maxLines = 1,
    }) {
      final value = _firstString(core, sourceKeys);
      if (value == null) return;
      fields.add(
        _DraftField(
          section: section,
          key: key,
          label: label,
          value: value,
          keyboardType: keyboardType,
          maxLines: maxLines,
        ),
      );
    }

    void addParsedInteger({
      required String section,
      required String key,
      required String label,
      required List<String> sourceKeys,
      required int? Function(String? value) parser,
    }) {
      final rawValue = _firstString(core, sourceKeys);
      final parsedValue = parser(rawValue);
      if (parsedValue != null) {
        fields.add(
          _DraftField(
            section: section,
            key: key,
            label: label,
            value: parsedValue.toString(),
            helperText: rawValue != null && rawValue != parsedValue.toString()
                ? rawValue
                : null,
            keyboardType: TextInputType.number,
          ),
        );
        return;
      }
      if (rawValue == null) return;
      fields.add(
        _DraftField.note(
          section: section,
          label: label,
          value: rawValue,
          helperText: _text(
            'Detected text needs numeric review before saving',
            'Save करण्याआधी हा आकडा तपासावा लागेल',
          ),
        ),
      );
    }

    void addControlled({
      required String section,
      required String idKey,
      required String label,
      required List<String> idKeys,
      required List<String> labelKeys,
      String? textFallbackKey,
    }) {
      final id = _firstInt(core, idKeys);
      final displayLabel = _firstDisplayLabel(core, labelKeys);
      if (id != null && id > 0) {
        fields.add(
          _DraftField.readOnly(
            section: section,
            key: idKey,
            label: label,
            value: displayLabel ?? _selectedIdLabel(id),
            saveValue: id,
          ),
        );
        return;
      }

      if (displayLabel == null) return;
      fields.add(
        textFallbackKey == null
            ? _DraftField.note(
                section: section,
                label: label,
                value: displayLabel,
                helperText: _text(
                  'Needs selection before saving',
                  'Save करण्याआधी निवड करावी लागेल',
                ),
              )
            : _DraftField(
                section: section,
                key: textFallbackKey,
                label: label,
                value: displayLabel,
              ),
      );
    }

    final basic = _text('Basic details', 'मूलभूत माहिती');
    final community = _text('Community', 'समुदाय');
    final residence = _text('Residence', 'राहण्याचे ठिकाण');
    final career = _text('Education & career', 'शिक्षण आणि करिअर');
    final lifestyle = _text('Lifestyle', 'जीवनशैली');

    addText(
      section: basic,
      key: 'full_name',
      label: AppStrings.name,
      sourceKeys: const <String>['full_name', 'name', 'candidate_name'],
      keyboardType: TextInputType.name,
    );
    addControlled(
      section: basic,
      idKey: 'gender_id',
      label: _text('Gender', 'लिंग'),
      idKeys: const <String>['gender_id'],
      labelKeys: const <String>['gender', 'gender_label', 'gender_option'],
    );
    addText(
      section: basic,
      key: 'date_of_birth',
      label: AppStrings.dateOfBirth,
      sourceKeys: const <String>['date_of_birth', 'dob', 'birth_date'],
      keyboardType: TextInputType.datetime,
    );
    addParsedInteger(
      section: basic,
      key: 'height_cm',
      label: _text('Height', 'उंची'),
      sourceKeys: const <String>['height_cm', 'height', 'height_text'],
      parser: _parseHeightCm,
    );
    addControlled(
      section: basic,
      idKey: 'marital_status_id',
      label: _text('Marital status', 'वैवाहिक स्थिती'),
      idKeys: const <String>['marital_status_id'],
      labelKeys: const <String>[
        'marital_status',
        'marital_status_label',
        'marital_status_option',
      ],
      textFallbackKey: 'marital_status',
    );
    addControlled(
      section: community,
      idKey: 'mother_tongue_id',
      label: _text('Mother tongue', 'मातृभाषा'),
      idKeys: const <String>['mother_tongue_id'],
      labelKeys: const <String>[
        'mother_tongue',
        'mother_tongue_label',
        'mother_tongue_option',
      ],
      textFallbackKey: 'mother_tongue',
    );
    addControlled(
      section: community,
      idKey: 'religion_id',
      label: _text('Religion', 'धर्म'),
      idKeys: const <String>['religion_id'],
      labelKeys: const <String>[
        'religion',
        'religion_label',
        'religion_option',
      ],
      textFallbackKey: 'religion',
    );
    addControlled(
      section: community,
      idKey: 'caste_id',
      label: AppStrings.caste,
      idKeys: const <String>['caste_id'],
      labelKeys: const <String>['caste', 'caste_label', 'caste_option'],
      textFallbackKey: 'caste',
    );
    addControlled(
      section: community,
      idKey: 'sub_caste_id',
      label: _text('Sub caste', 'पोटजात'),
      idKeys: const <String>['sub_caste_id'],
      labelKeys: const <String>[
        'sub_caste',
        'sub_caste_label',
        'sub_caste_option',
      ],
      textFallbackKey: 'sub_caste',
    );

    _addLocationField(fields, residence, core, address);

    addText(
      section: career,
      key: 'highest_education',
      label: AppStrings.education,
      sourceKeys: const <String>[
        'highest_education',
        'education',
        'education_text',
      ],
    );
    addControlled(
      section: career,
      idKey: 'working_with_type_id',
      label: _text('Working with', 'कामाचे स्वरूप'),
      idKeys: const <String>['working_with_type_id'],
      labelKeys: const <String>[
        'working_with',
        'working_with_label',
        'working_with_type',
      ],
    );
    addControlled(
      section: career,
      idKey: 'occupation_master_id',
      label: _text('Occupation', 'व्यवसाय'),
      idKeys: const <String>['occupation_master_id'],
      labelKeys: const <String>[
        'occupation_title',
        'occupation',
        'profession',
        'profession_label',
      ],
      textFallbackKey: 'occupation_title',
    );
    addText(
      section: career,
      key: 'company_name',
      label: _text('Company', 'कंपनी'),
      sourceKeys: const <String>['company_name'],
    );
    addText(
      section: career,
      key: 'work_location_text',
      label: _text('Work location', 'कामाचे ठिकाण'),
      sourceKeys: const <String>['work_location_text', 'work_location'],
    );
    addParsedInteger(
      section: career,
      key: 'annual_income',
      label: _text('Annual income', 'वार्षिक उत्पन्न'),
      sourceKeys: const <String>[
        'annual_income',
        'income_normalized_annual_amount',
        'income_amount',
      ],
      parser: _cleanInteger,
    );
    addText(
      section: career,
      key: 'income_period',
      label: _text('Income period', 'उत्पन्न कालावधी'),
      sourceKeys: const <String>['income_period'],
    );
    addText(
      section: career,
      key: 'income_value_type',
      label: _text('Income type', 'उत्पन्न प्रकार'),
      sourceKeys: const <String>['income_value_type'],
    );

    addControlled(
      section: lifestyle,
      idKey: 'diet_id',
      label: _text('Diet', 'आहार'),
      idKeys: const <String>['diet_id'],
      labelKeys: const <String>['diet', 'diet_label', 'diet_option'],
      textFallbackKey: 'diet',
    );
    addControlled(
      section: lifestyle,
      idKey: 'smoking_status_id',
      label: _text('Smoking', 'धूम्रपान'),
      idKeys: const <String>['smoking_status_id'],
      labelKeys: const <String>[
        'smoking_status',
        'smoking',
        'smoking_status_label',
      ],
      textFallbackKey: 'smoking_status',
    );
    addControlled(
      section: lifestyle,
      idKey: 'drinking_status_id',
      label: _text('Drinking', 'मद्यपान'),
      idKeys: const <String>['drinking_status_id'],
      labelKeys: const <String>[
        'drinking_status',
        'drinking',
        'drinking_status_label',
      ],
      textFallbackKey: 'drinking_status',
    );
    addControlled(
      section: lifestyle,
      idKey: 'physical_build_id',
      label: _text('Physical build', 'शारीरिक बांधा'),
      idKeys: const <String>['physical_build_id'],
      labelKeys: const <String>[
        'physical_build',
        'physical_build_label',
        'physical_build_option',
      ],
      textFallbackKey: 'physical_build',
    );
    addText(
      section: lifestyle,
      key: 'spectacles_lens',
      label: _text('Spectacles / lens', 'चष्मा / लेन्स'),
      sourceKeys: const <String>['spectacles_lens'],
    );

    return fields;
  }

  void _addLocationField(
    List<_DraftField> fields,
    String section,
    Map<String, dynamic> core,
    Map<String, dynamic>? address,
  ) {
    final locationId =
        _firstInt(core, const <String>['location_id', 'city_id']) ??
        _firstInt(address, const <String>['location_id', 'city_id']);
    final label =
        _firstDisplayLabel(core, const <String>[
          'location_label',
          'location_option',
          'location',
          'city',
          'city_name',
          'address_line',
        ]) ??
        _firstDisplayLabel(address, const <String>[
          'label',
          'display_label',
          'location',
          'city',
          'city_name',
          'address_line',
          'raw',
        ]);

    if (locationId != null && locationId > 0) {
      fields.add(
        _DraftField.readOnly(
          section: section,
          key: 'location_id',
          label: _text('Residence location', 'राहण्याचे ठिकाण'),
          value: label ?? _selectedIdLabel(locationId),
          saveValue: locationId,
        ),
      );
      final addressLine =
          _firstString(core, const <String>['address_line']) ??
          _firstString(address, const <String>['address_line', 'raw']);
      if (addressLine != null) {
        fields.add(
          _DraftField(
            section: section,
            key: 'address_line',
            label: _text('Address line', 'पत्ता'),
            value: addressLine,
            maxLines: addressLine.length > 70 ? 2 : 1,
          ),
        );
      }
      return;
    }

    if (label == null) return;
    fields.add(
      _DraftField.note(
        section: section,
        label: _text('Detected location', 'ओळखलेले ठिकाण'),
        value: label,
        helperText: _text(
          'Match a residence location before saving',
          'Save करण्याआधी राहण्याचे ठिकाण निवडावे लागेल',
        ),
      ),
    );
  }

  Map<String, dynamic>? _rawDraftFromPreview(Map<String, dynamic>? preview) {
    final normalizedDraft = _safeMap(preview?['normalized_draft']);
    return _safeMap(normalizedDraft?['raw_draft_json']);
  }

  Map<String, dynamic> _mergedCoreFromPreview(
    Map<String, dynamic> snapshot,
    Map<String, dynamic>? rawDraft,
  ) {
    final core = <String, dynamic>{};
    final rawCore = _safeMap(rawDraft?['core']);
    if (rawCore != null) core.addAll(rawCore);
    final snapshotCore = _safeMap(snapshot['core']);
    if (snapshotCore != null) core.addAll(snapshotCore);
    return core;
  }

  Map<String, dynamic>? _firstCurrentAddress(
    Map<String, dynamic> snapshot,
    Map<String, dynamic>? rawDraft,
  ) {
    final candidates = <Map<String, dynamic>>[];
    for (final source in <Map<String, dynamic>?>[snapshot, rawDraft]) {
      final addresses = source?['addresses'];
      if (addresses is! List) continue;
      for (final row in addresses) {
        final map = _safeMap(row);
        if (map != null) candidates.add(map);
      }
    }
    if (candidates.isEmpty) return null;

    bool hasResidenceValue(Map<String, dynamic> row) {
      return _firstInt(row, const <String>['location_id', 'city_id']) != null ||
          _firstString(row, const <String>['address_line', 'raw']) != null;
    }

    bool isSelfCurrent(Map<String, dynamic> row) {
      final scope =
          _stringValue(row['address_scope'] ?? row['scope']) ?? 'self';
      final type =
          _stringValue(
            row['type'] ?? row['address_type_key'] ?? row['address_type'],
          ) ??
          'current';
      return (scope == 'self' || scope.isEmpty) &&
          (type == 'current' || type.isEmpty);
    }

    for (final row in candidates) {
      if (isSelfCurrent(row) && hasResidenceValue(row)) return row;
    }
    for (final row in candidates) {
      if (hasResidenceValue(row)) return row;
    }
    return null;
  }

  String? _firstString(Map<String, dynamic>? values, List<String> keys) {
    if (values == null) return null;
    for (final key in keys) {
      final value = _stringValue(values[key]);
      if (value != null) return value;
    }
    return null;
  }

  int? _firstInt(Map<String, dynamic>? values, List<String> keys) {
    if (values == null) return null;
    for (final key in keys) {
      final value = _intFromValue(values[key]);
      if (value != null) return value;
    }
    return null;
  }

  int? _intFromValue(dynamic value) {
    if (value is Map) {
      for (final key in const <String>['id', 'value', 'key', 'location_id']) {
        final id = _intValue(value[key]);
        if (id != null) return id;
      }
      return null;
    }
    return _intValue(value);
  }

  String? _firstDisplayLabel(Map<String, dynamic>? values, List<String> keys) {
    if (values == null) return null;
    for (final key in keys) {
      final value = _displayLabelFromValue(values[key]);
      if (value != null) return value;
    }
    return null;
  }

  String? _displayLabelFromValue(dynamic value) {
    if (value is Map) {
      for (final key in const <String>[
        'label',
        'display_label',
        'name',
        'name_mr',
        'title',
        'text',
        'value',
      ]) {
        final label = _displayLabelFromValue(value[key]);
        if (label != null) return label;
      }
      return null;
    }
    final text = _stringValue(value);
    if (text == null || _intValue(text) != null) return null;
    return text;
  }

  int? _cleanInteger(String? value) {
    if (value == null) return null;
    final normalized = value.replaceAll(',', '').trim();
    if (!RegExp(r'^\d+$').hasMatch(normalized)) return null;
    return int.tryParse(normalized);
  }

  int? _parseHeightCm(String? value) {
    if (value == null) return null;
    final text = value.toLowerCase().trim();
    final direct = _cleanInteger(text);
    if (direct != null && direct >= 50 && direct <= 250) return direct;

    final cmMatch = RegExp(r'(\d{2,3})\s*cm').firstMatch(text);
    if (cmMatch != null) {
      final cm = int.tryParse(cmMatch.group(1) ?? '');
      if (cm != null && cm >= 50 && cm <= 250) return cm;
    }

    final feetMatch = RegExp(
      r"(\d)\s*(?:ft|feet|')\s*(\d{1,2})?",
    ).firstMatch(text);
    if (feetMatch == null) return null;
    final feet = int.tryParse(feetMatch.group(1) ?? '');
    final inches = int.tryParse(feetMatch.group(2) ?? '0') ?? 0;
    if (feet == null || feet <= 0 || inches < 0 || inches > 11) return null;
    final cm = ((feet * 12 + inches) * 2.54).round();
    if (cm < 50 || cm > 250) return null;
    return cm;
  }

  bool _isEmptyDraftValue(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    return false;
  }

  String _selectedIdLabel(int id) =>
      AppStrings.isMarathi ? 'निवडलेले #$id' : 'Selected #$id';

  String _text(String english, String marathi) =>
      AppStrings.isMarathi ? marathi : english;

  String _cleanOcrText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n')
        .trim();
  }

  Future<void> _deleteTemporaryPickedFile(String path) async {
    final lowerPath = path.toLowerCase();
    final looksTemporary =
        lowerPath.contains('/cache/') ||
        lowerPath.contains('\\cache\\') ||
        lowerPath.contains('image_picker');
    if (!looksTemporary) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup only.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.biodataIntakeTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.dashboard,
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (_) => false,
            ),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      bottomNavigationBar: _processing ? null : _bottomActionBar(),
      body: SafeArea(
        bottom: false,
        child: _processing ? _processingView() : _contentView(),
      ),
    );
  }

  Widget _contentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _introPanel(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _messagePanel(_errorMessage!, isError: true),
          ],
          if (_fields.isNotEmpty) ...[
            const SizedBox(height: 16),
            _reviewForm(),
          ],
          if (_rawText != null && _rawText!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _rawTextPanel(),
          ],
        ],
      ),
    );
  }

  Widget _introPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.document_scanner_outlined, color: _brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.biodataIntakeIntroTitle,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  AppStrings.biodataIntakeIntroSubtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messagePanel(String message, {required bool isError}) {
    final color = isError ? _brand : const Color(0xFF047857);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 14,
                height: 1.28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewForm() {
    final grouped = <String, List<_DraftField>>{};
    for (final field in _fields) {
      grouped.putIfAbsent(field.section, () => <_DraftField>[]).add(field);
    }

    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.biodataIntakeReviewTitle,
              style: const TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.biodataIntakeReviewSubtitle,
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            for (final entry in grouped.entries) ...[
              _sectionHeader(entry.key),
              for (final field in entry.value) ...[
                TextFormField(
                  initialValue: field.value,
                  readOnly: !field.editable,
                  keyboardType: field.keyboardType,
                  maxLines: field.maxLines,
                  textInputAction: field.maxLines > 1
                      ? TextInputAction.newline
                      : TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: field.label,
                    helperText: field.helperText,
                    suffixIcon: field.saveEnabled
                        ? field.editable
                              ? null
                              : const Icon(
                                  Icons.check_circle_outline,
                                  color: Color(0xFF047857),
                                )
                        : const Icon(Icons.info_outline, color: _muted),
                  ),
                  onChanged: field.editable
                      ? (value) => field.value = value
                      : null,
                  onSaved: field.editable
                      ? (value) => field.value = value?.trim() ?? ''
                      : null,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 9),
      child: Text(
        title,
        style: const TextStyle(
          color: _ink,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _rawTextPanel() {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 14),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      collapsedShape: RoundedRectangleBorder(
        side: const BorderSide(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      title: Text(
        AppStrings.biodataIntakeExtractedText,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SelectableText(
            _rawText!,
            style: const TextStyle(color: _ink, height: 1.38),
          ),
        ),
      ],
    );
  }

  Widget _processingView() {
    final messages = AppStrings.biodataIntakeProcessingMessages;
    final message = messages[_messageIndex % messages.length];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: _brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                    color: _brand,
                    strokeWidth: 4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: Text(
                message,
                key: ValueKey<String>(message),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 20,
                  height: 1.3,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.biodataIntakeSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomActionBar() {
    final hasDraft = _hasSaveableDraft;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => _pickAndProcess(
                        hasDraft ? ImageSource.gallery : ImageSource.camera,
                      ),
                icon: Icon(hasDraft ? Icons.refresh : Icons.photo_camera),
                label: Text(
                  hasDraft
                      ? AppStrings.biodataIntakeTryAnother
                      : AppStrings.camera,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saving
                    ? null
                    : hasDraft
                    ? _approveSnapshot
                    : () => _pickAndProcess(ImageSource.gallery),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(hasDraft ? Icons.check : Icons.upload_file),
                label: Text(
                  hasDraft
                      ? AppStrings.biodataIntakeConfirmSave
                      : AppStrings.gallery,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _responseOk(Map<String, dynamic> response) {
    final code = _intValue(response['statusCode']) ?? 0;
    if (response['success'] == false) return false;
    return response['success'] == true || (code >= 200 && code < 300);
  }

  String _responseMessage(Map<String, dynamic> response, String fallback) {
    return _stringValue(response['message']) ??
        _stringValue(_safeMap(response['error'])?['message']) ??
        fallback;
  }

  Map<String, dynamic>? _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  bool _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  String? _stringValue(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DraftField {
  _DraftField({
    required this.section,
    required this.key,
    required this.label,
    required this.value,
    this.helperText,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  }) : saveValue = null,
       editable = true,
       saveEnabled = true;

  _DraftField.readOnly({
    required this.section,
    required this.key,
    required this.label,
    required this.value,
    required this.saveValue,
  }) : editable = false,
       saveEnabled = true,
       helperText = null,
       keyboardType = TextInputType.text,
       maxLines = 1;

  _DraftField.note({
    required this.section,
    required this.label,
    required this.value,
    this.helperText,
  }) : key = '',
       saveValue = null,
       editable = false,
       saveEnabled = false,
       keyboardType = TextInputType.text,
       maxLines = 1;

  final String section;
  final String key;
  final String label;
  String value;
  final dynamic saveValue;
  final bool editable;
  final bool saveEnabled;
  final String? helperText;
  final TextInputType keyboardType;
  final int maxLines;
}
