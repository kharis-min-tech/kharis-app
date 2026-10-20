import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';

/// Says that notifications are off, what they would bring ([message]), and
/// turns them on: the OS prompt while it can still be shown
/// ([NotificationPermission.askable]), this app's page in system settings once
/// it can't ([NotificationPermission.blocked]).
///
/// Place it only for those two states. It re-reads the permission whenever the
/// app comes back to the foreground, so returning from system settings with
/// notifications allowed makes it go away.
class NotificationPermissionCard extends ConsumerStatefulWidget {
  const NotificationPermissionCard({
    super.key,
    required this.permission,
    required this.message,
    this.onPreferences,
    this.onNotNow,
  });

  final NotificationPermission permission;
  final String message;

  /// Opens the notification preferences. No link when `null`.
  final VoidCallback? onPreferences;

  /// Hides the card for good. No "Not now" when `null`.
  final VoidCallback? onNotNow;

  @override
  ConsumerState<NotificationPermissionCard> createState() =>
      _NotificationPermissionCardState();
}

class _NotificationPermissionCardState
    extends ConsumerState<NotificationPermissionCard> {
  late final AppLifecycleListener _lifecycle;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(notificationPermissionProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  bool get _blocked => widget.permission == NotificationPermission.blocked;

  Future<void> _turnOn() async {
    // Taken before the OS sheet opens: the member can leave this screen while
    // it is up, after which this widget's `ref` is dead. The follow-up runs on
    // its own provider, so the topics are still re-applied.
    final service = ref.read(notificationServiceProvider);
    if (_blocked) {
      await service.openSystemSettings();
      return;
    }
    final onAnswer = ref.read(notificationPermissionAnsweredProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    final granted = await service.requestPermission();
    await onAnswer(granted);
    if (!mounted) return;
    setState(() => _busy = false);
    if (granted) return;
    // Refused, or the OS no longer asks (Android after "Don't allow" twice):
    // either way the way on is system settings, offered once, not pushed.
    messenger?.showSnackBar(
      SnackBar(
        content: const Text('Notifications are still off.'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () => unawaited(service.openSystemSettings()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final onPreferences = widget.onPreferences;
    final onNotNow = widget.onNotNow;
    return Container(
      key: const Key('notification-permission-card'),
      decoration: BoxDecoration(
        color: kc.surface,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kc.chipBg,
                ),
                child: Icon(
                  Icons.notifications_off_outlined,
                  color: kc.onChip,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications are off',
                      style: AppTypography.ui(
                        size: 15,
                        weight: FontWeight.w600,
                      ).copyWith(color: kc.onBg),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.message,
                      style: AppTypography.bodySm.copyWith(color: kc.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              // DESIGN.md: one CTA style, gold with gold ink.
              style: FilledButton.styleFrom(
                backgroundColor: kc.accent,
                foregroundColor: kc.onAccent,
              ),
              onPressed: _busy ? null : _turnOn,
              child: Text(
                _blocked ? 'Turn on in Settings' : 'Turn on notifications',
              ),
            ),
          ),
          if (onPreferences != null || onNotNow != null)
            Row(
              children: [
                if (onPreferences != null)
                  TextButton(
                    onPressed: onPreferences,
                    child: Text(
                      'Choose what you get',
                      style: AppTypography.labelMd.copyWith(
                        color: kc.accentInk,
                      ),
                    ),
                  ),
                const Spacer(),
                if (onNotNow != null)
                  TextButton(
                    onPressed: onNotNow,
                    child: Text(
                      'Not now',
                      style: AppTypography.labelMd.copyWith(color: kc.muted),
                    ),
                  ),
              ],
            ),
          if (onPreferences == null && onNotNow == null)
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}
