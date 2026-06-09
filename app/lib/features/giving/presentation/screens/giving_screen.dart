import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'giving_webview_screen.dart';

class GivingScreen extends StatelessWidget {
  const GivingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Support the Vision',
                style: GoogleFonts.mavenPro(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your generosity fuels our mission to create a sanctuary for seekers and believers worldwide.',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: AppColors.textBody,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              // Giving card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.volunteer_activism,
                          color: AppColors.accent,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Give Online',
                              style: GoogleFonts.mavenPro(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                            Text(
                              'Secure online giving',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: const Color(0xFF6B6B6B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const GivingWebViewScreen(url: 'https://kharis.org/give'),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Give Now',
                          style: GoogleFonts.mavenPro(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
