import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import '../services/db_service.dart';
import '../services/discrete_db_service.dart';
import '../services/continuous_db_service.dart';

/// Wraps any child and lets the user paint multiple free-hand
/// polygons over it — but *only* when [enabled] is true.
/// Each time the finger lifts it calls [onComplete] with that
/// single polygon converted to image coordinates.
class RegionSelector extends StatefulWidget {
  final Widget child;
  final void Function(List<Offset>) onComplete;
  final VoidCallback? onOverlapDetected;
  final double samplingTolerance;
  final bool enabled;
  final String? imagePath; // Add this to get image dimensions
  final String doctorName;
  final String fileName;
  final int iteration;
  final String mode; // 'discrete' or 'continuous'
  final String sessionId;

  const RegionSelector({
    super.key,
    required this.child,
    required this.onComplete,
    this.onOverlapDetected,
    this.samplingTolerance = 4.0,
    this.enabled = true,
    this.imagePath,
    required this.doctorName,
    required this.fileName,
    required this.iteration,
    this.mode = 'discrete',
    required this.sessionId,
  });

  @override
  RegionSelectorState createState() => RegionSelectorState();
}

/// Public state, so parent can do:
///    _regionKey.currentState?.clearSelection();
///    _regionKey.currentState?.undoLastStroke();
class RegionSelectorState extends State<RegionSelector> {
  /// All the finished strokes in image coordinates (for overlap detection and display)
  final List<List<Offset>> _imageStrokes = [];

  /// The stroke currently being drawn (in screen coordinates)
  List<Offset> _current = [];

  /// Image dimensions for coordinate conversion
  Size? _imageSize;
  Size? _displaySize;
  Rect? _imageRect;

  // Add flag to prevent repeated SnackBars
  bool _hasShownOutOfBoundsWarning = false;

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();
  }

  /// Load image dimensions for coordinate conversion
  Future<void> _loadImageDimensions() async {
    if (widget.imagePath != null) {
      try {
        final data = await DefaultAssetBundle.of(
          context,
        ).load(widget.imagePath!);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        setState(() {
          _imageSize = Size(
            frame.image.width.toDouble(),
            frame.image.height.toDouble(),
          );
        });
      } catch (e) {
        print('Error loading image dimensions: $e');
      }
    }
  }

  /// Load existing regions from database
  /// This method expects RegionSelection objects from the database service
  void loadExistingRegions(List<dynamic> regions) {
    _imageStrokes.clear();
    for (final region in regions) {
      try {
        final pathJson = region.pathJson as String;
        final List<dynamic> jsonData = jsonDecode(pathJson);
        final List<Offset> imagePoints = jsonData
            .map(
              (point) => Offset(point['x'].toDouble(), point['y'].toDouble()),
            )
            .toList();
        _imageStrokes.add(imagePoints);
      } catch (e) {
        print('Error loading region: $e');
      }
    }
    setState(() {});
  }

  /// Call this to wipe everything out
  void clearSelection() {
    setState(() {
      _imageStrokes.clear();
      _current.clear();
    });
  }

  /// Undo the last drawn stroke
  bool undoLastStroke() {
    if (_imageStrokes.isEmpty) {
      return false;
    }
    setState(() {
      _imageStrokes.removeLast();
    });
    // Also delete from the correct database
    if (widget.mode == 'continuous') {
      ContinuousDbService.deleteLastRegion(
        doctorName: widget.doctorName,
        fileName: widget.fileName,
        iteration: widget.iteration,
        sessionId: widget.sessionId,
      );
    } else {
      DiscreteDbService.deleteLastRegion(
        doctorName: widget.doctorName,
        fileName: widget.fileName,
        iteration: widget.iteration,
        sessionId: widget.sessionId,
      );
    }
    return true;
  }

  /// Get the number of strokes
  int get strokeCount => _imageStrokes.length;

  /// Convert screen coordinates to image coordinates
  List<Offset> _convertToImageCoordinates(List<Offset> screenPoints) {
    if (_imageSize == null || _displaySize == null || _imageRect == null) {
      return screenPoints;
    }
    return screenPoints.map((point) {
      final relativeX = (point.dx - _imageRect!.left) / _imageRect!.width;
      final relativeY = (point.dy - _imageRect!.top) / _imageRect!.height;
      return Offset(
        relativeX * _imageSize!.width,
        relativeY * _imageSize!.height,
      );
    }).toList();
  }

  /// Convert image coordinates to screen coordinates
  List<Offset> _convertToScreenCoordinates(List<Offset> imagePoints) {
    if (_imageSize == null || _displaySize == null || _imageRect == null) {
      return imagePoints;
    }
    return imagePoints.map((point) {
      final relativeX = point.dx / _imageSize!.width;
      final relativeY = point.dy / _imageSize!.height;
      return Offset(
        _imageRect!.left + (relativeX * _imageRect!.width),
        _imageRect!.top + (relativeY * _imageRect!.height),
      );
    }).toList();
  }

  /// Check if a polygon overlaps with any existing polygons
  bool _checkOverlap(List<Offset> newPolygon) {
    if (_imageStrokes.isEmpty || newPolygon.length < 3) {
      return false;
    }
    for (final existingPolygon in _imageStrokes) {
      if (existingPolygon.length < 3) continue;
      for (final point in newPolygon) {
        if (_isPointInPolygon(point, existingPolygon)) {
          return true;
        }
      }
      for (final point in existingPolygon) {
        if (_isPointInPolygon(point, newPolygon)) {
          return true;
        }
      }
      if (_doPolygonsIntersect(newPolygon, existingPolygon)) {
        return true;
      }
    }
    return false;
  }

  /// Check if a point is inside a polygon using ray casting algorithm
  bool _isPointInPolygon(Offset point, List<Offset> polygon) {
    if (polygon.length < 3) return false;

    int intersections = 0;
    for (int i = 0; i < polygon.length; i++) {
      final j = (i + 1) % polygon.length;
      final p1 = polygon[i];
      final p2 = polygon[j];

      if (((p1.dy > point.dy) != (p2.dy > point.dy)) &&
          (point.dx <
              (p2.dx - p1.dx) * (point.dy - p1.dy) / (p2.dy - p1.dy) + p1.dx)) {
        intersections++;
      }
    }

    return intersections % 2 == 1;
  }

  /// Check if two polygons intersect by checking edge intersections
  bool _doPolygonsIntersect(List<Offset> poly1, List<Offset> poly2) {
    for (int i = 0; i < poly1.length; i++) {
      final a1 = poly1[i];
      final a2 = poly1[(i + 1) % poly1.length];

      for (int j = 0; j < poly2.length; j++) {
        final b1 = poly2[j];
        final b2 = poly2[(j + 1) % poly2.length];

        if (_doLinesIntersect(a1, a2, b1, b2)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Check if two line segments intersect
  bool _doLinesIntersect(Offset a1, Offset a2, Offset b1, Offset b2) {
    final denom =
        (b2.dy - b1.dy) * (a2.dx - a1.dx) - (b2.dx - b1.dx) * (a2.dy - a1.dy);
    if (denom == 0) return false; // Lines are parallel

    final ua =
        ((b2.dx - b1.dx) * (a1.dy - b1.dy) -
            (b2.dy - b1.dy) * (a1.dx - b1.dx)) /
        denom;
    final ub =
        ((a2.dx - a1.dx) * (a1.dy - b1.dy) -
            (a2.dy - a1.dy) * (a1.dx - b1.dx)) /
        denom;

    return ua >= 0 && ua <= 1 && ub >= 0 && ub <= 1;
  }

  void _handlePanStart(DragStartDetails details) {
    _current = [];
    // Reset out-of-bounds warning flag
    _hasShownOutOfBoundsWarning = false;
    setState(() {});
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final p = details.localPosition;
    // Only allow drawing inside the image rect
    if (_imageRect != null && !_imageRect!.contains(p)) {
      // Show warning SnackBar (same style as overlap), only once per stroke
      if (!_hasShownOutOfBoundsWarning) {
        _hasShownOutOfBoundsWarning = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot select outside the image. Please select a region within the image.',
            ),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    if (_current.isEmpty ||
        (p - _current.last).distance > widget.samplingTolerance) {
      setState(() => _current.add(p));
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_current.isNotEmpty && _current.length > 2) {
      final imageCoordinates = _convertToImageCoordinates(_current);
      if (_checkOverlap(imageCoordinates)) {
        setState(() {
          _current.clear();
        });
        widget.onOverlapDetected?.call();
        return;
      }
      _imageStrokes.add(imageCoordinates);
      widget.onComplete(imageCoordinates);
      _current = [];
      setState(() {});
    } else {
      setState(() {
        _current.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _displaySize = Size(constraints.maxWidth, constraints.maxHeight);
        if (_imageSize != null && _displaySize != null) {
          final fitted = applyBoxFit(
            BoxFit.contain,
            _imageSize!,
            _displaySize!,
          );
          _imageRect = Alignment.center.inscribe(
            fitted.destination,
            Offset.zero & _displaySize!,
          );
        }
        // Convert all image strokes to screen coordinates for display
        final displayStrokes = _imageStrokes
            .map(_convertToScreenCoordinates)
            .toList();
        return GestureDetector(
          onPanStart: widget.enabled ? _handlePanStart : null,
          onPanUpdate: widget.enabled ? _handlePanUpdate : null,
          onPanEnd: widget.enabled ? _handlePanEnd : null,
          child: Stack(
            children: [
              Positioned.fill(child: widget.child),
              if (widget.enabled) ...[
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MultiStrokePainter(displayStrokes),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: _SingleStrokePainter(_current)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Painter for a single stroke (filled + outline)
class _SingleStrokePainter extends CustomPainter {
  final List<Offset> points;
  final Paint _fill = Paint()
    ..style = PaintingStyle.fill
    ..color = Colors.red.withValues(alpha: 0.2);
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = Colors.red.withValues(alpha: 0.7);

  _SingleStrokePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    if (points.length > 2) {
      path.close();
      canvas.drawPath(path, _fill);
    }
    canvas.drawPath(path, _stroke);
  }

  @override
  bool shouldRepaint(covariant _SingleStrokePainter old) =>
      !listEquals(old.points, points);
}

/// Painter for multiple finished strokes
class _MultiStrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Paint _fill = Paint()
    ..style = PaintingStyle.fill
    ..color = Colors.red.withValues(alpha: 0.2);
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = Colors.red.withValues(alpha: 0.7);

  _MultiStrokePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (var points in strokes) {
      if (points.isEmpty) continue;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      if (points.length > 2) {
        path.close();
        canvas.drawPath(path, _fill);
      }
      canvas.drawPath(path, _stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _MultiStrokePainter old) {
    if (old.strokes.length != strokes.length) return true;
    for (var i = 0; i < strokes.length; i++) {
      if (!listEquals(old.strokes[i], strokes[i])) return true;
    }
    return false;
  }
}
