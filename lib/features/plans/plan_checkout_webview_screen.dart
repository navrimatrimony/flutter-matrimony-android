import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_language.dart';
import '../../core/app_strings.dart';

/// Opens the Laravel mobile checkout bridge + PayU flow inside the app.
///
/// When PayU finishes, Laravel redirects to the web `/plans` page. That URL is
/// the completion signal — the sheet closes and the caller refreshes plan state.
class PlanCheckoutWebViewScreen extends StatefulWidget {
  const PlanCheckoutWebViewScreen({
    super.key,
    required this.checkoutUrl,
    this.planName,
  });

  final String checkoutUrl;
  final String? planName;

  @override
  State<PlanCheckoutWebViewScreen> createState() =>
      _PlanCheckoutWebViewScreenState();
}

class _PlanCheckoutWebViewScreenState extends State<PlanCheckoutWebViewScreen> {
  late final WebViewController _controller;
  late final Uri _checkoutUri;
  bool _loading = true;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _checkoutUri = Uri.parse(widget.checkoutUrl);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!_finishing && mounted) setState(() => _loading = true);
          },
          onPageFinished: (url) {
            if (!_finishing && mounted) setState(() => _loading = false);
            _maybeFinish(url);
          },
          onNavigationRequest: (request) {
            if (_isCheckoutReturnUrl(request.url)) {
              _finishCompleted();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            if (!mounted || _finishing) return;
            setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(_checkoutUri);
  }

  bool _isOurHost(String host) {
    final expected = _checkoutUri.host.toLowerCase();
    final incoming = host.toLowerCase();
    if (expected.isEmpty) return false;
    return incoming == expected || incoming.endsWith('.$expected');
  }

  /// PayU success/failure both redirect to the web plans index (`/plans`).
  bool _isCheckoutReturnUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !_isOurHost(uri.host)) return false;

    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (path == '/plans') return true;

    // Some installs mount under a subdirectory; still treat trailing /plans.
    return path.endsWith('/plans');
  }

  void _maybeFinish(String url) {
    if (_isCheckoutReturnUrl(url)) {
      _finishCompleted();
    }
  }

  void _finishCompleted() {
    if (_finishing || !mounted) return;
    _finishing = true;
    Navigator.of(context).pop(true);
  }

  void _finishCancelled() {
    if (_finishing || !mounted) return;
    _finishing = true;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.planName ?? '').trim().isEmpty
        ? AppStrings.plansTitle
        : widget.planName!.trim();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _finishCancelled();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: _finishCancelled,
            icon: const Icon(Icons.close),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_loading)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(
                      currentAppLanguage == AppLanguage.marathi
                          ? 'पेमेंट app मध्येच सुरू आहे. पूर्ण झाल्यावर आपोआप परत येईल.'
                          : 'Payment stays in the app. You will return automatically when it finishes.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
