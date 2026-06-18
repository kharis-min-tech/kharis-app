import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_radius.dart';
import 'package:kharis_app/core/theme/app_typography.dart';

class RoleCard extends StatefulWidget {
  const RoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  State<RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                // rgba(30, 30, 30, 0.6)
                color: const Color(0x991E1E1E),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icon container — rounded-lg (8 px), accent-tinted bg
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.iconColor.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppRadius.defaultRadius),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.iconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Text block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: AppTypography.titleMd.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.description,
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
