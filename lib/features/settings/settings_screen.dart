import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_strings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _isSavingPrivacy = false;
  bool _isSavingCommunication = false;
  bool _isSavingNotifications = false;
  String? _errorMessage;
  Map<String, dynamic> _settings = <String, dynamic>{};
  Map<String, dynamic> _privacyValues = <String, dynamic>{};
  Map<String, dynamic> _communicationValues = <String, dynamic>{};
  Map<String, dynamic> _notificationValues = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.getSettings();
      if (!mounted) return;

      if (_responseSuccess(response)) {
        final settings = _settingsFrom(response);
        setState(() {
          _applySettings(settings);
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _errorMessage = _responseMessage(
          response,
          AppStrings.settingsLoadFailed,
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '${AppStrings.settingsLoadFailed} ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _savePrivacy() async {
    final payload = _editablePayload('privacy', _privacyValues);
    if (payload.isEmpty) {
      _showMessage(AppStrings.settingsReadOnly);
      return;
    }

    setState(() => _isSavingPrivacy = true);

    try {
      final response = await ApiClient.updatePrivacySettings(payload);
      if (!mounted) return;
      _handleSaveResponse(response, () => _isSavingPrivacy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingPrivacy = false);
      _showMessage(e.toString());
    }
  }

  Future<void> _saveCommunication() async {
    final payload = _editablePayload('communication', _communicationValues);
    if (payload.isEmpty) {
      _showMessage(AppStrings.settingsReadOnly);
      return;
    }

    setState(() => _isSavingCommunication = true);

    try {
      final response = await ApiClient.updateCommunicationSettings(payload);
      if (!mounted) return;
      _handleSaveResponse(response, () => _isSavingCommunication = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingCommunication = false);
      _showMessage(e.toString());
    }
  }

  Future<void> _saveNotifications() async {
    final payload = _editablePayload('notifications', _notificationValues);
    if (payload.isEmpty) {
      _showMessage(AppStrings.settingsReadOnly);
      return;
    }

    setState(() => _isSavingNotifications = true);

    try {
      final response = await ApiClient.updateNotificationSettings(payload);
      if (!mounted) return;
      _handleSaveResponse(response, () => _isSavingNotifications = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingNotifications = false);
      _showMessage(e.toString());
    }
  }

  void _handleSaveResponse(
    Map<String, dynamic> response,
    VoidCallback clearSaving,
  ) {
    if (_responseSuccess(response)) {
      final settings = _settingsFrom(response);
      setState(() {
        _applySettings(settings);
        clearSaving();
      });
      _showMessage(_responseMessage(response, AppStrings.settingsSaved));
      return;
    }

    setState(clearSaving);
    _showMessage(_responseMessage(response, AppStrings.settingsLoadFailed));
  }

  void _applySettings(Map<String, dynamic> settings) {
    _settings = settings;
    _privacyValues = _valuesFromSection('privacy');
    _communicationValues = _valuesFromSection('communication');
    _notificationValues = _valuesFromSection('notifications');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.settingsTitle)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadSettings,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSettings,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAccountCard(),
          const SizedBox(height: 14),
          _buildPrivacyCard(),
          const SizedBox(height: 14),
          _buildCommunicationCard(),
          const SizedBox(height: 14),
          _buildNotificationsCard(),
          const SizedBox(height: 14),
          _buildSecurityCard(),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    final account = _safeMap(_settings['account']) ?? <String, dynamic>{};

    return _sectionCard(
      title: AppStrings.settingsAccountSummary,
      icon: Icons.account_circle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _readOnlyLine(AppStrings.name, _displayValue(account['name'])),
          _readOnlyLine('Email', _displayValue(account['email'])),
          _readOnlyLine('Mobile', _displayValue(account['mobile'])),
          _readOnlyLine('Profile ID', _displayValue(account['profile_id'])),
        ],
      ),
    );
  }

  Widget _buildPrivacyCard() {
    final section = _section('privacy');
    final fields = _fields(section);

    return _sectionCard(
      title: AppStrings.settingsPrivacy,
      icon: Icons.privacy_tip,
      saving: _isSavingPrivacy,
      onSave: _sectionAvailable(section) ? _savePrivacy : null,
      child: _sectionAvailable(section)
          ? Column(
              children: [
                _selectControl(
                  fields,
                  'visibility_scope',
                  _privacyValues,
                  _updatePrivacyValue,
                ),
                _selectControl(
                  fields,
                  'show_photo_to',
                  _privacyValues,
                  _updatePrivacyValue,
                ),
                _selectControl(
                  fields,
                  'contact_visibility_rule',
                  _privacyValues,
                  _updatePrivacyValue,
                ),
                _selectControl(
                  fields,
                  'contact_visibility_strictness',
                  _privacyValues,
                  _updatePrivacyValue,
                ),
                _switchControl(
                  fields,
                  'contact_visibility_id_verified_only',
                  _privacyValues,
                  _updatePrivacyValue,
                ),
                _switchControl(
                  fields,
                  'contact_visibility_photo_only',
                  _privacyValues,
                  _updatePrivacyValue,
                ),
                _switchControl(
                  fields,
                  'contact_visibility_require_contact_request',
                  _privacyValues,
                  _updatePrivacyValue,
                ),
                _switchControl(
                  fields,
                  'contact_visibility_approval_required',
                  _privacyValues,
                  _updatePrivacyValue,
                ),
                _selectControl(
                  fields,
                  'contact_routing_mode',
                  _privacyValues,
                  _updatePrivacyValue,
                ),
                _switchControl(
                  fields,
                  'hide_from_blocked_users',
                  _privacyValues,
                  _updatePrivacyValue,
                ),
              ],
            )
          : _unavailableText(section),
    );
  }

  Widget _buildCommunicationCard() {
    final section = _section('communication');
    final fields = _fields(section);
    final adminPolicy =
        _safeMap(section['admin_policy']) ?? <String, dynamic>{};

    return _sectionCard(
      title: AppStrings.settingsCommunication,
      icon: Icons.contact_phone,
      saving: _isSavingCommunication,
      onSave: _sectionAvailable(section) ? _saveCommunication : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_sectionAvailable(section))
            _selectControl(
              fields,
              'contact_unlock_mode',
              _communicationValues,
              _updateCommunicationValue,
            )
          else
            _unavailableText(section),
          if (adminPolicy.isNotEmpty) ...[
            const Divider(height: 24),
            _smallHeading('Admin policy'),
            _readOnlyLine(
              'Request mode',
              _displayValue(adminPolicy['contact_request_mode']),
            ),
            _readOnlyLine(
              'Allowed scopes',
              _displayValue(adminPolicy['allowed_contact_scopes']),
            ),
            _readOnlyLine(
              'Messaging',
              _displayValue(adminPolicy['messaging_mode']),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationsCard() {
    final section = _section('notifications');
    final fields = _fields(section);

    return _sectionCard(
      title: AppStrings.settingsNotifications,
      icon: Icons.notifications,
      saving: _isSavingNotifications,
      onSave: _sectionAvailable(section) ? _saveNotifications : null,
      child: _sectionAvailable(section)
          ? Column(
              children: [
                _switchControl(
                  fields,
                  'email_alerts',
                  _notificationValues,
                  _updateNotificationValue,
                ),
                _switchControl(
                  fields,
                  'engagement_inactive_reminder',
                  _notificationValues,
                  _updateNotificationValue,
                ),
                _switchControl(
                  fields,
                  'engagement_new_matches_digest',
                  _notificationValues,
                  _updateNotificationValue,
                ),
              ],
            )
          : _unavailableText(section),
    );
  }

  Widget _buildSecurityCard() {
    final section = _section('security');
    final fields = _fields(section);

    return _sectionCard(
      title: AppStrings.settingsSecurity,
      icon: Icons.lock,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _readOnlyLine(
            _labelFor('email_verified'),
            _displayValue(_fieldValue(fields, 'email_verified')),
          ),
          _readOnlyLine(
            _labelFor('mobile_verified'),
            _displayValue(_fieldValue(fields, 'mobile_verified')),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    bool saving = false,
    Future<void> Function()? onSave,
  }) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onSave != null)
                  TextButton.icon(
                    onPressed: saving ? null : onSave,
                    icon: saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(AppStrings.settingsSave),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _selectControl(
    Map<String, dynamic> fields,
    String key,
    Map<String, dynamic> values,
    void Function(String key, dynamic value) onChanged,
  ) {
    final field = _safeMap(fields[key]);
    if (field == null) return const SizedBox.shrink();

    final options = _optionsFor(field, values[key]);
    if (options.isEmpty) {
      return _readOnlyLine(
        _labelFor(key),
        _displayValue(_fieldValue(fields, key)),
      );
    }

    final current = values[key]?.toString() ?? field['value']?.toString();
    final editable = _fieldEditable(field);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey('settings-$key-$current-$editable'),
        initialValue: current,
        isExpanded: true,
        decoration: InputDecoration(labelText: _labelFor(key)),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option['value'],
                child: Text(option['label'] ?? option['value'] ?? ''),
              ),
            )
            .toList(),
        onChanged: editable
            ? (value) {
                if (value == null) return;
                onChanged(key, value);
              }
            : null,
      ),
    );
  }

  Widget _switchControl(
    Map<String, dynamic> fields,
    String key,
    Map<String, dynamic> values,
    void Function(String key, dynamic value) onChanged,
  ) {
    final field = _safeMap(fields[key]);
    if (field == null) return const SizedBox.shrink();

    final editable = _fieldEditable(field);
    final value = _asBool(values[key] ?? field['value']) ?? false;

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(_labelFor(key)),
      subtitle: editable ? null : Text(AppStrings.settingsReadOnly),
      value: value,
      onChanged: editable ? (next) => onChanged(key, next) : null,
    );
  }

  Widget _readOnlyLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(flex: 5, child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _smallHeading(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _unavailableText(Map<String, dynamic> section) {
    final message = section['message']?.toString().trim();
    return Text(
      message == null || message.isEmpty
          ? AppStrings.settingsNoProfile
          : message,
      style: TextStyle(
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _updatePrivacyValue(String key, dynamic value) {
    setState(() => _privacyValues[key] = value);
  }

  void _updateCommunicationValue(String key, dynamic value) {
    setState(() => _communicationValues[key] = value);
  }

  void _updateNotificationValue(String key, dynamic value) {
    setState(() => _notificationValues[key] = value);
  }

  Map<String, dynamic> _editablePayload(
    String sectionKey,
    Map<String, dynamic> values,
  ) {
    final fields = _fields(_section(sectionKey));
    final payload = <String, dynamic>{};

    values.forEach((key, value) {
      final field = _safeMap(fields[key]);
      if (field == null || !_fieldEditable(field)) return;
      payload[key] = value;
    });

    return payload;
  }

  Map<String, dynamic> _valuesFromSection(String sectionKey) {
    final fields = _fields(_section(sectionKey));
    final values = <String, dynamic>{};

    fields.forEach((key, value) {
      final field = _safeMap(value);
      if (field == null || !field.containsKey('value')) return;
      values[key] = field['value'];
    });

    return values;
  }

  Map<String, dynamic> _settingsFrom(Map<String, dynamic> response) {
    final direct = _safeMap(response['settings']);
    if (direct != null) return direct;

    final data = _safeMap(response['data']);
    return _safeMap(data?['settings']) ?? <String, dynamic>{};
  }

  Map<String, dynamic> _section(String key) {
    return _safeMap(_settings[key]) ?? <String, dynamic>{};
  }

  Map<String, dynamic> _fields(Map<String, dynamic> section) {
    return _safeMap(section['fields']) ?? <String, dynamic>{};
  }

  dynamic _fieldValue(Map<String, dynamic> fields, String key) {
    final field = _safeMap(fields[key]);
    return field?['value'];
  }

  bool _sectionAvailable(Map<String, dynamic> section) {
    return section['available'] == true;
  }

  bool _fieldEditable(Map<String, dynamic> field) {
    return field['editable'] == true;
  }

  List<Map<String, String>> _optionsFor(
    Map<String, dynamic> field,
    dynamic currentValue,
  ) {
    final raw = field['options'];
    final options = <Map<String, String>>[];

    if (raw is List) {
      for (final item in raw) {
        final row = _safeMap(item);
        if (row == null) continue;
        final value = row['value']?.toString() ?? row['key']?.toString();
        if (value == null || value.isEmpty) continue;
        options.add(<String, String>{
          'value': value,
          'label': row['label']?.toString() ?? value,
        });
      }
    }

    final current = currentValue?.toString() ?? field['value']?.toString();
    if (current != null &&
        current.isNotEmpty &&
        !options.any((option) => option['value'] == current)) {
      options.add(<String, String>{'value': current, 'label': current});
    }

    return options;
  }

  bool _responseSuccess(Map<String, dynamic> response) {
    final status = response['statusCode'];
    final success = response['success'];
    return status is int && status >= 200 && status < 300 && success != false;
  }

  String _responseMessage(Map<String, dynamic> response, String fallback) {
    final message = response['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;

    final error = response['error']?.toString().trim();
    if (error != null && error.isNotEmpty) return error;

    return fallback;
  }

  Map<String, dynamic>? _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return null;
    if (['1', 'true', 'yes', 'on'].contains(text)) return true;
    if (['0', 'false', 'no', 'off'].contains(text)) return false;
    return null;
  }

  String _displayValue(dynamic value) {
    if (value == null) return AppStrings.settingsNotAvailable;
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is List) {
      if (value.isEmpty) return AppStrings.settingsNotAvailable;
      return value.map((item) => item.toString()).join(', ');
    }

    final text = value.toString().trim();
    return text.isEmpty ? AppStrings.settingsNotAvailable : text;
  }

  String _labelFor(String key) {
    final isMarathi = AppStrings.isMarathi;

    switch (key) {
      case 'visibility_scope':
        return isMarathi ? 'प्रोफाइल दृश्यता' : 'Profile visibility';
      case 'show_photo_to':
        return isMarathi ? 'फोटो कोण पाहू शकतो' : 'Photo visibility';
      case 'contact_visibility_rule':
        return isMarathi ? 'संपर्क कोण पाहू शकतो' : 'Contact visibility';
      case 'contact_visibility_strictness':
        return isMarathi ? 'संपर्क नियम' : 'Contact rule strictness';
      case 'contact_visibility_id_verified_only':
        return isMarathi ? 'फक्त ID verified' : 'Only ID verified profiles';
      case 'contact_visibility_photo_only':
        return isMarathi ? 'फोटो असलेले profile' : 'Only profiles with photo';
      case 'contact_visibility_require_contact_request':
        return isMarathi ? 'Contact request आवश्यक' : 'Require contact request';
      case 'contact_visibility_approval_required':
        return isMarathi ? 'मंजुरी आवश्यक' : 'Approval required';
      case 'contact_routing_mode':
        return isMarathi ? 'संपर्क मार्ग' : 'Contact route';
      case 'hide_from_blocked_users':
        return isMarathi
            ? 'Block केलेल्यांपासून लपवा'
            : 'Hide from blocked users';
      case 'contact_unlock_mode':
        return isMarathi ? 'Contact unlock पद्धत' : 'Contact unlock mode';
      case 'email_alerts':
        return isMarathi ? 'Email सूचना' : 'Email alerts';
      case 'engagement_inactive_reminder':
        return isMarathi ? 'Inactive reminder' : 'Inactive reminder';
      case 'engagement_new_matches_digest':
        return isMarathi ? 'नवीन matches digest' : 'New matches digest';
      case 'email_verified':
        return isMarathi ? 'Email verified' : 'Email verified';
      case 'mobile_verified':
        return isMarathi ? 'Mobile verified' : 'Mobile verified';
    }

    return key.replaceAll('_', ' ');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
