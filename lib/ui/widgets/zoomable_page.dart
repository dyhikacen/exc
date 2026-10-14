import 'dart:io';
import 'package:flutter/material.dart';

/// A single comic page widget that supports pinch-to-zoom and double-tap zoom
/// using Flutter's native [InteractiveViewer].
class ZoomablePage extends StatefulWidget {
  final String imagePath;
  final VoidCallback onTap;
  final ValueChanged<bool>? onZoomChanged;

  const ZoomablePage({
    super.key,
    required this.imagePath,
    required this.onTap,
    this.onZoomChanged,
  });

  @override
  State<ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<ZoomablePage>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomedNow = scale > 1.05;
    if (_isZoomed != isZoomedNow) {
      _isZoomed = isZoomedNow;
      widget.onZoomChanged?.call(_isZoomed);
    }
  }

  void _handleDoubleTap() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final Matrix4 endMatrix;

    if (currentScale > 1.05) {
      // Zoom out to normal
      endMatrix = Matrix4.identity();
    } else {
      // Zoom in 2.5x around the tapped position
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      final tx = -position.dx * 1.5;
      final ty = -position.dy * 1.5;
      endMatrix = Matrix4(
        2.5, 0.0, 0.0, 0.0,
        0.0, 2.5, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        tx, ty, 0.0, 1.0,
      );
    }

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward(from: 0);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 4.0,
        clipBehavior: Clip.none,
        child: Center(
          child: Image.file(
            File(widget.imagePath),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
