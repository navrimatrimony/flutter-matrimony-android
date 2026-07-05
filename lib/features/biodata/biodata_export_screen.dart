import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_loading.dart';
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
      return AppLoadingState.list(
        title: AppStrings.isMarathi
            ? 'Biodata options लोड होत आहेत'
            : 'Loading biodata options',
        icon: Icons.article_outlined,
      );
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
    final rawLabel = _stringValue(template['label'], fallback: key);
    final rawDescription = _stringValue(template['description']);
    final label = AppStrings.biodataTemplateLabel(key, rawLabel);
    final description = AppStrings.biodataTemplateDescription(
      key,
      rawDescription,
    );
    final orientation = _stringValue(template['orientation']);

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
              color: selected ? const Color(0xFFFFF7F3) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? _brandColor : const Color(0xFFE8DDD7),
                width: selected ? 1.7 : 1,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTemplatePreview(template, selected, available),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF2D2323),
                          fontWeight: FontWeight.w900,
                          height: 1.14,
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
                            AppStrings.biodataTemplateOrientation(orientation),
                          ),
                          _buildTemplateTag(
                            withPhoto
                                ? AppStrings.biodataTemplateWithPhoto
                                : AppStrings.biodataTemplateNoPhoto,
                          ),
                          if (premium)
                            _buildTemplateTag(
                              AppStrings.biodataTemplatePremium,
                            ),
                          if (!available)
                            _buildTemplateTag(AppStrings.biodataTemplateLocked),
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

  Widget _buildTemplatePreview(
    Map<String, dynamic> template,
    bool selected,
    bool available,
  ) {
    final key = _stringValue(template['key']);
    final orientation = _stringValue(template['orientation']).toLowerCase();
    final landscape = orientation == 'landscape';
    final withPhoto = template['with_photo'] == true;
    final style = _templateStyleFor(key);

    return Semantics(
      label: AppStrings.biodataTemplateDesignPreview,
      child: SizedBox(
        width: 88,
        height: 116,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: landscape ? 86 : 64,
                height: landscape ? 66 : 102,
                padding: EdgeInsets.all(landscape ? 5 : 6),
                decoration: BoxDecoration(
                  color: available ? style.paper : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: available
                        ? (selected ? _brandColor : style.border)
                        : const Color(0xFFD1D5DB),
                    width: selected ? 1.6 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 9,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Opacity(
                  opacity: available ? 1 : 0.54,
                  child: key == 'photo_side_biodata'
                      ? _buildPhotoSidePreview(style)
                      : _buildClassicPreview(style, withPhoto, landscape),
                ),
              ),
              if (!available)
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassicPreview(
    _TemplateVisualStyle style,
    bool withPhoto,
    bool landscape,
  ) {
    final lineCount = landscape ? 4 : 7;

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: style.accent, width: 1.2),
            ),
          ),
        ),
        Positioned(
          left: 6,
          right: 6,
          top: 5,
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: style.accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        if (withPhoto)
          Positioned(
            right: 6,
            top: landscape ? 18 : 22,
            child: Container(
              width: landscape ? 18 : 22,
              height: landscape ? 24 : 28,
              decoration: BoxDecoration(
                color: style.photo,
                borderRadius: BorderRadius.circular(style.roundPhoto ? 999 : 3),
                border: Border.all(color: style.border),
              ),
            ),
          ),
        Positioned(
          left: 8,
          right: withPhoto ? (landscape ? 31 : 34) : 8,
          top: landscape ? 18 : 20,
          bottom: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(lineCount, (index) {
              final wide = index.isEven ? 1.0 : 0.72;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: FractionallySizedBox(
                  widthFactor: wide,
                  alignment: Alignment.centerLeft,
                  child: _buildPreviewLine(style),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSidePreview(_TemplateVisualStyle style) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              color: style.photo,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 5,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: style.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 7),
              for (var index = 0; index < 5; index++) ...[
                _buildPreviewLine(style),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewLine(_TemplateVisualStyle style) {
    return Container(
      height: 3.4,
      decoration: BoxDecoration(
        color: style.ink.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  _TemplateVisualStyle _templateStyleFor(String key) {
    return switch (key) {
      'parichay_patra_photo' => const _TemplateVisualStyle(
        paper: Color(0xFFFFF7ED),
        accent: Color(0xFFEA580C),
        border: Color(0xFFF59E0B),
        ink: Color(0xFF7C2D12),
        photo: Color(0xFFFBCFE8),
        roundPhoto: false,
      ),
      'photo_side_biodata' => const _TemplateVisualStyle(
        paper: Color(0xFFFEFCE8),
        accent: Color(0xFF6D28D9),
        border: Color(0xFF7C3AED),
        ink: Color(0xFF4C1D95),
        photo: Color(0xFFC7D2FE),
        roundPhoto: false,
      ),
      'simple_landscape_no_photo' => const _TemplateVisualStyle(
        paper: Color(0xFFF8FAFC),
        accent: Color(0xFF334155),
        border: Color(0xFF94A3B8),
        ink: Color(0xFF0F172A),
        photo: Color(0xFFE2E8F0),
        roundPhoto: false,
      ),
      'double_portrait_photo' => const _TemplateVisualStyle(
        paper: Color(0xFFFFFBEB),
        accent: Color(0xFFB45309),
        border: Color(0xFFD97706),
        ink: Color(0xFF78350F),
        photo: Color(0xFFFDE68A),
        roundPhoto: false,
      ),
      'royal_landscape_photo' => const _TemplateVisualStyle(
        paper: Color(0xFFEEF2FF),
        accent: Color(0xFF4338CA),
        border: Color(0xFFB45309),
        ink: Color(0xFF312E81),
        photo: Color(0xFFDDD6FE),
        roundPhoto: true,
      ),
      'classic_portrait_no_photo' => const _TemplateVisualStyle(
        paper: Color(0xFFFFFBF7),
        accent: Color(0xFFBE123C),
        border: Color(0xFFFDA4AF),
        ink: Color(0xFF881337),
        photo: Color(0xFFFFE4E6),
        roundPhoto: false,
      ),
      _ => const _TemplateVisualStyle(
        paper: Color(0xFFFFFBF7),
        accent: Color(0xFFDC2626),
        border: Color(0xFFFCA5A5),
        ink: Color(0xFF7F1D1D),
        photo: Color(0xFFFFE4E6),
        roundPhoto: false,
      ),
    };
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

class _TemplateVisualStyle {
  const _TemplateVisualStyle({
    required this.paper,
    required this.accent,
    required this.border,
    required this.ink,
    required this.photo,
    required this.roundPhoto,
  });

  final Color paper;
  final Color accent;
  final Color border;
  final Color ink;
  final Color photo;
  final bool roundPhoto;
}
