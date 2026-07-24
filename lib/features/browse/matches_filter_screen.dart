import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_strings.dart';
import '../../core/app_language.dart';

const Object _unset = Object();

class MatchesFilterState {
  const MatchesFilterState({
    this.ageFrom,
    this.ageTo,
    this.heightFromCm,
    this.heightToCm,
    this.religionId,
    this.religionLabel,
    this.casteId,
    this.casteLabel,
    this.countryId,
    this.countryLabel,
    this.stateId,
    this.stateLabel,
    this.districtId,
    this.districtLabel,
    this.locationId,
    this.locationLabel,
    this.photoAvailable = false,
    this.verifiedPhoto = false,
    this.recentlyActive = false,
    this.educationId,
    this.educationLabel,
    this.occupationId,
    this.occupationLabel,
    this.maritalStatusId,
    this.maritalStatusLabel,
  });

  final int? ageFrom;
  final int? ageTo;
  final int? heightFromCm;
  final int? heightToCm;
  final int? religionId;
  final String? religionLabel;
  final int? casteId;
  final String? casteLabel;
  final int? countryId;
  final String? countryLabel;
  final int? stateId;
  final String? stateLabel;
  final int? districtId;
  final String? districtLabel;
  final int? locationId;
  final String? locationLabel;
  final bool photoAvailable;
  final bool verifiedPhoto;
  final bool recentlyActive;
  final int? educationId;
  final String? educationLabel;
  final int? occupationId;
  final String? occupationLabel;
  final int? maritalStatusId;
  final String? maritalStatusLabel;

  bool get hasActiveFilters =>
      ageFrom != null ||
      ageTo != null ||
      heightFromCm != null ||
      heightToCm != null ||
      religionId != null ||
      _hasText(religionLabel) ||
      casteId != null ||
      _hasText(casteLabel) ||
      countryId != null ||
      _hasText(countryLabel) ||
      stateId != null ||
      _hasText(stateLabel) ||
      districtId != null ||
      _hasText(districtLabel) ||
      locationId != null ||
      _hasText(locationLabel) ||
      photoAvailable ||
      verifiedPhoto ||
      recentlyActive ||
      educationId != null ||
      _hasText(educationLabel) ||
      occupationId != null ||
      _hasText(occupationLabel) ||
      maritalStatusId != null ||
      _hasText(maritalStatusLabel);

  bool get hasLocationFilter =>
      countryId != null ||
      _hasText(countryLabel) ||
      stateId != null ||
      _hasText(stateLabel) ||
      districtId != null ||
      _hasText(districtLabel) ||
      locationId != null ||
      _hasText(locationLabel);

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;

  String? get casteQuery {
    final value = casteLabel?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  MatchesFilterState copyWith({
    Object? ageFrom = _unset,
    Object? ageTo = _unset,
    Object? heightFromCm = _unset,
    Object? heightToCm = _unset,
    Object? religionId = _unset,
    Object? religionLabel = _unset,
    Object? casteId = _unset,
    Object? casteLabel = _unset,
    Object? countryId = _unset,
    Object? countryLabel = _unset,
    Object? stateId = _unset,
    Object? stateLabel = _unset,
    Object? districtId = _unset,
    Object? districtLabel = _unset,
    Object? locationId = _unset,
    Object? locationLabel = _unset,
    Object? photoAvailable = _unset,
    Object? verifiedPhoto = _unset,
    Object? recentlyActive = _unset,
    Object? educationId = _unset,
    Object? educationLabel = _unset,
    Object? occupationId = _unset,
    Object? occupationLabel = _unset,
    Object? maritalStatusId = _unset,
    Object? maritalStatusLabel = _unset,
  }) {
    return MatchesFilterState(
      ageFrom: identical(ageFrom, _unset) ? this.ageFrom : ageFrom as int?,
      ageTo: identical(ageTo, _unset) ? this.ageTo : ageTo as int?,
      heightFromCm: identical(heightFromCm, _unset)
          ? this.heightFromCm
          : heightFromCm as int?,
      heightToCm: identical(heightToCm, _unset)
          ? this.heightToCm
          : heightToCm as int?,
      religionId: identical(religionId, _unset)
          ? this.religionId
          : religionId as int?,
      religionLabel: identical(religionLabel, _unset)
          ? this.religionLabel
          : religionLabel as String?,
      casteId: identical(casteId, _unset) ? this.casteId : casteId as int?,
      casteLabel: identical(casteLabel, _unset)
          ? this.casteLabel
          : casteLabel as String?,
      countryId: identical(countryId, _unset)
          ? this.countryId
          : countryId as int?,
      countryLabel: identical(countryLabel, _unset)
          ? this.countryLabel
          : countryLabel as String?,
      stateId: identical(stateId, _unset) ? this.stateId : stateId as int?,
      stateLabel: identical(stateLabel, _unset)
          ? this.stateLabel
          : stateLabel as String?,
      districtId: identical(districtId, _unset)
          ? this.districtId
          : districtId as int?,
      districtLabel: identical(districtLabel, _unset)
          ? this.districtLabel
          : districtLabel as String?,
      locationId: identical(locationId, _unset)
          ? this.locationId
          : locationId as int?,
      locationLabel: identical(locationLabel, _unset)
          ? this.locationLabel
          : locationLabel as String?,
      photoAvailable: identical(photoAvailable, _unset)
          ? this.photoAvailable
          : photoAvailable as bool,
      verifiedPhoto: identical(verifiedPhoto, _unset)
          ? this.verifiedPhoto
          : verifiedPhoto as bool,
      recentlyActive: identical(recentlyActive, _unset)
          ? this.recentlyActive
          : recentlyActive as bool,
      educationId: identical(educationId, _unset)
          ? this.educationId
          : educationId as int?,
      educationLabel: identical(educationLabel, _unset)
          ? this.educationLabel
          : educationLabel as String?,
      occupationId: identical(occupationId, _unset)
          ? this.occupationId
          : occupationId as int?,
      occupationLabel: identical(occupationLabel, _unset)
          ? this.occupationLabel
          : occupationLabel as String?,
      maritalStatusId: identical(maritalStatusId, _unset)
          ? this.maritalStatusId
          : maritalStatusId as int?,
      maritalStatusLabel: identical(maritalStatusLabel, _unset)
          ? this.maritalStatusLabel
          : maritalStatusLabel as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MatchesFilterState &&
        other.ageFrom == ageFrom &&
        other.ageTo == ageTo &&
        other.heightFromCm == heightFromCm &&
        other.heightToCm == heightToCm &&
        other.religionId == religionId &&
        other.religionLabel == religionLabel &&
        other.casteId == casteId &&
        other.casteLabel == casteLabel &&
        other.countryId == countryId &&
        other.countryLabel == countryLabel &&
        other.stateId == stateId &&
        other.stateLabel == stateLabel &&
        other.districtId == districtId &&
        other.districtLabel == districtLabel &&
        other.locationId == locationId &&
        other.locationLabel == locationLabel &&
        other.photoAvailable == photoAvailable &&
        other.verifiedPhoto == verifiedPhoto &&
        other.recentlyActive == recentlyActive &&
        other.educationId == educationId &&
        other.educationLabel == educationLabel &&
        other.occupationId == occupationId &&
        other.occupationLabel == occupationLabel &&
        other.maritalStatusId == maritalStatusId &&
        other.maritalStatusLabel == maritalStatusLabel;
  }

  @override
  int get hashCode => Object.hashAll([
    ageFrom,
    ageTo,
    heightFromCm,
    heightToCm,
    religionId,
    religionLabel,
    casteId,
    casteLabel,
    countryId,
    countryLabel,
    stateId,
    stateLabel,
    districtId,
    districtLabel,
    locationId,
    locationLabel,
    photoAvailable,
    verifiedPhoto,
    recentlyActive,
    educationId,
    educationLabel,
    occupationId,
    occupationLabel,
    maritalStatusId,
    maritalStatusLabel,
  ]);
}

class MatchesFilterScreen extends StatefulWidget {
  const MatchesFilterScreen({super.key, required this.initialFilters});

  final MatchesFilterState initialFilters;

  @override
  State<MatchesFilterScreen> createState() => _MatchesFilterScreenState();
}

class _MatchesFilterScreenState extends State<MatchesFilterScreen> {
  static const Color _brandColor = Color(0xFFDC2626);
  static const Color _brandSoft = Color(0xFFFFE4E6);
  static const Color _ink = Color(0xFF2F2427);
  static const int _minAge = 18;
  static const int _maxAge = 70;
  static const int _minHeightCm = 137;
  static const int _maxHeightCm = 213;

  late MatchesFilterState _draft;

  bool get _isMarathi => AppStrings.isMarathi;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialFilters;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8F5),
        appBar: AppBar(
          title: Text(_text('Filter matches', 'फिल्टर')),
          centerTitle: true,
          backgroundColor: _brandColor,
          foregroundColor: Colors.white,
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.72),
            tabs: [
              Tab(text: _text('Minimum', 'Minimum')),
              Tab(text: _text('Advanced', 'Advanced')),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildMinimumFilters(), _buildAdvancedFilters()],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _draft = const MatchesFilterState());
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(_text('Clear', 'Clear')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _brandColor,
                      side: const BorderSide(color: _brandColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, _draft),
                    icon: const Icon(Icons.done_rounded),
                    label: Text(_text('Apply', 'Apply')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimumFilters() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _buildSectionCard(
          title: _text('Basic preference', 'Basic preference'),
          children: [
            _buildRangeBlock(
              label: _text('Age', 'वय'),
              valueLabel: _ageLabel,
              values: RangeValues(
                (_draft.ageFrom ?? _minAge).toDouble(),
                (_draft.ageTo ?? _maxAge).toDouble(),
              ),
              min: _minAge.toDouble(),
              max: _maxAge.toDouble(),
              divisions: _maxAge - _minAge,
              onChanged: (values) {
                setState(() {
                  _draft = _draft.copyWith(
                    ageFrom: values.start.round(),
                    ageTo: values.end.round(),
                  );
                });
              },
            ),
            const SizedBox(height: 18),
            _buildRangeBlock(
              label: _text('Height', 'उंची'),
              valueLabel: _heightLabel,
              values: RangeValues(
                (_draft.heightFromCm ?? _minHeightCm).toDouble(),
                (_draft.heightToCm ?? _maxHeightCm).toDouble(),
              ),
              min: _minHeightCm.toDouble(),
              max: _maxHeightCm.toDouble(),
              divisions: _maxHeightCm - _minHeightCm,
              onChanged: (values) {
                setState(() {
                  _draft = _draft.copyWith(
                    heightFromCm: values.start.round(),
                    heightToCm: values.end.round(),
                  );
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: _text('Community', 'धर्म / जात'),
          children: [
            _buildPickerTile(
              icon: Icons.temple_hindu_outlined,
              label: _text('Religion', 'धर्म'),
              value: _draft.religionLabel,
              onTap: _pickReligion,
              onClear: _draft.religionId == null
                  ? null
                  : () {
                      setState(() {
                        _draft = _draft.copyWith(
                          religionId: null,
                          religionLabel: null,
                          casteId: null,
                          casteLabel: null,
                        );
                      });
                    },
            ),
            const SizedBox(height: 10),
            _buildPickerTile(
              icon: Icons.groups_2_outlined,
              label: _text('Caste', 'जात'),
              value: _draft.casteLabel,
              onTap: _pickCaste,
              onClear: _draft.casteId == null
                  ? null
                  : () {
                      setState(() {
                        _draft = _draft.copyWith(
                          casteId: null,
                          casteLabel: null,
                        );
                      });
                    },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: _text('Location', 'ठिकाण'),
          children: [
            _buildPickerTile(
              icon: Icons.public_rounded,
              label: _text('Country', 'देश'),
              value: _draft.countryLabel,
              onTap: () => _pickLocation('country'),
              onClear: _draft.countryId == null
                  ? null
                  : () {
                      setState(() {
                        _draft = _draft.copyWith(
                          countryId: null,
                          countryLabel: null,
                          stateId: null,
                          stateLabel: null,
                          districtId: null,
                          districtLabel: null,
                          locationId: null,
                          locationLabel: null,
                        );
                      });
                    },
            ),
            const SizedBox(height: 10),
            _buildPickerTile(
              icon: Icons.map_outlined,
              label: _text('State', 'राज्य'),
              value: _draft.stateLabel,
              onTap: () => _pickLocation('state'),
              onClear: _draft.stateId == null
                  ? null
                  : () {
                      setState(() {
                        _draft = _draft.copyWith(
                          stateId: null,
                          stateLabel: null,
                          districtId: null,
                          districtLabel: null,
                          locationId: null,
                          locationLabel: null,
                        );
                      });
                    },
            ),
            const SizedBox(height: 10),
            _buildPickerTile(
              icon: Icons.location_city_outlined,
              label: _text('District', 'जिल्हा'),
              value: _draft.districtLabel ?? _draft.locationLabel,
              onTap: () => _pickLocation('district'),
              onClear: _draft.districtId == null && _draft.locationId == null
                  ? null
                  : () {
                      setState(() {
                        _draft = _draft.copyWith(
                          districtId: null,
                          districtLabel: null,
                          locationId: null,
                          locationLabel: null,
                        );
                      });
                    },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedFilters() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _buildSectionCard(
          title: _text('Profile quality', 'प्रोफाइल quality'),
          children: [
            _buildSwitchTile(
              icon: Icons.photo_camera_back_outlined,
              label: _text('Photo available', 'फोटो उपलब्ध'),
              value: _draft.photoAvailable,
              onChanged: (value) {
                setState(() {
                  _draft = _draft.copyWith(photoAvailable: value);
                });
              },
            ),
            const SizedBox(height: 8),
            _buildSwitchTile(
              icon: Icons.verified_outlined,
              label: _text('Verified photo', 'Verified photo'),
              value: _draft.verifiedPhoto,
              onChanged: (value) {
                setState(() {
                  _draft = _draft.copyWith(verifiedPhoto: value);
                });
              },
            ),
            const SizedBox(height: 8),
            _buildSwitchTile(
              icon: Icons.bolt_outlined,
              label: _text('Recently active', 'Recently active'),
              value: _draft.recentlyActive,
              onChanged: (value) {
                setState(() {
                  _draft = _draft.copyWith(recentlyActive: value);
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: _text('Education and work', 'शिक्षण / काम'),
          children: [
            _buildPickerTile(
              icon: Icons.school_outlined,
              label: _text('Education', 'शिक्षण'),
              value: _draft.educationLabel,
              onTap: _pickEducation,
              onClear: _draft.educationId == null
                  ? null
                  : () {
                      setState(() {
                        _draft = _draft.copyWith(
                          educationId: null,
                          educationLabel: null,
                        );
                      });
                    },
            ),
            const SizedBox(height: 10),
            _buildPickerTile(
              icon: Icons.work_outline_rounded,
              label: _text('Occupation', 'व्यवसाय'),
              value: _draft.occupationLabel,
              onTap: _pickOccupation,
              onClear: _draft.occupationId == null
                  ? null
                  : () {
                      setState(() {
                        _draft = _draft.copyWith(
                          occupationId: null,
                          occupationLabel: null,
                        );
                      });
                    },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: _text('Marital', 'वैवाहिक'),
          children: [
            _buildPickerTile(
              icon: Icons.favorite_border_rounded,
              label: _text('Marital status', 'वैवाहिक स्थिती'),
              value: _draft.maritalStatusLabel,
              onTap: _pickMaritalStatus,
              onClear: _draft.maritalStatusId == null
                  ? null
                  : () {
                      setState(() {
                        _draft = _draft.copyWith(
                          maritalStatusId: null,
                          maritalStatusLabel: null,
                        );
                      });
                    },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9DAD5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRangeBlock({
    required String label,
    required String Function(int value) valueLabel,
    required RangeValues values,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<RangeValues> onChanged,
  }) {
    final start = values.start.round();
    final end = values.end.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${valueLabel(start)} - ${valueLabel(end)}',
              style: const TextStyle(
                color: _brandColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        RangeSlider(
          values: values,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: _brandColor,
          inactiveColor: _brandSoft,
          labels: RangeLabels(valueLabel(start), valueLabel(end)),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildPickerTile({
    required IconData icon,
    required String label,
    required String? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final hasValue = value != null && value.trim().isNotEmpty;

    return Material(
      color: const Color(0xFFFCFBFA),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6D8D3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: _brandColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B5A5E),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasValue ? value : _text('Select', 'निवडा'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasValue ? _ink : Colors.grey.shade500,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.grey.shade600,
                )
              else
                const Icon(Icons.chevron_right_rounded, color: _brandColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFBFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6D8D3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _brandColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: _brandColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _pickReligion() async {
    final option = await _openLookupPicker(
      title: _text('Select religion', 'धर्म निवडा'),
      loader: (query) async => _rowsFromResponse(
        await ApiClient.searchReligions(
          query: query,
          locale: appLanguageCode(currentAppLanguage),
        ),
      ),
    );
    if (option == null) return;

    setState(() {
      _draft = _draft.copyWith(
        religionId: option.id,
        religionLabel: option.label,
        casteId: null,
        casteLabel: null,
      );
    });
  }

  Future<void> _pickCaste() async {
    final religionId = _draft.religionId;
    if (religionId == null) {
      _showSnackBar(_text('Select religion first.', 'आधी धर्म निवडा.'));
      return;
    }

    final option = await _openLookupPicker(
      title: _text('Select caste', 'जात निवडा'),
      loader: (query) async => _rowsFromResponse(
        await ApiClient.searchCastes(
          religionId: religionId,
          query: query,
          locale: appLanguageCode(currentAppLanguage),
        ),
      ),
    );
    if (option == null) return;

    setState(() {
      _draft = _draft.copyWith(casteId: option.id, casteLabel: option.label);
    });
  }

  Future<void> _pickLocation(String type) async {
    final title = switch (type) {
      'country' => _text('Select country', 'देश निवडा'),
      'state' => _text('Select state', 'राज्य निवडा'),
      _ => _text('Select district', 'जिल्हा निवडा'),
    };

    final option = await _openLookupPicker(
      title: title,
      loader: (query) async => _rowsFromResponse(
        await ApiClient.searchLocationsForOnboarding(
          query: query,
          type: type,
          locale: appLanguageCode(currentAppLanguage),
        ),
      ),
      locationRows: true,
    );
    if (option == null) return;

    setState(() {
      if (type == 'country') {
        _draft = _draft.copyWith(
          countryId: option.id,
          countryLabel: option.label,
          stateId: null,
          stateLabel: null,
          districtId: null,
          districtLabel: null,
          locationId: null,
          locationLabel: null,
        );
      } else if (type == 'state') {
        _draft = _draft.copyWith(
          stateId: option.id,
          stateLabel: option.label,
          districtId: null,
          districtLabel: null,
          locationId: null,
          locationLabel: null,
        );
      } else {
        _draft = _draft.copyWith(
          districtId: option.id,
          districtLabel: option.label,
          locationId: null,
          locationLabel: null,
        );
      }
    });
  }

  Future<void> _pickEducation() async {
    final option = await _openLookupPicker(
      title: _text('Select education', 'शिक्षण निवडा'),
      loader: (query) async => _rowsFromResponse(
        await ApiClient.searchEducation(
          query: query,
          locale: appLanguageCode(currentAppLanguage),
        ),
      ),
    );
    if (option == null) return;

    setState(() {
      _draft = _draft.copyWith(
        educationId: option.id,
        educationLabel: option.label,
      );
    });
  }

  Future<void> _pickOccupation() async {
    final option = await _openLookupPicker(
      title: _text('Select occupation', 'व्यवसाय निवडा'),
      loader: (query) async => _rowsFromResponse(
        await ApiClient.searchOccupations(
          query: query,
          locale: appLanguageCode(currentAppLanguage),
        ),
      ),
    );
    if (option == null) return;

    setState(() {
      _draft = _draft.copyWith(
        occupationId: option.id,
        occupationLabel: option.label,
      );
    });
  }

  Future<void> _pickMaritalStatus() async {
    final options = await _maritalStatusRows();
    if (options.isEmpty && mounted) {
      _showSnackBar(
        _text(
          'Marital status options are not available.',
          'वैवाहिक स्थितीचे पर्याय उपलब्ध नाहीत.',
        ),
      );
      return;
    }

    final option = await _openLookupPicker(
      title: _text('Select marital status', 'वैवाहिक स्थिती निवडा'),
      loader: (query) async => _filterRows(options, query),
    );
    if (option == null) return;

    setState(() {
      _draft = _draft.copyWith(
        maritalStatusId: option.id,
        maritalStatusLabel: option.label,
      );
    });
  }

  Future<List<Map<String, dynamic>>> _maritalStatusRows() async {
    try {
      final data = await ApiClient.getProfileMaritalLifestyleOptions();
      return List<Map<String, dynamic>>.from(
        data['marital_statuses'] ?? const <Map<String, dynamic>>[],
      );
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<_LookupOption?> _openLookupPicker({
    required String title,
    required Future<List<Map<String, dynamic>>> Function(String query) loader,
    bool locationRows = false,
  }) {
    return showModalBottomSheet<_LookupOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _LookupPickerSheet(
          title: title,
          loader: loader,
          locationRows: locationRows,
          isMarathi: _isMarathi,
        );
      },
    );
  }

  List<Map<String, dynamic>> _rowsFromResponse(Map<String, dynamic> response) {
    return _rowsFromAny(response);
  }

  List<Map<String, dynamic>> _rowsFromAny(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((row) {
        return Map<String, dynamic>.from(row);
      }).toList();
    }

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in [
        'data',
        'items',
        'results',
        'options',
        'rows',
        'locations',
        'religions',
        'castes',
        'education',
        'occupations',
        'marital_statuses',
      ]) {
        final rows = _rowsFromAny(map[key]);
        if (rows.isNotEmpty) return rows;
      }
    }

    return <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _filterRows(
    List<Map<String, dynamic>> rows,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return rows;

    return rows.where((row) {
      final label = _optionLabel(row).toLowerCase();
      return label.contains(normalizedQuery);
    }).toList();
  }

  String _ageLabel(int value) => _isMarathi ? '$value वर्षे' : '$value yrs';

  String _heightLabel(int cm) {
    final totalInches = (cm / 2.54).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return '$feet\'$inches"';
  }

  String _text(String en, String mr) => _isMarathi ? mr : en;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

typedef _LookupLoader =
    Future<List<Map<String, dynamic>>> Function(String query);

class _LookupPickerSheet extends StatefulWidget {
  const _LookupPickerSheet({
    required this.title,
    required this.loader,
    required this.locationRows,
    required this.isMarathi,
  });

  final String title;
  final _LookupLoader loader;
  final bool locationRows;
  final bool isMarathi;

  @override
  State<_LookupPickerSheet> createState() => _LookupPickerSheetState();
}

class _LookupPickerSheetState extends State<_LookupPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load('');
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), () {
      _load(_searchController.text);
    });
  }

  Future<void> _load(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await widget.loader(query);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rows = <Map<String, dynamic>>[];
        _loading = false;
        _error = appText.couldNotLoadOptions;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5D6D1),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF2F2427),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: appText.search,
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFFFCFBFA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE6D8D3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE6D8D3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFFDC2626),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            if (_loading)
              const SizedBox(height: 2, child: LinearProgressIndicator()),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    if (!_loading && _rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            appText.noOptionsFound,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
      itemCount: _rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = _rows[index];
        final label = widget.locationRows
            ? ApiClient.locationSuggestionLabel(row)
            : _optionLabel(row);
        final subtitle = _optionSubtitle(row, label);
        final option = _LookupOption(_optionId(row), label);

        return ListTile(
          leading: Icon(
            widget.locationRows
                ? Icons.place_outlined
                : Icons.radio_button_unchecked_rounded,
            color: const Color(0xFFDC2626),
          ),
          title: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: subtitle == null
              ? null
              : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => Navigator.pop(context, option),
        );
      },
    );
  }
}

class _LookupOption {
  const _LookupOption(this.id, this.label);

  final int? id;
  final String label;
}

int? _optionId(Map<String, dynamic> row) {
  for (final key in ['id', 'value', 'location_id']) {
    final value = row[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}

String _optionLabel(Map<String, dynamic> row) {
  return ApiClient.safeDisplayLabel(row, allowIdFallback: true) ?? 'Option';
}

String? _optionSubtitle(Map<String, dynamic> row, String label) {
  for (final key in ['hierarchy', 'subtitle', 'description']) {
    final value = ApiClient.safeDisplayLabel(row[key]);
    if (value != null && value != label) return value;
  }
  return null;
}
