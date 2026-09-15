import 'dart:ui';
import 'package:flutter/material.dart';

Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required String title,
  required String subtitle,
  required IconData icon,
  required Widget content,
  List<Color>? iconBackgroundColor,
  List<Widget>? actions,
}) {
  final gradientColors = iconBackgroundColor ??
      const [
        Color(0xFF2E65FF),
        Color(0xFF8236FE),
      ];

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, anim, secondAnim, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
    pageBuilder: (ctx, anim, secondAnim) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                    maxWidth: 600,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(ctx).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.75),
                        Theme.of(ctx).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.white.withValues(alpha: 0.55),
                      ],
                    ),
                    border: Border.all(
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.9),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                        child: Row(
                          children: [
                            // Icon bubble
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: gradientColors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                icon,
                                color: Theme.of(ctx).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Title & subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      color: Theme.of(ctx).brightness == Brightness.dark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      color: Theme.of(ctx).brightness == Brightness.dark
                                          ? Colors.white.withValues(alpha: 0.6)
                                          : Colors.black87.withValues(alpha: 0.6),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Close button
                            GestureDetector(
                              onTap: () => Navigator.of(ctx).pop(),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(ctx).brightness == Brightness.dark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.black.withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: Theme.of(ctx).brightness == Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.black.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Theme.of(ctx).brightness == Brightness.dark
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : Colors.black87.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Content Area (Flexible and Scrollable)
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(20, 0, 20, actions != null ? 8 : 20),
                          child: content,
                        ),
                      ),
                      
                      if (actions != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: actions.expand((widget) => [widget, const SizedBox(width: 8)]).toList()..removeLast(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
