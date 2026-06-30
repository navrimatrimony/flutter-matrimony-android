import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_strings.dart';
import '../../core/profile_photo_view.dart';

class ContactInboxScreen extends StatefulWidget {
  const ContactInboxScreen({super.key});

  @override
  State<ContactInboxScreen> createState() => _ContactInboxScreenState();
}

class _ContactInboxScreenState extends State<ContactInboxScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _received = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _sent = <Map<String, dynamic>>[];
  Map<String, dynamic> _meta = <String, dynamic>{};
  final Set<int> _busyRequestIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  Future<void> _loadInbox() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.getContactInbox();
      if (!mounted) return;

      if (_responseSuccess(response)) {
        setState(() {
          _received = _safeMapList(response['received']);
          _sent = _safeMapList(response['sent']);
          _meta = _safeMap(response['meta']) ?? <String, dynamic>{};
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _errorMessage = _responseErrorMessage(
          response,
          'Contact inbox load झाली नाही.',
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'एक अनपेक्षित एरर आली: ${e.toString()}';
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
          title: Text(AppStrings.contactRequests),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Received'),
              Tab(text: 'Sent'),
            ],
          ),
        ),
        body: _buildBody(),
      ),
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
                onPressed: _loadInbox,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      children: [
        _buildRequestList(
          rows: _received,
          emptyText: 'No pending contact requests.',
          received: true,
        ),
        _buildRequestList(
          rows: _sent,
          emptyText: 'No sent contact requests.',
          received: false,
        ),
      ],
    );
  }

  Widget _buildRequestList({
    required List<Map<String, dynamic>> rows,
    required String emptyText,
    required bool received,
  }) {
    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadInbox,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.28),
            Icon(
              received ? Icons.inbox_outlined : Icons.outbox_outlined,
              size: 42,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              emptyText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6E625F),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInbox,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildRequestCard(rows[index], received: received);
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> row, {required bool received}) {
    final profile = _safeMap(
      received ? row['sender_profile'] : row['receiver_profile'],
    );
    final id = _displayInt(row['id']);
    final status = _displayString(row['status']) ?? 'pending';
    final scopes = _stringList(row['requested_scopes']);
    final busy = id != null && _busyRequestIds.contains(id);
    final subtitle = _joinNonEmpty([
      _displayInt(profile?['age'])?.toString(),
      _displayString(profile?['community']),
      _displayString(profile?['location']),
    ]);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDE2DE)),
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
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(profile),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayString(profile?['name']) ?? 'Profile',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF2E2220),
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
              _buildStatusPill(status),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoLine(
            icon: Icons.help_outline,
            label: 'Reason',
            value: _reasonText(row),
          ),
          if (scopes.isNotEmpty)
            _buildInfoLine(
              icon: Icons.contact_phone_outlined,
              label: 'Requested',
              value: scopes.join(', '),
            ),
          if (_displayString(row['created_at']) != null)
            _buildInfoLine(
              icon: Icons.schedule,
              label: 'Created',
              value: _displayString(row['created_at'])!,
            ),
          if (received && status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: busy || id == null
                        ? null
                        : () => _showApproveSheet(row),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy || id == null
                        ? null
                        : () => _rejectRequest(row),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic>? profile) {
    final photoUrl = ApiClient.normalizeProfilePhotoUrl(
      profile?['profile_photo_url'] ?? profile?['profile_photo'],
    );

    return ProfilePhotoView(
      photoUrl: photoUrl,
      width: 56,
      height: 56,
      circle: true,
      backgroundColor: const Color(0xFFF1E7E3),
      placeholderColor: const Color(0xFF9B1B46),
      placeholderIcon: Icons.person_outline,
    );
  }

  Widget _buildStatusPill(String status) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'accepted' => const Color(0xFF2F9E67),
      'rejected' => const Color(0xFFC2410C),
      'pending' => const Color(0xFFC78318),
      _ => const Color(0xFF6E625F),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildInfoLine({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9B1B46)),
          const SizedBox(width: 7),
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
              value,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showApproveSheet(Map<String, dynamic> row) async {
    final id = _displayInt(row['id']);
    if (id == null) return;

    final requestedScopes = _stringList(row['requested_scopes']).toSet();
    final configuredScopeOptions = _optionList(_meta['scope_options'])
        .where((option) => requestedScopes.contains(option.key))
        .toList(growable: false);
    final scopeOptions = configuredScopeOptions.isNotEmpty
        ? configuredScopeOptions
        : requestedScopes
              .map((scope) => _OptionData(key: scope, label: scope))
              .toList(growable: false);
    final durationOptions = _optionList(_meta['duration_options']);
    final selectedScopes = requestedScopes.toSet();
    var durationKey = durationOptions.isNotEmpty
        ? durationOptions.first.key
        : 'approve_once';

    final draft = await showModalBottomSheet<_ApproveDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void submit() {
              if (selectedScopes.isEmpty) {
                setSheetState(() {
                  errorText = 'किमान एक contact method grant करा.';
                });
                return;
              }

              Navigator.pop(
                sheetContext,
                _ApproveDraft(
                  grantedScopes: selectedScopes.toList(growable: false),
                  durationKey: durationKey,
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Approve Contact',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2E2220),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: scopeOptions
                          .map((scope) {
                            final selected = selectedScopes.contains(scope.key);
                            return FilterChip(
                              label: Text(scope.label),
                              selected: selected,
                              onSelected: (value) {
                                setSheetState(() {
                                  if (value) {
                                    selectedScopes.add(scope.key);
                                  } else {
                                    selectedScopes.remove(scope.key);
                                  }
                                  errorText = null;
                                });
                              },
                            );
                          })
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: durationKey,
                      decoration: const InputDecoration(
                        labelText: 'Duration',
                        prefixIcon: Icon(Icons.timer_outlined),
                      ),
                      items:
                          (durationOptions.isEmpty
                                  ? const [
                                      _OptionData(
                                        key: 'approve_once',
                                        label: 'Approve once (24 hours)',
                                      ),
                                    ]
                                  : durationOptions)
                              .map(
                                (option) => DropdownMenuItem<String>(
                                  value: option.key,
                                  child: Text(option.label),
                                ),
                              )
                              .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          durationKey = value;
                          errorText = null;
                        });
                      },
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: submit,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Grant Access'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (draft == null) return;
    await _approveRequest(id, draft);
  }

  Future<void> _approveRequest(int id, _ApproveDraft draft) async {
    setState(() {
      _busyRequestIds.add(id);
    });

    try {
      final response = await ApiClient.approveContactRequest(
        requestId: id,
        grantedScopes: draft.grantedScopes,
        durationKey: draft.durationKey,
      );
      if (!mounted) return;

      if (_responseSuccess(response)) {
        _showSnackBar(_backendMessage(response, 'Contact access granted.'));
        await _loadInbox();
        return;
      }

      _showSnackBar(
        _responseErrorMessage(response, 'Contact approve करता आला नाही.'),
        error: true,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('एक अनपेक्षित एरर आली: ${e.toString()}', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busyRequestIds.remove(id);
        });
      }
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> row) async {
    final id = _displayInt(row['id']);
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject request?'),
        content: const Text('This will reject the contact request.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _busyRequestIds.add(id);
    });

    try {
      final response = await ApiClient.rejectContactRequest(id);
      if (!mounted) return;

      if (_responseSuccess(response)) {
        _showSnackBar(_backendMessage(response, 'Request rejected.'));
        await _loadInbox();
        return;
      }

      _showSnackBar(
        _responseErrorMessage(response, 'Contact reject करता आली नाही.'),
        error: true,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('एक अनपेक्षित एरर आली: ${e.toString()}', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busyRequestIds.remove(id);
        });
      }
    }
  }

  String _reasonText(Map<String, dynamic> row) {
    final reason =
        _displayString(row['reason_label']) ??
        _displayString(row['reason']) ??
        'Contact request';
    final other = _displayString(row['other_reason_text']);

    return other == null ? reason : '$reason - $other';
  }

  List<_OptionData> _optionList(dynamic value) {
    return _safeMapList(value)
        .map((item) {
          final key =
              _displayString(item['key']) ??
              _displayString(item['id']) ??
              _displayString(item['value']);
          final label =
              _displayString(item['label']) ??
              _displayString(item['name']) ??
              key;
          if (key == null || label == null) return null;

          return _OptionData(key: key, label: label);
        })
        .whereType<_OptionData>()
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

  int? _displayInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];

    return value
        .map(_displayString)
        .whereType<String>()
        .toList(growable: false);
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
    final statusCode = _displayInt(response['statusCode']) ?? 0;
    return response['success'] == true && statusCode >= 200 && statusCode < 300;
  }

  String _backendMessage(Map<String, dynamic> response, String fallback) {
    return _displayString(response['message']) ?? fallback;
  }

  String _responseErrorMessage(Map<String, dynamic> response, String fallback) {
    return _displayString(response['message']) ?? fallback;
  }

  void _showSnackBar(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }
}

class _OptionData {
  final String key;
  final String label;

  const _OptionData({required this.key, required this.label});
}

class _ApproveDraft {
  final List<String> grantedScopes;
  final String durationKey;

  const _ApproveDraft({required this.grantedScopes, required this.durationKey});
}
