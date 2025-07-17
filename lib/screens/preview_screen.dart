// // // lib/screens/preview_screen.dart
// //
// // import 'dart:convert';
// // import 'dart:ui' as ui;
// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// // import 'package:collection/collection.dart';
// // import '../services/db_service.dart';
// //
// // class RegionPreviewScreen extends StatelessWidget {
// //   final String fileName;
// //   final String doctorName;
// //   final int iteration;
// //
// //   const RegionPreviewScreen({
// //     Key? key,
// //     required this.fileName,
// //     required this.doctorName,
// //     required this.iteration,
// //   }) : super(key: key);
// //
// //   /// Load the actual image so we can get its true pixel dimensions
// //   Future<ui.Image> _loadUiImage() async {
// //     final data = await rootBundle.load(fileName);
// //     final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
// //     final frame = await codec.getNextFrame();
// //     return frame.image;
// //   }
// //
// //   /// Fetch all saved regions for this doctor/file/iteration
// //   Future<List<List<Offset>>> _loadRegions() async {
// //     final rows = await DbService.fetchRegions();
// //     return rows
// //         .where((r) =>
// //     r.doctorName == doctorName &&
// //         r.fileName == fileName &&
// //         r.iteration == iteration)
// //         .map((r) {
// //       final pts = (jsonDecode(r.pathJson) as List)
// //           .cast<Map<String, dynamic>>()
// //           .map((m) => Offset(
// //         (m['x'] as num).toDouble(),
// //         (m['y'] as num).toDouble(),
// //       ))
// //           .toList();
// //       return pts;
// //     })
// //         .toList();
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(title: const Text('Preview Regions')),
// //       body: FutureBuilder<List<dynamic>>(
// //         future: Future.wait([_loadUiImage(), _loadRegions()]),
// //         builder: (ctx, snap) {
// //           if (snap.connectionState != ConnectionState.done)
// //             return const Center(child: CircularProgressIndicator());
// //
// //           final ui.Image image = snap.data![0] as ui.Image;
// //           final List<List<Offset>> regions =
// //           snap.data![1] as List<List<Offset>>;
// //
// //           if (regions.isEmpty) {
// //             return const Center(child: Text('No regions to preview.'));
// //           }
// //
// //           return LayoutBuilder(builder: (c, constraints) {
// //             final dstSize = Size(
// //               constraints.maxWidth,
// //               constraints.maxHeight,
// //             );
// //
// //             final srcSize = Size(
// //               image.width.toDouble(),
// //               image.height.toDouble(),
// //             );
// //
// //             // How Flutter letter-boxes the image with BoxFit.contain:
// //             final fitted = applyBoxFit(BoxFit.contain, srcSize, dstSize);
// //             final dstRect = Alignment.center
// //                 .inscribe(fitted.destination, Offset.zero & dstSize);
// //             final srcRect = Alignment.center
// //                 .inscribe(fitted.source, Offset.zero & srcSize);
// //
// //             // Pre-scale your polygons into preview coordinates:
// //             final scaleX = dstRect.width / srcRect.width;
// //             final scaleY = dstRect.height / srcRect.height;
// //             final offX = dstRect.left - srcRect.left * scaleX;
// //             final offY = dstRect.top - srcRect.top * scaleY;
// //
// //             final scaledRegions = regions
// //                 .map((poly) => poly
// //                 .map((pt) => Offset(
// //               offX + pt.dx * scaleX,
// //               offY + pt.dy * scaleY,
// //             ))
// //                 .toList())
// //                 .toList();
// //
// //             return CustomPaint(
// //               size: dstSize,
// //               painter: _RegionPreviewPainter(
// //                 image: image,
// //                 dstRect: dstRect,
// //                 regions: scaledRegions,
// //               ),
// //             );
// //           });
// //         },
// //       ),
// //     );
// //   }
// // }
// //
// // class _RegionPreviewPainter extends CustomPainter {
// //   final ui.Image image;
// //   final Rect dstRect;
// //   final List<List<Offset>> regions;
// //   final Paint _paint = Paint();
// //
// //   _RegionPreviewPainter({
// //     required this.image,
// //     required this.dstRect,
// //     required this.regions,
// //   });
// //
// //   @override
// //   void paint(Canvas canvas, Size size) {
// //     // 1) Fill whole canvas black
// //     canvas.drawRect(Offset.zero & size, _paint..color = Colors.black);
// //
// //     // 2) For each region: clip & draw that slice of the image
// //     for (var poly in regions) {
// //       if (poly.length < 2) continue;
// //       final path = Path()..moveTo(poly.first.dx, poly.first.dy);
// //       for (var pt in poly.skip(1)) path.lineTo(pt.dx, pt.dy);
// //       path.close();
// //
// //       canvas.save();
// //       canvas.clipPath(path);
// //       // draw the full image (srcRect) into the letterboxed dstRect
// //       canvas.drawImageRect(
// //         image,
// //         Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
// //         dstRect,
// //         _paint,
// //       );
// //       canvas.restore();
// //     }
// //   }
// //
// //   @override
// //   bool shouldRepaint(covariant _RegionPreviewPainter old) {
// //     return old.regions.length != regions.length ||
// //         !_deepEquals(old.regions, regions);
// //   }
// //
// //   bool _deepEquals(List<List<Offset>> a, List<List<Offset>> b) {
// //     if (a.length != b.length) return false;
// //     for (var i = 0; i < a.length; i++) {
// //       if (!const ListEquality<Offset>().equals(a[i], b[i])) {
// //         return false;
// //       }
// //     }
// //     return true;
// //   }
// // }
// // lib/screens/preview_screen.dart
//
// // lib/screens/preview_screen.dart
//
// import 'dart:convert';
// import 'dart:ui' as ui;
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:collection/collection.dart';
// import '../services/db_service.dart';
//
// class RegionPreviewScreen extends StatelessWidget {
//   final String fileName;
//   final String doctorName;
//   final int iteration;
//
//   const RegionPreviewScreen({
//     Key? key,
//     required this.fileName,
//     required this.doctorName,
//     required this.iteration,
//   }) : super(key: key);
//
//   /// Load the actual image so we can get its true pixel dimensions
//   Future<ui.Image> _loadUiImage() async {
//     final data = await rootBundle.load(fileName);
//     final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
//     final frame = await codec.getNextFrame();
//     return frame.image;
//   }
//
//   /// Fetch all saved regions for this doctor/file/iteration
//   Future<List<List<Offset>>> _loadRegions() async {
//     final rows = await DbService.fetchRegions();
//     return rows
//         .where((r) =>
//     r.doctorName == doctorName &&
//         r.fileName == fileName)
//         .map((r) {
//       final pts = (jsonDecode(r.pathJson) as List)
//           .cast<Map<String, dynamic>>()
//           .map((m) => Offset(
//         (m['x'] as num).toDouble(),
//         (m['y'] as num).toDouble(),
//       ))
//           .toList();
//       return pts;
//     }).toList();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Preview Regions'),
//         backgroundColor: Colors.black,
//         foregroundColor: Colors.white,
//       ),
//       backgroundColor: Colors.black,
//       body: FutureBuilder<List<dynamic>>(
//         future: Future.wait([_loadUiImage(), _loadRegions()]),
//         builder: (ctx, snap) {
//           if (snap.connectionState != ConnectionState.done)
//             return const Center(child: CircularProgressIndicator());
//
//           final ui.Image image = snap.data![0] as ui.Image;
//           final List<List<Offset>> regions =
//           snap.data![1] as List<List<Offset>>;
//
//           if (regions.isEmpty) {
//             return const Center(
//               child: Text(
//                 'No regions to preview.',
//                 style: TextStyle(color: Colors.white),
//               ),
//             );
//           }
//
//           return LayoutBuilder(builder: (c, constraints) {
//             final containerSize = Size(
//               constraints.maxWidth,
//               constraints.maxHeight,
//             );
//
//             final imageSize = Size(
//               image.width.toDouble(),
//               image.height.toDouble(),
//             );
//
//             // Calculate how the image fits in the container with BoxFit.contain
//             final fitted = applyBoxFit(BoxFit.contain, imageSize, containerSize);
//             final imageRect = Alignment.center.inscribe(
//               fitted.destination,
//               Offset.zero & containerSize,
//             );
//
//             // Calculate scaling factors
//             final scaleX = imageRect.width / imageSize.width;
//             final scaleY = imageRect.height / imageSize.height;
//
//             // Transform regions from original image coordinates to display coordinates
//             final transformedRegions = regions.map((region) {
//               return region.map((point) {
//                 return Offset(
//                   imageRect.left + (point.dx * scaleX),
//                   imageRect.top + (point.dy * scaleY),
//                 );
//               }).toList();
//             }).toList();
//
//             return CustomPaint(
//               size: containerSize,
//               painter: _RegionPreviewPainter(
//                 image: image,
//                 imageRect: imageRect,
//                 regions: transformedRegions,
//               ),
//             );
//           });
//         },
//       ),
//     );
//   }
// }
//
// class _RegionPreviewPainter extends CustomPainter {
//   final ui.Image image;
//   final Rect imageRect;
//   final List<List<Offset>> regions;
//
//   _RegionPreviewPainter({
//     required this.image,
//     required this.imageRect,
//     required this.regions,
//   });
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     // 1) Fill the entire canvas with black
//     canvas.drawRect(
//       Offset.zero & size,
//       Paint()..color = Colors.black,
//     );
//
//     // 2) For each region, clip and draw that part of the image
//     for (var region in regions) {
//       if (region.length < 3) continue; // Need at least 3 points for a polygon
//
//       // Create path for the region
//       final path = Path();
//       path.moveTo(region.first.dx, region.first.dy);
//       for (var i = 1; i < region.length; i++) {
//         path.lineTo(region[i].dx, region[i].dy);
//       }
//       path.close();
//
//       // Save canvas state
//       canvas.save();
//
//       // Clip to the region
//       canvas.clipPath(path);
//
//       // Draw the image in the clipped area
//       canvas.drawImageRect(
//         image,
//         Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
//         imageRect,
//         Paint(),
//       );
//
//       // Restore canvas state
//       canvas.restore();
//
//       // Optional: Draw region outline for debugging
//       canvas.drawPath(
//         path,
//         Paint()
//           ..style = PaintingStyle.stroke
//           ..color = Colors.red.withOpacity(0.5)
//           ..strokeWidth = 2,
//       );
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant _RegionPreviewPainter old) {
//     return old.regions.length != regions.length ||
//         !_deepEquals(old.regions, regions);
//   }
//
//   bool _deepEquals(List<List<Offset>> a, List<List<Offset>> b) {
//     if (a.length != b.length) return false;
//     for (var i = 0; i < a.length; i++) {
//       if (!const ListEquality<Offset>().equals(a[i], b[i])) {
//         return false;
//       }
//     }
//     return true;
//   }
// }

// lib/screens/preview_screen.dart

import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';
import '../services/discrete_db_service.dart';
import '../services/continuous_db_service.dart';

class RegionPreviewScreen extends StatelessWidget {
  final String fileName;
  final String doctorName;
  final int iteration;
  final String mode; // 'discrete' or 'continuous'

  const RegionPreviewScreen({
    super.key,
    required this.fileName,
    required this.doctorName,
    required this.iteration,
    this.mode = 'discrete',
  });

  /// Load the actual image so we can get its true pixel dimensions
  Future<ui.Image> _loadUiImage() async {
    final data = await rootBundle.load(fileName);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Fetch all saved regions for this doctor/file/iteration
  Future<List<List<Offset>>> _loadRegions() async {
    final rows = mode == 'continuous'
        ? await ContinuousDbService.fetchRegions()
        : await DiscreteDbService.fetchRegions();
    return rows
        .where(
          (r) =>
              r.doctorName == doctorName &&
              r.fileName == fileName &&
              r.iteration == iteration,
        )
        .map((r) {
          final pts = (jsonDecode(r.pathJson) as List)
              .cast<Map<String, dynamic>>()
              .map(
                (m) => Offset(
                  (m['x'] as num).toDouble(),
                  (m['y'] as num).toDouble(),
                ),
              )
              .toList();
          return pts;
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Regions'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([_loadUiImage(), _loadRegions()]),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final ui.Image image = snap.data![0] as ui.Image;
          final List<List<Offset>> regions =
              snap.data![1] as List<List<Offset>>;

          if (regions.isEmpty) {
            return const Center(
              child: Text(
                'No regions to preview.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return LayoutBuilder(
            builder: (c, constraints) {
              final containerSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );

              final imageSize = Size(
                image.width.toDouble(),
                image.height.toDouble(),
              );

              // Calculate how the image fits in the container with BoxFit.contain
              final fitted = applyBoxFit(
                BoxFit.contain,
                imageSize,
                containerSize,
              );
              final imageRect = Alignment.center.inscribe(
                fitted.destination,
                Offset.zero & containerSize,
              );

              // Calculate scaling factors
              final scaleX = imageRect.width / imageSize.width;
              final scaleY = imageRect.height / imageSize.height;

              // Transform regions from image coordinates to display coordinates
              final transformedRegions = regions.map((region) {
                return region.map((point) {
                  // Convert from image coordinates to display coordinates
                  final relativeX = point.dx / imageSize.width;
                  final relativeY = point.dy / imageSize.height;

                  return Offset(
                    imageRect.left + (relativeX * imageRect.width),
                    imageRect.top + (relativeY * imageRect.height),
                  );
                }).toList();
              }).toList();

              return CustomPaint(
                size: containerSize,
                painter: _RegionPreviewPainter(
                  image: image,
                  imageRect: imageRect,
                  regions: transformedRegions,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RegionPreviewPainter extends CustomPainter {
  final ui.Image image;
  final Rect imageRect;
  final List<List<Offset>> regions;

  _RegionPreviewPainter({
    required this.image,
    required this.imageRect,
    required this.regions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1) Fill the entire canvas with black
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);

    // 2) For each region, clip and draw that part of the image
    for (var region in regions) {
      if (region.length < 3) continue; // Need at least 3 points for a polygon

      // Create path for the region
      final path = Path();
      path.moveTo(region.first.dx, region.first.dy);
      for (var i = 1; i < region.length; i++) {
        path.lineTo(region[i].dx, region[i].dy);
      }
      path.close();

      // Save canvas state
      canvas.save();

      // Clip to the region
      canvas.clipPath(path);

      // Draw the image in the clipped area
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        imageRect,
        Paint(),
      );

      // Restore canvas state
      canvas.restore();

      // Optional: Draw region outline for debugging
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.red.withOpacity(0.5)
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RegionPreviewPainter old) {
    return old.regions.length != regions.length ||
        !_deepEquals(old.regions, regions);
  }

  bool _deepEquals(List<List<Offset>> a, List<List<Offset>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!const ListEquality<Offset>().equals(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }
}
