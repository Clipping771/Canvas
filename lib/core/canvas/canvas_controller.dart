// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final canvasControllerProvider = Provider<CanvasController>((ref) {
  return CanvasController();
});

class CanvasController {
  final TransformationController _transformationController =
      TransformationController();

  // Expose for InteractiveViewer only internally if needed, but preferably InteractiveViewer gets it from here.
  TransformationController get transformationController =>
      _transformationController;

  CancelableOperation<void>? _cameraOperation;

  bool _isInteracting = false;

  void setInteracting(bool value) {
    _isInteracting = value;
    // We could trigger queued animations here if we implement a complex queue
  }

  Offset screenToWorld(Offset screenPos) {
    final Matrix4 transform = _transformationController.value;
    final Matrix4 inverseTransform = Matrix4.copy(transform)..invert();
    final Vector3 localVector = inverseTransform.perspectiveTransform(
      Vector3(screenPos.dx, screenPos.dy, 0),
    );
    return Offset(localVector.x, localVector.y);
  }

  Offset worldToScreen(Offset worldPos) {
    final Matrix4 transform = _transformationController.value;
    final Vector3 screenVector = transform.perspectiveTransform(
      Vector3(worldPos.dx, worldPos.dy, 0),
    );
    return Offset(screenVector.x, screenVector.y);
  }

  Rect getViewportRect(Size screenSize) {
    final topLeft = screenToWorld(Offset.zero);
    final bottomRight = screenToWorld(
      Offset(screenSize.width, screenSize.height),
    );
    return Rect.fromPoints(topLeft, bottomRight);
  }

  void animateTo(
    Offset targetWorldPos,
    Size screenSize, {
    required TickerProvider vsync,
  }) {
    // If user is panning/drawing, ideally queue or skip. For now, cancel old.
    if (_isInteracting) return;

    _cameraOperation?.cancel();

    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final targetScreenCenter = Offset(
      screenSize.width / 2,
      screenSize.height / 2,
    );

    // We want targetWorldPos to end up at targetScreenCenter.
    // T_new * targetWorldPos = targetScreenCenter
    // Translate = targetScreenCenter - targetWorldPos * scale

    final dx = targetScreenCenter.dx - targetWorldPos.dx * currentScale;
    final dy = targetScreenCenter.dy - targetWorldPos.dy * currentScale;

    final Matrix4 targetMatrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(currentScale);

    final currentMatrix = _transformationController.value;

    // Calculate distance for adaptive duration
    final currentCenterWorld = screenToWorld(targetScreenCenter);
    final distance = (currentCenterWorld - targetWorldPos).distance;

    Duration duration;
    if (distance < 500) {
      duration = const Duration(milliseconds: 180);
    } else if (distance < 1500)
      duration = const Duration(milliseconds: 280);
    else if (distance < 4000)
      duration = const Duration(milliseconds: 420);
    else
      duration = const Duration(milliseconds: 550);

    final AnimationController animationController = AnimationController(
      vsync: vsync,
      duration: duration,
    );

    final Animation<Matrix4> animation =
        Matrix4Tween(begin: currentMatrix, end: targetMatrix).animate(
          CurvedAnimation(
            parent: animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    animation.addListener(() {
      _transformationController.value = animation.value;
    });

    _cameraOperation = CancelableOperation.fromFuture(
      animationController.forward().then((_) {
        animationController.dispose();
      }),
      onCancel: () {
        animationController.dispose();
      },
    );
  }

  void dispose() {
    _cameraOperation?.cancel();
    _transformationController.dispose();
  }
}
