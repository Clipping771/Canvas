import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math' as math;

class TransformSelectionOverlay extends StatefulWidget {
  final Rect bounds;
  final TransformationController transformationController;
  final void Function(double dx, double dy, double scale, double rotation)
  onTransform;
  final VoidCallback onTransformEnd;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onDeselect;

  const TransformSelectionOverlay({
    super.key,
    required this.bounds,
    required this.transformationController,
    required this.onTransform,
    required this.onTransformEnd,
    required this.onDuplicate,
    required this.onDelete,
    required this.onDeselect,
  });

  @override
  State<TransformSelectionOverlay> createState() =>
      _TransformSelectionOverlayState();
}

class _TransformSelectionOverlayState extends State<TransformSelectionOverlay> {
  double _currentScale = 1.0;
  double _currentRotation = 0.0;
  Offset _currentTranslation = Offset.zero;

  Offset? _startDragPos;
  double? _startDragScale;
  double? _startDragRotation;
  Offset? _startDragTranslation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.transformationController,
      builder: (context, child) {
        final canvasScale = widget.transformationController.value
            .getMaxScaleOnAxis();
        // The inverse scale factor ensures that UI elements stay exactly the same
        // physical size on the screen, regardless of how much the canvas is zoomed.
        final inverseScale = 1.0 / canvasScale;

        final padding = 10.0 * inverseScale;
        final rect = widget.bounds.inflate(padding);

        final handleSize = 14.0 * inverseScale;
        final strokeWidth = 2.0 * inverseScale;

        return Positioned(
          left: rect.left - (handleSize * 2),
          top:
              rect.top -
              (60 *
                  inverseScale), // Extra space for rotation handle and toolbar
          width: rect.width + (handleSize * 4),
          height: rect.height + (handleSize * 4) + (60 * inverseScale),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Translation Area
              Positioned(
                left: handleSize * 2,
                top: 60 * inverseScale,
                width: rect.width,
                height: rect.height,
                child: GestureDetector(
                  onPanStart: (details) {
                    _startDragPos = details.globalPosition;
                    _startDragTranslation = _currentTranslation;
                  },
                  onPanUpdate: (details) {
                    if (_startDragPos != null) {
                      // Delta must be scaled down by the canvas scale so translation matches physical drag
                      final delta =
                          (details.globalPosition - _startDragPos!) *
                          inverseScale;
                      _currentTranslation = _startDragTranslation! + delta;
                      widget.onTransform(
                        _currentTranslation.dx,
                        _currentTranslation.dy,
                        _currentScale,
                        _currentRotation,
                      );
                    }
                  },
                  onPanEnd: (_) {
                    widget.onTransformEnd();
                    _resetTransform();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.blueAccent,
                        width: strokeWidth,
                        style: BorderStyle.solid,
                      ),
                      color: Colors.blueAccent.withOpacity(0.05),
                    ),
                  ),
                ),
              ),

              // Scale Handles
              ..._buildScaleHandles(rect, handleSize, inverseScale),

              // Rotation Handle (Top Center)
              Positioned(
                left: (rect.width / 2) + (handleSize * 2) - (handleSize / 2),
                top: (60 * inverseScale) - (30 * inverseScale),
                child: GestureDetector(
                  onPanStart: (details) {
                    _startDragPos = details.globalPosition;
                    _startDragRotation = _currentRotation;
                  },
                  onPanUpdate: (details) {
                    if (_startDragPos != null) {
                      final delta = details.globalPosition - _startDragPos!;
                      _currentRotation = _startDragRotation! + (delta.dx / 100);
                      widget.onTransform(
                        _currentTranslation.dx,
                        _currentTranslation.dy,
                        _currentScale,
                        _currentRotation,
                      );
                    }
                  },
                  onPanEnd: (_) {
                    widget.onTransformEnd();
                    _resetTransform();
                  },
                  child: Container(
                    width: handleSize * 1.5,
                    height: handleSize * 1.5,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.green,
                        width: strokeWidth,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4 * inverseScale,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.rotate_right,
                      size: handleSize,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),

              // Floating Action Toolbar (Above the rotation handle)
              Positioned(
                left: (rect.width / 2) + (handleSize * 2) - (60 * inverseScale),
                top: 0,
                child: Transform.scale(
                  scale: inverseScale,
                  alignment: Alignment.bottomCenter,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            CupertinoIcons.doc_on_doc,
                            color: Colors.black87,
                          ),
                          tooltip: 'Duplicate',
                          onPressed: widget.onDuplicate,
                          iconSize: 20,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          color: Colors.grey.shade300,
                        ),
                        IconButton(
                          icon: const Icon(
                            CupertinoIcons.trash,
                            color: Colors.redAccent,
                          ),
                          tooltip: 'Delete',
                          onPressed: widget.onDelete,
                          iconSize: 20,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _resetTransform() {
    setState(() {
      _currentScale = 1.0;
      _currentRotation = 0.0;
      _currentTranslation = Offset.zero;
      _startDragPos = null;
    });
  }

  List<Widget> _buildScaleHandles(Rect rect, double size, double inverseScale) {
    final top = 60 * inverseScale;
    final left = size * 2;

    return [
      _buildScaleHandle(
        left - (size / 2),
        top - (size / 2),
        rect,
        -1,
        -1,
        size,
        inverseScale,
      ), // Top Left
      _buildScaleHandle(
        left + rect.width - (size / 2),
        top - (size / 2),
        rect,
        1,
        -1,
        size,
        inverseScale,
      ), // Top Right
      _buildScaleHandle(
        left - (size / 2),
        top + rect.height - (size / 2),
        rect,
        -1,
        1,
        size,
        inverseScale,
      ), // Bottom Left
      _buildScaleHandle(
        left + rect.width - (size / 2),
        top + rect.height - (size / 2),
        rect,
        1,
        1,
        size,
        inverseScale,
      ), // Bottom Right
    ];
  }

  Widget _buildScaleHandle(
    double left,
    double top,
    Rect rect,
    double dirX,
    double dirY,
    double size,
    double inverseScale,
  ) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanStart: (details) {
          _startDragPos = details.globalPosition;
          _startDragScale = _currentScale;
        },
        onPanUpdate: (details) {
          if (_startDragPos != null) {
            // Delta needs to be converted back to logical space
            final delta =
                (details.globalPosition - _startDragPos!) * inverseScale;

            // Calculate proportional scale change based on diagonal movement
            final double baseSize = math.sqrt(
              rect.width * rect.width + rect.height * rect.height,
            );
            final double dragDist = delta.dx * dirX + delta.dy * dirY;

            _currentScale = _startDragScale! * (1 + (dragDist / baseSize) * 2);
            if (_currentScale < 0.1) _currentScale = 0.1;

            widget.onTransform(
              _currentTranslation.dx,
              _currentTranslation.dy,
              _currentScale,
              _currentRotation,
            );
          }
        },
        onPanEnd: (_) {
          widget.onTransformEnd();
          _resetTransform();
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.blueAccent,
              width: 2 * inverseScale,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 4 * inverseScale),
            ],
          ),
        ),
      ),
    );
  }
}
