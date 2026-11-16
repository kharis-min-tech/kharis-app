import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/kharis_theme.dart';

/// The Kharis icon set: 24px grid, 2px rounded line, with play, pause and
/// flame filled. Never mix in Material or Cupertino icons, so the app keeps
/// one icon style.
abstract final class KIcons {
  static const String _dir = 'assets/icons';
  static const String home = '$_dir/home.svg';
  static const String messages = '$_dir/messages.svg';
  static const String bible = '$_dir/bible.svg';
  static const String bookOpen = '$_dir/book-open.svg';
  static const String more = '$_dir/more.svg';
  static const String play = '$_dir/play.svg';
  static const String pause = '$_dir/pause.svg';
  static const String download = '$_dir/download.svg';
  static const String check = '$_dir/check.svg';
  static const String chevronRight = '$_dir/chevron-right.svg';
  static const String chevronLeft = '$_dir/chevron-left.svg';
  static const String chevronDown = '$_dir/chevron-down.svg';
  static const String chevronUp = '$_dir/chevron-up.svg';
  static const String close = '$_dir/close.svg';
  static const String sort = '$_dir/sort.svg';
  static const String plus = '$_dir/plus.svg';
  static const String minus = '$_dir/minus.svg';
  static const String search = '$_dir/search.svg';
  static const String share = '$_dir/share.svg';
  static const String soundwave = '$_dir/soundwave.svg';
  static const String video = '$_dir/video.svg';
  static const String audio = '$_dir/audio.svg';
  static const String flame = '$_dir/flame.svg';
  static const String calendar = '$_dir/calendar.svg';
  static const String bell = '$_dir/bell.svg';
  static const String pin = '$_dir/pin.svg';
  static const String scroll = '$_dir/scroll.svg';
  static const String pages = '$_dir/pages.svg';
  static const String bookmark = '$_dir/bookmark.svg';
  static const String playCircle = '$_dir/play-circle.svg';
  static const String trophy = '$_dir/trophy.svg';
  static const String heart = '$_dir/heart.svg';
  static const String pen = '$_dir/pen.svg';
  static const String note = '$_dir/note.svg';
  static const String users = '$_dir/users.svg';
  static const String lock = '$_dir/lock.svg';
  static const String gift = '$_dir/gift.svg';
  static const String gear = '$_dir/gear.svg';
  static const String collection = '$_dir/collection.svg';
  static const String card = '$_dir/card.svg';
  static const String repeat = '$_dir/repeat.svg';
  static const String mic = '$_dir/mic.svg';
  static const String send = '$_dir/send.svg';
  static const String moon = '$_dir/moon.svg';
  static const String help = '$_dir/help.svg';
  static const String signOut = '$_dir/sign-out.svg';
  static const String textSize = '$_dir/text-size.svg';
  static const String sparkle = '$_dir/sparkle.svg';
  static const String rewind = '$_dir/rewind.svg';
}

/// Draws one icon from [KIcons] in a theme colour.
class KIcon extends StatelessWidget {
  const KIcon(this.asset, {super.key, this.size = KSize.icon, this.color, this.semanticLabel});

  /// One of the [KIcons] paths.
  final String asset;
  final double size;

  /// Defaults to the theme's text colour.
  final Color? color;

  /// Leave null for decorative icons; set it when the icon carries meaning alone.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      colorFilter: ColorFilter.mode(color ?? context.k.text, BlendMode.srcIn),
    );
  }
}
