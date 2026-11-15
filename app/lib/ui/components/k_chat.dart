import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_circle_button.dart';
import 'k_icon.dart';
import 'k_icon_button.dart';

BorderRadiusGeometry _bubbleRadius({required bool fromUser}) {
  const round = Radius.circular(KRadius.bubble);
  const tail = Radius.circular(KRadius.bubbleTail);
  return BorderRadiusDirectional.only(
    topStart: round,
    topEnd: round,
    bottomStart: fromUser ? round : tail,
    bottomEnd: fromUser ? tail : round,
  );
}

/// One message in the Grace thread. Grace: surface2, on the left, tail
/// bottom-left. The person: primaryTint, on the right, tail bottom-right.
/// At most 82% of the thread width.
class KChatBubble extends StatelessWidget {
  const KChatBubble({
    super.key,
    required this.text,
    required this.fromUser,
    this.semanticLabel,
  });

  final String text;

  /// True for the person's own message, false for Grace.
  final bool fromUser;

  /// Read in place of the text, to say who is speaking: "Grace: …".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: fromUser
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth * KRatio.bubbleMaxWidth,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fromUser ? k.primaryTint : k.surface2,
              borderRadius: _bubbleRadius(fromUser: fromUser),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KSpace.x3,
                vertical: KSpace.xxl,
              ),
              child: Text(
                text,
                semanticsLabel: semanticLabel,
                style: KharisText.body.copyWith(color: k.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three muted dots in a Grace bubble while an answer is on its way. The
/// dots pulse in turn; with reduce motion on they stay still.
class KTypingIndicator extends StatefulWidget {
  const KTypingIndicator({super.key, this.semanticLabel = 'Grace is typing'});

  final String semanticLabel;

  @override
  State<KTypingIndicator> createState() => _KTypingIndicatorState();
}

class _KTypingIndicatorState extends State<KTypingIndicator>
    with SingleTickerProviderStateMixin {
  static const int _dots = 3;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: KMotion.typing,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse
        ..stop()
        ..value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Full at the start of a dot's turn, dimmest halfway, full again at the
  /// end. Each dot starts a sixth of a cycle after the one before.
  double _opacity(int dot) {
    final phase = (_pulse.value - dot / (_dots * 2)) % 1;
    final dip = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return 1 - (1 - KRatio.typingDim) * dip;
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Semantics(
      liveRegion: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: k.surface2,
            borderRadius: _bubbleRadius(fromUser: false),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpace.x3,
              vertical: KSpace.xxl,
            ),
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _dots; i++) ...[
                    if (i > 0) const SizedBox(width: KSpace.xs),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: k.muted.withValues(alpha: _opacity(i)),
                      ),
                      child: const SizedBox.square(dimension: KSize.typingDot),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The message box at the bottom of the Grace sheet: a search-field style
/// input, an optional microphone button and a round primary send button.
class KComposer extends StatelessWidget {
  const KComposer({
    super.key,
    required this.hint,
    required this.onSend,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onMic,
    this.sendLabel = 'Send',
    this.micLabel = 'Speak your message',
  });

  /// Placeholder, for example "Ask Grace anything…".
  final String hint;

  /// Null disables sending, for example while the box is empty.
  final VoidCallback? onSend;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  /// Null hides the microphone button.
  final VoidCallback? onMic;
  final String sendLabel;
  final String micLabel;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.tile)),
        border: Border.all(color: k.border),
        boxShadow: context.isDarkTheme ? KShadow.cardDark : KShadow.cardLight,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: KSize.searchField),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: KSpace.x3,
            end: KSpace.xs,
            top: KSpace.xs,
            bottom: KSpace.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    onSubmitted: onSend == null ? null : (_) => onSend!(),
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    cursorColor: k.primaryText,
                    style: KharisText.body.copyWith(color: k.text),
                    decoration: InputDecoration.collapsed(
                      hintText: hint,
                      hintStyle: KharisText.body.copyWith(color: k.muted),
                    ),
                  ),
                ),
              ),
              if (onMic != null)
                KIconButton(
                  icon: KIcons.mic,
                  label: micLabel,
                  onPressed: onMic,
                ),
              KCircleButton(
                icon: KIcons.send,
                label: sendLabel,
                onPressed: onSend,
                size: KSize.touchMin,
                iconSize: KSize.iconMd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
