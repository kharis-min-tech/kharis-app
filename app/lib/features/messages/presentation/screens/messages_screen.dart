import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Center(child: Text('Messages')),
    );
  }
}
