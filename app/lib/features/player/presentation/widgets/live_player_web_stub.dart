import 'package:flutter/widgets.dart';

/// Non-web stub. Never used at runtime on mobile/desktop because
/// LiveStreamScreen only renders this widget when kIsWeb is true.
class LivePlayerWeb extends StatelessWidget {
  const LivePlayerWeb({super.key, required this.streamUrl});

  final String streamUrl;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
