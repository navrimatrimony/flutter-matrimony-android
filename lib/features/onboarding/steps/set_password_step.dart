import 'package:flutter/material.dart';

class SetPasswordStep extends StatefulWidget {
  const SetPasswordStep({
    super.key,
    required this.locale,
    required this.loading,
    required this.onBack,
    required this.onSave,
    required this.onSkip,
  });

  final String locale;
  final bool loading;
  final VoidCallback onBack;
  final Future<String?> Function({
    required String password,
    required String passwordConfirmation,
  })
  onSave;
  final VoidCallback onSkip;

  @override
  State<SetPasswordStep> createState() => _SetPasswordStepState();
}

class _SetPasswordStepState extends State<SetPasswordStep> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();

  bool _showPassword = false;
  bool _showConfirmation = false;
  bool _saving = false;
  String? _error;

  bool get _mr => widget.locale == 'mr';
  bool get _busy => widget.loading || _saving;
  bool get _canSave =>
      _passwordController.text.trim().isNotEmpty &&
      _confirmationController.text.trim().isNotEmpty &&
      !_busy;

  String _t(String en, String mr) => _mr ? mr : en;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final password = _passwordController.text;
    final confirmation = _confirmationController.text;

    if (password.trim().isEmpty || confirmation.trim().isEmpty) {
      setState(() {
        _error = _t(
          'Enter password and confirm password.',
          'Password आणि confirm password दोन्ही भरा.',
        );
      });
      return;
    }

    if (password != confirmation) {
      setState(() {
        _error = _t(
          'Password and confirm password do not match.',
          'Password आणि confirm password जुळत नाहीत.',
        );
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await widget.onSave(
      password: password,
      passwordConfirmation: confirmation,
    );
    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = error;
    });
  }

  void _onEdited(String _) {
    if (_error == null) {
      setState(() {});
      return;
    }
    setState(() {
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final height = MediaQuery.sizeOf(context).height;
    final verticalPadding = MediaQuery.paddingOf(context).vertical;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height - verticalPadding - 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _busy ? null : widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _t('Set Password', 'Password तयार करा'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Center(
                child: Container(
                  width: 136,
                  height: 136,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.18),
                      width: 8,
                    ),
                  ),
                  child: Icon(
                    Icons.phonelink_lock_outlined,
                    size: 68,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 34),
              Text(
                _t(
                  'Set a password if you wish to log in with it',
                  'Password ने login करायचे असल्यास password तयार करा',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 28),
              _PasswordField(
                controller: _passwordController,
                label: _t('Create Password', 'Password तयार करा'),
                visible: _showPassword,
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                toggleTooltip: _showPassword
                    ? _t('Hide password', 'Password लपवा')
                    : _t('Show password', 'Password दाखवा'),
                onChanged: _onEdited,
                onToggle: () {
                  setState(() {
                    _showPassword = !_showPassword;
                  });
                },
              ),
              const SizedBox(height: 14),
              _PasswordField(
                controller: _confirmationController,
                label: _t('Confirm Password', 'Password पुन्हा भरा'),
                visible: _showConfirmation,
                enabled: !_busy,
                textInputAction: TextInputAction.done,
                toggleTooltip: _showConfirmation
                    ? _t('Hide password', 'Password लपवा')
                    : _t('Show password', 'Password दाखवा'),
                onChanged: _onEdited,
                onSubmitted: (_) => _submit(),
                onToggle: () {
                  setState(() {
                    _showConfirmation = !_showConfirmation;
                  });
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: colors.error,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ],
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSave ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_t('Save', 'Save')),
                ),
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: _busy ? null : widget.onSkip,
                child: Text(
                  _t('I will do this later', 'मी हे नंतर करेन'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.visible,
    required this.enabled,
    required this.textInputAction,
    required this.toggleTooltip,
    required this.onChanged,
    required this.onToggle,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool visible;
  final bool enabled;
  final TextInputAction textInputAction;
  final String toggleTooltip;
  final ValueChanged<String> onChanged;
  final VoidCallback onToggle;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: !visible,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: textInputAction,
      autofillHints: const [AutofillHints.newPassword],
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: enabled ? onToggle : null,
          tooltip: toggleTooltip,
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }
}
