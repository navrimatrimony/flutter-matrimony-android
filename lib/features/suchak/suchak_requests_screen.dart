import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_language.dart';
import '../../core/app_loading.dart';
import '../../core/profile_photo_view.dart';
import '../chat/chat_screen.dart';

/// Both halves of the member's Suchak request pipeline, from one call to
/// `GET /suchak-requests`:
///
///   * **Received** — requests waiting on this member's own answer, because a
///     Suchak represents their profile and someone asked about them. The
///     candidate AND their Suchak may both answer; the first answer wins and
///     the server settles the race, so a second answer comes back as a calm
///     "already answered by …" rather than an error.
///   * **Sent** — requests this member sent to somebody else's Suchak, and
///     where each one stands.
class SuchakRequestsScreen extends StatefulWidget {
  const SuchakRequestsScreen({super.key});

  @override
  State<SuchakRequestsScreen> createState() => _SuchakRequestsScreenState();
}

class _SuchakRequestsScreenState extends State<SuchakRequestsScreen> {
  static const Color _accent = Color(0xFF9B1B46);
  static const Color _heading = Color(0xFF2E2220);
  static const Color _hairline = Color(0xFFEDE2DE);
  static const Color _muted = Color(0xFF6E625F);

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _received = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _sent = <Map<String, dynamic>>[];
  List<_SuchakDecisionOption> _decisionOptions = <_SuchakDecisionOption>[];
  final Set<int> _busyRequestIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.getSuchakRequests();
      if (!mounted) return;

      if (_responseSuccess(response)) {
        final data = _safeMap(response['data']) ?? <String, dynamic>{};
        setState(() {
          _received = _safeMapList(data['received']);
          _sent = _safeMapList(data['sent']);
          _decisionOptions = _optionList(data['decision_options']);
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _errorMessage = _responseMessage(
          response,
          appText.suchakRequestsDidNotLoad,
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = appText.unexpectedErrorOccurred(e.toString());
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(appText.suchakRequestsTitle),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/suchak-meetings');
              },
              child: Text(appText.suchakMeetingsOpenFromRequests),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: appText.tabReceived),
              Tab(text: appText.tabSent),
            ],
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return AppLoadingState.list(
        title: appText.loadingSuchakRequests,
        icon: Icons.support_agent,
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
                onPressed: _loadRequests,
                icon: const Icon(Icons.refresh),
                label: Text(appText.retry),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      children: [
        _buildList(
          rows: _received,
          emptyText: appText.noReceivedSuchakRequests,
          emptyIcon: Icons.inbox_outlined,
          builder: _buildReceivedCard,
        ),
        _buildList(
          rows: _sent,
          emptyText: appText.noSentSuchakRequests,
          emptyIcon: Icons.outbox_outlined,
          builder: _buildSentCard,
        ),
      ],
    );
  }

  Widget _buildList({
    required List<Map<String, dynamic>> rows,
    required String emptyText,
    required IconData emptyIcon,
    required Widget Function(Map<String, dynamic> row) builder,
  }) {
    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.26),
            Icon(emptyIcon, size: 42, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              emptyText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => builder(rows[index]),
      ),
    );
  }

  /// Someone asked this member's Suchak about them. Both this member and that
  /// Suchak can answer, so the buttons only appear while the server still says
  /// `candidate_can_answer`.
  Widget _buildReceivedCard(Map<String, dynamic> row) {
    final id = _asInt(row['id']);
    final profile = _safeMap(row['from_profile']);
    final busy = id != null && _busyRequestIds.contains(id);
    final canAnswer = _asBool(row['candidate_can_answer']) ?? false;
    final answeredBy = _displayString(row['answered_by_label']);
    final subtitle = _joinNonEmpty([
      _asInt(profile?['age'])?.toString(),
      ApiClient.safeDisplayLabel(profile?['community']),
      ApiClient.safeDisplayLabel(profile?['location']),
    ]);

    return _card(
      children: [
        _cardHeader(
          photoUrl: ApiClient.normalizeProfilePhotoUrl(
            profile?['profile_photo_url'],
          ),
          title:
              ApiClient.safeDisplayLabel(profile?['name']) ??
              appText.nameNotAvailable,
          subtitle: subtitle,
          statusLabel: _statusLabel(row),
          status: _displayString(row['status']),
          fallbackIcon: Icons.person_outline,
        ),
        if (_displayString(row['message']) != null)
          _infoLine(
            icon: Icons.chat_bubble_outline,
            label: appText.suchakRequestTheirMessage,
            value: _displayString(row['message'])!,
          ),
        if (_dateLabel(row['created_at']) != null)
          _infoLine(
            icon: Icons.schedule,
            label: appText.suchakRequestAskedOnDate(_dateLabel(row['created_at'])!),
          ),
        if (answeredBy != null)
          _infoLine(
            icon: Icons.how_to_reg_outlined,
            label: appText.suchakRequestAnsweredByName(answeredBy),
          ),
        if (canAnswer && id != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _answer(id, _decisionKey('interested')),
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.favorite_border),
                  label: Text(_decisionLabel('interested')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _answer(id, _decisionKey('not_interested')),
                  icon: const Icon(Icons.close),
                  label: Text(_decisionLabel('not_interested')),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// A request this member sent to somebody else's Suchak.
  Widget _buildSentCard(Map<String, dynamic> row) {
    final suchak = _safeMap(row['suchak']);
    final conversationId = _asInt(row['chat_conversation_id']);
    final answeredBy = _displayString(row['answered_by_label']);

    return _card(
      children: [
        _cardHeader(
          photoUrl: ApiClient.normalizeProfilePhotoUrl(suchak?['photo_url']),
          title:
              ApiClient.safeDisplayLabel(suchak?['name']) ?? appText.suchakLabel,
          subtitle:
              ApiClient.safeDisplayLabel(suchak?['subtitle']) ??
              appText.suchakContactSubtitleFallback,
          statusLabel: _statusLabel(row),
          status: _displayString(row['status']),
          fallbackIcon: Icons.support_agent,
        ),
        if (_displayString(row['message']) != null)
          _infoLine(
            icon: Icons.chat_bubble_outline,
            label: appText.suchakRequestYourMessage,
            value: _displayString(row['message'])!,
          ),
        if (_dateLabel(row['created_at']) != null)
          _infoLine(
            icon: Icons.schedule,
            label: appText.suchakRequestSentOnDate(_dateLabel(row['created_at'])!),
          ),
        if (answeredBy != null)
          _infoLine(
            icon: Icons.how_to_reg_outlined,
            label: appText.suchakRequestAnsweredByName(answeredBy),
          ),
        if (conversationId != null && conversationId > 0) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ChatScreen(initialConversationId: conversationId),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(appText.suchakRequestOpenChatButton),
            ),
          ),
        ],
      ],
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _cardHeader({
    required String? photoUrl,
    required String title,
    required String? subtitle,
    required String? statusLabel,
    required String? status,
    required IconData fallbackIcon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfilePhotoView(
          photoUrl: photoUrl,
          width: 52,
          height: 52,
          circle: true,
          backgroundColor: const Color(0xFFF1E7E3),
          placeholderColor: _accent,
          placeholderIcon: fallbackIcon,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (statusLabel != null) _statusPill(statusLabel, status),
      ],
    );
  }

  Widget _statusPill(String label, String? status) {
    final color = _statusColor(status);

    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _infoLine({
    required IconData icon,
    required String label,
    String? value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _accent),
          const SizedBox(width: 7),
          if (value != null)
            Text(
              '$label: ',
              style: const TextStyle(
                color: Color(0xFF594044),
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          Expanded(
            child: Text(
              value ?? label,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 12.5,
                fontWeight: value == null ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The candidate answering for themselves.
  ///
  /// Their Suchak sees the same request and may answer it first — that is a
  /// normal outcome, not an error: the server returns HTTP 200 with
  /// `code: already_answered` and says who got there first. It is shown as
  /// information and the list is reloaded so the real outcome replaces the
  /// buttons.
  Future<void> _answer(int requestId, String decision) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(appText.suchakRequestConfirmTitle),
        content: Text(appText.suchakRequestConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(appText.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(appText.yes),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busyRequestIds.add(requestId);
    });

    try {
      final response = await ApiClient.decideSuchakRequest(
        requestId: requestId,
        decision: decision,
      );
      if (!mounted) return;

      if (_responseSuccess(response)) {
        final data = _safeMap(response['data']) ?? <String, dynamic>{};
        final alreadyAnswered = _asBool(data['already_answered']) ?? false;
        final answeredBy = _displayString(data['answered_by_label']);

        if (alreadyAnswered) {
          _showSnackBar(
            _responseMessage(
              response,
              answeredBy == null
                  ? appText.suchakRequestAlreadyAnswered
                  : appText.suchakRequestAlreadyAnsweredBy(answeredBy),
            ),
            // Somebody answered first. That is the system working, so it is
            // reported in the neutral tone, never as a failure.
            const Color(0xFF334155),
          );
        } else {
          _showSnackBar(
            _responseMessage(response, appText.suchakRequestDecisionRecorded),
            const Color(0xFF2F9E67),
          );
        }

        await _loadRequests();
        return;
      }

      _showSnackBar(
        _responseMessage(response, appText.couldNotAnswerSuchakRequest),
        Colors.red,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        appText.unexpectedErrorOccurred(e.toString()),
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyRequestIds.remove(requestId);
        });
      }
    }
  }

  String _decisionKey(String fallback) {
    for (final option in _decisionOptions) {
      if (option.key == fallback) return option.key;
    }

    return fallback;
  }

  String _decisionLabel(String key) {
    for (final option in _decisionOptions) {
      if (option.key == key) return option.label;
    }

    return key == 'interested'
        ? appText.suchakRequestInterested
        : appText.suchakRequestNotInterested;
  }

  String? _statusLabel(Map<String, dynamic> row) {
    return ApiClient.safeDisplayLabel(row['status_label']) ??
        _displayString(row['status']);
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'candidate_interested':
      case 'accepted_by_suchak':
        return const Color(0xFF2F9E67);
      case 'candidate_not_interested':
        return const Color(0xFFC2410C);
      case 'closed':
      case 'expired':
      case 'cancelled':
        return _muted;
      default:
        return const Color(0xFFC78318);
    }
  }

  /// Dates arrive as ISO-8601. Only the calendar day is useful here, and
  /// slicing it keeps the digits Latin in every locale — a locale-aware
  /// formatter is exactly what would render Devanagari numerals for `mr`.
  String? _dateLabel(dynamic value) {
    final raw = _displayString(value);
    if (raw == null) return null;

    final match = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(raw);
    return match?.group(1) ?? raw;
  }

  List<_SuchakDecisionOption> _optionList(dynamic value) {
    return _safeMapList(value)
        .map((item) {
          final key = _displayString(item['key']);
          final label = _displayString(item['label']) ?? key;
          if (key == null || label == null) return null;

          return _SuchakDecisionOption(key: key, label: label);
        })
        .whereType<_SuchakDecisionOption>()
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _safeMapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }

    if (value is Map) {
      final nested = value['data'] ?? value['items'] ?? value['results'];
      if (nested is List) return _safeMapList(nested);
    }

    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String? _displayString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return null;
  }

  String? _joinNonEmpty(List<String?> values) {
    final parts = values
        .map((value) => value?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    return parts.isEmpty ? null : parts.join(' • ');
  }

  bool _responseSuccess(Map<String, dynamic> response) {
    final statusCode = _asInt(response['statusCode']) ?? 0;
    return response['success'] == true && statusCode >= 200 && statusCode < 300;
  }

  String _responseMessage(Map<String, dynamic> response, String fallback) {
    return _displayString(response['message']) ?? fallback;
  }

  void _showSnackBar(String message, Color background) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: background),
    );
  }
}

class _SuchakDecisionOption {
  final String key;
  final String label;

  const _SuchakDecisionOption({required this.key, required this.label});
}
