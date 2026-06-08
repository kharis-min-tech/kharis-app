import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/theme/app_colors.dart';

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
      ..setBackgroundColor(AppColors.surfaceDark)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
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
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceElevated,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: _goBack,
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.mavenPro(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textPrimary, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: AppColors.surfaceDark,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(
                color: AppColors.orange,
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
