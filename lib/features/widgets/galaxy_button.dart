import 'dart:math' as math;

import 'package:flutter/material.dart';

class GalaxyButton extends StatefulWidget {
  const GalaxyButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
    this.minHeight = 52,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final double minHeight;

  @override
  State<GalaxyButton> createState() => _GalaxyButtonState();
}

class _GalaxyButtonState extends State<GalaxyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation;
  bool _hovered = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;
    final enabled = widget.onPressed != null;
    final active = enabled && (_hovered || _pressed);

    return Semantics(
      button: true,
      enabled: enabled,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: enabled
              ? () {
                  Feedback.forTap(context);
                  widget.onPressed!();
                }
              : null,
          child: AnimatedScale(
            scale: _pressed ? 0.985 : 1,
            duration: const Duration(milliseconds: 120),
            child: AnimatedBuilder(
              animation: _rotation,
              builder: (context, _) {
                return CustomPaint(
                  painter: _GalaxyBorderPainter(
                    progress: _rotation.value,
                    color: accent,
                    radius: widget.borderRadius.topLeft,
                    active: active,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    constraints: BoxConstraints(minHeight: widget.minHeight),
                    padding: widget.padding,
                    decoration: BoxDecoration(
                      borderRadius: widget.borderRadius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          surface,
                          Color.lerp(surface, accent, active ? 0.16 : 0.045)!,
                        ],
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.22),
                                blurRadius: 22,
                                spreadRadius: 1,
                              ),
                            ]
                          : const [],
                    ),
                    child: Center(
                      child: Opacity(
                        opacity: enabled ? 1 : 0.48,
                        child: widget.child,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GalaxyBorderPainter extends CustomPainter {
  const _GalaxyBorderPainter({
    required this.progress,
    required this.color,
    required this.radius,
    required this.active,
  });

  final double progress;
  final Color color;
  final Radius radius;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final borderRect = rect.deflate(0.8);
    final rrect = RRect.fromRectAndRadius(
      borderRect,
      Radius.circular(radius.x),
    );

    final spark = color.withValues(alpha: active ? 0.98 : 0.48);
    final shader = SweepGradient(
      transform: GradientRotation(progress * math.pi * 2),
      colors: [
        color.withValues(alpha: 0.10),
        spark,
        color.withValues(alpha: 0.14),
        color.withValues(alpha: 0.10),
      ],
      stops: const [0.0, 0.42, 0.53, 1.0],
    ).createShader(rect);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 1.5 : 1.0
      ..shader = shader;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GalaxyBorderPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        radius != oldDelegate.radius ||
        active != oldDelegate.active;
  }
}
