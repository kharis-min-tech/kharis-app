import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/press_effect.dart';
import 'package:kharis_app/shared/widgets/skeleton.dart';

const double _kRowHeight = 68;

/// Home's way into Scripture as one compact row: today's Content Studio
/// reading when there is one (its reference, opening the reader), otherwise
/// the whole Bible. Loading holds the row's place with a skeleton so the
/// sections below do not jump when the day's content lands.
class HomeBibleRow extends ConsumerWidget {
  const HomeBibleRow({super.key, this.padding = EdgeInsets.zero});

  /// Space around the row.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(dailyContentProvider);
    final reading = contentAsync.valueOrNull?.reading;
    final loading =
        !contentAsync.hasValue &&
        contentAsync.isLoading &&
        !contentAsync.hasError;

    final Widget row;
    if (reading != null) {
      final reference = reading.reference.trim();
      final title = reference.isEmpty ? reading.title : reference;
      // One supporting line: the reading's own title when the reference
      // headlines, else the start of its text; nothing when it has neither.
      final subtitle = reference.isNotEmpty && reading.title != reference
          ? reading.title
          : reading.body.trim();
      row = _Row(
        title: title,
        subtitle: subtitle.isEmpty ? null : subtitle,
        semanticsLabel: "Today's reading: $title. Read now",
        onTap: () => context.push('/reading'),
      );
    } else if (loading) {
      row = const Skeleton(
        key: Key('home-bible-row-loading'),
        width: double.infinity,
        height: _kRowHeight,
        radius: AppRadius.card,
      );
    } else {
      row = _Row(
        title: 'Read the Bible',
        subtitle: 'Every book and chapter, in your translation.',
        semanticsLabel: 'Read the Bible',
        onTap: () => context.push('/bible'),
      );
    }

    return Padding(
      key: const Key('home-bible-row'),
      padding: padding,
      child: row,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.subtitle,
    required this.semanticsLabel,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final subtitle = this.subtitle;
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: PressEffect(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: _kRowHeight),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: kc.surface,
            borderRadius: AppRadius.cardBorder,
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kc.chipBg,
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 22,
                  color: kc.onChip,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.ui(
                        size: 15,
                        weight: FontWeight.w700,
                      ).copyWith(color: kc.onBg, height: 1.25),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.ui(
                          size: 12.5,
                        ).copyWith(color: kc.muted, height: 1.3),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 22, color: kc.muted),
            ],
          ),
        ),
      ),
    );
  }
}
