import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../main.dart';

OverlayEntry? _currentToastEntry;
Timer? _currentToastTimer;

void showWebNotificationToast({
  required String senderName,
  required String messageText,
  String? senderId,
  VoidCallback? onReply,
}) {
  final overlayState = rootNavigatorKey.currentState?.overlay;
  if (overlayState == null) return;

  // Dismiss any existing toast safely
  _currentToastTimer?.cancel();
  if (_currentToastEntry != null && _currentToastEntry!.mounted) {
    try {
      _currentToastEntry?.remove();
    } catch (_) {}
  }
  _currentToastEntry = null;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _WebNotificationToastWidget(
      senderName: senderName,
      messageText: messageText,
      onReply: () {
        if (entry.mounted) {
          try {
            entry.remove();
          } catch (_) {}
        }
        if (_currentToastEntry == entry) {
          _currentToastEntry = null;
        }
        onReply?.call();
      },
      onDismiss: () {
        if (entry.mounted) {
          try {
            entry.remove();
          } catch (_) {}
        }
        if (_currentToastEntry == entry) {
          _currentToastEntry = null;
        }
      },
    ),
  );

  _currentToastEntry = entry;
  overlayState.insert(entry);
}

class _WebNotificationToastWidget extends StatefulWidget {
  final String senderName;
  final String messageText;
  final VoidCallback onReply;
  final VoidCallback onDismiss;

  const _WebNotificationToastWidget({
    required this.senderName,
    required this.messageText,
    required this.onReply,
    required this.onDismiss,
  });

  @override
  State<_WebNotificationToastWidget> createState() =>
      _WebNotificationToastWidgetState();
}

class _WebNotificationToastWidgetState extends State<_WebNotificationToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _autoDismissTimer;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.35, 0.0),
      end: Offset.zero,
    ).animate(curved);

    _controller.forward();
    _startTimer();
  }

  void _startTimer() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isHovered) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _autoDismissTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.senderName.isNotEmpty
        ? widget.senderName.substring(0, 1).toUpperCase()
        : 'U';

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final toastWidth = screenWidth < 420 ? (screenWidth - 32) : 360.0;
    final rightPadding = screenWidth < 420 ? 16.0 : 24.0;
    final topPadding = mediaQuery.padding.top + 20.0;

    return Positioned(
      top: topPadding,
      right: rightPadding,
      child: Material(
        color: Colors.transparent,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            setState(() {
              _isHovered = true;
            });
            _autoDismissTimer?.cancel();
          },
          onExit: (_) {
            setState(() {
              _isHovered = false;
            });
            _startTimer();
          },
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: toastWidth,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _isHovered
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.12),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: const Color(0xFF2E65FF).withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: widget.onReply,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 14.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Top row: Avatar, Sender Name, Timestamp, Close Button
                            Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF2E65FF),
                                        Color(0xFF8236FE)
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Name & Subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.senderName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Text(
                                        'New Message • Just now',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Close button
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _dismiss,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white
                                          .withValues(alpha: 0.08),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white70,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Message Preview
                            Text(
                              widget.messageText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            // Action Row: Reply Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: widget.onReply,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF2E65FF),
                                          Color(0xFF4F46E5)
                                        ],
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF2E65FF)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Reply',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
