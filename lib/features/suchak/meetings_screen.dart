import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_language.dart';
import '../../core/app_loading.dart';

/// Meetings where this member is the customer side (U9b).
///
/// U10: confirm when `visit_status` is `completed`. Dispute lands in U11.
class SuchakMeetingsScreen extends StatefulWidget {
  const SuchakMeetingsScreen({super.key});

  @override
  State<SuchakMeetingsScreen> createState() => _SuchakMeetingsScreenState();
}

class _SuchakMeetingsScreenState extends State<SuchakMeetingsScreen> {
  static const Color _accent = Color(0xFF9B1B46);
  static const Color _heading = Color(0xFF2E2220);
  static const Color _muted = Color(0xFF6E625F);
  static const Color _hairline = Color(0xFFEDE2DE);

  bool _isLoading = true;
  String? _errorMessage;
  String? _actionMessage;
  List<Map<String, dynamic>> _meetings = <Map<String, dynamic>>[];
  final Set<int> _busyVisitIds = <int>{};

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

  bool _canConfirm(String status) => status == 'completed';

  bool _canDispute(String status) => status == 'completed';

  Future<void> _confirmMeeting(Map<String, dynamic> row) async {
    final visitId = _asInt(row['id']);
    if (visitId == null || _busyVisitIds.contains(visitId)) return;

    final note = await _askNoteDialog(
      title: appText.suchakMeetingConfirmTitle,
      hint: appText.suchakMeetingConfirmNoteHint,
      actionLabel: appText.suchakMeetingConfirmAction,
    );
    if (note == null || !mounted) return;

    setState(() {
      _busyVisitIds.add(visitId);
      _actionMessage = null;
    });

    try {
      final response = await ApiClient.confirmSuchakMeeting(
        visitId: visitId,
        confirmationNote: note,
      );
      if (!mounted) return;

      if (_responseSuccess(response)) {
        setState(() {
          _busyVisitIds.remove(visitId);
          _actionMessage = _responseMessage(
            response,
            appText.suchakMeetingConfirmed,
          );
        });
        await _loadMeetings();
        return;
      }

      setState(() {
        _busyVisitIds.remove(visitId);
        _actionMessage = _responseMessage(
          response,
          appText.couldNotConfirmSuchakMeeting,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyVisitIds.remove(visitId);
        _actionMessage = appText.unexpectedErrorOccurred(e.toString());
      });
    }
  }

  Future<void> _disputeMeeting(Map<String, dynamic> row) async {
    final visitId = _asInt(row['id']);
    if (visitId == null || _busyVisitIds.contains(visitId)) return;

    final reason = await _askNoteDialog(
      title: appText.suchakMeetingDisputeTitle,
      hint: appText.suchakMeetingDisputeReasonHint,
      actionLabel: appText.suchakMeetingDisputeAction,
    );
    if (reason == null || !mounted) return;

    setState(() {
      _busyVisitIds.add(visitId);
      _actionMessage = null;
    });

    try {
      final response = await ApiClient.disputeSuchakMeeting(
        visitId: visitId,
        disputeReason: reason,
      );
      if (!mounted) return;

      if (_responseSuccess(response)) {
        setState(() {
          _busyVisitIds.remove(visitId);
          _actionMessage = _responseMessage(
            response,
            appText.suchakMeetingDisputed,
          );
        });
        await _loadMeetings();
        return;
      }

      setState(() {
        _busyVisitIds.remove(visitId);
        _actionMessage = _responseMessage(
          response,
          appText.couldNotDisputeSuchakMeeting,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyVisitIds.remove(visitId);
        _actionMessage = appText.unexpectedErrorOccurred(e.toString());
      });
    }
  }

  Future<String?> _askNoteDialog({
    required String title,
    required String hint,
    required String actionLabel,
  }) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(hintText: hint),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(appText.cancel),
              ),
              TextButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  Navigator.of(context).pop(text);
                },
                child: Text(actionLabel),
              ),
            ],
          );
        },
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
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
    if (_isLoading && _meetings.isEmpty) {
      return AppLoadingState.list(
        title: appText.loadingSuchakMeetings,
        icon: Icons.event_available_outlined,
      );
    }

    if (_errorMessage != null && _meetings.isEmpty) {
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

    return Column(
      children: [
        if (_actionMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              _actionMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _heading,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadMeetings,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _meetings.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _buildMeetingCard(_meetings[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeetingCard(Map<String, dynamic> row) {
    final suchakName = (row['suchak_display_name'] ?? '').toString().trim();
    final status = (row['visit_status'] ?? '').toString().trim();
    final scheduled = (row['scheduled_for'] ?? '').toString().trim();
    final visitId = _asInt(row['id']);
    final busy = visitId != null && _busyVisitIds.contains(visitId);

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
            suchakName.isEmpty
                ? appText.suchakMeetingsUntitledSuchak
                : suchakName,
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
          if (_canConfirm(status) || _canDispute(status)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (_canConfirm(status))
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : () => _confirmMeeting(row),
                      style: FilledButton.styleFrom(backgroundColor: _accent),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(appText.suchakMeetingConfirmAction),
                    ),
                  ),
                if (_canConfirm(status) && _canDispute(status))
                  const SizedBox(width: 8),
                if (_canDispute(status))
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => _disputeMeeting(row),
                      child: Text(appText.suchakMeetingDisputeAction),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
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
