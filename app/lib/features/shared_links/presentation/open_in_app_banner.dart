import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kharis_app/core/constants/app_links.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The universal / App Link for the shared path the browser landed on, and
/// on Android an `intent:` URL for the same link that Chrome hands straight
/// to the installed app (falling back to the Play Store when it is not).
@visibleForTesting
Uri openInAppUri(Uri landed, TargetPlatform platform) {
  final link = Uri(
    scheme: 'https',
    host: AppLinks.host,
    path: landed.path,
    query: landed.hasQuery ? landed.query : null,
  );
  if (platform != TargetPlatform.android) return link;
  final query = link.hasQuery ? '?${link.query}' : '';
  return Uri.parse(
    'intent://${link.host}${link.path}$query#Intent;scheme=https;'
    'package=${AppLinks.androidPackage};'
    'S.browser_fallback_url=${Uri.encodeComponent(AppLinks.playStoreUrl)};end',
  );
}

/// Slim web-only bar above the app, shown when the browser opened one of the
/// shared-link paths (`/m/…`, `/e/…`, `/a/…`): "Open in the Kharis app" and,
/// where the store fits the device, "Get the app". The web app keeps working
/// underneath, so the person can listen right there. Dismissible.
///
/// No App Store listing id exists in the repo, so iOS gets no "Get the app";
/// iOS opens an installed app from the shared link itself (universal link)
/// before the browser is involved.
class OpenInAppBanner extends StatefulWidget {
  OpenInAppBanner({
    super.key,
    required this.child,
    Uri? landed,
    bool? isWeb,
    TargetPlatform? platform,
  }) : landed = landed ?? Uri.base,
       isWeb = isWeb ?? kIsWeb,
       platform = platform ?? defaultTargetPlatform;

  final Widget child;

  /// The URL the app was opened at (the browser's address on web). Read
  /// once: in-app navigation later rewrites the address bar.
  final Uri landed;

  final bool isWeb;
  final TargetPlatform platform;

  @override
  State<OpenInAppBanner> createState() => _OpenInAppBannerState();
}

class _OpenInAppBannerState extends State<OpenInAppBanner> {
  /// The shared link the browser opened. Kept from the first build: the
  /// address bar follows in-app navigation (a message link moves on to
  /// /messages under the player), but the app should open the link itself.
  late final Uri _landed = widget.landed;

  /// Fixed for the session, so the tree shape around the app never changes.
  late final bool _eligible =
      widget.isWeb && AppLinks.isSharedPath(_landed.path);
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (!_eligible) return widget.child;
    final visible = !_dismissed;
    return Column(
      children: [
        // Dismissing swaps this slot only; the app below keeps its state.
        if (visible) _bar(context) else const SizedBox.shrink(),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: visible,
            child: widget.child,
          ),
        ),
      ],
    );
  }

  Widget _bar(BuildContext context) {
    final android = widget.platform == TargetPlatform.android;
    final showStore = widget.platform != TargetPlatform.iOS;
    final k = context.k;
    return ColoredBox(
      key: const Key('open-in-app-banner'),
      color: k.bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpace.xl,
            vertical: KSpace.md,
          ),
          child: KCard(
            padding: const EdgeInsetsDirectional.only(
              start: KSpace.x3,
              end: KSpace.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: KTextLink(
                      label: 'Open in the Kharis app',
                      // Chrome only hands an intent: URL to the app from
                      // a same-tab navigation.
                      onTap: () => _launch(
                        openInAppUri(_landed, widget.platform),
                        window: android ? '_self' : '_blank',
                      ),
                    ),
                  ),
                ),
                if (showStore) ...[
                  const SizedBox(width: KSpace.md),
                  KTextLink(
                    label: 'Get the app',
                    onTap: () => _launch(
                      Uri.parse(AppLinks.playStoreUrl),
                      window: '_blank',
                    ),
                  ),
                ],
                const SizedBox(width: KSpace.md),
                KIconButton(
                  key: const Key('open-in-app-dismiss'),
                  icon: KIcons.close,
                  label: 'Dismiss',
                  color: k.muted,
                  onPressed: () => setState(() => _dismissed = true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _launch(Uri uri, {required String window}) {
    unawaited(
      launchUrl(uri, webOnlyWindowName: window).catchError((Object _) => false),
    );
  }
}
