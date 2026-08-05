import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_language.dart';

/// Member self-service account deletion — the in-app half of what Google Play
/// requires of any app that can create an account in-app.
///
/// The screen is built around the fact that most people who open it do not
/// actually want to be erased. Pausing is offered first and given the same
/// visual weight, deletion sits below it, and three deliberate steps stand
/// between arriving here and losing anything: a reason, the typed word
/// `delete`, and a 30-day window in which cancelling restores everything.
///
/// The typed word is verified again on the server. This screen's copy of the
/// check is only there to give a useful error before the round trip.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  static const String _confirmWord = 'delete';

  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _error;

  /// `active`, `paused` or `deletion_pending` — mirrors the server.
  String _state = 'active';
  int _graceDays = 30;
  int? _daysLeft;
  List<String> _reasons = const [];

  /// Null until the member has chosen to go past the pause option.
  bool _showDeleteFlow = false;
  String? _reasonKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _confirmController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiClient.fetchAccountDeletionStatus();
      if (!mounted) return;
      setState(() {
        _applyStatus(data);
        _reasons = (data['reasons'] as List?)?.cast<String>() ?? const [];
        _graceDays = (data['grace_days'] as num?)?.toInt() ?? 30;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = appText.deleteAccountGenericError;
        _loading = false;
      });
    }
  }

  void _applyStatus(Map<String, dynamic> data) {
    final deletion = (data['deletion'] as Map?)?.cast<String, dynamic>();
    _state = (deletion?['state'] as String?) ?? 'active';
    _daysLeft = (deletion?['days_left'] as num?)?.toInt();
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await action();
      if (!mounted) return;
      setState(() {
        _applyStatus(data);
        _showDeleteFlow = false;
        _reasonKey = null;
        _confirmController.clear();
        _noteController.clear();
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = appText.deleteAccountGenericError;
        _busy = false;
      });
    }
  }

  Future<void> _submitDeletion() async {
    if (_confirmController.text.trim().toLowerCase() != _confirmWord) {
      setState(() => _error = appText.deleteAccountConfirmError);
      return;
    }
    if (_reasonKey == null) return;

    await _run(
      () => ApiClient.requestAccountDeletion(
        confirmation: _confirmController.text.trim(),
        reasonKey: _reasonKey!,
        reasonNote: _reasonKey == 'other' && _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
      ),
    );
  }

  String _reasonLabel(String key) {
    switch (key) {
      case 'no_suitable_matches':
        return appText.deleteAccountReasonNoSuitableMatches;
      case 'found_match_elsewhere':
        return appText.deleteAccountReasonFoundMatchElsewhere;
      case 'too_many_messages':
        return appText.deleteAccountReasonTooManyMessages;
      case 'privacy_concern':
        return appText.deleteAccountReasonPrivacyConcern;
      case 'hard_to_use':
        return appText.deleteAccountReasonHardToUse;
      default:
        return appText.deleteAccountReasonOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(appText.deleteAccountTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) _errorBanner(),
                if (_state == 'deletion_pending')
                  _pendingCard()
                else ...[
                  Text(appText.deleteAccountIntro),
                  const SizedBox(height: 20),
                  _pauseCard(),
                  const SizedBox(height: 12),
                  _deleteCard(),
                ],
                const SizedBox(height: 24),
                _whatHappensCard(),
              ],
            ),
    );
  }

  Widget _errorBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
        ),
      ),
    );
  }

  /// Shown instead of the options once a deletion is running, so the only
  /// action on screen is the one that saves the account.
  Widget _pendingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              appText.deleteAccountPendingTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(appText.deleteAccountPendingBody(_daysLeft ?? _graceDays)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : () => _run(ApiClient.cancelAccountDeletion),
              child: Text(appText.deleteAccountPendingCancelCta),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pauseCard() {
    final paused = _state == 'paused';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              appText.deleteAccountPauseTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(paused
                ? appText.deleteAccountPausedBanner
                : appText.deleteAccountPauseBody),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => _run(paused ? ApiClient.resumeAccount : ApiClient.pauseAccount),
              child: Text(paused
                  ? appText.deleteAccountResumeCta
                  : appText.deleteAccountPauseCta),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deleteCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              appText.deleteAccountDeleteTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(appText.deleteAccountDeleteBody(_graceDays)),
            const SizedBox(height: 16),
            if (!_showDeleteFlow)
              OutlinedButton(
                onPressed: _busy ? null : () => setState(() => _showDeleteFlow = true),
                child: Text(appText.deleteAccountDeleteCta),
              )
            else
              ..._deleteFlowFields(),
          ],
        ),
      ),
    );
  }

  List<Widget> _deleteFlowFields() {
    return [
      const Divider(height: 24),
      Text(
        appText.deleteAccountReasonPrompt,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 4),
      Text(
        appText.deleteAccountReasonHint,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      // Tappable rows rather than a dropdown: the product owner asked for
      // buttons the member presses, and every option stays visible so none is
      // hidden behind a tap. Built from plain ListTiles because RadioListTile's
      // groupValue/onChanged are deprecated in this Flutter version.
      for (final key in _reasons)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(
            _reasonKey == key
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            color: _reasonKey == key ? Theme.of(context).colorScheme.primary : null,
          ),
          title: Text(_reasonLabel(key)),
          onTap: _busy ? null : () => setState(() => _reasonKey = key),
        ),
      if (_reasonKey == 'other') ...[
        const SizedBox(height: 8),
        TextField(
          controller: _noteController,
          maxLength: 500,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: appText.deleteAccountReasonNoteLabel,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
      const SizedBox(height: 16),
      Text(
        appText.deleteAccountConfirmPrompt,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _confirmController,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          hintText: appText.deleteAccountConfirmHint,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
        ),
        // Stays disabled until a reason is chosen AND the word is right, so the
        // destructive button cannot be reached by momentum alone.
        onPressed: _busy ||
                _reasonKey == null ||
                _confirmController.text.trim().toLowerCase() != _confirmWord
            ? null
            : _submitDeletion,
        child: Text(appText.deleteAccountFinalCta),
      ),
    ];
  }

  Widget _whatHappensCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appText.deleteAccountWhatHappensTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text(
          appText.deleteAccountWhatHappensBody,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
