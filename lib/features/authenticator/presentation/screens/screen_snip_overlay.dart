import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A fullscreen overlay that shows a captured screenshot and lets the user
/// draw a rectangle selection (like Windows Snipping Tool).
/// Returns the selected region as a Rect (in image coordinates) when done.
class ScreenSnipOverlay extends StatefulWidget {
  final File screenshotFile;

  const ScreenSnipOverlay({super.key, required this.screenshotFile});

  @override
  State<ScreenSnipOverlay> createState() => _ScreenSnipOverlayState();
}

class _ScreenSnipOverlayState extends State<ScreenSnipOverlay>
    with SingleTickerProviderStateMixin {
  ui.Image? _image;
  Offset? _startPoint;
  Offset? _currentPoint;
  bool _isDragging = false;
  bool _isLoading = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _loadImage();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.screenshotFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _image = frame.image;
        _isLoading = false;
      });
    }
  }

  Rect? get _selectionRect {
    if (_startPoint == null || _currentPoint == null) return null;
    return Rect.fromPoints(_startPoint!, _currentPoint!);
  }

  /// Convert screen-space rect to image-space rect
  Rect _toImageRect(Rect screenRect, Size displaySize) {
    if (_image == null) return screenRect;
    final scaleX = _image!.width / displaySize.width;
    final scaleY = _image!.height / displaySize.height;
    return Rect.fromLTRB(
      (screenRect.left * scaleX).roundToDouble(),
      (screenRect.top * scaleY).roundToDouble(),
      (screenRect.right * scaleX).roundToDouble(),
      (screenRect.bottom * scaleY).roundToDouble(),
    );
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _startPoint = details.localPosition;
      _currentPoint = details.localPosition;
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPoint = details.localPosition;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_selectionRect != null && _selectionRect!.width > 10 && _selectionRect!.height > 10) {
      final displaySize = MediaQuery.of(context).size;
      final imageRect = _toImageRect(_selectionRect!, displaySize);
      Navigator.of(context).pop(imageRect);
    } else {
      setState(() {
        _startPoint = null;
        _currentPoint = null;
        _isDragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _image == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Loading screenshot...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Screenshot as background
            RawImage(
              image: _image,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),

            // Dark overlay with selection cutout
            CustomPaint(
              painter: _SnipOverlayPainter(
                selectionRect: _selectionRect,
              ),
              size: Size.infinite,
            ),

            // Instruction banner at top
            if (!_isDragging)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.85),
                            Colors.black.withValues(alpha: 0.6 + _pulseController.value * 0.15),
                          ],
                        ),
                      ),
                      child: const SafeArea(
                        bottom: false,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.crop_free_rounded, color: Colors.white, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Draw a rectangle around the QR code to scan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Cancel button
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ),
              ),
            ),

            // Selection size indicator
            if (_selectionRect != null && _selectionRect!.width > 30 && _selectionRect!.height > 30)
              Positioned(
                left: _selectionRect!.center.dx - 40,
                top: _selectionRect!.bottom + 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_selectionRect!.width.toInt()} × ${_selectionRect!.height.toInt()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Paints the dark overlay with the selection rectangle cut out
class _SnipOverlayPainter extends CustomPainter {
  final Rect? selectionRect;

  _SnipOverlayPainter({this.selectionRect});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);

    if (selectionRect == null) {
      // No selection — draw full overlay
      canvas.drawRect(Offset.zero & size, overlayPaint);
    } else {
      // Draw overlay around the selection (hollow out the selection area)
      final rect = selectionRect!;

      // Top
      canvas.drawRect(Rect.fromLTRB(0, 0, size.width, rect.top), overlayPaint);
      // Bottom
      canvas.drawRect(Rect.fromLTRB(0, rect.bottom, size.width, size.height), overlayPaint);
      // Left
      canvas.drawRect(Rect.fromLTRB(0, rect.top, rect.left, rect.bottom), overlayPaint);
      // Right
      canvas.drawRect(Rect.fromLTRB(rect.right, rect.top, size.width, rect.bottom), overlayPaint);

      // Selection border
      final borderPaint = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawRect(rect, borderPaint);

      // Corner handles
      const handleSize = 10.0;
      final handlePaint = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.fill;

      // Top-left
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: rect.topLeft, width: handleSize, height: handleSize),
          const Radius.circular(2),
        ),
        handlePaint,
      );
      // Top-right
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: rect.topRight, width: handleSize, height: handleSize),
          const Radius.circular(2),
        ),
        handlePaint,
      );
      // Bottom-left
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: rect.bottomLeft, width: handleSize, height: handleSize),
          const Radius.circular(2),
        ),
        handlePaint,
      );
      // Bottom-right
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: rect.bottomRight, width: handleSize, height: handleSize),
          const Radius.circular(2),
        ),
        handlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SnipOverlayPainter oldDelegate) {
    return oldDelegate.selectionRect != selectionRect;
  }
}
