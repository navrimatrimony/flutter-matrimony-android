import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/api_client.dart';
import '../photo/photo_upload_screen.dart';

class CreateMatrimonyProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? existingProfile;

  const CreateMatrimonyProfileScreen({super.key, this.existingProfile});

  @override
  State<CreateMatrimonyProfileScreen> createState() =>
      _CreateMatrimonyProfileScreenState();
}

class _CreateMatrimonyProfileScreenState
    extends State<CreateMatrimonyProfileScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _religionController = TextEditingController();
  final TextEditingController _casteController = TextEditingController();
  final TextEditingController _subCasteController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  bool _loading = false;
  bool _religionsLoading = false;
  bool _castesLoading = false;
  bool _subCasteSearching = false;
  bool _locationSearching = false;

  int? _selectedReligionId;
  int? _selectedCasteId;
  int? _selectedSubCasteId;
  int? _selectedLocationId;

  String? _selectedReligionLabel;
  String? _selectedCasteLabel;
  String? _selectedSubCasteLabel;
  String? _selectedLocationLabel;

  int _subCasteSearchRequest = 0;
  int _locationSearchRequest = 0;

  List<Map<String, dynamic>> _religions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _religionSuggestions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _castes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _casteSuggestions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _subCasteSuggestions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _locationSuggestions = <Map<String, dynamic>>[];
  final List<String> _selectedEducations = <String>[];

  @override
  void initState() {
    super.initState();
    _prefillExistingProfile();
    _loadReligions();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _dobController.dispose();
    _religionController.dispose();
    _casteController.dispose();
    _subCasteController.dispose();
    _educationController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _optionLabel(Map<String, dynamic> row, String fallbackPrefix) {
    final localizedValue = localizedMapValue(row);
    if (localizedValue != null) return localizedValue;

    for (final key in ['label', 'name', 'display_label', 'label_en']) {
      final value = row[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    return fallbackPrefix;
  }

  List<Map<String, dynamic>> _filterOptions(
    List<Map<String, dynamic>> rows,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return rows.take(20).toList();

    return rows
        .where((row) {
          return ['label', 'name', 'display_label', 'label_en', 'label_mr'].any(
            (key) {
              final value = row[key]?.toString().toLowerCase();
              return value != null && value.contains(normalizedQuery);
            },
          );
        })
        .take(20)
        .toList();
  }

  List<String> _splitEducationText(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) return <String>[];

    final parts = trimmedValue
        .split(RegExp(r'[,|\n\r]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    return parts.length > 1 ? parts : <String>[];
  }

  void _removeEducationChip(String value) {
    setState(() {
      _selectedEducations.remove(value);
    });
  }

  String _educationSubmitText() {
    if (_selectedEducations.isNotEmpty) {
      return _selectedEducations.join(', ');
    }

    return _educationController.text.trim();
  }

  String _educationDisplayText() {
    if (_selectedEducations.isNotEmpty) {
      final summary = _selectedEducations.join(', ');
      return _selectedEducations.length == 1
          ? summary
          : '${_selectedEducations.length} selected: $summary';
    }

    final typedText = _educationController.text.trim();
    if (typedText.isNotEmpty) return typedText;

    return 'Search and add education';
  }

  void _prefillExistingProfile() {
    final profile = widget.existingProfile;
    if (profile == null) return;

    _fullNameController.text = profile['full_name']?.toString() ?? '';
    final educationText = ApiClient.profileEducationLabel(profile) ?? '';
    final educationParts = _splitEducationText(educationText);
    if (educationParts.isNotEmpty) {
      _selectedEducations
        ..clear()
        ..addAll(educationParts);
      _educationController.clear();
    } else {
      _educationController.text = educationText;
    }
    _dobController.text = profile['date_of_birth']?.toString() ?? '';

    _selectedReligionId = _readInt(profile['religion_id']);
    _selectedCasteId = _readInt(profile['caste_id']);
    _selectedSubCasteId = _readInt(profile['sub_caste_id']);

    if (_selectedReligionId != null) {
      _selectedReligionLabel = ApiClient.profileReligionLabel(profile);
      if (_selectedReligionLabel != null) {
        _religionController.text = _selectedReligionLabel ?? '';
      }
    }

    if (_selectedCasteId != null) {
      _selectedCasteLabel = ApiClient.profileCasteLabel(profile);
      if (_selectedCasteLabel != null) {
        _casteController.text = _selectedCasteLabel ?? '';
      }
    } else {
      final casteText = ApiClient.safeDisplayLabel(profile['caste']);
      if (casteText != null && casteText.isNotEmpty) {
        _casteController.text = casteText;
      }
    }

    if (_selectedSubCasteId != null) {
      _selectedSubCasteLabel = ApiClient.profileSubCasteLabel(profile);
      if (_selectedSubCasteLabel != null) {
        _subCasteController.text = _selectedSubCasteLabel ?? '';
      }
    }

    _selectedLocationId = _readInt(profile['location_id']);

    final locationLabel = ApiClient.profileLocationLabel(
      profile,
      allowIdFallback: false,
    );
    if (locationLabel != null) {
      _selectedLocationLabel = locationLabel;
      _locationController.text = locationLabel;
    }
  }

  Future<void> _loadReligions() async {
    setState(() {
      _religionsLoading = true;
    });

    List<Map<String, dynamic>> results;
    try {
      results = await ApiClient.getReligions();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _religionsLoading = false;
      });
      _showMessage('Religion list load करता आली नाही.');
      return;
    }
    if (!mounted) return;

    setState(() {
      _religions = results;
      _religionSuggestions = <Map<String, dynamic>>[];
      _religionsLoading = false;
    });

    final selectedReligionId = _selectedReligionId;
    if (selectedReligionId != null) {
      final selected = results.where(
        (row) => _readInt(row['id']) == selectedReligionId,
      );
      if (selected.isNotEmpty) {
        final label = _optionLabel(selected.first, 'Religion');
        _selectedReligionLabel = label;
        _religionController.text = label;
      }
      await _loadCastes(selectedReligionId, preserveSelection: true);
    }
  }

  Future<void> _loadCastes(
    int religionId, {
    bool preserveSelection = false,
  }) async {
    setState(() {
      _castesLoading = true;
      _casteSuggestions = <Map<String, dynamic>>[];
    });

    List<Map<String, dynamic>> results;
    try {
      results = await ApiClient.getCastes(religionId: religionId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _castesLoading = false;
      });
      _showMessage('Caste list load करता आली नाही.');
      return;
    }
    if (!mounted) return;

    setState(() {
      _castes = results;
      _castesLoading = false;
    });

    if (preserveSelection && _selectedCasteId != null) {
      final selected = results.where(
        (row) => _readInt(row['id']) == _selectedCasteId,
      );
      if (selected.isNotEmpty) {
        final label = _optionLabel(selected.first, 'Caste');
        setState(() {
          _selectedCasteLabel = label;
          _casteController.text = label;
        });
      }
    }
  }

  void _onReligionChanged(String query) {
    if (_selectedReligionLabel == null || query != _selectedReligionLabel) {
      _selectedReligionId = null;
      _selectedReligionLabel = null;
      _selectedCasteId = null;
      _selectedCasteLabel = null;
      _selectedSubCasteId = null;
      _selectedSubCasteLabel = null;
      _castes = <Map<String, dynamic>>[];
      _casteController.clear();
      _subCasteController.clear();
    }

    setState(() {
      _religionSuggestions = _filterOptions(_religions, query);
    });
  }

  Future<void> _selectReligion(Map<String, dynamic> religion) async {
    final id = _readInt(religion['id']);
    if (id == null) return;

    final label = _optionLabel(religion, 'Religion');
    setState(() {
      _selectedReligionId = id;
      _selectedReligionLabel = label;
      _religionController.text = label;
      _religionSuggestions = <Map<String, dynamic>>[];
      _selectedCasteId = null;
      _selectedCasteLabel = null;
      _selectedSubCasteId = null;
      _selectedSubCasteLabel = null;
      _casteController.clear();
      _subCasteController.clear();
      _subCasteSuggestions = <Map<String, dynamic>>[];
    });

    await _loadCastes(id);
  }

  void _onCasteChanged(String query) {
    if (_selectedCasteLabel == null || query != _selectedCasteLabel) {
      _selectedCasteId = null;
      _selectedCasteLabel = null;
      _selectedSubCasteId = null;
      _selectedSubCasteLabel = null;
      _subCasteController.clear();
    }

    setState(() {
      _casteSuggestions = _filterOptions(_castes, query);
    });
  }

  void _selectCaste(Map<String, dynamic> caste) {
    final id = _readInt(caste['id']);
    if (id == null) return;

    final label = _optionLabel(caste, 'Caste');
    setState(() {
      _selectedCasteId = id;
      _selectedCasteLabel = label;
      _casteController.text = label;
      _casteSuggestions = <Map<String, dynamic>>[];
      _selectedSubCasteId = null;
      _selectedSubCasteLabel = null;
      _subCasteController.clear();
      _subCasteSuggestions = <Map<String, dynamic>>[];
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _searchSubCastes(String query) async {
    final casteId = _selectedCasteId;
    final requestId = ++_subCasteSearchRequest;
    final trimmedQuery = query.trim();

    if (_selectedSubCasteLabel == null ||
        trimmedQuery != _selectedSubCasteLabel) {
      _selectedSubCasteId = null;
      _selectedSubCasteLabel = null;
    }

    if (casteId == null || trimmedQuery.length < 2) {
      setState(() {
        _subCasteSearching = false;
        _subCasteSuggestions = <Map<String, dynamic>>[];
      });
      return;
    }

    setState(() {
      _subCasteSearching = true;
    });

    List<Map<String, dynamic>> results;
    try {
      results = await ApiClient.searchSubCastes(
        casteId: casteId,
        query: trimmedQuery,
      );
    } catch (_) {
      if (!mounted || requestId != _subCasteSearchRequest) return;
      setState(() {
        _subCasteSearching = false;
        _subCasteSuggestions = <Map<String, dynamic>>[];
      });
      _showMessage('Sub-caste search करता आली नाही.');
      return;
    }
    if (!mounted || requestId != _subCasteSearchRequest) return;

    setState(() {
      _subCasteSuggestions = results;
      _subCasteSearching = false;
    });
  }

  void _selectSubCaste(Map<String, dynamic> subCaste) {
    final id = _readInt(subCaste['id']);
    if (id == null) return;

    final label = _optionLabel(subCaste, 'Sub-caste');
    setState(() {
      _selectedSubCasteId = id;
      _selectedSubCasteLabel = label;
      _subCasteController.text = label;
      _subCasteSuggestions = <Map<String, dynamic>>[];
      _subCasteSearching = false;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _searchLocations(String query) async {
    final requestId = ++_locationSearchRequest;
    final trimmedQuery = query.trim();

    if (_selectedLocationLabel == null ||
        trimmedQuery != _selectedLocationLabel) {
      _selectedLocationId = null;
      _selectedLocationLabel = null;
    }

    if (trimmedQuery.length < 2) {
      setState(() {
        _locationSearching = false;
        _locationSuggestions = <Map<String, dynamic>>[];
      });
      return;
    }

    setState(() {
      _locationSearching = true;
    });

    List<Map<String, dynamic>> results;
    try {
      results = await ApiClient.searchLocations(trimmedQuery);
    } catch (_) {
      if (!mounted || requestId != _locationSearchRequest) return;
      setState(() {
        _locationSearching = false;
        _locationSuggestions = <Map<String, dynamic>>[];
      });
      _showMessage('Location search करता आली नाही.');
      return;
    }
    if (!mounted || requestId != _locationSearchRequest) return;

    setState(() {
      _locationSuggestions = results;
      _locationSearching = false;
    });
  }

  void _selectLocation(Map<String, dynamic> location) {
    final locationId = ApiClient.locationIdFrom(location);
    if (locationId == null) return;

    final label = ApiClient.locationSuggestionLabel(location);
    setState(() {
      _selectedLocationId = locationId;
      _selectedLocationLabel = label;
      _locationController.text = label;
      _locationSuggestions = <Map<String, dynamic>>[];
      _locationSearching = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitProfile() async {
    final selectedCasteLabel = _selectedCasteLabel?.trim();
    final casteLabel =
        selectedCasteLabel != null && selectedCasteLabel.isNotEmpty
        ? selectedCasteLabel
        : _casteController.text.trim();
    final educationText = _educationSubmitText();

    if (_selectedReligionId == null) {
      _showMessage('कृपया suggestions मधून religion निवडा.');
      return;
    }
    if (_selectedCasteId == null || casteLabel.isEmpty) {
      _showMessage('कृपया suggestions मधून caste निवडा.');
      return;
    }
    if (_selectedLocationId == null) {
      _showMessage('कृपया suggestions मधून location निवडा.');
      return;
    }
    if (educationText.isEmpty) {
      _showMessage('कृपया education भरा किंवा suggestion निवडा.');
      return;
    }

    setState(() {
      _loading = true;
    });

    final payload = <String, dynamic>{
      'full_name': _fullNameController.text.trim(),
      'date_of_birth': _dobController.text.trim(),
      'religion_id': _selectedReligionId,
      'caste_id': _selectedCasteId,
      'caste': casteLabel,
      'highest_education': educationText,
      'location_id': _selectedLocationId,
    };

    if (_selectedSubCasteId != null) {
      payload['sub_caste_id'] = _selectedSubCasteId;
    }

    Map<String, dynamic> response;
    try {
      response = widget.existingProfile == null
          ? await ApiClient.createMatrimonyProfile(payload)
          : await ApiClient.updateMatrimonyProfile(payload);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      _showMessage('Profile save करता आली नाही. कृपया पुन्हा प्रयत्न करा.');
      return;
    }

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    if (response['success'] == true) {
      final isCreate = widget.existingProfile == null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCreate ? 'Profile create यशस्वी!' : 'Profile update यशस्वी!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      if (isCreate) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PhotoUploadScreen()),
        );
      } else {
        Navigator.pushReplacementNamed(context, '/view-profile');
      }
    } else {
      _showMessage(response['message']?.toString() ?? 'Profile save failed');
    }
  }

  Widget _buildOptionSuggestions({
    required List<Map<String, dynamic>> suggestions,
    required String fallbackPrefix,
    required void Function(Map<String, dynamic>) onSelect,
    bool loading = false,
  }) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(),
      );
    }

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final item = suggestions[index];
          final label = _optionLabel(item, fallbackPrefix);
          final subtitle = item['category']?.toString().trim();

          return ListTile(
            dense: true,
            title: Text(label),
            subtitle: subtitle != null && subtitle.isNotEmpty
                ? Text(subtitle)
                : null,
            onTap: () => onSelect(item),
          );
        },
      ),
    );
  }

  Widget _buildEducationChips({VoidCallback? onChanged}) {
    if (_selectedEducations.isEmpty) {
      if (_educationController.text.trim().isNotEmpty) {
        return const SizedBox.shrink();
      }

      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Search suggestions or add typed education.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _selectedEducations.map((education) {
            return InputChip(
              label: Text(education),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () {
                _removeEducationChip(education);
                onChanged?.call();
              },
              backgroundColor: Colors.blue.shade50,
              side: BorderSide(color: Colors.blue.shade200),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _openEducationPicker() async {
    final result = await showModalBottomSheet<_EducationPickerResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _EducationPickerSheet(
          initialSelected: _selectedEducations,
          initialText: _educationController.text,
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      _selectedEducations
        ..clear()
        ..addAll(result.selected);
      _educationController.text =
          result.selected.isEmpty ? result.typedText : '';
    });
    FocusScope.of(context).unfocus();
  }

  Widget _buildLocationSuggestions() {
    if (_locationSearching) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(),
      );
    }

    if (_locationSuggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _locationSuggestions.length,
        itemBuilder: (context, index) {
          final location = _locationSuggestions[index];
          final label = ApiClient.locationSuggestionLabel(location);
          final hierarchy = location['hierarchy']?.toString().trim();

          return ListTile(
            dense: true,
            title: Text(label),
            subtitle:
                hierarchy != null && hierarchy.isNotEmpty && hierarchy != label
                ? Text(hierarchy)
                : null,
            onTap: () => _selectLocation(location),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subCasteEnabled = _selectedCasteId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingProfile == null ? 'Create Profile' : 'Edit Profile',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dobController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Date of Birth (YYYY-MM-DD)',
              ),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime(1995),
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                );

                if (pickedDate != null) {
                  if (!context.mounted) return;

                  final dateStr =
                      "${pickedDate.year.toString().padLeft(4, '0')}-"
                      "${pickedDate.month.toString().padLeft(2, '0')}-"
                      "${pickedDate.day.toString().padLeft(2, '0')}";
                  _dobController.text = dateStr;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Date select केले: $dateStr'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _religionController,
              decoration: const InputDecoration(labelText: 'Religion'),
              onChanged: _onReligionChanged,
              onTap: () => _onReligionChanged(_religionController.text),
            ),
            _buildOptionSuggestions(
              suggestions: _religionSuggestions,
              fallbackPrefix: 'Religion',
              onSelect: _selectReligion,
              loading: _religionsLoading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _casteController,
              enabled: _selectedReligionId != null && !_castesLoading,
              decoration: InputDecoration(
                labelText: 'Caste',
                hintText: _selectedReligionId == null
                    ? 'Select religion first'
                    : null,
              ),
              onChanged: _onCasteChanged,
              onTap: () => _onCasteChanged(_casteController.text),
            ),
            _buildOptionSuggestions(
              suggestions: _casteSuggestions,
              fallbackPrefix: 'Caste',
              onSelect: _selectCaste,
              loading: _castesLoading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subCasteController,
              enabled: subCasteEnabled,
              decoration: InputDecoration(
                labelText: 'Sub-caste (Optional)',
                hintText: subCasteEnabled ? null : 'Select caste first',
              ),
              onChanged: _searchSubCastes,
            ),
            _buildOptionSuggestions(
              suggestions: _subCasteSuggestions,
              fallbackPrefix: 'Sub-caste',
              onSelect: _selectSubCaste,
              loading: _subCasteSearching,
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _openEducationPicker,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Education',
                  suffixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _educationDisplayText(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        _selectedEducations.isEmpty &&
                            _educationController.text.trim().isEmpty
                        ? Colors.grey.shade700
                        : null,
                  ),
                ),
              ),
            ),
            _buildEducationChips(),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
              onChanged: _searchLocations,
            ),
            _buildLocationSuggestions(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submitProfile,
                child: _loading
                    ? const CircularProgressIndicator()
                    : Text(
                        widget.existingProfile == null
                            ? 'Create Profile'
                            : 'Update Profile',
                      ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }
}

class _EducationPickerResult {
  final List<String> selected;
  final String typedText;

  const _EducationPickerResult({
    required this.selected,
    required this.typedText,
  });
}

class _EducationPickerSheet extends StatefulWidget {
  final List<String> initialSelected;
  final String initialText;

  const _EducationPickerSheet({
    required this.initialSelected,
    required this.initialText,
  });

  @override
  State<_EducationPickerSheet> createState() => _EducationPickerSheetState();
}

class _EducationPickerSheetState extends State<_EducationPickerSheet> {
  late final TextEditingController _searchController;
  late final List<String> _selected;
  List<Map<String, dynamic>> _suggestions = <Map<String, dynamic>>[];
  bool _searching = false;
  int _searchRequest = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialText);
    _selected = List<String>.from(widget.initialSelected);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _hasEducationChip(String label) {
    final normalizedLabel = label.trim().toLowerCase();
    return _selected.any(
      (item) => item.trim().toLowerCase() == normalizedLabel,
    );
  }

  bool _canAddEducationLabel(String value) {
    final label = value.trim();
    return label.isNotEmpty && !_hasEducationChip(label);
  }

  void _addEducation(String value) {
    final label = value.trim();
    if (!_canAddEducationLabel(label)) return;

    setState(() {
      _selected.add(label);
      _searchController.clear();
      _suggestions = <Map<String, dynamic>>[];
      _searching = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _removeEducation(String value) {
    setState(() {
      _selected.remove(value);
    });
  }

  Future<void> _searchEducation(String query) async {
    final currentRequest = ++_searchRequest;
    final trimmedQuery = query.trim();

    if (trimmedQuery.length < 2) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _suggestions = <Map<String, dynamic>>[];
      });
      return;
    }

    setState(() {
      _searching = true;
    });

    List<Map<String, dynamic>> results;
    try {
      results = await ApiClient.searchEducationDegrees(trimmedQuery);
    } catch (_) {
      if (!mounted || currentRequest != _searchRequest) return;
      setState(() {
        _suggestions = <Map<String, dynamic>>[];
        _searching = false;
      });
      return;
    }
    if (!mounted || currentRequest != _searchRequest) return;

    setState(() {
      _suggestions = results;
      _searching = false;
    });
  }

  void _finish() {
    Navigator.pop(
      context,
      _EducationPickerResult(
        selected: List<String>.from(_selected),
        typedText: _searchController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final canAddTyped = _canAddEducationLabel(query);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select education',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Done'),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Search education',
                  hintText: 'Type degree or education',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Add typed education',
                    icon: const Icon(Icons.add),
                    onPressed: canAddTyped
                        ? () => _addEducation(_searchController.text)
                        : null,
                  ),
                ),
                onChanged: _searchEducation,
                onSubmitted: _addEducation,
              ),
              _buildSelectedChips(),
              const SizedBox(height: 12),
              if (_searching) const LinearProgressIndicator(),
              if (_searching) const SizedBox(height: 8),
              Expanded(child: _buildResults(query, canAddTyped)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedChips() {
    if (_selected.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Search suggestions or add typed education.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _selected.map((education) {
            return InputChip(
              label: Text(education),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () => _removeEducation(education),
              backgroundColor: Colors.blue.shade50,
              side: BorderSide(color: Colors.blue.shade200),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildResults(String query, bool canAddTyped) {
    if (query.length < 2) {
      return Center(
        child: Text(
          'Type at least 2 letters to search.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No suggestion found.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: canAddTyped
                  ? () => _addEducation(_searchController.text)
                  : null,
              icon: const Icon(Icons.add),
              label: Text('Add "$query"'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _suggestions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final education = _suggestions[index];
        final label = ApiClient.safeDisplayLabel(education) ?? 'Education';
        final alreadySelected = _hasEducationChip(label);

        return ListTile(
          leading: Icon(
            alreadySelected ? Icons.check_circle : Icons.school_outlined,
            color: alreadySelected ? Colors.green : null,
          ),
          title: Text(label),
          trailing: alreadySelected ? const Text('Added') : null,
          onTap: alreadySelected ? null : () => _addEducation(label),
        );
      },
    );
  }
}
