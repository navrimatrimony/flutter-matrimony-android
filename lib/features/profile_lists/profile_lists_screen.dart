import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_strings.dart';
import '../matrimony_profile/profile_detail_screen.dart';

enum _ProfileListKind { shortlisted, blocked, hidden }

class ProfileListsScreen extends StatefulWidget {
  const ProfileListsScreen({super.key});

  @override
  State<ProfileListsScreen> createState() => _ProfileListsScreenState();
}

class _ProfileListsScreenState extends State<ProfileListsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _busyKeys = <String>{};
  List<Map<String, dynamic>> _shortlisted = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _blocked = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _hidden = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final responses = await Future.wait([
        ApiClient.getShortlistedProfiles(),
        ApiClient.getBlockedProfiles(),
        ApiClient.getHiddenProfiles(),
      ]);

      if (!mounted) return;

      Map<String, dynamic>? firstError;
      for (final response in responses) {
        if (!_responseSuccess(response)) {
          firstError = response;
          break;
        }
      }

      if (firstError != null) {
        final errorResponse = firstError;
        setState(() {
          _errorMessage = _responseMessage(
            errorResponse,
            AppStrings.profileListsLoadFailed,
          );
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _shortlisted = _profilesFrom(responses[0]);
        _blocked = _profilesFrom(responses[1]);
        _hidden = _profilesFrom(responses[2]);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '${AppStrings.profileListsLoadFailed} ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.profileListsTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: AppStrings.profileListsShortlist),
              Tab(text: AppStrings.profileListsBlocked),
              Tab(text: AppStrings.profileListsHidden),
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
                onPressed: _loadLists,
                icon: const Icon(Icons.refresh),
                label: Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      children: [
        _buildList(
          kind: _ProfileListKind.shortlisted,
          rows: _shortlisted,
          emptyText: AppStrings.noShortlistedProfiles,
          emptyIcon: Icons.favorite_border,
        ),
        _buildList(
          kind: _ProfileListKind.blocked,
          rows: _blocked,
          emptyText: AppStrings.noBlockedProfiles,
          emptyIcon: Icons.block,
        ),
        _buildList(
          kind: _ProfileListKind.hidden,
          rows: _hidden,
          emptyText: AppStrings.noHiddenProfiles,
          emptyIcon: Icons.visibility_off_outlined,
        ),
      ],
    );
  }

  Widget _buildList({
    required _ProfileListKind kind,
    required List<Map<String, dynamic>> rows,
    required String emptyText,
    required IconData emptyIcon,
  }) {
    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadLists,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.28),
            Icon(emptyIcon, size: 44, color: Colors.grey),
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
      onRefresh: _loadLists,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildProfileCard(kind, rows[index], rows);
        },
      ),
    );
  }

  Widget _buildProfileCard(
    _ProfileListKind kind,
    Map<String, dynamic> row,
    List<Map<String, dynamic>> visibleRows,
  ) {
    final profileId = _profileId(row);
    final canOpen =
        _boolValue(_actionState(row)['can_open_profile']) ||
        _boolValue(row['can_open_profile']);
    final title = _stringValue(_field(row, 'name')) ?? AppStrings.profile;
    final photoUrl = _stringValue(_field(row, 'primary_photo_url'));
    final subtitle = _joinNonEmpty([
      _stringValue(_field(row, 'age_label')),
      _stringValue(_field(row, 'height_label')),
      _stringValue(_field(row, 'community_label')),
      _stringValue(_field(row, 'location_label')),
    ]);
    final detail = _joinNonEmpty([
      _stringValue(_field(row, 'education_label')),
      _stringValue(_field(row, 'occupation_label')),
    ]);
    final busyKey = '${kind.name}:${profileId ?? 0}';
    final busy = _busyKeys.contains(busyKey);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: profileId == null
          ? null
          : () {
              _openProfile(row, visibleRows);
            },
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEDE2DE)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(photoUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF2E2220),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (!canOpen)
                              const Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: Color(0xFF8B6F6A),
                              ),
                          ],
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF6E625F),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (detail != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF8B6F6A),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: busy || profileId == null
                      ? null
                      : () {
                          _runAction(kind, row);
                        },
                  icon: busy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_actionIcon(kind)),
                  label: Text(_actionLabel(kind)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        height: 86,
        color: const Color(0xFFF1DDD8),
        child: photoUrl == null
            ? const Icon(Icons.person, color: Color(0xFFB42318), size: 34)
            : Image.network(
                photoUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) {
                  return const Icon(
                    Icons.person,
                    color: Color(0xFFB42318),
                    size: 34,
                  );
                },
              ),
      ),
    );
  }

  Future<void> _openProfile(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> visibleRows,
  ) async {
    final profileId = _profileId(row);
    if (profileId == null) return;

    final canOpen =
        _boolValue(_actionState(row)['can_open_profile']) ||
        _boolValue(row['can_open_profile']);
    if (!canOpen) {
      _showSnackBar(AppStrings.profileOpenNotAllowed, error: true);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileDetailScreen(
          profileId: profileId,
          profileIds: _openableIds(visibleRows),
        ),
      ),
    );
  }

  Future<void> _runAction(
    _ProfileListKind kind,
    Map<String, dynamic> row,
  ) async {
    final profileId = _profileId(row);
    if (profileId == null) return;

    final confirmed = await _confirmAction(_actionLabel(kind));
    if (confirmed != true || !mounted) return;

    final busyKey = '${kind.name}:$profileId';
    setState(() {
      _busyKeys.add(busyKey);
    });

    try {
      final response = switch (kind) {
        _ProfileListKind.shortlisted => await ApiClient.removeShortlist(
          profileId,
        ),
        _ProfileListKind.blocked => await ApiClient.unblockProfile(profileId),
        _ProfileListKind.hidden => await ApiClient.unhideProfile(profileId),
      };

      if (!mounted) return;

      if (_responseSuccess(response)) {
        setState(() {
          _removeLocal(kind, profileId);
          _busyKeys.remove(busyKey);
        });
        _showSnackBar(_responseMessage(response, _successMessage(kind)));
        return;
      }

      setState(() {
        _busyKeys.remove(busyKey);
      });
      _showSnackBar(
        _responseMessage(response, AppStrings.profileListsLoadFailed),
        error: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyKeys.remove(busyKey);
      });
      _showSnackBar(e.toString(), error: true);
    }
  }

  Future<bool?> _confirmAction(String actionLabel) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.confirmAction),
        content: Text(actionLabel),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.confirmAction),
          ),
        ],
      ),
    );
  }

  void _removeLocal(_ProfileListKind kind, int profileId) {
    bool keepOtherProfile(Map<String, dynamic> row) {
      return _profileId(row) != profileId;
    }

    switch (kind) {
      case _ProfileListKind.shortlisted:
        _shortlisted = _shortlisted.where(keepOtherProfile).toList();
        break;
      case _ProfileListKind.blocked:
        _blocked = _blocked.where(keepOtherProfile).toList();
        break;
      case _ProfileListKind.hidden:
        _hidden = _hidden.where(keepOtherProfile).toList();
        break;
    }
  }

  List<int> _openableIds(List<Map<String, dynamic>> rows) {
    return rows
        .where((row) {
          return _boolValue(_actionState(row)['can_open_profile']) ||
              _boolValue(row['can_open_profile']);
        })
        .map(_profileId)
        .whereType<int>()
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _profilesFrom(Map<String, dynamic> response) {
    final rows = response['profiles'];
    if (rows is! List) return <Map<String, dynamic>>[];

    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Map<String, dynamic> _actionState(Map<String, dynamic> row) {
    final value = row['action_state'];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  dynamic _field(Map<String, dynamic> row, String key) {
    if (row[key] != null) return row[key];

    final display = row['display'];
    if (display is! Map) return null;

    final card = display['card'];
    if (card is! Map) return null;

    return card[key];
  }

  int? _profileId(Map<String, dynamic> row) {
    return _intValue(row['profile_id']) ?? _intValue(row['id']);
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

  String? _joinNonEmpty(List<String?> values) {
    final parts = values
        .map((value) => value?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    return parts.isEmpty ? null : parts.join(' • ');
  }

  bool _responseSuccess(Map<String, dynamic> response) {
    final statusCode = _intValue(response['statusCode']) ?? 0;
    return response['success'] == true && statusCode >= 200 && statusCode < 300;
  }

  String _responseMessage(Map<String, dynamic> response, String fallback) {
    return _stringValue(response['message']) ?? fallback;
  }

  String _actionLabel(_ProfileListKind kind) {
    return switch (kind) {
      _ProfileListKind.shortlisted => AppStrings.removeFromShortlist,
      _ProfileListKind.blocked => AppStrings.unblockProfile,
      _ProfileListKind.hidden => AppStrings.unhideProfile,
    };
  }

  IconData _actionIcon(_ProfileListKind kind) {
    return switch (kind) {
      _ProfileListKind.shortlisted => Icons.bookmark_remove_outlined,
      _ProfileListKind.blocked => Icons.lock_open_outlined,
      _ProfileListKind.hidden => Icons.visibility_outlined,
    };
  }

  String _successMessage(_ProfileListKind kind) {
    return switch (kind) {
      _ProfileListKind.shortlisted => AppStrings.profileRemovedFromShortlist,
      _ProfileListKind.blocked => AppStrings.profileUnblocked,
      _ProfileListKind.hidden => AppStrings.profileUnhidden,
    };
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
