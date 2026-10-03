import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:kharis_app/core/theme/theme.dart';

enum _PageState { loading, ready, failed }

/// The secure giving page inside the app, with a loading state and an
/// error state that offers Retry and Open in browser.
class GivingWebViewScreen extends StatefulWidget {
  const GivingWebViewScreen({
    super.key,
    required this.url,
    this.title = 'Give',
  });

  final String url;
  final String title;

  @override
  State<GivingWebViewScreen> createState() => _GivingWebViewScreenState();
}

class _GivingWebViewScreenState extends State<GivingWebViewScreen> {
  late final WebViewController _controller;
  _PageState _state = _PageState.loading;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => _set(_PageState.loading),
          onPageFinished: (_) {
            // A failed main-frame load still fires onPageFinished on some
            // platforms; keep the error state rather than revealing a blank
            // or browser-default error page.
            if (_state != _PageState.failed) _set(_PageState.ready);
          },
          onWebResourceError: (error) {
            // Sub-resource failures (an analytics script, an image) do not
            // stop the member giving; only the page itself does.
            if (error.isForMainFrame ?? true) _set(_PageState.failed);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _set(_PageState next) {
    if (!mounted || _state == next) return;
    setState(() => _state = next);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The web view paints its own background before the page renders; keep it
    // on the active theme so there is no flash of the wrong brightness.
    _controller.setBackgroundColor(context.kc.bg);
  }

  Future<void> _retry() async {
    setState(() => _state = _PageState.loading);
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _goBack() async {
    if (_state != _PageState.failed && await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kc.surfaceAlt,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: kc.onBg,
            size: 20,
          ),
          onPressed: _goBack,
        ),
        title: Text(
          widget.title,
          style: AppTypography.ui(
            size: 16,
            weight: FontWeight.w600,
            color: kc.onBg,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Close',
            icon: Icon(Icons.close_rounded, color: kc.onBg, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_state == _PageState.loading)
            Container(
              color: kc.bg,
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                color: kc.accentInk,
                strokeWidth: 2.5,
              ),
            ),
          if (_state == _PageState.failed)
            GivingLoadError(
              onRetry: _retry,
              onOpenInBrowser: () => launchUrl(
                Uri.parse(widget.url),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-surface error shown when the giving page cannot load.
@visibleForTesting
class GivingLoadError extends StatelessWidget {
  const GivingLoadError({
    super.key,
    required this.onRetry,
    required this.onOpenInBrowser,
  });

  final VoidCallback onRetry;
  final VoidCallback onOpenInBrowser;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Container(
      color: kc.bg,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 44, color: kc.muted),
          const SizedBox(height: 14),
          Text(
            'We could not open the giving page',
            textAlign: TextAlign.center,
            style: AppTypography.ui(
              size: 16,
              weight: FontWeight.w700,
              color: kc.onBg,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Check your connection and try again. You can also give by bank '
            'transfer from the Giving tab.',
            textAlign: TextAlign.center,
            style: AppTypography.ui(size: 13.5, height: 1.45, color: kc.muted),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: kc.accent,
                foregroundColor: kc.onAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.buttonBorder,
                ),
              ),
              child: Text(
                'Retry',
                style: AppTypography.ui(
                  size: 15,
                  weight: FontWeight.w700,
                  color: kc.onAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onOpenInBrowser,
            child: Text(
              'Open in browser',
              style: AppTypography.ui(
                size: 14,
                weight: FontWeight.w600,
                color: kc.accentInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Launches the giving URL on the current platform.
///
/// On mobile: pushes [GivingWebViewScreen] via Navigator.
/// On web: opens the URL in a new tab via url_launcher.
Future<void> openGivingFlow(BuildContext context, String url) async {
  if (kIsWeb) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    return;
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => GivingWebViewScreen(url: url),
    ),
  );
}
