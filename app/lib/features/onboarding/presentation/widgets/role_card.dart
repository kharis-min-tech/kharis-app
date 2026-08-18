import 'package:flutter/material.dart';
import 'package:kharis_app/core/theme/theme.dart';

/// A full-width onboarding choice row (design-handoff v3): a white card with a
/// tinted [accent] icon tile, title, supporting line and trailing chevron.
/// Presses scale to .97 per the design motion spec.
class RoleCard extends StatefulWidget {
  const RoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.accent = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color accent;

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
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.kc.surface,
            borderRadius: AppRadius.cardBorder,
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              // Tinted icon tile (44px, radius 13).
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.12),
                  borderRadius: AppRadius.tileBorder,
                ),
                child: Icon(widget.icon, color: widget.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTypography.ui(size: 16, weight: FontWeight.w700)
                          .copyWith(color: context.kc.onBg),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.description,
                      style: AppTypography.ui(size: 13)
                          .copyWith(color: context.kc.muted, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: context.kc.muted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
