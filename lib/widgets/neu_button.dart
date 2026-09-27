import 'package:flutter/material.dart';

/// Neumorphic Button inspired by Uiverse.io by adamgiebl.
///
/// Features:
/// - Inset dual shadows (inner dark shadow on top-left, inner light highlight on bottom-right)
/// - Outer dual shadows on hover / focus
/// - Smooth 0.2s ease-in-out transition
/// - Adaptive light & dark mode support
class NeuButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final String label;
  final double height;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double fontSize;

  const NeuButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.height = 44,
    this.padding,
    this.borderRadius = 50,
    this.fontSize = 14,
  });

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Palette strictly matching Uiverse.io (#e0e0e0, #bcbcbc, #ffffff, #4d4d4d, #cecece)
    final backgroundColor = isDark ? const Color(0xFF222630) : const Color(0xFFE0E0E0);
    final borderColor = isDark ? const Color(0xFF353B49) : const Color(0xFFCECECE);
    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF4D4D4D);
    final darkShadowColor = isDark
        ? const Color(0xFF12141A).withValues(alpha: 0.95)
        : const Color(0xFFBCBCBC);
    final lightShadowColor = isDark
        ? const Color(0xFF383F50).withValues(alpha: 0.7)
        : const Color(0xFFFFFFFF);

    final activeState = _isHovered || _isPressed;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: widget.height,
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: activeState
                ? [
                    BoxShadow(
                      color: darkShadowColor.withValues(alpha: isDark ? 0.7 : 0.85),
                      offset: const Offset(2, 2),
                      blurRadius: 5,
                    ),
                    BoxShadow(
                      color: lightShadowColor.withValues(alpha: isDark ? 0.4 : 0.95),
                      offset: const Offset(-2, -2),
                      blurRadius: 5,
                    ),
                  ]
                : const [],
          ),
          child: CustomPaint(
            painter: _NeuInsetShadowPainter(
              borderRadius: widget.borderRadius > 2 ? widget.borderRadius - 2 : widget.borderRadius,
              isHovered: _isHovered,
              isPressed: _isPressed,
              isDark: isDark,
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    IconTheme(
                      data: IconThemeData(
                        color: textColor,
                        size: widget.fontSize + 4,
                      ),
                      child: widget.icon!,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NeuInsetShadowPainter extends CustomPainter {
  final double borderRadius;
  final bool isHovered;
  final bool isPressed;
  final bool isDark;

  _NeuInsetShadowPainter({
    required this.borderRadius,
    required this.isHovered,
    required this.isPressed,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final darkShadowColor = isDark
        ? const Color(0xFF12141A).withValues(alpha: 0.95)
        : const Color(0xFFBCBCBC);
    final lightShadowColor = isDark
        ? const Color(0xFF383F50).withValues(alpha: 0.7)
        : const Color(0xFFFFFFFF);

    final double blur = (isHovered || isPressed) ? 5.0 : 10.0;
    final double offset = (isHovered || isPressed) ? 2.0 : 4.0;

    canvas.save();
    canvas.clipRRect(rrect);

    // 1. Inset Dark Shadow (top-left: hole shifted down-right by (offset, offset))
    final darkPaint = Paint()
      ..color = darkShadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    final darkHole = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(blur * 3))
      ..addRRect(rrect.shift(Offset(offset, offset)));
    canvas.drawPath(darkHole, darkPaint);

    // 2. Inset Light Shadow (bottom-right: hole shifted up-left by (-offset, -offset))
    final lightPaint = Paint()
      ..color = lightShadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    final lightHole = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(blur * 3))
      ..addRRect(rrect.shift(Offset(-offset, -offset)));
    canvas.drawPath(lightHole, lightPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NeuInsetShadowPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.isHovered != isHovered ||
        oldDelegate.isPressed != isPressed ||
        oldDelegate.isDark != isDark;
  }
}
