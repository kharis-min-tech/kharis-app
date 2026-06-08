import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Center(child: Text('Calendar')),
    );
  }
}
