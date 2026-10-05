import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/admin/data/london_time.dart';
import 'package:kharis_app/features/admin/presentation/widgets/studio_form_kit.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/data/studio_notification_repository.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Studio history: every notification, newest first (admins read them all;
/// the list is narrowed to what this admin manages on screen).
final studioNotificationHistoryProvider =
    StreamProvider.autoDispose<List<StudioNotification>>(
      (ref) => ref.watch(studioNotificationRepositoryProvider).watchHistory(),
    );

/// Whether [scope] may send to, or cancel a notification for, [audience].
/// Mirrors `managesNotificationAudience` in `firestore.rules`.
bool canManageNotificationAudience(
  AdminScope scope,
  NotificationAudience audience,
) {
  if (scope.isSuperAdmin) return true;
  if (!scope.isCampusAdmin) return false;
  return switch (audience.type) {
    NotificationAudience.testType => true,
    NotificationAudience.branchType => scope.branchNames.contains(
      audience.branch,
    ),
    _ => false,
  };
}

/// What a tap on the notification opens.
enum NotificationLinkKind {
  none('Nothing (opens the app)', null),
  home('Home', '/home'),
  messages('Messages', '/messages'),
  sermon('A message (sermon)', null),
  event('An event', null),
  announcement('An announcement', null),
  giving('Giving', '/giving'),
  reading('Today\u2019s reading', '/reading'),
  calendar('Calendar', '/calendar'),
  web('A web address', null);

  const NotificationLinkKind(this.label, this.path);

  final String label;

  /// The fixed app path, for kinds that need no further choice.
  final String? path;
}

/// Content Studio: compose a push and see what has been sent.
///
/// Super admins send to everyone, one branch or staff test devices; a branch
/// admin to their own branches or test devices (the rules enforce the same).
class AdminNotificationsScreen extends ConsumerWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Notifications',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        iconTheme: const IconThemeData(color: AppColors.heading),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.xl,
        ),
        children: const [
          NotificationComposer(),
          SizedBox(height: AppSpacing.xl),
          _History(),
        ],
      ),
    );
  }
}

/// The compose form: title, message, link, audience, when, preview, send.
class NotificationComposer extends ConsumerStatefulWidget {
  const NotificationComposer({super.key});

  @override
  ConsumerState<NotificationComposer> createState() =>
      _NotificationComposerState();
}

class _NotificationComposerState extends ConsumerState<NotificationComposer> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _webUrl = TextEditingController();

  NotificationLinkKind _linkKind = NotificationLinkKind.none;
  String? _sermonId;
  String? _eventId;
  String? _newsId;

  /// Starts on staff test devices: the one audience every Studio user has,
  /// and the safe place to check a push before sending it wider.
  String _audienceType = NotificationAudience.testType;
  String? _branch;

  /// Null is "Send now".
  DateTime? _scheduleAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_title, _body]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _webUrl.dispose();
    super.dispose();
  }

  /// The link as stored, or null for none. Assumes the form validated.
  String? get _link => switch (_linkKind) {
    NotificationLinkKind.sermon =>
      _sermonId == null ? null : '/m/${Uri.encodeComponent(_sermonId!)}',
    NotificationLinkKind.event =>
      _eventId == null ? null : '/e/${Uri.encodeComponent(_eventId!)}',
    NotificationLinkKind.announcement =>
      _newsId == null ? null : '/a/${Uri.encodeComponent(_newsId!)}',
    NotificationLinkKind.web => _webUrl.text.trim(),
    _ => _linkKind.path,
  };

  NotificationAudience? get _audience => switch (_audienceType) {
    NotificationAudience.allType => const NotificationAudience.all(),
    NotificationAudience.testType => const NotificationAudience.test(),
    _ => _branch == null ? null : NotificationAudience.branch(_branch!),
  };

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(adminScopeProvider).valueOrNull;
    // Watched so the author is loaded by the time Send is tapped.
    ref.watch(currentUserProvider);
    if (scope == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.secondary),
      );
    }
    // A branch admin can never pick Everyone; a stale choice falls back.
    if (!scope.isSuperAdmin && _audienceType == NotificationAudience.allType) {
      _audienceType = NotificationAudience.testType;
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New notification',
            style: AppTypography.titleMd.copyWith(color: AppColors.heading),
          ),
          const SizedBox(height: AppSpacing.md),
          const StudioFieldLabel('Title'),
          TextFormField(
            key: const Key('notification-title'),
            controller: _title,
            maxLength: kNotificationTitleMax,
            textCapitalization: TextCapitalization.sentences,
            style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
            decoration: studioInputDecoration(hint: 'Prayer night moved'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Add a title' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          const StudioFieldLabel('Message'),
          TextFormField(
            key: const Key('notification-body'),
            controller: _body,
            maxLength: kNotificationBodyMax,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
            decoration: studioInputDecoration(
              hint: 'What members see under the title',
            ),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Add a message' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          const StudioFieldLabel('Tapping it opens'),
          _linkField(),
          ..._linkDetail(),
          const SizedBox(height: AppSpacing.md),
          const StudioFieldLabel('Send to'),
          _audienceField(scope),
          const SizedBox(height: AppSpacing.md),
          const StudioFieldLabel('When'),
          _whenField(),
          const SizedBox(height: AppSpacing.md),
          const StudioFieldLabel('Preview'),
          _Preview(
            title: _title.text.trim(),
            body: _body.text.trim(),
            audience: _audience?.label,
          ),
          const SizedBox(height: AppSpacing.md),
          StudioSaveButton(
            label: _scheduleAt == null ? 'Send now' : 'Schedule',
            saving: _saving,
            onPressed: () => _submit(scope),
          ),
        ],
      ),
    );
  }

  Widget _linkField() => DropdownButtonFormField<NotificationLinkKind>(
    key: const Key('notification-link-kind'),
    initialValue: _linkKind,
    dropdownColor: AppColors.surfaceContainer,
    style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
    decoration: studioInputDecoration(),
    items: [
      for (final kind in NotificationLinkKind.values)
        DropdownMenuItem(value: kind, child: Text(kind.label)),
    ],
    onChanged: (kind) => setState(() {
      _linkKind = kind ?? NotificationLinkKind.none;
    }),
  );

  /// The second control a link kind needs: which message, event,
  /// announcement or web address.
  List<Widget> _linkDetail() {
    Widget picker<T>({
      required AsyncValue<List<T>> source,
      required String? value,
      required String Function(T) id,
      required String Function(T) label,
      required String hint,
      required String missing,
      required ValueChanged<String?> onChanged,
    }) {
      final items = source.valueOrNull;
      if (items == null) {
        return StudioHint(
          source.hasError ? 'Could not load the list.' : 'Loading\u2026',
          color: source.hasError ? AppColors.error : null,
        );
      }
      return DropdownButtonFormField<String>(
        initialValue: items.any((i) => id(i) == value) ? value : null,
        isExpanded: true,
        dropdownColor: AppColors.surfaceContainer,
        style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
        decoration: studioInputDecoration(hint: hint),
        items: [
          for (final item in items.take(kNotificationPageSize))
            DropdownMenuItem(
              value: id(item),
              child: Text(label(item), overflow: TextOverflow.ellipsis),
            ),
        ],
        validator: (v) => v == null ? missing : null,
        onChanged: onChanged,
      );
    }

    final Widget? detail = switch (_linkKind) {
      NotificationLinkKind.sermon => picker(
        source: ref.watch(adminSermonsProvider),
        value: _sermonId,
        id: (s) => s.id,
        label: (s) => s.title,
        hint: 'Choose a message',
        missing: 'Choose a message',
        onChanged: (v) => setState(() => _sermonId = v),
      ),
      NotificationLinkKind.event => picker<Event>(
        source: ref.watch(upcomingEventsProvider(null)),
        value: _eventId,
        id: (e) => e.id,
        label: (e) => '${e.title} \u00b7 ${studioDayLabel(e.startTime)}',
        hint: 'Choose an upcoming event',
        missing: 'Choose an event',
        onChanged: (v) => setState(() => _eventId = v),
      ),
      NotificationLinkKind.announcement => picker(
        source: ref.watch(adminNewsProvider),
        value: _newsId,
        id: (n) => n.id,
        label: (n) => n.title,
        hint: 'Choose an announcement',
        missing: 'Choose an announcement',
        onChanged: (v) => setState(() => _newsId = v),
      ),
      NotificationLinkKind.web => TextFormField(
        key: const Key('notification-web-url'),
        controller: _webUrl,
        keyboardType: TextInputType.url,
        style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
        decoration: studioInputDecoration(hint: 'https://'),
        validator: (v) => notificationLinkError((v ?? '').trim()),
      ),
      _ => null,
    };
    return [
      if (detail != null) ...[const SizedBox(height: AppSpacing.xs), detail],
    ];
  }

  Widget _audienceField(AdminScope scope) {
    final branchNames = scope.isSuperAdmin
        ? [
            for (final b in ref.watch(branchesProvider).valueOrNull ?? const [])
              b.name,
          ]
        : (scope.branchNames.toList()..sort());
    final options = <(String, String)>[
      if (scope.isSuperAdmin) (NotificationAudience.allType, 'Everyone'),
      (NotificationAudience.branchType, 'One branch'),
      (NotificationAudience.testType, 'Staff test devices'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final (type, label) in options)
              ChoiceChip(
                label: Text(label),
                selected: _audienceType == type,
                onSelected: (_) => setState(() => _audienceType = type),
                selectedColor: AppColors.secondary,
                backgroundColor: AppColors.surfaceSubtle,
                labelStyle: AppTypography.labelMd.copyWith(
                  color: _audienceType == type
                      ? AppColors.onSecondary
                      : AppColors.onSurface,
                ),
                showCheckmark: false,
              ),
          ],
        ),
        if (_audienceType == NotificationAudience.branchType) ...[
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<String>(
            key: const Key('notification-branch'),
            initialValue: branchNames.contains(_branch) ? _branch : null,
            dropdownColor: AppColors.surfaceContainer,
            style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
            decoration: studioInputDecoration(hint: 'Choose a branch'),
            items: [
              for (final name in branchNames)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            validator: (v) => v == null ? 'Choose a branch' : null,
            onChanged: (v) => setState(() => _branch = v),
          ),
        ],
        if (_audienceType == NotificationAudience.testType)
          const StudioHint(
            'Goes only to phones signed in to Studio, so you can check it '
            'before sending it to members.',
          ),
      ],
    );
  }

  Widget _whenField() {
    final at = _scheduleAt;
    return StudioPickerButton(
      label: at == null
          ? 'Send now (tap to schedule)'
          : '${studioDateTimeLabel(toLondonWallClock(at))} (UK time)',
      hasValue: at != null,
      icon: Icons.schedule_rounded,
      onTap: _pickSchedule,
      onClear: at == null ? null : () => setState(() => _scheduleAt = null),
      clearTooltip: 'Send now instead',
    );
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now().toUtc();
    final start = toLondonWallClock(
      _scheduleAt ?? now.add(const Duration(hours: 1)),
    );
    final date = await pickStudioDate(
      context,
      initial: start,
      first: toLondonWallClock(now),
      last: toLondonWallClock(now).add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await pickStudioTime(
      context,
      initial: TimeOfDay(hour: start.hour, minute: start.minute),
    );
    if (time == null || !mounted) return;
    setState(() => _scheduleAt = londonWallTime(date, time.hour, time.minute));
  }

  Future<void> _submit(AdminScope scope) async {
    final messenger = ScaffoldMessenger.of(context);
    void say(String message, {bool error = false}) => messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? AppColors.errorContainer
            : AppColors.surfaceElevated,
      ),
    );

    if (!(_formKey.currentState?.validate() ?? false)) return;
    final audience = _audience;
    if (audience == null || !canManageNotificationAudience(scope, audience)) {
      say('You can\u2019t send to that audience.', error: true);
      return;
    }
    final scheduleAt = _scheduleAt;
    if (scheduleAt != null && !scheduleAt.isAfter(DateTime.now())) {
      say('Pick a time in the future, or send now.', error: true);
      return;
    }
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      say('Sign in again to send notifications.', error: true);
      return;
    }
    if (audience.type == NotificationAudience.allType &&
        !await _confirmEveryone(scheduleAt)) {
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(studioNotificationRepositoryProvider)
          .schedule(
            title: _title.text,
            body: _body.text,
            link: _link,
            audience: audience,
            sendAt: scheduleAt,
            createdBy: user.id,
            createdByName: user.displayName.trim().isNotEmpty
                ? user.displayName
                : user.email,
          );
      if (!mounted) return;
      say(
        scheduleAt == null
            ? 'Sending to ${audience.label}.'
            : 'Scheduled for ${studioDateTimeLabel(toLondonWallClock(scheduleAt))} (UK time).',
      );
      _formKey.currentState?.reset();
      _title.clear();
      _body.clear();
      _webUrl.clear();
      setState(() {
        _linkKind = NotificationLinkKind.none;
        _sermonId = _eventId = _newsId = null;
        _scheduleAt = null;
      });
    } catch (e) {
      say('Could not send: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmEveryone(DateTime? at) async {
    final when = at == null
        ? 'now'
        : 'on ${studioDateTimeLabel(toLondonWallClock(at))} (UK time)';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text(
          'Send to everyone?',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        content: Text(
          'Every member with notifications on gets this $when, '
          'in every branch.',
          style: AppTypography.bodyLg.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(at == null ? 'Send to everyone' : 'Schedule'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}

/// Roughly how the push reads on a lock screen.
class _Preview extends StatelessWidget {
  const _Preview({required this.title, required this.body, this.audience});

  final String title;
  final String body;
  final String? audience;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kharis \u00b7 now',
            style: AppTypography.labelMd.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            title.isEmpty ? 'Title' : title,
            style: AppTypography.bodyLg.copyWith(
              color: title.isEmpty ? AppColors.textFaint : AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            body.isEmpty ? 'Message' : body,
            style: AppTypography.bodySm.copyWith(
              color: body.isEmpty ? AppColors.textFaint : AppColors.textMuted,
            ),
          ),
          if (audience != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'To: $audience',
              style: AppTypography.labelMd.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sent, scheduled and failed notifications this admin manages.
class _History extends ConsumerWidget {
  const _History();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(adminScopeProvider).valueOrNull;
    final history = ref.watch(studioNotificationHistoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'History',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        const SizedBox(height: AppSpacing.sm),
        history.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.secondary),
          ),
          error: (_, _) => const StudioHint(
            'Could not load sent notifications.',
            color: AppColors.error,
          ),
          data: (all) {
            final items = [
              for (final n in all)
                if (scope != null &&
                    canManageNotificationAudience(scope, n.audience))
                  n,
            ];
            if (items.isEmpty) {
              return const StudioHint(
                'Nothing sent yet. Notifications you send or schedule show '
                'here.',
              );
            }
            return Column(
              children: [
                for (final n in items) ...[
                  _HistoryRow(item: n),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.item});

  final StudioNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String at(DateTime t) => studioDateTimeLabel(toLondonWallClock(t));
    final sendAt = item.sendAt;
    final sentAt = item.sentAt;
    final when = switch (item.status) {
      StudioNotificationStatus.sent when sentAt != null => 'Sent ${at(sentAt)}',
      StudioNotificationStatus.scheduled when sendAt != null =>
        'Due ${at(sendAt)}',
      _ when sendAt != null => 'Was due ${at(sendAt)}',
      _ => null,
    };
    final meta = [
      item.audience.label,
      item.status.label,
      ?when,
      if (item.createdByName != null) 'by ${item.createdByName}',
    ].join(' \u00b7 ');
    final error = item.error;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.bodyLg.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  meta,
                  style: AppTypography.labelMd.copyWith(
                    color: item.status == StudioNotificationStatus.failed
                        ? AppColors.error
                        : AppColors.textMuted,
                  ),
                ),
                if (error != null) StudioHint(error, color: AppColors.error),
              ],
            ),
          ),
          if (item.status.cancellable)
            TextButton(
              onPressed: () => _cancel(context, ref),
              child: Text(
                'Cancel',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(studioNotificationRepositoryProvider).cancel(item.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Cancelled "${item.title}".'),
          backgroundColor: AppColors.surfaceElevated,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not cancel: $e'),
          backgroundColor: AppColors.errorContainer,
        ),
      );
    }
  }
}
