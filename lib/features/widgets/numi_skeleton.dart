import 'package:flutter/material.dart';

/// Skeletons that mirror the layout of the screen being loaded.
/// They are placeholders only: no network requests or business logic run here.
enum NumiSkeletonKind {
  splash,
  homeHistory,
  chatMessages,
  projects,
  files,
  artifacts,
  connectors,
  settings,
  profile,
  notifications,
  memories,
  searchResults,
  credits,
  plans,
  coderPreview,
  imagePreview,
}

class NumiSkeleton extends StatefulWidget {
  const NumiSkeleton({
    super.key,
    required this.kind,
    this.dense = false,
    this.itemCount = 4,
  });

  final NumiSkeletonKind kind;
  final bool dense;
  final int itemCount;

  @override
  State<NumiSkeleton> createState() => _NumiSkeletonState();
}

class _NumiSkeletonState extends State<NumiSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest.withValues(alpha: 0.76);
    final panel = scheme.surfaceContainerHighest.withValues(alpha: 0.26);
    final highlight = Color.alphaBlend(
      scheme.surface.withValues(alpha: 0.86),
      scheme.surfaceContainerHighest,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(220.0, 760.0).toDouble()
            : MediaQuery.sizeOf(context).width.clamp(220.0, 760.0).toDouble();
        final content = _buildLayout(width, base, panel);
        return AnimatedBuilder(
          animation: _controller,
          child: content,
          builder: (context, child) {
            final shift = -1.5 + (_controller.value * 3.0);
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(shift, 0),
                end: Alignment(shift + 1.15, 0),
                colors: [base, highlight, base],
                stops: const [0.22, 0.5, 0.78],
              ).createShader(bounds),
              child: child,
            );
          },
        );
      },
    );
  }

  Widget _buildLayout(double width, Color base, Color panel) {
    final pad = widget.dense ? 8.0 : 16.0;
    final gap = widget.dense ? 8.0 : 13.0;
    switch (widget.kind) {
      case NumiSkeletonKind.splash:
        return Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _box(64, 64, base, radius: 20),
              const SizedBox(height: 18),
              _box(width * 0.42, 13, base),
              const SizedBox(height: 10),
              _box(width * 0.27, 9, base),
            ],
          ),
        );
      case NumiSkeletonKind.homeHistory:
        return _padded(
          pad,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _box(width * 0.38, 13, base),
              SizedBox(height: gap),
              for (var i = 0; i < widget.itemCount; i++)
                _fileRow(width, base, dense: true),
            ],
          ),
        );
      case NumiSkeletonKind.chatMessages:
        return _padded(
          pad,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _message(width, base, fromUser: false),
              _message(width, base, fromUser: true),
              _message(width, base, fromUser: false),
              _message(width, base, fromUser: true),
              _message(width, base, fromUser: false),
            ],
          ),
        );
      case NumiSkeletonKind.projects:
        return _padded(
          pad,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _box(width * 0.32, 15, base),
                  const Spacer(),
                  _box(34, 34, base, radius: 12),
                ],
              ),
              SizedBox(height: gap),
              for (var i = 0; i < widget.itemCount; i++)
                _projectCard(width, base, panel),
            ],
          ),
        );
      case NumiSkeletonKind.files:
      case NumiSkeletonKind.searchResults:
        return _padded(
          pad,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.dense) _box(width * 0.4, 14, base),
              SizedBox(height: gap),
              for (
                var i = 0;
                i < (widget.dense ? 3 : widget.itemCount + 1);
                i++
              )
                _fileRow(width, base, dense: widget.dense),
            ],
          ),
        );
      case NumiSkeletonKind.artifacts:
        return _padded(
          pad,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _box(width * 0.36, 15, base),
              SizedBox(height: gap),
              for (var i = 0; i < widget.itemCount; i++)
                _artifactCard(width, base, panel),
            ],
          ),
        );
      case NumiSkeletonKind.connectors:
        return _padded(
          pad,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _box(width * 0.42, 15, base),
              SizedBox(height: gap),
              for (var i = 0; i < widget.itemCount; i++)
                _connectorCard(width, base, panel),
            ],
          ),
        );
      case NumiSkeletonKind.settings:
      case NumiSkeletonKind.notifications:
      case NumiSkeletonKind.memories:
        return _padded(
          pad,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _box(width * 0.34, 15, base),
              SizedBox(height: gap),
              for (var i = 0; i < widget.itemCount; i++)
                _settingsRow(width, base),
            ],
          ),
        );
      case NumiSkeletonKind.profile:
        return _padded(
          pad,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _circle(74, base),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _box(width * 0.34, 13, base),
                        const SizedBox(height: 9),
                        _box(width * 0.38, 9, base),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: gap * 2),
              for (var i = 0; i < 4; i++) _formField(width, base),
            ],
          ),
        );
      case NumiSkeletonKind.credits:
        return _padded(
          pad,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _box(width * 0.32, 12, base),
              const SizedBox(height: 10),
              _box(width * 0.56, 28, base),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _box(double.infinity, 38, base, radius: 12)),
                  const SizedBox(width: 9),
                  Expanded(child: _box(double.infinity, 38, base, radius: 12)),
                ],
              ),
            ],
          ),
        );
      case NumiSkeletonKind.plans:
        return _padded(
          pad,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _box(width * 0.42, 19, base),
              const SizedBox(height: 10),
              _box(width * 0.74, 10, base),
              SizedBox(height: gap * 1.5),
              for (var i = 0; i < 3; i++) _planCard(width, base, panel),
            ],
          ),
        );
      case NumiSkeletonKind.coderPreview:
        return _padded(
          pad,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _box(28, 28, base, radius: 8),
                  const SizedBox(width: 9),
                  _box(width * 0.36, 10, base),
                  const Spacer(),
                  _box(58, 25, base, radius: 8),
                ],
              ),
              SizedBox(height: gap),
              Container(
                height: 220,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(width * 0.24, 10, base),
                    const SizedBox(height: 15),
                    _box(width * 0.72, 9, base),
                    const SizedBox(height: 10),
                    _box(width * 0.54, 9, base),
                    const SizedBox(height: 10),
                    _box(width * 0.64, 9, base),
                    const Spacer(),
                    _box(width * 0.3, 25, base, radius: 8),
                  ],
                ),
              ),
            ],
          ),
        );
      case NumiSkeletonKind.imagePreview:
        return _padded(
          pad,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _box(width * 0.34, 9, base),
                  const Spacer(),
                  _box(48, 9, base),
                ],
              ),
            ],
          ),
        );
    }
  }

  Widget _padded(double padding, Widget child) => Padding(
    padding: EdgeInsets.all(padding),
    child: SizedBox(width: double.infinity, child: child),
  );

  Widget _box(double width, double height, Color color, {double radius = 7}) =>
      SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );

  Widget _circle(double size, Color color) => SizedBox(
    width: size,
    height: size,
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );

  Widget _projectCard(double width, Color base, Color panel) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        _box(40, 40, base, radius: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _box(width * 0.42, 10, base),
              const SizedBox(height: 8),
              _box(width * 0.27, 8, base),
            ],
          ),
        ),
        _circle(22, base),
      ],
    ),
  );

  Widget _fileRow(double width, Color base, {required bool dense}) => Padding(
    padding: EdgeInsets.symmetric(vertical: dense ? 5 : 8),
    child: Row(
      children: [
        _box(dense ? 17 : 22, dense ? 17 : 22, base, radius: 5),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _box(width * (dense ? 0.43 : 0.53), dense ? 8 : 10, base),
              if (!dense) ...[
                const SizedBox(height: 6),
                _box(width * 0.29, 7, base),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _artifactCard(double width, Color base, Color panel) => Container(
    margin: const EdgeInsets.only(bottom: 11),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _box(width * 0.27, 10, base),
        const SizedBox(height: 10),
        _box(width * 0.72, 9, base),
        const SizedBox(height: 7),
        _box(width * 0.38, 9, base),
      ],
    ),
  );

  Widget _connectorCard(double width, Color base, Color panel) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        _box(40, 40, base, radius: 11),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _box(width * 0.34, 10, base),
              const SizedBox(height: 8),
              _box(width * 0.3, 8, base),
            ],
          ),
        ),
        _box(65, 28, base, radius: 9),
      ],
    ),
  );

  Widget _settingsRow(double width, Color base) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        _box(34, 34, base, radius: 10),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _box(width * 0.42, 10, base),
              const SizedBox(height: 7),
              _box(width * 0.42, 8, base),
            ],
          ),
        ),
        _circle(17, base),
      ],
    ),
  );

  Widget _formField(double width, Color base) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _box(width * 0.22, 9, base),
        const SizedBox(height: 8),
        _box(double.infinity, 47, base, radius: 12),
      ],
    ),
  );

  Widget _planCard(double width, Color base, Color panel) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _box(width * 0.32, 12, base),
        const SizedBox(height: 12),
        _box(width * 0.45, 23, base),
        const SizedBox(height: 12),
        _box(width * 0.77, 8, base),
        const SizedBox(height: 8),
        _box(width * 0.59, 8, base),
        const SizedBox(height: 15),
        _box(double.infinity, 38, base, radius: 10),
      ],
    ),
  );

  Widget _message(double width, Color base, {required bool fromUser}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          mainAxisAlignment: fromUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!fromUser) ...[_circle(28, base), const SizedBox(width: 9)],
            Container(
              width: width * (fromUser ? 0.62 : 0.62),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(width * 0.48, 8, base.withValues(alpha: 0.72)),
                  const SizedBox(height: 8),
                  _box(width * 0.61, 8, base.withValues(alpha: 0.72)),
                  if (!fromUser) ...[
                    const SizedBox(height: 8),
                    _box(width * 0.37, 8, base.withValues(alpha: 0.72)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}
