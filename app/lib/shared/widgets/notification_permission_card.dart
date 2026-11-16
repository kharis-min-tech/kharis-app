import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/ui/components/components.dart';
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
    final k = context.k;
    final onPreferences = widget.onPreferences;
    final onNotNow = widget.onNotNow;
    return KCard(
      key: const Key('notification-permission-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const KIconTile(KIcons.bell),
              const SizedBox(width: KSpace.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications are off',
                      style: KharisText.title.copyWith(color: k.text),
                    ),
                    const SizedBox(height: KSpace.xs),
                    Text(
                      widget.message,
                      style: KharisText.meta.copyWith(color: k.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpace.x3),
          KButton(
            label: _blocked ? 'Turn on in Settings' : 'Turn on notifications',
            onPressed: _turnOn,
            loading: _busy,
            expand: true,
          ),
          if (onPreferences != null || onNotNow != null) ...[
            const SizedBox(height: KSpace.xs),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: KSpace.x3,
              children: [
                if (onPreferences != null)
                  KTextLink(label: 'Choose what you get', onTap: onPreferences),
                if (onNotNow != null)
                  KTextLink(label: 'Not now', onTap: onNotNow),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
