import 'package:flutter/material.dart';

/// Shared skeleton loader. Page-sized constraints render content placeholders;
/// fixed compact constraints render a shimmer block for buttons and controls.
class NumiLoadingAnimation extends StatefulWidget {
  const NumiLoadingAnimation({super.key, this.size = 48});
  final double size;

  @override
  State<NumiLoadingAnimation> createState() => _NumiLoadingAnimationState();
}

class _NumiLoadingAnimationState extends State<NumiLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = colors.surfaceContainerHighest.withValues(alpha: 0.72);
    final highlight = colors.surface.withValues(alpha: 0.96);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final height = constraints.maxHeight;
        final pageSized = width >= 260 && (!height.isFinite || height >= 220);
        final child = pageSized
            ? _pageSkeleton(width, base)
            : SizedBox(
                width: constraints.hasBoundedWidth ? constraints.maxWidth : widget.size,
                height: constraints.hasBoundedHeight ? constraints.maxHeight : widget.size,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(widget.size <= 24 ? 7 : 12),
                  ),
                ),
              );

        return AnimatedBuilder(
          animation: _controller,
          child: child,
          builder: (context, child) => ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment(-1.5 + 3 * _controller.value, 0),
              end: Alignment(-0.5 + 3 * _controller.value, 0),
              colors: [base, highlight, base],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(bounds),
            child: child,
          ),
        );
      },
    );
  }

  Widget _pageSkeleton(double width, Color base) {
    final contentWidth = width.clamp(260.0, 720.0).toDouble();
    Widget block(double w, double h, {double radius = 7}) => SizedBox(
      width: w,
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(radius)),
      ),
    );

    return Center(
      child: SizedBox(
        width: contentWidth,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                block(42, 42, radius: 14),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  block(contentWidth * 0.42, 12),
                  const SizedBox(height: 8),
                  block(contentWidth * 0.27, 9),
                ])),
                block(30, 30, radius: 10),
              ]),
              const SizedBox(height: 24),
              block(contentWidth * 0.48, 16),
              const SizedBox(height: 10),
              block(contentWidth * 0.72, 10),
              const SizedBox(height: 20),
              for (var index = 0; index < 3; index++) ...[
                Container(
                  height: 66,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(15)),
                  child: Row(children: [
                    block(38, 38, radius: 11),
                    const SizedBox(width: 12),
                    Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      block(contentWidth * 0.42, 10),
                      const SizedBox(height: 8),
                      block(contentWidth * (index == 1 ? 0.29 : 0.52), 8),
                    ])),
                  ]),
                ),
                const SizedBox(height: 11),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
