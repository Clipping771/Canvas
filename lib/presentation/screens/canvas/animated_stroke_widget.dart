// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:vinci_board/core/models/stroke.dart';

class AnimatedStrokeWidget extends StatelessWidget {
  final Stroke stroke;
  final Animation<double> animation;
  final Widget child;

  const AnimatedStrokeWidget({
    super.key,
    required this.stroke,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (stroke.animationType == null) return child;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, childWidget) {
        double t = animation.value;
        if (stroke.animationProgress != null &&
            stroke.animationProgress! > 1000) {
          final elapsedMs =
              DateTime.now().millisecondsSinceEpoch - stroke.animationProgress!;
          t = (elapsedMs % 2000) / 2000.0;
        }

        Matrix4 transform = Matrix4.identity();
        double opacity = 1.0;

        switch (stroke.animationType) {
          case 'pulse':
            final scale = 1.0 + 0.15 * math.sin(t * 2 * math.pi);
            // We need to scale from center. But since we are transforming the widget,
            // we should set the alignment in Transform.
            transform.scale(scale, scale);
            break;
          case 'bounce':
            final yOffset = -30.0 * math.sin(t * math.pi).abs();
            transform.translate(0.0, yOffset);
            break;
          case 'spin':
            transform.rotateZ(t * 2 * math.pi);
            break;
          case 'slide':
            final xOffset = 30.0 * math.sin(t * 2 * math.pi);
            transform.translate(xOffset, 0.0);
            break;
          case 'shake':
            final shakeOffset = 10.0 * math.sin(t * 8 * math.pi);
            transform.translate(shakeOffset, 0.0);
            break;
          case 'fade':
            opacity = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
            break;
        }

        Widget result = childWidget!;

        if (opacity < 1.0) {
          result = Opacity(opacity: opacity, child: result);
        }

        return Transform(
          transform: transform,
          alignment: Alignment.center,
          child: result,
        );
      },
      child: child,
    );
  }
}
