import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/app_strings.dart';

class BiodataIntakeScreen extends StatefulWidget {
  const BiodataIntakeScreen({super.key});

  @override
  State<BiodataIntakeScreen> createState() => _BiodataIntakeScreenState();
}

class _BiodataIntakeScreenState extends State<BiodataIntakeScreen> {
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
  bool _loadingIntakes = false;
  bool _processing = false;
  bool _saving = false;
  bool _savingReviewSnapshot = false;
  String? _errorMessage;
  String? _rawText;
  String? _pickedImagePath;
  Map<String, dynamic>? _intake;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _intakeSettings;
  Map<String, dynamic> _snapshot = <String, dynamic>{};
  List<Map<String, dynamic>> _intakes = <Map<String, dynamic>>[];
  List<_DraftField> _fields = <_DraftField>[];
  final Set<String> _collapsedPanels = <String>{
    'uploaded_photo',
    'previous_intakes',
    'normalized_draft',
    'parsed_json',
    'debug',
  };
  final Set<String> _expandedReviewSections = <String>{};
  final Set<String> _collapsedReviewSections = <String>{};

  @override
  void initState() {
    super.initState();
    _loadIntakes();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    unawaited(_deleteTemporaryPickedFile(_pickedImagePath));
    super.dispose();
  }

  Future<void> _loadIntakes() async {
    if (_loadingIntakes) return;
    setState(() {
      _loadingIntakes = true;
    });
    try {
      final response = await ApiClient.getBiodataIntakes();
      final rows = _listOfMaps(response['intakes'] ?? response['data']);
      if (!mounted) return;
      setState(() {
        _intakes = rows;
        _intakeSettings = _safeMap(response['intake_settings']);
      });
    } catch (_) {
      // Intake history is helpful, but upload/review should still work.
    } finally {
      if (mounted) {
        setState(() {
          _loadingIntakes = false;
        });
      }
    }
  }

  Future<void> _pickAndProcess(ImageSource source) async {
    if (_processing || _saving || _savingReviewSnapshot) return;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2000,
      maxHeight: 2600,
    );
    if (picked == null) return;

    final previousPickedPath = _pickedImagePath;
    if (previousPickedPath != null && previousPickedPath != picked.path) {
      unawaited(_deleteTemporaryPickedFile(previousPickedPath));
    }

    setState(() {
      _processing = true;
      _saving = false;
      _errorMessage = null;
      _rawText = null;
      _preview = null;
      _intake = null;
      _snapshot = <String, dynamic>{};
      _fields = <_DraftField>[];
      _pickedImagePath = picked.path;
      _messageIndex = 0;
    });
    _startMessageRotation();

    try {
      if (_intakeSettings == null && !_loadingIntakes) {
        await _loadIntakes();
      }

      final usesLaravelPipeline = _usesLaravelBiodataPipeline;
      String? normalizedText;
      final Map<String, dynamic> response;

      if (usesLaravelPipeline) {
        _OcrEvidence? mlKitEvidence;
        try {
          mlKitEvidence = await _extractOcrEvidence(picked.path);
        } catch (_) {
          mlKitEvidence = null;
        }
        final mlKitText = mlKitEvidence == null
            ? null
            : _cleanOcrText(mlKitEvidence.text);
        response = await ApiClient.createBiodataIntakeFromFile(
          file: File(picked.path),
          parseNow: true,
          mlKitRawText: mlKitText,
          mlKitLinesJson: mlKitEvidence?.lines,
          mlKitBlocksJson: mlKitEvidence?.blocks,
        );
      } else {
        final text = await _extractText(picked.path);
        normalizedText = _cleanOcrText(text);
        if (normalizedText.length < 20) {
          _setProcessingError(AppStrings.biodataIntakeNoReadableText);
          return;
        }

        response = await ApiClient.createBiodataIntakeFromText(
          rawText: normalizedText,
          parseNow: true,
        );
      }
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
      final rawText = _stringValue(preview?['raw_text']) ?? normalizedText;
      final parseFailureMessage = _parseFailureMessage(intake);
      setState(() {
        _rawText = rawText;
        _intake = intake;
        _preview = preview;
        _intakeSettings =
            _safeMap(response['intake_settings']) ??
            _safeMap(preview?['intake_settings']) ??
            _intakeSettings;
        _snapshot = _snapshotFromPreview(preview);
        _fields = _draftFieldsFromPreview(preview);
        _errorMessage =
            parseFailureMessage ??
            (!_hasSaveableDraft ? AppStrings.biodataIntakeFieldsEmpty : null);
      });
    } catch (error) {
      _setProcessingError(
        '${AppStrings.biodataIntakeProcessFailed} ${error.toString()}',
      );
    } finally {
      _stopProcessing();
      unawaited(_loadIntakes());
    }
  }

  Future<void> _openExistingIntake(Map<String, dynamic> row) async {
    if (_processing || _saving || _savingReviewSnapshot) return;
    final intakeId = _intValue(row['id']);
    if (intakeId == null) return;

    setState(() {
      _processing = true;
      _saving = false;
      _errorMessage = null;
      _rawText = null;
      _preview = null;
      _intake = row;
      _snapshot = <String, dynamic>{};
      _fields = <_DraftField>[];
      _messageIndex = 0;
    });
    _startMessageRotation();

    try {
      final response = await ApiClient.getBiodataIntakePreview(intakeId);
      if (!_responseOk(response)) {
        _setProcessingError(
          _responseMessage(response, AppStrings.biodataIntakeProcessFailed),
        );
        return;
      }
      final preview = _safeMap(response['preview']);
      final responseIntake = _safeMap(response['intake']) ?? row;
      if (preview == null || response['ready'] == false) {
        _setProcessingError(
          _parseFailureMessage(responseIntake) ??
              _text(
                'This biodata is not ready for review yet.',
                'हा बायोडाटा अजून review साठी तयार नाही.',
              ),
        );
        return;
      }
      if (!mounted) return;
      final previousPickedPath = _pickedImagePath;
      if (previousPickedPath != null) {
        unawaited(_deleteTemporaryPickedFile(previousPickedPath));
      }
      setState(() {
        _rawText = _stringValue(preview['raw_text']);
        _preview = preview;
        _intake = responseIntake;
        _intakeSettings =
            _safeMap(response['intake_settings']) ??
            _safeMap(preview['intake_settings']) ??
            _intakeSettings;
        _snapshot = _snapshotFromPreview(preview);
        _fields = _draftFieldsFromPreview(preview);
        _pickedImagePath = null;
        _errorMessage = !_hasSaveableDraft
            ? AppStrings.biodataIntakeFieldsEmpty
            : null;
      });
    } catch (error) {
      _setProcessingError(
        '${AppStrings.biodataIntakeProcessFailed} ${error.toString()}',
      );
    } finally {
      _stopProcessing();
    }
  }

  Future<String> _extractText(String path) async {
    final evidence = await _extractOcrEvidence(path);
    return evidence.text;
  }

  Future<_OcrEvidence> _extractOcrEvidence(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.devanagiri);
    try {
      final inputImage = InputImage.fromFilePath(path);
      final recognized = await recognizer.processImage(inputImage);
      return _OcrEvidence(
        text: _layoutAwareOcrText(recognized),
        lines: _recognizedLineEvidence(recognized),
        blocks: _recognizedBlockEvidence(recognized),
      );
    } finally {
      await recognizer.close();
    }
  }

  List<Map<String, dynamic>> _recognizedLineEvidence(
    RecognizedText recognized,
  ) {
    final rows = <Map<String, dynamic>>[];
    for (
      var blockIndex = 0;
      blockIndex < recognized.blocks.length;
      blockIndex++
    ) {
      final block = recognized.blocks[blockIndex];
      for (var lineIndex = 0; lineIndex < block.lines.length; lineIndex++) {
        final line = block.lines[lineIndex];
        final text = line.text.trim();
        if (text.isEmpty) continue;
        rows.add({
          'block_index': blockIndex,
          'line_index': lineIndex,
          'text': text,
          'box': _boxEvidence(line.boundingBox),
        });
      }
    }

    return rows;
  }

  List<Map<String, dynamic>> _recognizedBlockEvidence(
    RecognizedText recognized,
  ) {
    final rows = <Map<String, dynamic>>[];
    for (
      var blockIndex = 0;
      blockIndex < recognized.blocks.length;
      blockIndex++
    ) {
      final block = recognized.blocks[blockIndex];
      final text = block.text.trim();
      if (text.isEmpty) continue;
      rows.add({
        'block_index': blockIndex,
        'text': text,
        'box': _boxEvidence(block.boundingBox),
        'line_count': block.lines.length,
      });
    }

    return rows;
  }

  Map<String, double> _boxEvidence(Rect box) {
    return {
      'left': box.left,
      'top': box.top,
      'right': box.right,
      'bottom': box.bottom,
      'width': box.width,
      'height': box.height,
    };
  }

  String _layoutAwareOcrText(RecognizedText recognized) {
    final ocrLines = <_OcrLine>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;
        final box = line.boundingBox;
        ocrLines.add(
          _OcrLine(
            text: text,
            left: box.left,
            top: box.top,
            right: box.right,
            bottom: box.bottom,
          ),
        );
      }
    }

    if (ocrLines.length < 2) return recognized.text;

    ocrLines.sort((a, b) {
      final topCompare = a.top.compareTo(b.top);
      if (topCompare != 0) return topCompare;
      return a.left.compareTo(b.left);
    });

    final rows = <List<_OcrLine>>[];
    for (final line in ocrLines) {
      List<_OcrLine>? target;
      for (final row in rows.reversed) {
        if (_sameOcrRow(row, line)) {
          target = row;
          break;
        }
      }
      if (target == null) {
        rows.add(<_OcrLine>[line]);
      } else {
        target.add(line);
      }
    }

    rows.sort((a, b) => _rowTop(a).compareTo(_rowTop(b)));

    final rowTexts = <String>[];
    for (final row in rows) {
      row.sort((a, b) => a.left.compareTo(b.left));
      final text = _joinOcrRow(row.map((line) => line.text).toList());
      if (text.trim().isNotEmpty) rowTexts.add(text.trim());
    }

    return rowTexts.isEmpty ? recognized.text : rowTexts.join('\n');
  }

  bool _sameOcrRow(List<_OcrLine> row, _OcrLine line) {
    final rowTop = _rowTop(row);
    final rowBottom = _rowBottom(row);
    final rowHeight = math.max(1.0, rowBottom - rowTop);
    final lineHeight = math.max(1.0, line.height);
    final overlap =
        math.min(rowBottom, line.bottom) - math.max(rowTop, line.top);
    final minHeight = math.min(rowHeight, lineHeight);
    if (overlap >= minHeight * 0.34) return true;

    final rowCenter = rowTop + (rowHeight / 2);
    final tolerance = math.max(8.0, math.min(28.0, minHeight * 0.7));
    return (rowCenter - line.centerY).abs() <= tolerance;
  }

  double _rowTop(List<_OcrLine> row) =>
      row.map((line) => line.top).reduce(math.min);

  double _rowBottom(List<_OcrLine> row) =>
      row.map((line) => line.bottom).reduce(math.max);

  String _joinOcrRow(List<String> segments) {
    final cleaned = segments
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) return '';
    if (cleaned.length == 1) return cleaned.first;

    final first = cleaned.first;
    final rest = cleaned
        .skip(1)
        .where((segment) => !RegExp(r'^[\s:：\-–—|]+$').hasMatch(segment))
        .toList();
    if (rest.isEmpty) return first;

    if (_looksLikeBiodataLabel(first)) {
      return '${_stripTrailingSeparator(first)} : ${rest.join(' ')}';
    }

    return cleaned.join(' ');
  }

  bool _looksLikeBiodataLabel(String value) {
    final text = _stripTrailingSeparator(value);
    return RegExp(
      r'^(?:'
      r'मुलाचे\s+नां?व|मुलीचे\s+नां?व|वधूचे\s+नां?व|नां?व|'
      r'जन्म\s*तारीख|जन्मतारीख|जन्म\s*वेळ|जन्मवेळ|जन्म\s*ठिकाण|जन्म\s*स्थळ|'
      r'धर्म|जात|कास्ट|उपजात|उप\s*जात|कुलदैवत|देवक|गोत्र|रास|राशी|नक्षत्र|गण|नाडी|नाड|'
      r'उंची|ऊंची|वजन|वर्ण|रंग|ब्लड\s*ग्रुप|रक्त\s*गट|'
      r'शिक्षण|नोकरी|व्यवसाय|नोकरी\s*/\s*व्यवसाय|कंपनी|कामाचे\s*ठिकाण|उत्पन्न|'
      r'वडील|वडिलांचे\s+नाव|पित्याचे\s+नाव|आई|आईचे\s+नाव|मातेचे\s+नाव|'
      r'भाऊ|बहीण|बहिण|मामा|मावशी|आत्या|नातेवाईक|नातेसंबंध|नाते\s*संबंध|'
      r'पत्ता|पता|सध्याचा\s+पत्ता|निवास|मूळ\s*गाव|मोबाईल|मोबाइल|फोन|संपर्क|अपेक्षा|'
      r'name|full\s*name|date\s*of\s*birth|dob|birth\s*time|birth\s*place|religion|caste|education|occupation|company|address|mobile'
      r')$',
      caseSensitive: false,
      unicode: true,
    ).hasMatch(text);
  }

  String _stripTrailingSeparator(String value) {
    return value
        .replaceAll(RegExp(r'[\s:：\-–—|.]+$'), '')
        .replaceAll(RegExp(r'^[\s:：\-–—|.]+'), '')
        .trim();
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
    if (_processing || _saving || _savingReviewSnapshot || !_hasSaveableDraft) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();

    var intakeId = _intValue(_intake?['id']);
    if (intakeId == null) {
      _showSnackBar(AppStrings.biodataIntakeProcessFailed);
      return;
    }
    final createReplacementIntake =
        _boolValue(_intake?['approved_by_user']) ||
        _boolValue(_intake?['intake_locked']);

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _editedSnapshotForSave();
      if (!_snapshotHasSaveableContent(snapshot)) {
        _showSnackBar(
          _text(
            'No safe new details to save. Existing profile information was kept.',
            'Save करण्यासाठी सुरक्षित नवीन माहिती नाही. आधीची profile माहिती तशीच ठेवली आहे.',
          ),
        );
        return;
      }

      if (createReplacementIntake) {
        final replacementIntakeId =
            await _createReplacementIntakeFromCurrentText();
        if (replacementIntakeId == null) return;
        intakeId = replacementIntakeId;
      }

      final response = await ApiClient.approveBiodataIntake(
        intakeId: intakeId,
        snapshot: snapshot,
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

  Future<void> _saveReviewedSnapshot() async {
    if (_processing || _saving || _savingReviewSnapshot || !_hasSaveableDraft) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();

    final intakeId = _intValue(_intake?['id']);
    if (intakeId == null) {
      _showSnackBar(AppStrings.biodataIntakeProcessFailed);
      return;
    }
    if (_isApprovedOrLockedIntake(_intake)) {
      _showSnackBar(AppStrings.biodataIntakeAlreadyApprovedLocked);
      return;
    }

    setState(() {
      _savingReviewSnapshot = true;
      _errorMessage = null;
    });

    try {
      final snapshot = _reviewedSnapshotForSave();
      if (!_snapshotHasSaveableContent(snapshot)) {
        _showSnackBar(AppStrings.biodataIntakeFieldsEmpty);
        return;
      }

      final response = await ApiClient.reviewBiodataIntakeSnapshot(
        intakeId: intakeId,
        reviewedSnapshot: snapshot,
      );
      if (!_responseOk(response)) {
        final message = _responseMessage(
          response,
          AppStrings.biodataIntakeReviewSaveFailed,
        );
        _showSnackBar(
          _looksLikeApprovedLockedResponse(response, message)
              ? AppStrings.biodataIntakeAlreadyApprovedLocked
              : message,
        );
        return;
      }

      await _refreshAfterReviewedSnapshotSave(intakeId, response);
      if (!mounted) return;
      _showSnackBar(AppStrings.biodataIntakeReviewSaveSuccess);
    } catch (error) {
      _showSnackBar(
        '${AppStrings.biodataIntakeReviewSaveFailed} ${error.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingReviewSnapshot = false;
        });
      }
    }
  }

  Future<void> _refreshAfterReviewedSnapshotSave(
    int intakeId,
    Map<String, dynamic> saveResponse,
  ) async {
    Map<String, dynamic>? refreshedPreview;
    Map<String, dynamic>? refreshedIntake = _safeMap(saveResponse['intake']);
    Map<String, dynamic>? refreshedSettings = _safeMap(
      saveResponse['intake_settings'],
    );

    try {
      final previewResponse = await ApiClient.getBiodataIntakePreview(intakeId);
      if (_responseOk(previewResponse)) {
        refreshedPreview =
            _safeMap(previewResponse['preview']) ?? refreshedPreview;
        refreshedIntake =
            _safeMap(previewResponse['intake']) ?? refreshedIntake;
        refreshedSettings =
            _safeMap(previewResponse['intake_settings']) ??
            _safeMap(refreshedPreview?['intake_settings']) ??
            refreshedSettings;
      }
    } catch (_) {
      // Best-effort refresh; the save response still contains the snapshot.
    }

    if (!mounted) return;
    final approvalSnapshot = _safeMap(saveResponse['approval_snapshot']);

    setState(() {
      if (refreshedIntake != null) _intake = refreshedIntake;
      if (refreshedSettings != null) _intakeSettings = refreshedSettings;

      if (refreshedPreview != null) {
        _preview = refreshedPreview;
        _snapshot = _snapshotFromPreview(refreshedPreview);
        _fields = _draftFieldsFromPreview(refreshedPreview);
      } else if (approvalSnapshot != null) {
        _snapshot = approvalSnapshot;
        final preview = _preview == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(_preview!);
        preview['review_snapshot'] = approvalSnapshot;
        _preview = preview;
        _fields = _draftFieldsFromPreview(preview);
      }

      _errorMessage = null;
    });
  }

  Future<int?> _createReplacementIntakeFromCurrentText() async {
    final sourceText = _rawText?.trim();
    if (sourceText == null || sourceText.length < 20) {
      _showSnackBar(
        _text(
          'Existing biodata text is not available. Upload the biodata again.',
          'आधीचा biodata text उपलब्ध नाही. Biodata पुन्हा upload करा.',
        ),
      );
      return null;
    }

    final response = await ApiClient.createBiodataIntakeFromText(
      rawText: sourceText,
      parseNow: true,
    );
    if (!_responseOk(response)) {
      _showSnackBar(
        _responseMessage(response, AppStrings.biodataIntakeProcessFailed),
      );
      return null;
    }

    final intake = _safeMap(response['intake']) ?? _safeMap(response['data']);
    final intakeId = _intValue(intake?['id']);
    if (intakeId == null) {
      _showSnackBar(AppStrings.biodataIntakeProcessFailed);
      return null;
    }

    final preview = _safeMap(response['preview']);
    if (preview == null && _stringValue(intake?['parse_status']) != 'parsed') {
      final previewResponse = await ApiClient.getBiodataIntakePreview(intakeId);
      if (!_responseOk(previewResponse) || previewResponse['ready'] == false) {
        _showSnackBar(
          _responseMessage(
            previewResponse,
            _text(
              'A fresh editable intake was created, but it is not ready yet.',
              'नवीन editable intake तयार झाला, पण तो अजून ready नाही.',
            ),
          ),
        );
        return null;
      }
    }

    return intakeId;
  }

  Future<Map<String, dynamic>> _editedSnapshotForSave() async {
    final existingProfile = await _loadExistingProfileForOverwriteGuard();
    return _editedSnapshot(existingProfile);
  }

  Map<String, dynamic> _reviewedSnapshotForSave() {
    final snapshot = _deepCopyMap(_snapshot);
    for (final field in _fields) {
      if (!field.saveEnabled || field.path.isEmpty) continue;
      final value = _fieldSaveValue(field);
      if (_isEmptyDraftValue(value)) continue;
      _setSnapshotPathValue(snapshot, field.path, value);
    }

    snapshot['snapshot_schema_version'] =
        _intValue(snapshot['snapshot_schema_version']) ?? 1;
    snapshot['core'] = _safeMap(snapshot['core']) ?? <String, dynamic>{};
    return snapshot;
  }

  Map<String, dynamic> _editedSnapshot(Map<String, dynamic> existingProfile) {
    final snapshot = _deepCopyMap(_snapshot);
    final core = _safeMap(snapshot['core']) ?? <String, dynamic>{};
    final fieldsByKey = <String, _DraftField>{
      for (final field in _fields)
        if (field.isCoreField && field.key.isNotEmpty) field.key: field,
    };
    for (final field in _fields) {
      if (!field.saveEnabled || field.path.isEmpty) continue;
      final value = _fieldSaveValue(field);
      if (!field.isCoreField) {
        if (field.editable && field.wasEdited && !_isEmptyDraftValue(value)) {
          _setSnapshotPathValue(snapshot, field.path, value);
        }
        continue;
      }

      if (!_shouldSaveField(field, value, existingProfile)) {
        final existing = _existingProfileValue(existingProfile, field.key);
        if (!_isEmptyDraftValue(existing) && !field.wasEdited) {
          core.remove(field.key);
        }
        continue;
      }
      core[field.key] = value;
    }
    for (final key in core.keys.toList()) {
      final field = fieldsByKey[key];
      if (field != null && field.wasEdited) continue;
      final existing = _existingProfileValue(existingProfile, key);
      if (!_isEmptyDraftValue(existing)) core.remove(key);
    }

    snapshot['snapshot_schema_version'] =
        _intValue(snapshot['snapshot_schema_version']) ?? 1;
    snapshot['core'] = core;
    return snapshot;
  }

  void _setSnapshotPathValue(
    Map<String, dynamic> snapshot,
    List<Object> path,
    dynamic value,
  ) {
    if (path.isEmpty) return;
    dynamic cursor = snapshot;
    for (var index = 0; index < path.length - 1; index += 1) {
      final part = path[index];
      final nextPart = path[index + 1];
      if (part is int) {
        if (cursor is! List || part < 0 || part >= cursor.length) return;
        cursor = cursor[part];
        continue;
      }

      if (cursor is! Map) return;
      final key = part.toString();
      var next = cursor[key];
      if (next == null) {
        next = nextPart is int ? <dynamic>[] : <String, dynamic>{};
        cursor[key] = next;
      }
      if (nextPart is int && next is List) {
        while (next.length <= nextPart) {
          next.add(<String, dynamic>{});
        }
      }
      cursor = next;
    }

    final last = path.last;
    if (last is int) {
      if (cursor is List && last >= 0 && last < cursor.length) {
        cursor[last] = value;
      }
      return;
    }
    if (cursor is Map) {
      cursor[last.toString()] = value;
    }
  }

  Future<Map<String, dynamic>> _loadExistingProfileForOverwriteGuard() async {
    try {
      final response = await ApiClient.getMyProfile();
      return _safeMap(response['profile']) ??
          _safeMap(_safeMap(response['data'])?['profile']) ??
          Map<String, dynamic>.from(ApiClient.currentUserProfile ?? {});
    } catch (_) {
      return Map<String, dynamic>.from(ApiClient.currentUserProfile ?? {});
    }
  }

  dynamic _fieldSaveValue(_DraftField field) {
    return field.editable
        ? _coerceFieldValue(field.key, field.value.trim())
        : field.saveValue;
  }

  bool _shouldSaveField(
    _DraftField field,
    dynamic value,
    Map<String, dynamic> existingProfile,
  ) {
    if (!field.saveEnabled || field.key.isEmpty || _isEmptyDraftValue(value)) {
      return false;
    }

    final existing = _existingProfileValue(existingProfile, field.key);
    if (_isEmptyDraftValue(existing)) return true;

    if (_sameDraftValue(existing, value)) {
      return false;
    }

    return field.editable && field.wasEdited;
  }

  dynamic _existingProfileValue(Map<String, dynamic> profile, String key) {
    final direct = profile[key];
    if (!_isEmptyDraftValue(direct)) return direct;

    final display = _safeMap(profile['display']);
    final displayValue = display?[key];
    if (!_isEmptyDraftValue(displayValue)) return displayValue;

    return null;
  }

  bool _sameDraftValue(dynamic a, dynamic b) {
    final aInt = _intFromValue(a);
    final bInt = _intFromValue(b);
    if (aInt != null && bInt != null) return aInt == bInt;

    final aText = _stringValue(a)?.toLowerCase();
    final bText = _stringValue(b)?.toLowerCase();
    if (aText == null || bText == null) return false;
    return aText == bText;
  }

  dynamic _coerceFieldValue(String key, String value) {
    if (_integerCoreKeys.contains(key)) {
      return _cleanInteger(value) ?? value;
    }
    return value;
  }

  Map<String, dynamic> _snapshotFromPreview(Map<String, dynamic>? preview) {
    final review = _safeMap(preview?['review_snapshot']);
    if (review != null && review.isNotEmpty) return review;

    final approval = _safeMap(preview?['approval_snapshot']);
    if (approval != null && approval.isNotEmpty) return approval;

    final parsed = _safeMap(preview?['parsed_snapshot']);
    if (parsed != null && parsed.isNotEmpty) return parsed;

    final snapshot = _safeMap(preview?['snapshot']);
    if (snapshot != null && snapshot.isNotEmpty) return snapshot;

    return <String, dynamic>{'snapshot_schema_version': 1, 'core': {}};
  }

  bool get _hasSaveableDraft =>
      _fields.any((field) => field.saveEnabled && field.key.isNotEmpty) ||
      _snapshotHasSaveableContent(_snapshot);

  bool get _usesLaravelBiodataPipeline =>
      _stringValue(_intakeSettings?['mobile_biodata_source_mode']) ==
      'laravel_pipeline';

  bool _isApprovedOrLockedIntake(Map<String, dynamic>? intake) {
    return _boolValue(intake?['approved_by_user']) ||
        _boolValue(intake?['intake_locked']);
  }

  bool _looksLikeApprovedLockedResponse(
    Map<String, dynamic> response,
    String message,
  ) {
    final code = _intValue(response['statusCode']);
    final text = message.toLowerCase();
    return code == 422 &&
        (text.contains('approved') ||
            text.contains('lock') ||
            message.contains('मंजूर'));
  }

  List<_DraftField> _draftFieldsFromPreview(Map<String, dynamic>? preview) {
    final fields = _onboardingFieldsFromPreview(preview);
    _addReviewSectionFields(fields, preview);
    return fields;
  }

  List<_DraftField> _onboardingFieldsFromPreview(
    Map<String, dynamic>? preview,
  ) {
    final snapshot = _snapshotFromPreview(preview);
    final rawDraft = _rawDraftFromPreview(preview);
    final core = _mergedCoreFromPreview(snapshot, rawDraft);
    final address = _firstCurrentAddress(snapshot, rawDraft);
    final fields = <_DraftField>[];
    final usedCoreKeys = <String>{};

    void markCoreKeys(Iterable<String> keys) {
      usedCoreKeys.addAll(keys.where((key) => key.trim().isNotEmpty));
    }

    void addText({
      required String section,
      required String key,
      required String label,
      required List<String> sourceKeys,
      TextInputType keyboardType = TextInputType.text,
      int maxLines = 1,
    }) {
      markCoreKeys(<String>[key, ...sourceKeys]);
      final value = _firstString(core, sourceKeys);
      if (value == null) return;
      fields.add(
        _DraftField(
          section: section,
          key: key,
          label: label,
          value: value,
          helperText: key == 'full_name' && _isSuspiciousFullName(value)
              ? _text(
                  'Enter the actual candidate name before saving',
                  'Save करण्याआधी उमेदवाराचे खरे नाव भरा',
                )
              : null,
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
      markCoreKeys(<String>[key, ...sourceKeys]);
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
      markCoreKeys(<String>[
        idKey,
        ...idKeys,
        ...labelKeys,
        if (textFallbackKey != null) textFallbackKey,
      ]);
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
    final physical = _text('Physical', 'शारीरिक माहिती');
    final career = _text('Education & career', 'शिक्षण आणि करिअर');
    final family = _text('Family details', 'कौटुंबिक माहिती');
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
    addText(
      section: basic,
      key: 'birth_time',
      label: _text('Birth time', 'जन्म वेळ'),
      sourceKeys: const <String>['birth_time', 'birth_time_text'],
    );
    addText(
      section: basic,
      key: 'birth_place_text',
      label: _text('Birth place', 'जन्म ठिकाण'),
      sourceKeys: const <String>['birth_place_text', 'birth_place'],
    );
    addParsedInteger(
      section: physical,
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
    markCoreKeys(const <String>[
      'location_id',
      'city_id',
      'location_label',
      'location_option',
      'location',
      'city',
      'city_name',
      'address_line',
    ]);

    addText(
      section: physical,
      key: 'weight_kg',
      label: _text('Weight', 'वजन'),
      sourceKeys: const <String>['weight_kg', 'weight'],
      keyboardType: TextInputType.number,
    );
    addText(
      section: physical,
      key: 'complexion',
      label: _text('Complexion', 'वर्ण'),
      sourceKeys: const <String>['complexion', 'complexion_text'],
    );
    addText(
      section: physical,
      key: 'blood_group',
      label: _text('Blood group', 'रक्त गट'),
      sourceKeys: const <String>['blood_group'],
    );
    addText(
      section: physical,
      key: 'physical_condition',
      label: _text('Physical condition', 'शारीरिक स्थिती'),
      sourceKeys: const <String>['physical_condition'],
    );

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

    addText(
      section: family,
      key: 'father_name',
      label: _text('Father name', 'वडिलांचे नाव'),
      sourceKeys: const <String>['father_name'],
      keyboardType: TextInputType.name,
    );
    addText(
      section: family,
      key: 'father_occupation',
      label: _text('Father occupation', 'वडिलांचा व्यवसाय'),
      sourceKeys: const <String>[
        'father_occupation',
        'father_occupation_title',
      ],
    );
    addText(
      section: family,
      key: 'father_extra_info',
      label: _text('Father details', 'वडिलांची माहिती'),
      sourceKeys: const <String>['father_extra_info'],
      maxLines: 2,
    );
    addText(
      section: family,
      key: 'mother_name',
      label: _text('Mother name', 'आईचे नाव'),
      sourceKeys: const <String>['mother_name'],
      keyboardType: TextInputType.name,
    );
    addText(
      section: family,
      key: 'mother_occupation',
      label: _text('Mother occupation', 'आईचा व्यवसाय'),
      sourceKeys: const <String>[
        'mother_occupation',
        'mother_occupation_title',
      ],
    );
    addText(
      section: family,
      key: 'mother_extra_info',
      label: _text('Mother details', 'आईची माहिती'),
      sourceKeys: const <String>['mother_extra_info'],
      maxLines: 2,
    );
    addText(
      section: family,
      key: 'family_type',
      label: _text('Family type', 'कुटुंब प्रकार'),
      sourceKeys: const <String>['family_type'],
    );
    addText(
      section: family,
      key: 'family_status',
      label: _text('Family status', 'कुटुंब स्थिती'),
      sourceKeys: const <String>['family_status'],
    );
    addText(
      section: family,
      key: 'family_values',
      label: _text('Family values', 'कुटुंब मूल्ये'),
      sourceKeys: const <String>['family_values'],
    );
    addText(
      section: family,
      key: 'other_relatives_text',
      label: _text('Relatives', 'नातेवाईक'),
      sourceKeys: const <String>['other_relatives_text'],
      maxLines: 2,
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

    _addRemainingCoreFields(fields, core, usedCoreKeys);

    return fields;
  }

  void _addReviewSectionFields(
    List<_DraftField> fields,
    Map<String, dynamic>? preview,
  ) {
    final sections = _safeMap(preview?['review_sections']);
    if (sections == null || sections.isEmpty) return;

    final existingPathKeys = fields.map((field) => field.pathKey).toSet();
    for (final sectionKey in _reviewSectionOrder(preview, sections)) {
      if (sectionKey == 'core') continue;
      final section = _safeMap(sections[sectionKey]);
      if (section == null) continue;
      final data = section['data'];
      if (!_snapshotHasSaveableContent(data)) continue;

      final sectionLabel =
          _stringValue(section['label']) ??
          _sectionLabelFromKey(sectionKey) ??
          sectionKey;
      final snapshotKey = _snapshotKeyForReviewSection(sectionKey);
      _appendReviewValueFields(
        fields: fields,
        section: sectionLabel,
        value: data,
        path: <Object>[snapshotKey],
        existingPathKeys: existingPathKeys,
      );
    }
  }

  List<String> _reviewSectionOrder(
    Map<String, dynamic>? preview,
    Map<String, dynamic> sections,
  ) {
    final order = <String>[];
    final editable = preview?['editable_form_sections'];
    if (editable is List) {
      for (final row in editable) {
        final key = _stringValue(_safeMap(row)?['key']);
        if (key == null) continue;
        final mapped = _reviewSectionKeyForEditableKey(key);
        if (sections.containsKey(mapped) && !order.contains(mapped)) {
          order.add(mapped);
        }
      }
    }
    for (final key in sections.keys) {
      if (!order.contains(key)) order.add(key);
    }
    return order;
  }

  String _reviewSectionKeyForEditableKey(String key) {
    return switch (key) {
      'basic-info' => 'core',
      'education-career' => 'career',
      'family-details' => 'core',
      'alliance' => 'children',
      'property' => 'property_summary',
      'about-me' => 'narrative',
      'about-preferences' => 'preferences',
      _ => key,
    };
  }

  String _snapshotKeyForReviewSection(String sectionKey) {
    return switch (sectionKey) {
      'education' => 'education_history',
      'career' => 'career_history',
      'narrative' => 'extended_narrative',
      _ => sectionKey,
    };
  }

  String? _sectionLabelFromKey(String key) {
    return switch (key) {
      'contacts' => _text('Contacts', 'संपर्क'),
      'children' => _text('Children', 'मुले'),
      'siblings' => _text('Siblings', 'भावंडे'),
      'education' => _text('Education', 'शिक्षण'),
      'career' => _text('Career', 'करिअर'),
      'addresses' => _text('Addresses', 'पत्ते'),
      'relatives' => _text('Relatives', 'नातेवाईक'),
      'property_summary' => _text('Property summary', 'मालमत्ता सारांश'),
      'property_assets' => _text('Property assets', 'मालमत्ता'),
      'horoscope' => _text('Horoscope', 'पत्रिका'),
      'preferences' => _text('Partner preferences', 'जोडीदार अपेक्षा'),
      'narrative' => _text('About me', 'माझ्याबद्दल'),
      _ => null,
    };
  }

  void _appendReviewValueFields({
    required List<_DraftField> fields,
    required String section,
    required dynamic value,
    required List<Object> path,
    required Set<String> existingPathKeys,
    String? labelPrefix,
    int depth = 0,
  }) {
    if (value is Map) {
      final map = _safeMap(value);
      if (map == null) return;
      final keys = map.keys.where(_shouldShowReviewKey).toList()..sort();
      for (final key in keys) {
        final child = map[key];
        if (!_snapshotHasSaveableContent(child)) continue;
        final label = _joinLabels(labelPrefix, _fieldLabelFromKey(key) ?? key);
        _appendReviewValueFields(
          fields: fields,
          section: section,
          value: child,
          path: <Object>[...path, key],
          existingPathKeys: existingPathKeys,
          labelPrefix: label,
          depth: depth + 1,
        );
      }
      return;
    }

    if (value is List) {
      for (var index = 0; index < value.length; index += 1) {
        final child = value[index];
        if (!_snapshotHasSaveableContent(child)) continue;
        final label = _joinLabels(
          labelPrefix,
          _text('Row ${index + 1}', 'नोंद ${index + 1}'),
        );
        _appendReviewValueFields(
          fields: fields,
          section: section,
          value: child,
          path: <Object>[...path, index],
          existingPathKeys: existingPathKeys,
          labelPrefix: label,
          depth: depth + 1,
        );
      }
      return;
    }

    final text = _reviewTextFromValue(value);
    if (text == null) return;
    final pathKey = _pathKey(path);
    if (existingPathKeys.contains(pathKey)) return;
    existingPathKeys.add(pathKey);
    final label =
        labelPrefix ?? _fieldLabelFromKey(path.last.toString()) ?? pathKey;
    final editable = !_looksLikeSystemPath(path);
    fields.add(
      _DraftField(
        section: section,
        key: path.last.toString(),
        label: label,
        value: text,
        path: path,
        maxLines: text.length > 70 ? 2 : 1,
        editable: editable,
        saveEnabled: editable,
      ),
    );
  }

  bool _shouldShowReviewKey(String key) {
    if (key == 'id' ||
        key == 'user_id' ||
        key == 'snapshot_schema_version' ||
        key == 'confidence_map') {
      return false;
    }
    return !key.endsWith('_id') && !key.endsWith('_ids');
  }

  bool _looksLikeSystemPath(List<Object> path) {
    final key = path.isEmpty ? '' : path.last.toString();
    return key == 'id' || key.endsWith('_id') || key.endsWith('_ids');
  }

  String _joinLabels(String? prefix, String label) {
    final clean = label.trim();
    if (prefix == null || prefix.trim().isEmpty) return clean;
    if (clean.isEmpty) return prefix.trim();
    return '${prefix.trim()} - $clean';
  }

  String _pathKey(List<Object> path) => path.map((part) => '$part').join('.');

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
    return _safeMap(normalizedDraft?['raw_draft']) ??
        _decodeJsonMap(normalizedDraft?['raw_draft_json']);
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

  void _addRemainingCoreFields(
    List<_DraftField> fields,
    Map<String, dynamic> core,
    Set<String> usedCoreKeys,
  ) {
    final keys = core.keys.toList()..sort();
    for (final key in keys) {
      if (usedCoreKeys.contains(key) ||
          key.endsWith('_id') ||
          key.endsWith('_ids') ||
          key == 'id' ||
          key == 'user_id') {
        continue;
      }

      final value = _reviewTextFromValue(core[key]);
      if (value == null) continue;

      fields.add(
        _DraftField(
          section: _text('Other details', 'इतर माहिती'),
          key: key,
          label: _fieldLabelFromKey(key) ?? key,
          value: value,
          maxLines: value.length > 70 ? 2 : 1,
        ),
      );
      usedCoreKeys.add(key);
    }
  }

  String? _reviewTextFromValue(dynamic value) {
    if (value == null) return null;
    if (value is List || value is Map) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? _fieldLabelFromKey(String? key) {
    final text = key?.trim();
    if (text == null || text.isEmpty) return null;
    return text
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  Map<String, dynamic>? _decodeJsonMap(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      return _safeMap(decoded);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _deepCopyMap(Map<String, dynamic> value) {
    try {
      final decoded = jsonDecode(jsonEncode(value));
      return _safeMap(decoded) ?? Map<String, dynamic>.from(value);
    } catch (_) {
      return Map<String, dynamic>.from(value);
    }
  }

  bool _snapshotHasSaveableContent(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is num || value is bool) return true;
    if (value is List) return value.any(_snapshotHasSaveableContent);
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (key == 'snapshot_schema_version') continue;
        if (_snapshotHasSaveableContent(entry.value)) return true;
      }
    }
    return false;
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

  String? _fullNameValidationMessage(String? value) {
    if (!_isSuspiciousFullName(value)) return null;
    return _text(
      'Please replace this with the actual candidate name.',
      'कृपया इथे उमेदवाराचे खरे नाव भरा.',
    );
  }

  bool _isSuspiciousFullName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return false;
    final normalized = text.toLowerCase();
    if (RegExp(r'^(?:मुलाचे|मुलीचे|वधूचे)?\s*नां?व\s*[:\-]?$').hasMatch(text)) {
      return true;
    }
    if (RegExp(
      r'(?:श्री\s*गणेश|गणेशाय|गजानन|प्रसन्न|देवी|माहिती|जन्म|उंची|शिक्षण|नोकरी|व्यवसाय|धर्म|जात|पत्ता|संपर्क)',
    ).hasMatch(text)) {
      return true;
    }
    return normalized == 'name' ||
        normalized == 'full name' ||
        normalized == 'male' ||
        normalized == 'female';
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

  Future<void> _deleteTemporaryPickedFile(String? path) async {
    if (path == null || path.trim().isEmpty) return;
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
          if (_pickedImagePath != null) ...[
            const SizedBox(height: 12),
            _selectedImagePanel(),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _messagePanel(_errorMessage!, isError: true),
          ],
          if (_intakes.isNotEmpty || _loadingIntakes) ...[
            const SizedBox(height: 16),
            _intakeHistoryPanel(),
          ],
          if (_fields.isNotEmpty) ...[
            const SizedBox(height: 16),
            _reviewForm(),
          ],
          if (_normalizedDraftAvailable) ...[
            const SizedBox(height: 16),
            _normalizedDraftPanel(),
          ],
          if (_parsedJsonSections.isNotEmpty) ...[
            const SizedBox(height: 16),
            _parsedJsonPanel(),
          ],
          if (_debugRows.isNotEmpty) ...[
            const SizedBox(height: 16),
            _debugPanel(),
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

  Widget _selectedImagePanel() {
    final path = _pickedImagePath;
    if (path == null) return const SizedBox.shrink();
    return _panel(
      title: _text('Uploaded biodata photo', 'Upload केलेला बायोडाटा फोटो'),
      icon: Icons.image_outlined,
      collapseKey: 'uploaded_photo',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _emptyPanelText(
            _text(
              'Photo preview is not available.',
              'फोटो preview उपलब्ध नाही.',
            ),
          ),
        ),
      ),
    );
  }

  Widget _intakeHistoryPanel() {
    return _panel(
      title: _text('Previous biodata intakes', 'आधीचे बायोडाटा इंटेक'),
      icon: Icons.history_outlined,
      collapseKey: 'previous_intakes',
      trailing: _loadingIntakes
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              tooltip: _text('Refresh', 'Refresh'),
              onPressed: _loadIntakes,
              icon: const Icon(Icons.refresh),
            ),
      child: _intakes.isEmpty
          ? _emptyPanelText(
              _text(
                'No biodata intake uploaded yet.',
                'अजून कोणताही बायोडाटा इंटेक upload केलेला नाही.',
              ),
            )
          : Column(
              children: [for (final row in _intakes) _intakeHistoryRow(row)],
            ),
    );
  }

  Widget _intakeHistoryRow(Map<String, dynamic> row) {
    final id = _intValue(row['id']);
    final parseStatus = _stringValue(row['parse_status']) ?? '-';
    final approved = _boolValue(row['approved_by_user']);
    final source = _stringValue(row['source_label']) ?? 'Biodata';
    final parsedAt = _stringValue(row['parsed_at']);
    return InkWell(
      onTap: id == null ? null : () => _openExistingIntake(row),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: approved
                    ? const Color(0xFF047857).withValues(alpha: 0.1)
                    : _brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                approved ? Icons.check_circle_outline : Icons.description,
                color: approved ? const Color(0xFF047857) : _brand,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    id == null ? source : '#$id · $source',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    approved
                        ? _text('Approved', 'Approved')
                        : '$parseStatus${parsedAt == null ? '' : ' · $parsedAt'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (id != null) const Icon(Icons.chevron_right, color: _muted),
          ],
        ),
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
      child: _panel(
        title: AppStrings.biodataIntakeReviewTitle,
        icon: Icons.assignment_turned_in_outlined,
        collapseKey: 'review_details',
        maintainChildState: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            for (final indexed in grouped.entries.toList().asMap().entries)
              _reviewFieldSection(
                indexed.value.key,
                indexed.value.value,
                initiallyCollapsed: false,
              ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: (_saving || _savingReviewSnapshot)
                  ? null
                  : _saveReviewedSnapshot,
              icon: _savingReviewSnapshot
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(AppStrings.biodataIntakeSaveReview),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewFieldSection(
    String title,
    List<_DraftField> fields, {
    required bool initiallyCollapsed,
  }) {
    final collapsed = _reviewSectionCollapsed(title, initiallyCollapsed);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _toggleReviewSection(title, collapsed),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    fields.length.toString(),
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    collapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: _muted,
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Column(
                children: [
                  for (final field in fields) ...[
                    TextFormField(
                      key: ValueKey<String>(field.pathKey),
                      initialValue: field.value,
                      readOnly: !field.editable,
                      keyboardType: field.maxLines > 1
                          ? TextInputType.multiline
                          : field.keyboardType,
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
                      validator: (value) => field.key == 'full_name'
                          ? _fullNameValidationMessage(value)
                          : null,
                      onSaved: field.editable
                          ? (value) => field.value = value?.trim() ?? ''
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _reviewSectionCollapsed(String title, bool initiallyCollapsed) {
    if (_expandedReviewSections.contains(title)) return false;
    if (_collapsedReviewSections.contains(title)) return true;

    return initiallyCollapsed;
  }

  void _toggleReviewSection(String title, bool currentlyCollapsed) {
    setState(() {
      if (currentlyCollapsed) {
        _expandedReviewSections.add(title);
        _collapsedReviewSections.remove(title);
      } else {
        _collapsedReviewSections.add(title);
        _expandedReviewSections.remove(title);
      }
    });
  }

  String? _parseFailureMessage(Map<String, dynamic>? intake) {
    if (_stringValue(intake?['parse_status']) != 'error') return null;
    final detail = _stringValue(intake?['last_error']);
    if (detail == null || detail.trim().isEmpty) {
      return AppStrings.biodataIntakeProcessFailed;
    }

    return _text('Parsing failed: $detail', 'Parsing failed: $detail');
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

  bool get _normalizedDraftAvailable {
    final normalized = _safeMap(_preview?['normalized_draft']);
    return _boolValue(normalized?['available']);
  }

  List<Map<String, dynamic>> get _parsedJsonSections {
    final sections = _safeMap(_preview?['parsed_json_sections']);
    if (sections == null) return <Map<String, dynamic>>[];
    return sections.entries
        .map((entry) {
          final section = _safeMap(entry.value);
          if (section == null) return null;
          final data = section['data'];
          if (!_snapshotHasSaveableContent(data)) return null;
          return <String, dynamic>{
            'key': entry.key,
            'label': _stringValue(section['label']) ?? entry.key,
            'data': data,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  List<MapEntry<String, String>> get _debugRows {
    final rows = <MapEntry<String, String>>[];
    void addMap(String prefix, Map<String, dynamic>? map) {
      if (map == null) return;
      final keys = map.keys.toList()..sort();
      for (final key in keys) {
        final value = map[key];
        if (!_snapshotHasSaveableContent(value)) continue;
        rows.add(MapEntry('$prefix$key', _compactValue(value)));
      }
    }

    addMap('', _safeMap(_preview?['debug']));
    addMap('setting.', _intakeSettings);
    return rows;
  }

  Widget _normalizedDraftPanel() {
    final normalized = _safeMap(_preview?['normalized_draft']);
    if (normalized == null) return const SizedBox.shrink();
    final detected = _listOfMaps(normalized['detected_but_not_included']);
    final sections = _safeMap(normalized['sections']) ?? <String, dynamic>{};
    final reconciliation = _safeMap(normalized['draft_parsed_reconciliation']);
    final rawDraftJson = _stringValue(normalized['raw_draft_json']);
    final sectionEntries = sections.entries
        .where((entry) => _listOfMaps(entry.value).isNotEmpty)
        .toList();

    return _panel(
      title: _text('Normalized Biodata Draft', 'Normalized Biodata Draft'),
      icon: Icons.fact_check_outlined,
      collapseKey: 'normalized_draft',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (detected.isNotEmpty) ...[
            _subsectionTitle(
              _text(
                'Detected but not included',
                'ओळखले पण form मध्ये न घेतलेली माहिती',
              ),
            ),
            for (final row in detected)
              _keyValueRow(
                _stringValue(row['label']) ?? '-',
                _compactValue(row['value']),
                helper: _stringValue(row['reason']),
                flagged: true,
              ),
            const SizedBox(height: 10),
          ],
          for (final entry in sectionEntries)
            _normalizedSection(entry.key, _listOfMaps(entry.value)),
          if (_snapshotHasSaveableContent(reconciliation))
            ExpansionTile(
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(
                _text('Draft / parsed reconciliation', 'Draft / parsed तपासणी'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              children: [
                for (final entry in reconciliation!.entries)
                  if (_snapshotHasSaveableContent(entry.value))
                    _keyValueRow(entry.key, _prettyJson(entry.value)),
              ],
            ),
          if (rawDraftJson != null)
            ExpansionTile(
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(
                _text('Raw normalized draft JSON', 'Raw normalized draft JSON'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    rawDraftJson,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      height: 1.35,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          if (sectionEntries.isEmpty && detected.isEmpty)
            _emptyPanelText(
              _text('No draft rows.', 'Draft rows उपलब्ध नाहीत.'),
            ),
        ],
      ),
    );
  }

  Widget _normalizedSection(String key, List<Map<String, dynamic>> rows) {
    final title = key == 'review_needed'
        ? _text('Missing / review needed', 'Missing / review needed')
        : _sectionLabelFromKey(key) ?? _fieldLabelFromKey(key) ?? key;
    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      children: [
        for (final row in rows)
          _keyValueRow(
            _stringValue(row['label']) ?? _stringValue(row['field']) ?? '-',
            _compactValue(row['value']),
            helper:
                _stringValue(row['review_hint']) ??
                _stringValue(row['review_reason']),
            flagged: _boolValue(row['needs_review']) || key == 'review_needed',
          ),
      ],
    );
  }

  Widget _parsedJsonPanel() {
    return _panel(
      title: _text('Parsed JSON', 'Parsed JSON'),
      icon: Icons.data_object_outlined,
      collapseKey: 'parsed_json',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in _parsedJsonSections)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 10),
              title: Text(
                _stringValue(section['label']) ?? '-',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    _prettyJson(section['data']),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      height: 1.35,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _debugPanel() {
    return _panel(
      title: _text('OCR preprocessing diagnostics', 'OCR diagnostics'),
      icon: Icons.bug_report_outlined,
      collapseKey: 'debug',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in _debugRows) _keyValueRow(row.key, row.value),
        ],
      ),
    );
  }

  Widget _panel({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
    String? collapseKey,
    bool maintainChildState = false,
  }) {
    final collapsed =
        collapseKey != null && _collapsedPanels.contains(collapseKey);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: _brand),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing,
              if (collapseKey != null)
                IconButton(
                  tooltip: collapsed
                      ? _text('Expand', 'उघडा')
                      : _text('Minimize', 'मिनिमाइज'),
                  onPressed: () {
                    setState(() {
                      if (collapsed) {
                        _collapsedPanels.remove(collapseKey);
                        if (collapseKey == 'review_details') {
                          _collapsedReviewSections.clear();
                          _expandedReviewSections.clear();
                        }
                      } else {
                        _collapsedPanels.add(collapseKey);
                      }
                    });
                  },
                  icon: Icon(
                    collapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: _muted,
                  ),
                ),
            ],
          ),
          if (maintainChildState) ...[
            if (!collapsed) const SizedBox(height: 12),
            Offstage(offstage: collapsed, child: child),
          ] else if (!collapsed) ...[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }

  Widget _subsectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: _ink,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _keyValueRow(
    String label,
    String value, {
    String? helper,
    bool flagged = false,
  }) {
    final color = flagged ? const Color(0xFFB45309) : _muted;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: flagged ? const Color(0xFFFFFBEB) : const Color(0xFFFAF7F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: flagged ? const Color(0xFFFBBF24) : _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value.isEmpty ? '-' : value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (helper != null && helper.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              helper,
              style: TextStyle(
                color: color,
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyPanelText(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _muted,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  String _prettyJson(dynamic value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return _compactValue(value);
    }
  }

  String _compactValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is num || value is bool) return value.toString();
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
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
    final savingAny = _saving || _savingReviewSnapshot;
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
                onPressed: savingAny
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
                onPressed: savingAny
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

  List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.map(_safeMap).whereType<Map<String, dynamic>>().toList();
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
    List<Object>? path,
    this.saveEnabled = true,
    this.editable = true,
    this.helperText,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  }) : initialValue = value,
       saveValue = null,
       path = path ?? (key.isEmpty ? const <Object>[] : <Object>['core', key]);

  _DraftField.readOnly({
    required this.section,
    required this.key,
    required this.label,
    required this.value,
    required this.saveValue,
    List<Object>? path,
  }) : initialValue = value,
       editable = false,
       saveEnabled = true,
       path = path ?? (key.isEmpty ? const <Object>[] : <Object>['core', key]),
       helperText = null,
       keyboardType = TextInputType.text,
       maxLines = 1;

  _DraftField.note({
    required this.section,
    required this.label,
    required this.value,
    this.helperText,
  }) : key = '',
       initialValue = value,
       saveValue = null,
       editable = false,
       saveEnabled = false,
       path = const <Object>[],
       keyboardType = TextInputType.text,
       maxLines = 1;

  final String section;
  final String key;
  final String label;
  String value;
  final String initialValue;
  final dynamic saveValue;
  final bool editable;
  final bool saveEnabled;
  final List<Object> path;
  final String? helperText;
  final TextInputType keyboardType;
  final int maxLines;

  bool get wasEdited => value.trim() != initialValue.trim();

  bool get isCoreField =>
      path.length == 2 && path.first == 'core' && path.last == key;

  String get pathKey => path.map((part) => '$part').join('.');
}

class _OcrLine {
  const _OcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get height => bottom - top;
  double get centerY => top + (height / 2);
}

class _OcrEvidence {
  const _OcrEvidence({
    required this.text,
    required this.lines,
    required this.blocks,
  });

  final String text;
  final List<Map<String, dynamic>> lines;
  final List<Map<String, dynamic>> blocks;
}
