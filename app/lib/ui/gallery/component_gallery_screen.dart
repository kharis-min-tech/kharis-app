import 'package:flutter/material.dart';

import '../components/components.dart';

/// One entry of the design-check gallery: a component with its variants and
/// states. The golden tests render these same entries, so the gallery and
/// the goldens cannot drift apart.
class GallerySection {
  const GallerySection({
    required this.id,
    required this.title,
    required this.caption,
    required this.builder,
  });

  /// Stable name, also the golden file name.
  final String id;
  final String title;
  final String caption;
  final WidgetBuilder builder;
}

/// Every icon in the set, by name. A test checks this against assets/icons/.
const Map<String, String> galleryIcons = {
  'home': KIcons.home,
  'messages': KIcons.messages,
  'bible': KIcons.bible,
  'book-open': KIcons.bookOpen,
  'more': KIcons.more,
  'play': KIcons.play,
  'pause': KIcons.pause,
  'download': KIcons.download,
  'check': KIcons.check,
  'chevron-right': KIcons.chevronRight,
  'chevron-left': KIcons.chevronLeft,
  'chevron-down': KIcons.chevronDown,
  'chevron-up': KIcons.chevronUp,
  'close': KIcons.close,
  'sort': KIcons.sort,
  'plus': KIcons.plus,
  'minus': KIcons.minus,
  'search': KIcons.search,
  'share': KIcons.share,
  'soundwave': KIcons.soundwave,
  'video': KIcons.video,
  'audio': KIcons.audio,
  'flame': KIcons.flame,
  'calendar': KIcons.calendar,
  'bell': KIcons.bell,
  'pin': KIcons.pin,
  'scroll': KIcons.scroll,
  'pages': KIcons.pages,
  'bookmark': KIcons.bookmark,
  'play-circle': KIcons.playCircle,
  'trophy': KIcons.trophy,
  'heart': KIcons.heart,
  'pen': KIcons.pen,
  'note': KIcons.note,
  'users': KIcons.users,
  'lock': KIcons.lock,
  'gift': KIcons.gift,
  'gear': KIcons.gear,
  'collection': KIcons.collection,
  'card': KIcons.card,
  'repeat': KIcons.repeat,
  'mic': KIcons.mic,
  'send': KIcons.send,
  'moon': KIcons.moon,
  'help': KIcons.help,
  'sign-out': KIcons.signOut,
  'text-size': KIcons.textSize,
  'sparkle': KIcons.sparkle,
  'rewind': KIcons.rewind,
};

/// Holds one value for a demo, so a gallery entry can be tapped and show
/// its other state.
class _Demo<T> extends StatefulWidget {
  const _Demo({required this.initial, required this.builder});

  final T initial;
  final Widget Function(BuildContext context, T value, ValueChanged<T> set)
  builder;

  @override
  State<_Demo<T>> createState() => _DemoState<T>();
}

class _DemoState<T> extends State<_Demo<T>> {
  late T _value = widget.initial;

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    _value,
    (value) => setState(() => _value = value),
  );
}

Widget _gap() => const SizedBox(height: KSpace.xl);

Widget _wrap(List<Widget> children) => Wrap(
  spacing: KSpace.md,
  runSpacing: KSpace.md,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: children,
);

Widget _column(List<Widget> children) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  mainAxisSize: MainAxisSize.min,
  children: children,
);

const _sortOptions = [
  KSortOption(value: 'relevant', label: 'Most relevant'),
  KSortOption(value: 'newest', label: 'Newest first'),
  KSortOption(value: 'oldest', label: 'Oldest first'),
  KSortOption(value: 'shortest', label: 'Shortest first'),
];

/// The gallery entries. [artwork] and [photo] fill the image slots; leave
/// them null to show the surface2 placeholder every image sits on while it
/// loads.
List<GallerySection> gallerySections({
  ImageProvider? artwork,
  ImageProvider? photo,
}) {
  void noop() {}

  return [
    GallerySection(
      id: 'type',
      title: 'Type scale',
      caption: 'Plus Jakarta Sans at 400, 600, 700 and 800.',
      builder: (context) {
        final k = context.k;
        return _column([
          Text('64', style: KharisText.display.copyWith(color: k.text)),
          Text(
            'Screen title',
            style: KharisText.screenTitle.copyWith(color: k.text),
          ),
          Text(
            'Page title',
            style: KharisText.pageTitle.copyWith(color: k.text),
          ),
          Text('Headline', style: KharisText.headline.copyWith(color: k.text)),
          Text('Section', style: KharisText.section.copyWith(color: k.text)),
          Text('Title', style: KharisText.title.copyWith(color: k.text)),
          Text(
            'Reading: In the beginning was the Word.',
            style: KharisText.reading.copyWith(color: k.text),
          ),
          Text(
            'Body: paragraphs and descriptions.',
            style: KharisText.body.copyWith(color: k.text),
          ),
          Text('Button', style: KharisText.button.copyWith(color: k.text)),
          Text('Link', style: KharisText.link.copyWith(color: k.primaryText)),
          Text(
            'Item title',
            style: KharisText.itemTitle.copyWith(color: k.text),
          ),
          Text('Meta line', style: KharisText.meta.copyWith(color: k.muted)),
          Text('Caption', style: KharisText.caption.copyWith(color: k.muted)),
          Text('Small', style: KharisText.small.copyWith(color: k.muted)),
          const KOverline('Overline'),
        ]);
      },
    ),
    GallerySection(
      id: 'button',
      title: 'KButton',
      caption:
          'Primary, inverse, tonal, outline and text; with an icon; '
          'loading; disabled; the 56 main call to action.',
      builder: (context) => _column([
        _wrap([
          KButton(label: 'Listen now', onPressed: noop),
          KButton(
            label: 'Save for offline',
            onPressed: noop,
            variant: KButtonVariant.inverse,
          ),
          KButton(
            label: 'Make it a plan',
            onPressed: noop,
            variant: KButtonVariant.tonal,
          ),
          KButton(
            label: 'Change branch',
            onPressed: noop,
            variant: KButtonVariant.outline,
          ),
          KButton(
            label: 'Skip for now',
            onPressed: noop,
            variant: KButtonVariant.text,
          ),
          KButton(label: 'Listen', onPressed: noop, icon: KIcons.play),
          KButton(label: 'Sending', onPressed: noop, loading: true),
          const KButton(label: 'Unavailable', onPressed: null),
        ]),
        _gap(),
        KButton(
          label: 'Give £50 now',
          onPressed: noop,
          size: KButtonSize.cta,
          expand: true,
        ),
      ]),
    ),
    GallerySection(
      id: 'icon_button',
      title: 'KIconButton',
      caption: 'Plain, filled and disabled. 40 visible in a 44 hit area.',
      builder: (context) => _wrap([
        KIconButton(icon: KIcons.search, label: 'Search', onPressed: noop),
        KIconButton(
          icon: KIcons.bell,
          label: 'Notifications',
          onPressed: noop,
          variant: KIconButtonVariant.filled,
        ),
        const KIconButton(
          icon: KIcons.download,
          label: 'Download',
          onPressed: null,
          variant: KIconButtonVariant.filled,
        ),
      ]),
    ),
    GallerySection(
      id: 'text_link',
      title: 'KTextLink',
      caption: 'Plain and with a chevron.',
      builder: (context) => _wrap([
        KTextLink(label: 'History', onTap: noop),
        KTextLink(label: 'See all', onTap: noop, showChevron: true),
      ]),
    ),
    GallerySection(
      id: 'chip',
      title: 'KChip',
      caption: 'Unselected, selected, with an icon, with a chevron.',
      builder: (context) => _wrap([
        KChip(label: 'Book', onTap: noop),
        KChip(label: 'Theme', onTap: noop, selected: true),
        KChip(label: 'Most relevant', onTap: noop, leading: KIcons.sort),
        KChip(label: 'Series', onTap: noop, showChevron: true),
      ]),
    ),
    GallerySection(
      id: 'chip_row',
      title: 'KChipRow',
      caption: 'Scrolls sideways and fades at the right edge. Tap to select.',
      builder: (context) => _Demo<int>(
        initial: 0,
        builder: (context, selected, set) => KChipRow(
          children: [
            for (final (i, label) in const [
              'Sort',
              'Book',
              'Theme',
              'Series',
              'Date',
              'Length',
            ].indexed)
              KChip(
                label: label,
                selected: i == selected,
                onTap: () => set(i),
                showChevron: true,
              ),
          ],
        ),
      ),
    ),
    GallerySection(
      id: 'toggle_button',
      title: 'KToggleButton',
      caption: 'Off and on. The icon and label change with the state.',
      builder: (context) => _wrap([
        _Demo<bool>(
          initial: false,
          builder: (context, on, set) => KToggleButton(
            label: 'Remind me',
            selectedLabel: 'Reminder on',
            icon: KIcons.bell,
            selected: on,
            onChanged: set,
          ),
        ),
        _Demo<bool>(
          initial: true,
          builder: (context, on, set) => KToggleButton(
            label: 'Follow',
            selectedLabel: 'Following',
            icon: KIcons.plus,
            selected: on,
            onChanged: set,
          ),
        ),
      ]),
    ),
    GallerySection(
      id: 'option_card',
      title: 'KOptionCard',
      caption: 'Single choice. Selected has a tint, an outline and a check.',
      builder: (context) => _Demo<int>(
        initial: 0,
        builder: (context, selected, set) => _column([
          KOptionCard(
            title: 'Tithe',
            meta: 'A tenth, given first',
            icon: KIcons.gift,
            selected: selected == 0,
            onTap: () => set(0),
          ),
          const SizedBox(height: KSpace.md),
          KOptionCard(
            title: 'Offering',
            meta: "This week's offering",
            icon: KIcons.heart,
            selected: selected == 1,
            onTap: () => set(1),
          ),
          const SizedBox(height: KSpace.md),
          KOptionCard(
            title: 'King James Version',
            selected: selected == 2,
            onTap: () => set(2),
          ),
        ]),
      ),
    ),
    GallerySection(
      id: 'tabs',
      title: 'KTabs',
      caption: 'Text tabs. Selected has the text colour and an underline.',
      builder: (context) => _Demo<int>(
        initial: 0,
        builder: (context, index, set) => KTabs(
          tabs: const ['For you', 'Books', 'Themes', 'Series', 'Downloads'],
          currentIndex: index,
          onChanged: set,
        ),
      ),
    ),
    GallerySection(
      id: 'streak_dots',
      title: 'KStreakDots',
      caption: 'A week of seven. Done days are filled and checked.',
      builder: (context) => const KStreakDots(
        days: [true, true, true, false, true, true, false],
        semanticLabel: '5 of 7 days this week',
      ),
    ),
    GallerySection(
      id: 'card',
      title: 'KCard',
      caption: 'Default padding 16, compact 14, and tappable.',
      builder: (context) {
        final k = context.k;
        Widget body(String text) =>
            Text(text, style: KharisText.body.copyWith(color: k.text));
        return _column([
          KCard(child: body('Default card, 16 padding.')),
          const SizedBox(height: KSpace.md),
          KCard(
            padding: const EdgeInsets.all(KSpace.xxl),
            child: body('Compact card, 14 padding.'),
          ),
          const SizedBox(height: KSpace.md),
          KCard(
            onTap: noop,
            semanticLabel: 'Tappable card',
            child: body('Tappable card, read as one item.'),
          ),
        ]);
      },
    ),
    GallerySection(
      id: 'section_header',
      title: 'KSectionHeader and KOverline',
      caption: 'With and without a text action; the eyebrow above a title.',
      builder: (context) => _column([
        KSectionHeader(
          title: 'Continue listening',
          actionLabel: 'History',
          onAction: noop,
        ),
        const KSectionHeader(title: 'Your collections'),
        const KOverline("Today's reading"),
      ]),
    ),
    GallerySection(
      id: 'badge',
      title: 'KBadge',
      caption: 'Duration, live and new.',
      builder: (context) => _wrap(const [
        KBadge('52 min'),
        KBadge('Live', variant: KBadgeVariant.live),
        KBadge('New', variant: KBadgeVariant.newItem),
        KBadge('27-day reading', icon: KIcons.flame),
      ]),
    ),
    GallerySection(
      id: 'media_tile',
      title: 'KMediaTile',
      caption: 'Messages 1:1, videos 16:9, Shorts 9:16.',
      builder: (context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: KMediaTile(
              title: 'In Spirit and Truth',
              meta: 'Pastor David Antwi',
              duration: '52 min',
              image: artwork,
              onTap: noop,
            ),
          ),
          const SizedBox(width: KSpace.xl),
          Expanded(
            flex: 5,
            child: KMediaTile(
              title: 'When worship becomes personal',
              meta: 'Sunday Service',
              duration: '1:05',
              aspect: KMediaAspect.video,
              image: photo,
              onTap: noop,
            ),
          ),
          const SizedBox(width: KSpace.xl),
          Expanded(
            flex: 3,
            child: KMediaTile(
              title: 'Spirit and truth, together',
              meta: 'John 4:24',
              duration: '0:41',
              aspect: KMediaAspect.short,
              image: photo,
              onTap: noop,
            ),
          ),
        ],
      ),
    ),
    GallerySection(
      id: 'hero_card',
      title: 'KHeroCard',
      caption: 'One per screen. Text always sits on the ink gradient.',
      builder: (context) => KHeroCard(
        overline: 'New from Sunday',
        title: 'The Portraits of Christ',
        meta: 'Pastor David Antwi · Sunday Service · 58 min',
        image: photo,
        primaryAction: KButton(
          label: 'Listen now',
          icon: KIcons.play,
          onPressed: noop,
          expand: true,
        ),
        secondaryActions: [
          KIconButton(
            icon: KIcons.download,
            label: 'Download',
            onPressed: noop,
            variant: KIconButtonVariant.filled,
          ),
        ],
      ),
    ),
    GallerySection(
      id: 'list_row',
      title: 'KListRow and KListGroup',
      caption: 'Icon tile, thumbnail, a trailing value and a chevron.',
      builder: (context) => KListGroup(
        children: [
          KListRow(
            title: 'Notifications',
            leading: const KIconTile(KIcons.bell),
            trailing: Text(
              'On',
              style: KharisText.meta.copyWith(color: context.k.muted),
            ),
            onTap: noop,
          ),
          KListRow(
            title: 'For the drive',
            meta: '8 messages · 3 h 40 min',
            leading: KThumbnail(image: artwork),
            showChevron: true,
            onTap: noop,
          ),
          const KListRow(
            title: 'Faith that moves mountains, a very long title that ends',
            meta: 'Pastor David Antwi · 12 Oct 2026',
            trailing: KBadge('48 min'),
          ),
        ],
      ),
    ),
    GallerySection(
      id: 'empty_state',
      title: 'KEmptyState',
      caption: 'Icon, one-line title, one-line hint and an optional button.',
      builder: (context) => KEmptyState(
        icon: KIcons.download,
        title: 'No downloads yet',
        hint: 'Save a message to listen without a connection.',
        action: KButton(
          label: 'Browse messages',
          onPressed: noop,
          variant: KButtonVariant.tonal,
        ),
      ),
    ),
    GallerySection(
      id: 'skeleton',
      title: 'KSkeleton',
      caption: 'Surface2 blocks that match the layout they stand in for.',
      builder: (context) => KListGroup(
        children: [
          for (var i = 0; i < 2; i++)
            const Padding(
              padding: EdgeInsets.all(KSpace.x3),
              child: Row(
                children: [
                  KSkeleton(width: KSize.thumb, height: KSize.thumb),
                  SizedBox(width: KSpace.xl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KSkeleton(height: KSpace.xxl, radius: KRadius.xs),
                        SizedBox(height: KSpace.md),
                        FractionallySizedBox(
                          widthFactor: KRatio.bubbleMaxWidth,
                          child: KSkeleton(
                            height: KSpace.xl,
                            radius: KRadius.xs,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
    GallerySection(
      id: 'error_state',
      title: 'KErrorState',
      caption: 'One line saying what happened and what to do, and Retry.',
      builder: (context) => KErrorState(
        message: "Messages didn't load. Check your connection and retry.",
        onRetry: noop,
      ),
    ),
    GallerySection(
      id: 'search_field',
      title: 'KSearchField',
      caption: 'Empty, and with a trailing icon button.',
      builder: (context) => _column([
        const KSearchField(hint: 'Search a word, verse or question'),
        const SizedBox(height: KSpace.md),
        KSearchField(
          hint: 'Search messages',
          trailing: KIconButton(
            icon: KIcons.bookOpen,
            label: 'Choose a passage',
            onPressed: noop,
          ),
        ),
      ]),
    ),
    GallerySection(
      id: 'screen_header',
      title: 'KScreenHeader',
      caption: 'Screen title and up to two icon buttons. No back button.',
      builder: (context) => KScreenHeader(
        title: 'Messages',
        actions: [
          KIconButton(
            icon: KIcons.search,
            label: 'Search messages',
            onPressed: noop,
            variant: KIconButtonVariant.filled,
          ),
          KIconButton(
            icon: KIcons.bell,
            label: 'Notifications',
            onPressed: noop,
            variant: KIconButtonVariant.filled,
          ),
        ],
      ),
    ),
    GallerySection(
      id: 'bottom_sheet',
      title: 'KBottomSheet',
      caption:
          'Sheet colour, grab handle and title. Open it to check the scrim, '
          'swipe to dismiss and the fade under reduce motion.',
      builder: (context) => _column([
        KBottomSheet(
          title: 'Choose a book',
          child: Text(
            'Sheet content sits here, 20 from each side.',
            style: KharisText.body.copyWith(color: context.k.text),
          ),
        ),
        _gap(),
        KButton(
          label: 'Open the sheet',
          variant: KButtonVariant.outline,
          onPressed: () => showKBottomSheet<void>(
            context: context,
            title: 'Grace',
            titleSize: KSheetTitleSize.page,
            builder: (sheetContext) => Text(
              'Swipe down or tap outside to close.',
              style: KharisText.body.copyWith(color: sheetContext.k.text),
            ),
          ),
        ),
      ]),
    ),
    GallerySection(
      id: 'sort_sheet',
      title: 'KSortSheet',
      caption: 'Radio rows, one choice.',
      builder: (context) => _Demo<String>(
        initial: 'relevant',
        builder: (context, selected, set) => _column([
          KBottomSheet(
            title: 'Sort by',
            child: KSortSheet<String>(
              options: _sortOptions,
              selected: selected,
              onSelected: set,
            ),
          ),
          _gap(),
          KButton(
            label: 'Open the sort sheet',
            variant: KButtonVariant.outline,
            onPressed: () async {
              final choice = await showKSortSheet<String>(
                context: context,
                title: 'Sort by',
                options: _sortOptions,
                selected: selected,
              );
              if (choice != null) set(choice);
            },
          ),
        ]),
      ),
    ),
    GallerySection(
      id: 'floating_nav',
      title: 'KFloatingNav',
      caption: 'Home, Messages, Bible, More. The active tab has a pill.',
      builder: (context) => _Demo<int>(
        initial: 1,
        builder: (context, index, set) => KFloatingNav(
          currentIndex: index,
          onTap: set,
          items: const [
            KNavItem(label: 'Home', icon: KIcons.home),
            KNavItem(label: 'Messages', icon: KIcons.messages),
            KNavItem(label: 'Bible', icon: KIcons.bible),
            KNavItem(label: 'More', icon: KIcons.more),
          ],
        ),
      ),
    ),
    GallerySection(
      id: 'grace_button',
      title: 'KGraceButton',
      caption: 'Bobs 5 over 2.8 s with a halo. Still under reduce motion.',
      builder: (context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: KGraceButton(
          onPressed: noop,
          semanticLabel: 'Ask Grace, your Bible companion',
        ),
      ),
    ),
    GallerySection(
      id: 'mini_player',
      title: 'KMiniPlayer',
      caption: 'Playing and paused. Sits above the nav.',
      builder: (context) => _Demo<bool>(
        initial: true,
        builder: (context, playing, set) => _column([
          KMiniPlayer(
            title: 'The Portraits of Christ',
            subtitle: 'Pastor David Antwi',
            artwork: artwork,
            progress: 0.42,
            playing: playing,
            onPlayPause: () => set(!playing),
            onClose: noop,
            onTap: noop,
          ),
          const SizedBox(height: KSpace.md),
          KMiniPlayer(
            title: 'Let the Bible live: Hebrews 11, a long title that ends',
            progress: 0.8,
            playing: false,
            onPlayPause: noop,
            onClose: noop,
          ),
        ]),
      ),
    ),
    GallerySection(
      id: 'continue_listening',
      title: 'KContinueListening',
      caption: 'At most three, newest first. A fourth is left to History.',
      builder: (context) => KContinueListening(
        onHistory: noop,
        items: [
          KContinueItem(
            title: 'In Spirit and Truth',
            meta: 'Pastor David Antwi · 18 min left',
            progress: 0.66,
            artwork: artwork,
            onPlay: noop,
            onTap: noop,
          ),
          KContinueItem(
            title: 'Christ: the eternally blessed God',
            meta: 'Truly Man, Truly God · 31 min left',
            progress: 0.3,
            onPlay: noop,
          ),
          KContinueItem(
            title: 'Let the Bible live: Hebrews 11',
            meta: 'Podcast · 9 min left',
            progress: 0.85,
            onPlay: noop,
          ),
          KContinueItem(
            title: 'Not shown: the fourth item',
            meta: 'Only in History',
            progress: 0.1,
            onPlay: noop,
          ),
        ],
      ),
    ),
    GallerySection(
      id: 'event_card',
      title: 'KEventCard',
      caption: 'Date block, title, meta and a Remind me toggle.',
      builder: (context) => _Demo<bool>(
        initial: false,
        builder: (context, on, set) => _column([
          KEventCard(
            month: 'Wed',
            day: '11',
            title: 'Midweek Service · 19:00',
            meta: 'The Lighthouse Theatre, Camberwell',
            dateSemanticLabel: 'Wednesday 11 November',
            toggle: KToggleButton(
              label: 'Remind me',
              selectedLabel: 'Reminder on',
              icon: KIcons.bell,
              selected: on,
              onChanged: set,
            ),
          ),
          const SizedBox(height: KSpace.md),
          const KEventCard(
            month: 'Nov',
            day: '22',
            title: 'Baptism Sunday',
            meta: 'Kharis London',
          ),
        ]),
      ),
    ),
    GallerySection(
      id: 'chat',
      title: 'KChatBubble and KTypingIndicator',
      caption: 'Grace on the left, the person on the right, then typing.',
      builder: (context) => _column(const [
        KChatBubble(text: 'What should I read before Sunday?', fromUser: true),
        SizedBox(height: KSpace.md),
        KChatBubble(
          text:
              'Pastor David is preaching through The Portraits of Christ. '
              'Part 1 began in John 1, so reading it this week will set you '
              'up for Part 2.',
          fromUser: false,
          semanticLabel:
              'Grace: Pastor David is preaching through The Portraits of '
              'Christ. Part 1 began in John 1, so reading it this week will '
              'set you up for Part 2.',
        ),
        SizedBox(height: KSpace.md),
        KTypingIndicator(),
      ]),
    ),
    GallerySection(
      id: 'composer',
      title: 'KComposer',
      caption: 'Message box with a microphone and a round send button.',
      builder: (context) => _column([
        KComposer(hint: 'Ask Grace anything…', onSend: noop, onMic: noop),
        const SizedBox(height: KSpace.md),
        const KComposer(hint: 'Sending is off while empty', onSend: null),
      ]),
    ),
    GallerySection(
      id: 'icons',
      title: 'KIcon',
      caption: 'The ${galleryIcons.length} Kharis icons. No others are used.',
      builder: (context) => Wrap(
        spacing: KSpace.xl,
        runSpacing: KSpace.xl,
        children: [
          for (final entry in galleryIcons.entries)
            KIcon(entry.value, semanticLabel: entry.key),
        ],
      ),
    ),
    GallerySection(
      id: 'dove_mark',
      title: 'KDoveMark',
      caption: 'The dove is an image, tinted by the theme.',
      builder: (context) => _wrap([
        const KDoveMark(size: KSize.iconLg, semanticLabel: 'Kharis Church'),
        KDoveMark(size: KSize.graceSize, color: context.k.highlightText),
      ]),
    ),
  ];
}

/// The design-check gallery: every component with its variants and states,
/// in the new theme, with a light and dark switch. Debug builds only (see
/// the `/design` route).
class ComponentGalleryScreen extends StatefulWidget {
  const ComponentGalleryScreen({super.key});

  @override
  State<ComponentGalleryScreen> createState() => _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState extends State<ComponentGalleryScreen> {
  static const _artwork = AssetImage('assets/hero/preaching-open-bible.jpg');
  static const _photo = AssetImage('assets/hero/sunday-service-stage.jpg');

  late final List<GallerySection> _sections = gallerySections(
    artwork: _artwork,
    photo: _photo,
  );

  /// Null until the switch is used: the gallery then follows the system.
  bool? _dark;

  @override
  Widget build(BuildContext context) {
    final dark =
        _dark ?? MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    return Theme(
      data: dark ? KharisTheme.dark() : KharisTheme.light(),
      child: Builder(
        builder: (context) {
          final k = context.k;
          return Scaffold(
            backgroundColor: k.bg,
            body: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: KSize.maxContentWidth,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.only(
                      top: KSpace.x3,
                      bottom: KSpace.sectionTop,
                    ),
                    children: [
                      const KScreenHeader(title: 'Components'),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          KSpace.gutter,
                          KSpace.xl,
                          KSpace.gutter,
                          0,
                        ),
                        child: Row(
                          children: [
                            KChip(
                              label: 'Light',
                              selected: !dark,
                              onTap: () => setState(() => _dark = false),
                            ),
                            const SizedBox(width: KSpace.md),
                            KChip(
                              label: 'Dark',
                              selected: dark,
                              onTap: () => setState(() => _dark = true),
                            ),
                          ],
                        ),
                      ),
                      for (final section in _sections)
                        GallerySectionView(section: section),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Components that run edge to edge and bring their own side padding.
const _edgeToEdge = {'chip_row', 'tabs', 'screen_header', 'floating_nav'};

/// One gallery entry: its name, a caption, then the component.
class GallerySectionView extends StatelessWidget {
  const GallerySectionView({super.key, required this.section});

  final GallerySection section;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final demo = Builder(builder: section.builder);

    return Padding(
      padding: const EdgeInsets.only(top: KSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    section.title,
                    style: KharisText.title.copyWith(color: k.text),
                  ),
                ),
                Text(
                  section.caption,
                  style: KharisText.meta.copyWith(color: k.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpace.xl),
          if (_edgeToEdge.contains(section.id))
            demo
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
              child: demo,
            ),
        ],
      ),
    );
  }
}
