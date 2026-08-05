import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_language.dart';
import '../../core/app_loading.dart';

/// Read-only list of meetings where this member is the customer side (U9b).
///
/// Confirm / dispute actions land in U10 / U11 on these same rows.
class SuchakMeetingsScreen extends StatefulWidget {
  const SuchakMeetingsScreen({super.key});

  @override
  State<SuchakMeetingsScreen> createState() => _SuchakMeetingsScreenState();
}

class _SuchakMeetingsScreenState extends State<SuchakMeetingsScreen> {
  static const Color _heading = Color(0xFF2E2220);
  static const Color _muted = Color(0xFF6E625F);
  static const Color _hairline = Color(0xFFEDE2DE);

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _meetings = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  Future<void> _loadMeetings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.getSuchakMeetings();
      if (!mounted) return;

      if (_responseSuccess(response)) {
        final data = _safeMap(response['data']) ?? <String, dynamic>{};
        setState(() {
          _meetings = _safeMapList(data['meetings']);
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _errorMessage = _responseMessage(
          response,
          appText.suchakMeetingsDidNotLoad,
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
    return Scaffold(
      appBar: AppBar(title: Text(appText.suchakMeetingsTitle)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return AppLoadingState.list(
        title: appText.loadingSuchakMeetings,
        icon: Icons.event_available_outlined,
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
                onPressed: _loadMeetings,
                icon: const Icon(Icons.refresh),
                label: Text(appText.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_meetings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_busy_outlined, size: 48, color: _muted),
              const SizedBox(height: 12),
              Text(
                appText.noSuchakMeetings,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMeetings,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _meetings.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _buildMeetingCard(_meetings[index]),
      ),
    );
  }

  Widget _buildMeetingCard(Map<String, dynamic> row) {
    final suchakName = (row['suchak_display_name'] ?? '').toString().trim();
    final status = (row['visit_status'] ?? '').toString().trim();
    final scheduled = (row['scheduled_for'] ?? '').toString().trim();

    return Container(
      key: ValueKey<Object>(row['id'] ?? scheduled),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: _hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suchakName.isEmpty ? appText.suchakMeetingsUntitledSuchak : suchakName,
            style: const TextStyle(
              color: _heading,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          if (scheduled.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              appText.suchakMeetingScheduledFor(scheduled),
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          ],
          if (status.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              status,
              style: const TextStyle(
                color: _heading,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _responseSuccess(Map<String, dynamic> response) {
    final success = response['success'];
    return success == true || success == 1 || success == '1';
  }

  String _responseMessage(Map<String, dynamic> response, String fallback) {
    final message = response['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    return fallback;
  }

  Map<String, dynamic>? _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic item) => MapEntry(key.toString(), item));
    }
    return null;
  }

  List<Map<String, dynamic>> _safeMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .map(_safeMap)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }
}
