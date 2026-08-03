import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:kharis_app/core/theme/theme.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The web view paints its own background before the page renders; keep it
    // on the active theme so there is no flash of the wrong brightness.
    _controller.setBackgroundColor(context.kc.bg);
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.kc.surfaceAlt,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: context.kc.onBg, size: 20),
          onPressed: _goBack,
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.plusJakartaSans(
            color: context.kc.onBg,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close_rounded,
                color: context.kc.onBg, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: context.kc.bg,
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                color: context.kc.accentInk,
                strokeWidth: 2.5,
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
/// On web: opens URL in a new tab via url_launcher.
Future<void> openGivingFlow(BuildContext context, String url) async {
  if (kIsWeb) {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
