import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_card.dart';
import 'k_icon.dart';

enum KMoreStreakTone {
  /// The reading streak: highlight tint, with the flame.
  highlight,

  /// The messages streak: primary tint.
  primary,
}

/// A streak on the More profile card, such as "27-day reading".
class KMoreStreakBadge extends StatelessWidget {
  const KMoreStreakBadge(
    this.label, {
    super.key,
    this.tone = KMoreStreakTone.primary,
    this.icon,
  });

  final String label;
  final KMoreStreakTone tone;

  /// One of the [KIcons] paths, shown before the label.
  final String? icon;

  static const double _height = 26;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final (Color bg, Color fg, Color iconColor) = switch (tone) {
      KMoreStreakTone.highlight => (k.highlightTint, k.text, k.highlightText),
      KMoreStreakTone.primary => (k.primaryTint, k.primaryText, k.primaryText),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.chip)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _height),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpace.lg,
            vertical: KSpace.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                KIcon(icon!, size: KSize.iconXs, color: iconColor),
                const SizedBox(width: KSpace.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  style: KharisText.caption.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The member's card at the top of More: their initial (or photo) on
/// primary, their name, a line about them, their streaks and a chevron.
/// Read as one button.
class KMoreProfileCard extends StatelessWidget {
  const KMoreProfileCard({
    super.key,
    required this.name,
    required this.onTap,
    this.photo,
    this.subtitle,
    this.streaks = const [],
    this.semanticHint = 'Edit profile',
  });

  final String name;

  /// The member's photo. Their initial shows while it loads, if it fails
  /// and when there is none.
  final ImageProvider? photo;

  /// For example "London · member since 2021".
  final String? subtitle;

  /// Shown under the subtitle; leave empty when there is no streak.
  final List<KMoreStreakBadge> streaks;
  final VoidCallback onTap;

  /// What tapping the card does, said after its contents.
  final String semanticHint;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final trimmed = name.trim();

    return Semantics(
      container: true,
      button: true,
      label: [
        name,
        ?subtitle,
        for (final s in streaks) '${s.label} streak',
        semanticHint,
      ].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: KCard(
        onTap: onTap,
        child: Row(
          children: [
            _Avatar(
              initial: trimmed.isEmpty ? null : trimmed.characters.first,
              photo: photo,
            ),
            const SizedBox(width: KSpace.xxl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KharisText.title.copyWith(color: k.text),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: KSpace.xs),
                    Text(
                      subtitle!,
                      style: KharisText.meta.copyWith(color: k.muted),
                    ),
                  ],
                  if (streaks.isNotEmpty) ...[
                    const SizedBox(height: KSpace.md),
                    Wrap(
                      spacing: KSpace.sm,
                      runSpacing: KSpace.sm,
                      children: streaks,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: KSpace.xxl),
            KIcon(KIcons.chevronRight, color: k.muted),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.photo});

  final String? initial;
  final ImageProvider? photo;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final letter = initial == null
        ? null
        : Text(
            initial!.toUpperCase(),
            textScaler: TextScaler.noScaling,
            style: KharisText.headline.copyWith(color: k.onPrimary),
          );

    return Container(
      width: KSize.artwork,
      height: KSize.artwork,
      decoration: BoxDecoration(color: k.primary, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: photo == null
          ? letter
          : Image(
              image: photo!,
              width: KSize.artwork,
              height: KSize.artwork,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              frameBuilder: (_, child, frame, sync) =>
                  sync || frame != null ? child : (letter ?? child),
              errorBuilder: (_, _, _) => letter ?? const SizedBox.shrink(),
            ),
    );
  }
}
