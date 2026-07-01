import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_strings.dart';

class BiodataExportScreen extends StatefulWidget {
  const BiodataExportScreen({super.key});

  @override
  State<BiodataExportScreen> createState() => _BiodataExportScreenState();
}

class _BiodataExportScreenState extends State<BiodataExportScreen> {
  static const Color _brandColor = Color(0xFFDC2626);
  static const Color _brandDark = Color(0xFF9F1239);
  static const Color _surface = Color(0xFFFFFBF7);

  bool _isLoading = true;
  bool _isDownloading = false;
  bool _isSharing = false;
  String? _errorMessage;
  Map<String, dynamic> _options = <String, dynamic>{};
  Map<String, dynamic>? _lastExport;
  String _selectedFormat = 'pdf';
  String? _selectedTemplateKey;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.getBiodataExportOptions();
      if (!mounted) return;

      if (_responseSuccess(response)) {
        setState(() {
          _applyOptions(response);
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _errorMessage = _responseMessage(
          response,
          AppStrings.biodataExportLoadFailed,
        );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            '${AppStrings.biodataExportLoadFailed} ${error.toString()}';
        _isLoading = false;
      });
    }
  }

  void _applyOptions(Map<String, dynamic> response) {
    _options = Map<String, dynamic>.from(response);
    final formats = _stringList(_options['supported_formats']);
    final defaultFormat = _stringValue(_options['default_format']);
    if (formats.contains(_selectedFormat)) {
      // Keep current selection.
    } else if (defaultFormat.isNotEmpty && formats.contains(defaultFormat)) {
      _selectedFormat = defaultFormat;
    } else if (formats.isNotEmpty) {
      _selectedFormat = formats.first;
    } else {
      _selectedFormat = 'pdf';
    }

    final templates = _templates;
    final keys = templates
        .map((template) => _stringValue(template['key']))
        .where((key) => key.isNotEmpty)
        .toList();
    final defaultTemplate = _stringValue(_options['default_template']);
    if (_selectedTemplateKey != null && keys.contains(_selectedTemplateKey)) {
      // Keep current selection.
    } else if (defaultTemplate.isNotEmpty && keys.contains(defaultTemplate)) {
      _selectedTemplateKey = defaultTemplate;
    } else if (keys.isNotEmpty) {
      _selectedTemplateKey = keys.first;
    } else {
      _selectedTemplateKey = null;
    }
  }

  Future<void> _requestExport({required bool share}) async {
    if (!_canExport) {
      _showSnackBar(_statusMessage);
      return;
    }

    setState(() {
      if (share) {
        _isSharing = true;
      } else {
        _isDownloading = true;
      }
    });

    try {
      final response = await ApiClient.exportBiodata(
        format: _selectedFormat,
        template: _selectedTemplateKey,
      );
      if (!mounted) return;

      if (!_responseSuccess(response)) {
        _showSnackBar(
          _responseMessage(response, AppStrings.biodataExportFailed),
        );
        return;
      }

      final downloadUrl = _stringValue(
        response['download_url'] ?? response['file_url'],
      );
      if (downloadUrl.isEmpty) {
        _showSnackBar(AppStrings.biodataExportLinkMissing);
        return;
      }

      setState(() {
        _lastExport = Map<String, dynamic>.from(response);
      });

      if (share) {
        await _shareUrl(downloadUrl);
      } else {
        await _openUrl(downloadUrl);
      }
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('${AppStrings.biodataExportFailed} ${error.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isSharing = false;
        });
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnackBar(AppStrings.biodataExportLinkMissing);
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;

    if (opened) {
      _showSnackBar(AppStrings.biodataExportBrowserOpened);
      return;
    }

    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    _showSnackBar(AppStrings.biodataExportOpenFailedCopied);
  }

  Future<void> _shareUrl(String url) async {
    try {
      await Share.share(url, subject: AppStrings.biodataExportTitle);
      if (!mounted) return;
      _showSnackBar(AppStrings.biodataExportShared);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      _showSnackBar(AppStrings.biodataExportOpenFailedCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EF),
      appBar: AppBar(title: Text(AppStrings.biodataExportTitle)),
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
                onPressed: _loadOptions,
                icon: const Icon(Icons.refresh),
                label: Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOptions,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _buildStatusCard(),
          if (_lastExport != null) ...[
            const SizedBox(height: 14),
            _buildGeneratedCard(_lastExport!),
          ],
          const SizedBox(height: 14),
          _buildOptionsCard(),
          const SizedBox(height: 14),
          _buildWarningsCard(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final canExport = _canExport;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: _cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  canExport ? Icons.description : Icons.info_outline,
                  color: canExport ? _brandColor : const Color(0xFF8A5A00),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppStrings.biodataExportTitle,
                    style: const TextStyle(
                      color: _brandDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _statusMessage,
              style: const TextStyle(
                color: Color(0xFF5F4A45),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.biodataExportSubtitle,
              style: const TextStyle(color: Color(0xFF7C6A64)),
            ),
            const SizedBox(height: 12),
            _buildQuotaLine(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotaLine() {
    final state = _safeMap(_options['export_state']) ?? <String, dynamic>{};
    final unlimited = state['unlimited'] == true;
    final used = state['used'] ?? 0;
    final limit = state['limit'] ?? '-';
    final remaining = state['remaining'] ?? '-';
    final text = unlimited
        ? 'Unlimited downloads'
        : '$used / $limit, $remaining remaining';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8DDD7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.download, color: _brandColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsCard() {
    final templates = _templates;
    final unsupported = _safeMapList(_options['unsupported_formats']);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: _cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppStrings.biodataExportFormat, style: _sectionTitleStyle),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _formats
                  .map(
                    (format) => ChoiceChip(
                      label: Text(_formatLabel(format)),
                      selected: _selectedFormat == format,
                      onSelected: (selected) {
                        if (!selected) return;
                        setState(() => _selectedFormat = format);
                      },
                    ),
                  )
                  .toList(),
            ),
            for (final row in unsupported) ...[
              const SizedBox(height: 10),
              _buildInfoLine(Icons.info_outline, _stringValue(row['reason'])),
            ],
            const SizedBox(height: 18),
            Text(AppStrings.biodataExportTemplate, style: _sectionTitleStyle),
            const SizedBox(height: 10),
            if (templates.isEmpty)
              _buildInfoLine(
                Icons.error_outline,
                AppStrings.biodataExportUnavailable,
              )
            else
              ...templates.map(_buildTemplateOption),
            if (!_selectedTemplateAvailable && _selectedTemplate != null) ...[
              const SizedBox(height: 10),
              _buildInfoLine(
                Icons.lock_outline,
                _stringValue(
                  _selectedTemplate?['locked_reason'],
                  fallback: AppStrings.biodataExportUnavailable,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              AppStrings.biodataExportLinkExpires,
              style: const TextStyle(color: Color(0xFF7C6A64), fontSize: 13),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _canExport || _isDownloading
                        ? (_isDownloading || _isSharing
                              ? null
                              : () => _requestExport(share: false))
                        : null,
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.open_in_new),
                    label: Text(AppStrings.biodataExportDownload),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _canExport || _isSharing
                        ? (_isDownloading || _isSharing
                              ? null
                              : () => _requestExport(share: true))
                        : null,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share),
                    label: Text(AppStrings.biodataExportShare),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratedCard(Map<String, dynamic> export) {
    final url = _stringValue(export['download_url'] ?? export['file_url']);
    final template = _safeMap(export['template']) ?? <String, dynamic>{};
    final templateLabel = _stringValue(
      template['label'],
      fallback: _stringValue(
        template['key'],
        fallback: _selectedTemplateKey ?? '',
      ),
    );
    final format = _stringValue(
      export['format'],
      fallback: _selectedFormat,
    ).toUpperCase();
    final expiresAt = _formatExpiresAt(_stringValue(export['expires_at']));

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: _cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.task_alt, color: _brandColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppStrings.biodataGeneratedTitle,
                    style: const TextStyle(
                      color: _brandDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.biodataGeneratedSubtitle,
              style: const TextStyle(
                color: Color(0xFF7C6A64),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTemplateTag(format),
                if (templateLabel.isNotEmpty) _buildTemplateTag(templateLabel),
                if (expiresAt.isNotEmpty)
                  _buildTemplateTag(
                    '${AppStrings.biodataExpiresAt} $expiresAt',
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: url.isEmpty ? null : () => _openUrl(url),
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(AppStrings.biodataPreviewAction),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: AppStrings.biodataExportShare,
                  onPressed: url.isEmpty ? null : () => _shareUrl(url),
                  icon: const Icon(Icons.share),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: AppStrings.biodataCopyLink,
                  onPressed: url.isEmpty ? null : () => _copyUrl(url),
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateOption(Map<String, dynamic> template) {
    final key = _stringValue(template['key']);
    final selected = key.isNotEmpty && key == _selectedTemplateKey;
    final available = template['available'] == true;
    final premium = template['premium'] == true;
    final withPhoto = template['with_photo'] == true;
    final description = _stringValue(template['description']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: available && key.isNotEmpty
              ? () => setState(() => _selectedTemplateKey = key)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFF1F2) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? _brandColor : const Color(0xFFE8DDD7),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: available
                        ? const Color(0xFFFFE4E6)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    available
                        ? (withPhoto
                              ? Icons.badge_outlined
                              : Icons.article_outlined)
                        : Icons.lock_outline,
                    color: available ? _brandColor : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stringValue(template['label'], fallback: key),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF2D2323),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF7C6A64),
                            fontSize: 12.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildTemplateTag(
                            _stringValue(template['orientation']).isEmpty
                                ? 'A4'
                                : 'A4 ${_stringValue(template['orientation'])}',
                          ),
                          _buildTemplateTag(
                            withPhoto ? 'With photo' : 'No photo',
                          ),
                          if (premium) _buildTemplateTag('Premium'),
                          if (!available) _buildTemplateTag('Locked'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? _brandColor : const Color(0xFFB7A9A3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateTag(String label) {
    if (label.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4EF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8DDD7)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6B4F48),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildWarningsCard() {
    final warnings = _stringList(_options['warnings']);
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: _cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.biodataExportWarnings, style: _sectionTitleStyle),
            const SizedBox(height: 10),
            for (final warning in warnings)
              _buildInfoLine(Icons.warning_amber, warning),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoLine(IconData icon, String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF8A5A00), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF5F4A45),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  ShapeBorder _cardShape() {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: Color(0xFFE8DDD7)),
    );
  }

  TextStyle get _sectionTitleStyle => const TextStyle(
    color: _brandDark,
    fontSize: 16,
    fontWeight: FontWeight.w900,
  );

  bool get _canExport {
    return _options['can_export'] == true &&
        _formats.isNotEmpty &&
        _selectedTemplateKey != null &&
        _selectedTemplateAvailable;
  }

  String get _statusMessage {
    return _stringValue(
      _options['message'],
      fallback: AppStrings.biodataExportUnavailable,
    );
  }

  List<String> get _formats => _stringList(_options['supported_formats']);

  List<Map<String, dynamic>> get _templates {
    return _safeMapList(_options['templates']);
  }

  Map<String, dynamic>? get _selectedTemplate {
    final key = _selectedTemplateKey;
    if (key == null) return null;

    for (final template in _templates) {
      if (_stringValue(template['key']) == key) return template;
    }

    return null;
  }

  bool get _selectedTemplateAvailable {
    final template = _selectedTemplate;
    return template != null && template['available'] == true;
  }

  String _formatLabel(String format) {
    return switch (format.toLowerCase()) {
      'jpg' => AppStrings.biodataExportJpg,
      _ => AppStrings.biodataExportPdf,
    };
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _copyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    _showSnackBar(AppStrings.biodataLinkCopied);
  }

  static String _formatExpiresAt(String value) {
    if (value.isEmpty) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  static bool _responseSuccess(Map<String, dynamic> response) {
    final statusCode = _asInt(response['statusCode']) ?? 0;
    return response['success'] == true && statusCode >= 200 && statusCode < 300;
  }

  static String _responseMessage(
    Map<String, dynamic> response,
    String fallback,
  ) {
    final message = _stringValue(response['message']);
    if (message.isNotEmpty) return message;

    final blockedReason = _stringValue(response['blocked_reason']);
    return blockedReason.isEmpty ? fallback : blockedReason;
  }

  static Map<String, dynamic>? _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<Map<String, dynamic>> _safeMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String _stringValue(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
