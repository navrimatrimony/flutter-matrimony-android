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
        _fields = _fieldsFromSnapshot(_snapshot);
        _errorMessage = _fields.isEmpty
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
    if (_processing || _saving || _fields.isEmpty) return;
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
    final snapshot = Map<String, dynamic>.from(_snapshot);
    snapshot['snapshot_schema_version'] =
        snapshot['snapshot_schema_version'] ?? 1;

    final core = Map<String, dynamic>.from(_safeMap(snapshot['core']) ?? {});
    for (final field in _fields) {
      final value = field.value.trim();
      if (value.isEmpty) {
        core.remove(field.key);
      } else {
        core[field.key] = _coerceFieldValue(field.key, value);
      }
    }
    snapshot['core'] = core;

    return snapshot;
  }

  dynamic _coerceFieldValue(String key, String value) {
    if (key == 'height_cm' || key == 'annual_income') {
      return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? value;
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

  List<_DraftField> _fieldsFromSnapshot(Map<String, dynamic> snapshot) {
    final core = _safeMap(snapshot['core']) ?? <String, dynamic>{};
    final fields = <_DraftField>[];
    final usedKeys = <String>{};

    for (final seed in _preferredSeeds()) {
      final found = seed.sourceKeys
          .map((key) => MapEntry(key, _stringValue(core[key])))
          .firstWhere(
            (entry) => entry.value != null,
            orElse: () => const MapEntry('', null),
          );
      if (found.value == null) continue;

      fields.add(
        _DraftField(
          key: seed.key,
          label: seed.label,
          value: found.value!,
          keyboardType: seed.keyboardType,
          maxLines: seed.maxLines,
        ),
      );
      usedKeys.addAll(seed.sourceKeys);
      usedKeys.add(seed.key);
    }

    for (final entry in core.entries) {
      final key = entry.key.toString();
      if (usedKeys.contains(key) || !_showExtraCoreField(key, entry.value)) {
        continue;
      }

      final value = _stringValue(entry.value);
      if (value == null) continue;
      fields.add(
        _DraftField(
          key: key,
          label: _fieldLabel(key),
          value: value,
          maxLines: value.length > 70 ? 3 : 1,
        ),
      );
      if (fields.length >= 18) break;
    }

    return fields;
  }

  List<_DraftFieldSeed> _preferredSeeds() {
    return <_DraftFieldSeed>[
      _DraftFieldSeed(
        key: 'full_name',
        label: AppStrings.name,
        sourceKeys: const <String>['full_name', 'name', 'candidate_name'],
        keyboardType: TextInputType.name,
      ),
      _DraftFieldSeed(
        key: 'date_of_birth',
        label: AppStrings.dateOfBirth,
        sourceKeys: const <String>['date_of_birth', 'dob', 'birth_date'],
        keyboardType: TextInputType.datetime,
      ),
      _DraftFieldSeed(
        key: 'birth_time',
        label: AppStrings.isMarathi ? 'जन्मवेळ' : 'Birth time',
        sourceKeys: const <String>['birth_time'],
        keyboardType: TextInputType.datetime,
      ),
      _DraftFieldSeed(
        key: 'birth_place',
        label: AppStrings.isMarathi ? 'जन्म ठिकाण' : 'Birth place',
        sourceKeys: const <String>['birth_place', 'birth_place_text'],
      ),
      _DraftFieldSeed(
        key: 'height_cm',
        label: AppStrings.isMarathi ? 'उंची' : 'Height',
        sourceKeys: const <String>['height_cm', 'height'],
        keyboardType: TextInputType.number,
      ),
      _DraftFieldSeed(
        key: 'education',
        label: AppStrings.education,
        sourceKeys: const <String>[
          'education',
          'highest_education',
          'education_text',
        ],
      ),
      _DraftFieldSeed(
        key: 'profession',
        label: AppStrings.isMarathi ? 'व्यवसाय' : 'Profession',
        sourceKeys: const <String>[
          'profession',
          'occupation',
          'occupation_text',
        ],
      ),
      _DraftFieldSeed(
        key: 'company_name',
        label: AppStrings.isMarathi ? 'कंपनी' : 'Company',
        sourceKeys: const <String>['company_name'],
      ),
      _DraftFieldSeed(
        key: 'annual_income',
        label: AppStrings.isMarathi ? 'वार्षिक उत्पन्न' : 'Annual income',
        sourceKeys: const <String>['annual_income', 'income'],
        keyboardType: TextInputType.number,
      ),
      _DraftFieldSeed(
        key: 'religion',
        label: AppStrings.isMarathi ? 'धर्म' : 'Religion',
        sourceKeys: const <String>['religion'],
      ),
      _DraftFieldSeed(
        key: 'caste',
        label: AppStrings.caste,
        sourceKeys: const <String>['caste'],
      ),
      _DraftFieldSeed(
        key: 'sub_caste',
        label: AppStrings.isMarathi ? 'पोटजात' : 'Sub caste',
        sourceKeys: const <String>['sub_caste'],
      ),
      _DraftFieldSeed(
        key: 'gotra',
        label: AppStrings.isMarathi ? 'गोत्र' : 'Gotra',
        sourceKeys: const <String>['gotra'],
      ),
      _DraftFieldSeed(
        key: 'rashi',
        label: AppStrings.isMarathi ? 'राशी' : 'Rashi',
        sourceKeys: const <String>['rashi'],
      ),
      _DraftFieldSeed(
        key: 'nakshatra',
        label: AppStrings.isMarathi ? 'नक्षत्र' : 'Nakshatra',
        sourceKeys: const <String>['nakshatra'],
      ),
      _DraftFieldSeed(
        key: 'father_name',
        label: AppStrings.isMarathi ? 'वडिलांचे नाव' : 'Father name',
        sourceKeys: const <String>['father_name'],
      ),
      _DraftFieldSeed(
        key: 'mother_name',
        label: AppStrings.isMarathi ? 'आईचे नाव' : 'Mother name',
        sourceKeys: const <String>['mother_name'],
      ),
      _DraftFieldSeed(
        key: 'other_relatives_text',
        label: AppStrings.isMarathi ? 'नातेवाईक' : 'Relatives',
        sourceKeys: const <String>['other_relatives_text'],
        maxLines: 3,
      ),
    ];
  }

  bool _showExtraCoreField(String key, dynamic value) {
    if (value is Map || value is List) return false;
    if (key == 'primary_contact_number') return false;
    if (key.endsWith('_id') || key.endsWith('_ids')) return false;
    if (key.endsWith('_suggestion_applied')) return false;
    if (key.startsWith('_')) return false;
    return _stringValue(value) != null;
  }

  String _fieldLabel(String key) {
    final normalized = key.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return AppStrings.noInformation;
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

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
            for (final field in _fields) ...[
              TextFormField(
                initialValue: field.value,
                keyboardType: field.keyboardType,
                maxLines: field.maxLines,
                textInputAction: field.maxLines > 1
                    ? TextInputAction.newline
                    : TextInputAction.next,
                decoration: InputDecoration(labelText: field.label),
                onChanged: (value) => field.value = value,
                onSaved: (value) => field.value = value?.trim() ?? '',
              ),
              const SizedBox(height: 12),
            ],
          ],
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
    final hasDraft = _fields.isNotEmpty;
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
    required this.key,
    required this.label,
    required this.value,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  final String key;
  final String label;
  String value;
  final TextInputType keyboardType;
  final int maxLines;
}

class _DraftFieldSeed {
  const _DraftFieldSeed({
    required this.key,
    required this.label,
    required this.sourceKeys,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  final String key;
  final String label;
  final List<String> sourceKeys;
  final TextInputType keyboardType;
  final int maxLines;
}
