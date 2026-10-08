import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

class VoiceInputButton extends StatefulWidget {
  const VoiceInputButton({
    super.key,
    required this.isListening,
    required this.onTap,
    required this.color,
    this.enabled = true,
  });

  final bool isListening;
  final VoidCallback onTap;
  final Color color;
  final bool enabled;

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isListening) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VoiceInputButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isListening && !oldWidget.isListening) {
      _pulseController.repeat();
    } else if (!widget.isListening && oldWidget.isListening) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.isListening && widget.enabled;

    return SizedBox(
      width: 52,
      height: 52,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final phase = _pulseController.value * math.pi * 2;
          final outerScale = 1 + math.sin(phase) * .08;
          final innerScale = 1 + math.sin(phase + math.pi) * .06;
          final glowOpacity = .08 + math.sin(phase) * .035;

          return Stack(
            alignment: Alignment.center,
            children: [
              if (active)
                Transform.scale(
                  scale: outerScale,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.color.withValues(alpha: .18),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              if (active)
                Transform.scale(
                  scale: innerScale,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withValues(
                        alpha: glowOpacity.clamp(.02, .12),
                      ),
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: active ? 42 : 36,
                height: active ? 42 : 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? widget.color.withValues(alpha: .14)
                      : Colors.transparent,
                  border: Border.all(
                    color: active
                        ? widget.color.withValues(alpha: .34)
                        : Colors.transparent,
                  ),
                ),
              ),
              IconButton(
                tooltip: active ? 'Detener y transcribir' : 'Hablar',
                onPressed: widget.enabled ? widget.onTap : null,
                splashRadius: 24,
                icon: const Icon(LucideIcons.mic, size: 21),
              ),
            ],
          );
        },
      ),
    );
  }
}
