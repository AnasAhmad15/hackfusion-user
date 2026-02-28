import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// PharmaCo Chat Bubble
/// ────────────────────
/// Flat, clean, accessible chat bubbles for AI assistant and user.
/// Assistant: left-aligned, light surface background, with avatar.
/// User: right-aligned, primary color fill.
///
/// Usage:
///   ChatBubble.assistant(text: 'Hello! How can I help?')
///   ChatBubble.user(text: 'I need Paracetamol')
///   ChatBubble.typing()  // animated typing indicator

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isTyping;
  final String? avatarLabel;

  const ChatBubble({
    super.key,
    required this.text,
    this.isUser = false,
    this.isTyping = false,
    this.avatarLabel,
  });

  /// Assistant bubble — left-aligned with avatar.
  const ChatBubble.assistant({
    super.key,
    required this.text,
    this.avatarLabel = 'AI',
  })  : isUser = false,
        isTyping = false;

  /// User bubble — right-aligned, primary fill.
  const ChatBubble.user({
    super.key,
    required this.text,
  })  : isUser = true,
        isTyping = false,
        avatarLabel = null;

  /// Typing indicator (animated three dots).
  const ChatBubble.typing({
    super.key,
  })  : text = '',
        isUser = false,
        isTyping = true,
        avatarLabel = 'AI';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: PharmacoTokens.space12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Assistant avatar
          if (!isUser) ...[
            CircleAvatar(
              radius: PharmacoTokens.avatarSmall / 2,
              backgroundColor: PharmacoTokens.primarySurface,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: PharmacoTokens.iconSmall,
                color: PharmacoTokens.primaryBase,
              ),
            ),
            const SizedBox(width: PharmacoTokens.space8),
          ],
          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: PharmacoTokens.space16,
                vertical: PharmacoTokens.space12,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? PharmacoTokens.primaryBase
                    : (isDark
                        ? PharmacoTokens.darkSurfaceElevated
                        : PharmacoTokens.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(PharmacoTokens.radiusMedium),
                  topRight: const Radius.circular(PharmacoTokens.radiusMedium),
                  bottomLeft: Radius.circular(
                    isUser ? PharmacoTokens.radiusMedium : 0,
                  ),
                  bottomRight: Radius.circular(
                    isUser ? 0 : PharmacoTokens.radiusMedium,
                  ),
                ),
                boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
              ),
              child: isTyping
                  ? const _TypingIndicator()
                  : Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isUser
                            ? PharmacoTokens.white
                            : theme.colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: PharmacoTokens.space8),
        ],
      ),
    );
  }
}

/// Three-dot typing indicator with animation.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );

    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    // Stagger start
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (_, child) => Transform.translate(
            offset: Offset(0, _animations[i].value),
            child: child,
          ),
          child: Container(
            width: 8,
            height: 8,
            margin: EdgeInsets.only(
              right: i < 2 ? PharmacoTokens.space4 : 0,
            ),
            decoration: BoxDecoration(
              color: PharmacoTokens.neutral400,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
