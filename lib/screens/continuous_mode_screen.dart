// import 'package:flutter/material.dart';
// import 'label_screen.dart';
// import '../widgets/region_selector.dart';
// import '../providers/doctor_provider.dart';
// import '../services/continuous_db_service.dart';
// import 'preview_screen.dart';
// import 'package:provider/provider.dart';
// import 'database_view.dart' show ContinuousDatabaseViewScreen;
// import 'dart:convert';
// import '../services/db_service.dart' show RegionSelection;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:math';
// import 'dart:async';
// import '../widgets/labeling_screen_scaffold.dart';
// import '../widgets/mode_toolbar.dart';
// import '../widgets/user_info_card.dart';
// import '../widgets/appbar_actions_card.dart';
// import '../utils/downloads_path.dart';
// import 'package:intl/intl.dart';
// import 'dart:io';
// import 'package:light/light.dart';
// import '../utils/app_constants.dart';
// import 'package:open_file/open_file.dart';

// /// Map each English color to its single Korean label.
// const Map<String, String> _koreanColor = {
//   'Pale': '백색',
//   'Pink': '담홍색',
//   'Red': '홍색',
//   'DeepRed': '강홍색',
// };

// class ContinuousModeScreen extends StatefulWidget {
//   const ContinuousModeScreen({super.key});

//   @override
//   State<ContinuousModeScreen> createState() => _ContinuousModeScreenState();
// }

// class _ContinuousModeScreenState extends State<ContinuousModeScreen> {
//   bool _isSelectionMode = false;
//   int idx = 0;
//   List<ImageIteration> _sequence = [];
//   ContinuousLabelEvent? currentEvent;
//   final GlobalKey<RegionSelectorState> _regionKey =
//       GlobalKey<RegionSelectorState>();
//   bool _showRegionSavedMsg = false;
//   int? _selectedSlider; // 0: Pale-Pink, 1: Pink-Red, 2: Red-DeepRed
//   double _sliderValue0 = 0.0;
//   double _sliderValue1 = 0.0;
//   double _sliderValue2 = 0.0;
//   // Remove _loadedRegions and _checkOverlapWithLoadedRegions logic
//   // Add state for warning
//   final bool _showNextWarning = false;

//   // Ambient light sensor
//   Light? _light;
//   StreamSubscription<int>? _lightSubscription;
//   int? _currentLux;
//   int? _savedLuxForCurrentImage;
//   String? _currentImageKey;

//   @override
//   void initState() {
//     super.initState();
//     _initAsync();
//     _startLightSensor();
//   }

//   Future<void> _initAsync() async {
//     await _buildSequence();
//     await _loadLastIndexAndEvent();
//   }

//   void _startLightSensor() {
//     _light = Light();
//     _lightSubscription = _light!.lightSensorStream.listen(
//       (luxValue) {
//         setState(() {
//           _currentLux = luxValue;
//         });
//       },
//       onError: (err) {
//         // Optionally handle sensor errors
//         _currentLux = null;
//       },
//     );
//   }

//   @override
//   void dispose() {
//     _lightSubscription?.cancel();
//     super.dispose();
//   }

//   Future<void> _loadLastIndexAndEvent() async {
//     final prefs = await SharedPreferences.getInstance();
//     final doc = Provider.of<DoctorProvider>(context, listen: false).name;
//     final iters = Provider.of<DoctorProvider>(
//       context,
//       listen: false,
//     ).iterations;
//     final idxKey = 'lastContinuousIdx_${doc}_$iters';
//     final lastIdx = prefs.getInt(idxKey) ?? 0;
//     final lastMode = prefs.getBool('continuousIsSelectionMode') ?? false;
//     final seqKey = 'labelingSequence_${doc}_$iters';
//     final savedSeq = prefs.getString(seqKey);
//     if (savedSeq == null) {
//       await _buildSequence();
//     } else {
//       final decoded = jsonDecode(savedSeq) as List;
//       _sequence = decoded
//           .map((e) => ImageIteration(e['fileName'], e['iteration']))
//           .toList();
//     }
//     setState(() {
//       idx = lastIdx;
//       _isSelectionMode = lastMode;
//     });
//     _loadEvent();
//   }

//   Future<void> _buildSequence() async {
//     final base = List.generate(
//       2000,
//       (i) => 'assets/images/${(i + 1).toString().padLeft(4, '0')}.png',
//     );
//     final iters = Provider.of<DoctorProvider>(
//       context,
//       listen: false,
//     ).iterations;
//     final prefs = await SharedPreferences.getInstance();
//     final doc = Provider.of<DoctorProvider>(context, listen: false).name;
//     final seqKey = 'labelingSequence_${doc}_$iters';
//     final savedSeq = prefs.getString(seqKey);
//     if (savedSeq != null) {
//       // Restore saved sequence
//       final decoded = jsonDecode(savedSeq) as List;
//       _sequence = decoded
//           .map((e) => ImageIteration(e['fileName'], e['iteration']))
//           .toList();
//     } else {
//       // Shuffle base list ONCE with fixed seed
//       final shuffled = List<String>.from(base);
//       shuffled.shuffle(Random(42));
//       // Repeat for each iteration, grouping by pass
//       final seq = [
//         for (var n = 1; n <= iters; n++)
//           for (var img in shuffled) ImageIteration(img, n),
//       ];
//       _sequence = seq;
//       final toSave = _sequence
//           .map((e) => {'fileName': e.fileName, 'iteration': e.iteration})
//           .toList();
//       await prefs.setString(seqKey, jsonEncode(toSave));
//     }
//   }

//   Future<void> _loadEvent() async {
//     final doc = Provider.of<DoctorProvider>(context, listen: false).name;
//     final iters = Provider.of<DoctorProvider>(
//       context,
//       listen: false,
//     ).iterations;
//     final sessionId = '${doc}_$iters';
//     final img = _sequence[idx].fileName;
//     final iteration = _sequence[idx].iteration;
//     // Load regions
//     final regions = await ContinuousDbService.fetchRegions();
//     final currentImageRegions = regions
//         .where(
//           (r) =>
//               r.sessionId == sessionId &&
//               r.fileName == img &&
//               r.iteration == iteration,
//         )
//         .toList();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _regionKey.currentState?.loadExistingRegions(currentImageRegions);
//     });
//     // No need to update _loadedRegions
//     // Load last color event
//     final events = await ContinuousDbService.fetchEvents();
//     final matchingEvents = events
//         .where(
//           (e) =>
//               e.sessionId == sessionId &&
//               e.fileName == img &&
//               e.iteration == iteration,
//         )
//         .toList();
//     final last = matchingEvents.isNotEmpty ? matchingEvents.last : null;
//     if (last != null) {
//       int? restoredSlider;
//       double v0 = 0.0, v1 = 0.0, v2 = 0.0;
//       if (last.colorA == 'Pale' && last.colorB == 'Pink') {
//         restoredSlider = 0;
//         v0 = last.percentB / 100.0;
//       } else if (last.colorA == 'Pink' && last.colorB == 'Red') {
//         restoredSlider = 1;
//         v1 = last.percentB / 100.0;
//       } else if (last.colorA == 'Red' && last.colorB == 'DeepRed') {
//         restoredSlider = 2;
//         v2 = last.percentB / 100.0;
//       }
//       setState(() {
//         _sliderValue0 = v0;
//         _sliderValue1 = v1;
//         _sliderValue2 = v2;
//         _selectedSlider = restoredSlider;
//       });
//     } else {
//       setState(() {
//         _sliderValue0 = 0.0;
//         _sliderValue1 = 0.0;
//         _sliderValue2 = 0.0;
//         _selectedSlider = null;
//       });
//     }
//   }

//   void _onSliderTap(int sliderIdx) async {
//     setState(() {
//       _selectedSlider = sliderIdx;
//       _sliderValue0 = 0.0;
//       _sliderValue1 = 0.0;
//       _sliderValue2 = 0.0;
//     });
//     await _saveOrUpdateColorEvent(sliderIdx, 0.0);
//   }

//   Future<void> _saveOrUpdateColorEvent(int sliderIdx, double value) async {
//     final doc = Provider.of<DoctorProvider>(context, listen: false).name;
//     final iters = Provider.of<DoctorProvider>(
//       context,
//       listen: false,
//     ).iterations;
//     final sessionId = '${doc}_$iters';
//     final img = _sequence[idx].fileName;
//     final iteration = _sequence[idx].iteration;
//     final imageKey = '${img}_$iteration';

//     // Capture ambient light value for this image if not already set
//     if (_currentImageKey != imageKey) {
//       _currentImageKey = imageKey;
//       _savedLuxForCurrentImage = _currentLux;
//     }

//     // Delete all previous events for this image/iteration
//     await ContinuousDbService.deleteAllEventsForImage(
//       doctorName: doc,
//       fileName: img,
//       iteration: iteration,
//       sessionId: sessionId,
//     );
//     String colorA = '', colorB = '';
//     if (sliderIdx == 0) {
//       colorA = 'Pale';
//       colorB = 'Pink';
//     } else if (sliderIdx == 1) {
//       colorA = 'Pink';
//       colorB = 'Red';
//     } else if (sliderIdx == 2) {
//       colorA = 'Red';
//       colorB = 'DeepRed';
//     }
//     final event = ContinuousLabelEvent(
//       doctorName: doc,
//       fileName: img,
//       iteration: iteration,
//       timestamp: DateTime.now(),
//       ambientLux: _savedLuxForCurrentImage,
//       colorA: colorA,
//       percentA: 100 - (value * 100),
//       colorB: colorB,
//       percentB: value * 100,
//       sessionId: sessionId,
//     );
//     await ContinuousDbService.insertEvent(event);
//   }

//   void _onSliderChange(int idx, double value) {
//     setState(() {
//       _selectedSlider = idx;
//       if (idx == 0) _sliderValue0 = value;
//       if (idx == 1) _sliderValue1 = value;
//       if (idx == 2) _sliderValue2 = value;
//     });
//     _saveOrUpdateColorEvent(idx, value);
//   }

//   void _handleNext(int total) async {
//     // Only check in selection mode
//     if (_isSelectionMode) {
//       // Check if a slider is selected
//       final hasColor = _selectedSlider != null;
//       // Check if at least one region exists
//       final doc = Provider.of<DoctorProvider>(context, listen: false).name;
//       final iters = Provider.of<DoctorProvider>(
//         context,
//         listen: false,
//       ).iterations;
//       final sessionId = '${doc}_$iters';
//       final img = _sequence[idx].fileName;
//       final iteration = _sequence[idx].iteration;
//       final regions = await ContinuousDbService.fetchRegions();
//       final currentImageRegions = regions
//           .where(
//             (r) =>
//                 r.sessionId == sessionId &&
//                 r.fileName == img &&
//                 r.iteration == iteration,
//           )
//           .toList();
//       final hasRegion = currentImageRegions.isNotEmpty;
//       if (!hasColor || !hasRegion) {
//         // Show warning as SnackBar (orange, like overlap)
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text(
//               'Please select a color and draw at least one region to continue.',
//             ),
//             duration: Duration(seconds: 2),
//             backgroundColor: Colors.orange,
//           ),
//         );
//         return;
//       }
//     }
//     // Save color event if a slider is selected
//     if (_selectedSlider != null) {
//       double value = 0.0;
//       if (_selectedSlider == 0) value = _sliderValue0;
//       if (_selectedSlider == 1) value = _sliderValue1;
//       if (_selectedSlider == 2) value = _sliderValue2;
//       await _saveOrUpdateColorEvent(_selectedSlider!, value);
//     }
//     if (idx < total - 1) {
//       setState(() {
//         idx++;
//         _selectedSlider = null;
//         _sliderValue0 = 0.0;
//         _sliderValue1 = 0.0;
//         _sliderValue2 = 0.0;
//         // Reset ambient light tracking for new image
//         _currentImageKey = null;
//         _savedLuxForCurrentImage = null;
//       });
//       final doc = Provider.of<DoctorProvider>(context, listen: false).name;
//       final iters = Provider.of<DoctorProvider>(
//         context,
//         listen: false,
//       ).iterations;
//       final sessionId = '${doc}_$iters';
//       final idxKey = 'lastContinuousIdx_${doc}_$iters';
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setInt(idxKey, idx);
//       _loadEvent();
//     }
//   }

//   void _undoLastShape() {
//     if (_regionKey.currentState != null) {
//       final success = _regionKey.currentState!.undoLastStroke();
//       if (!success) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('No shapes to undo'),
//             duration: Duration(seconds: 1),
//           ),
//         );
//       }
//     }
//   }

//   void _handleRegionComplete(List<Offset> poly) async {
//     if (!_isSelectionMode || poly.isEmpty) return;
//     final doc = Provider.of<DoctorProvider>(context, listen: false).name;
//     final iters = Provider.of<DoctorProvider>(
//       context,
//       listen: false,
//     ).iterations;
//     final sessionId = '${doc}_$iters';
//     final jsonPoly = jsonEncode(
//       poly.map((o) => {'x': o.dx, 'y': o.dy}).toList(),
//     );
//     await ContinuousDbService.insertRegion(
//       RegionSelection(
//         doctorName: doc,
//         fileName: _sequence[idx].fileName,
//         pathJson: jsonPoly,
//         iteration: _sequence[idx].iteration,
//         timestamp: DateTime.now(),
//         ambientLux: null,
//         sessionId: sessionId,
//       ),
//     );
//     await _loadEvent(); // reload regions
//     setState(() {
//       _showRegionSavedMsg = true;
//     });
//     Future.delayed(const Duration(seconds: 1), () {
//       if (mounted) {
//         setState(() {
//           _showRegionSavedMsg = false;
//         });
//       }
//     });
//   }

//   // Remove _checkOverlapWithLoadedRegions and related code
//   // Remove _isPointInPolygon and _doPolygonsIntersect and related code
//   // Remove _doLinesIntersect and related code

//   @override
//   Widget build(BuildContext context) {
//     if (_sequence.isEmpty) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }
//     final total = _sequence.length;
//     final img = _sequence[idx].fileName;
//     final doc = Provider.of<DoctorProvider>(context, listen: false).name;
//     final iters = Provider.of<DoctorProvider>(
//       context,
//       listen: false,
//     ).iterations;
//     final sessionId = '${doc}_$iters';
//     final iteration = _sequence[idx].iteration;

//     // RegionSelector widget
//     final regionSelector = RegionSelector(
//       key: _regionKey,
//       enabled: _isSelectionMode,
//       imagePath: img,
//       onComplete: _handleRegionComplete,
//       onOverlapDetected: () {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text(
//               'Cannot select overlapping areas. Please select a different region.',
//             ),
//             duration: Duration(seconds: 2),
//             backgroundColor: Colors.orange,
//           ),
//         );
//       },
//       samplingTolerance: 6.0,
//       doctorName: doc,
//       fileName: img,
//       iteration: iteration,
//       mode: 'continuous',
//       sessionId: sessionId,
//       child: Image.asset(img),
//     );

//     // Region saved message
//     final regionSavedMessage = _showRegionSavedMsg
//         ? Positioned(
//             left: 0,
//             right: 0,
//             bottom: 12,
//             child: AnimatedOpacity(
//               opacity: _showRegionSavedMsg ? 1.0 : 0.0,
//               duration: const Duration(milliseconds: 300),
//               child: Center(
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     vertical: 6,
//                     horizontal: 16,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.7),
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: const Text(
//                     'Region saved!',
//                     style: TextStyle(color: Colors.white, fontSize: 14),
//                   ),
//                 ),
//               ),
//             ),
//           )
//         : null;

//     // Mode controls (sliders)
//     final modeControls = _isSelectionMode
//         ? Column(
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Card(
//                     elevation: AppConstants.cardElevation,
//                     color: AppConstants.cardBackgroundColor,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(
//                         AppConstants.cardBorderRadius,
//                       ),
//                     ),
//                     child: SizedBox(
//                       width: AppConstants.sliderWidth,
//                       height: AppConstants.sliderHeight,
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(
//                           vertical: 0,
//                           horizontal: 4,
//                         ),
//                         child: _buildStyledSlider(
//                           0,
//                           _koreanColor['Pale']!,
//                           _koreanColor['Pink']!,
//                           labelFontSize: 12,
//                           labelColor: Colors.deepPurple,
//                           labelBottomPadding: 0,
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 20),
//                   Card(
//                     elevation: AppConstants.cardElevation,
//                     color: AppConstants.cardBackgroundColor,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(
//                         AppConstants.cardBorderRadius,
//                       ),
//                     ),
//                     child: SizedBox(
//                       width: AppConstants.sliderWidth,
//                       height: AppConstants.sliderHeight,
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(
//                           vertical: 0,
//                           horizontal: 4,
//                         ),
//                         child: _buildStyledSlider(
//                           1,
//                           _koreanColor['Pink']!,
//                           _koreanColor['Red']!,
//                           labelFontSize: 12,
//                           labelColor: Colors.deepPurple,
//                           labelBottomPadding: 0,
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 20),
//                   Card(
//                     elevation: AppConstants.cardElevation,
//                     color: AppConstants.cardBackgroundColor,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(
//                         AppConstants.cardBorderRadius,
//                       ),
//                     ),
//                     child: SizedBox(
//                       width: AppConstants.sliderWidth,
//                       height: AppConstants.sliderHeight,
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(
//                           vertical: 0,
//                           horizontal: 4,
//                         ),
//                         child: _buildStyledSlider(
//                           2,
//                           _koreanColor['Red']!,
//                           _koreanColor['DeepRed']!,
//                           labelFontSize: 12,
//                           labelColor: Colors.deepPurple,
//                           labelBottomPadding: 0,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 16),
//             ],
//           )
//         : const SizedBox.shrink();

//     // Navigation buttons
//     final navigationButtons = Padding(
//       padding: const EdgeInsets.only(left: 32, right: 32, bottom: 24),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           GestureDetector(
//             onTap: idx > 0
//                 ? () async {
//                     setState(() {
//                       idx--;
//                       _selectedSlider = null;
//                       _sliderValue0 = 0.0;
//                       _sliderValue1 = 0.0;
//                       _sliderValue2 = 0.0;
//                       // Reset ambient light tracking for new image
//                       _currentImageKey = null;
//                       _savedLuxForCurrentImage = null;
//                     });
//                     final doc = Provider.of<DoctorProvider>(
//                       context,
//                       listen: false,
//                     ).name;
//                     final iters = Provider.of<DoctorProvider>(
//                       context,
//                       listen: false,
//                     ).iterations;
//                     final sessionId = '${doc}_$iters';
//                     final idxKey = 'lastContinuousIdx_${doc}_$iters';
//                     final prefs = await SharedPreferences.getInstance();
//                     await prefs.setInt(idxKey, idx);
//                     _loadEvent();
//                   }
//                 : null,
//             child: Card(
//               elevation: AppConstants.cardElevation,
//               color: AppConstants.cardBackgroundColor,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(
//                   AppConstants.cardBorderRadius,
//                 ),
//               ),
//               child: SizedBox(
//                 height: AppConstants.standardCardHeight,
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 28),
//                   child: Center(
//                     child: Text(
//                       'Previous',
//                       style: TextStyle(
//                         fontSize: 16,
//                         color: idx > 0
//                             ? Colors.deepPurple
//                             : Colors.deepPurple.withOpacity(0.4),
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           const Spacer(),
//           // Sliders in the middle
//           if (_isSelectionMode) ...[
//             Card(
//               elevation: 8,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(
//                   AppConstants.cardBorderRadius,
//                 ),
//               ),
//               child: SizedBox(
//                 width: 220,
//                 height: AppConstants.standardCardHeight,
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(
//                     vertical: 6,
//                     horizontal: 6,
//                   ),
//                   child: _buildStyledSlider(
//                     0,
//                     _koreanColor['Pale']!,
//                     _koreanColor['Pink']!,
//                     labelFontSize: 12,
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(width: 20),
//             Card(
//               elevation: 8,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(
//                   AppConstants.cardBorderRadius,
//                 ),
//               ),
//               child: SizedBox(
//                 width: 220,
//                 height: AppConstants.standardCardHeight,
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(
//                     vertical: 6,
//                     horizontal: 6,
//                   ),
//                   child: _buildStyledSlider(
//                     1,
//                     _koreanColor['Pink']!,
//                     _koreanColor['Red']!,
//                     labelFontSize: 12,
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(width: 12),
//             Card(
//               elevation: 8,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(
//                   AppConstants.cardBorderRadius,
//                 ),
//               ),
//               child: SizedBox(
//                 width: 220,
//                 height: AppConstants.standardCardHeight,
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(
//                     vertical: 6,
//                     horizontal: 6,
//                   ),
//                   child: _buildStyledSlider(
//                     2,
//                     _koreanColor['Red']!,
//                     _koreanColor['DeepRed']!,
//                     labelFontSize: 12,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//           const Spacer(),
//           GestureDetector(
//             onTap: () => _handleNext(total),
//             child: Card(
//               elevation: AppConstants.cardElevation,
//               color: AppConstants.cardBackgroundColor,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(
//                   AppConstants.cardBorderRadius,
//                 ),
//               ),
//               child: SizedBox(
//                 height: AppConstants.standardCardHeight,
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 28),
//                   child: Center(
//                     child: Text(
//                       'Next',
//                       style: const TextStyle(
//                         fontSize: 16,
//                         color: Colors.deepPurple,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );

//     final appBarContent = Row(
//       crossAxisAlignment: CrossAxisAlignment.center,
//       children: [
//         // Left: User info card
//         UserInfoCard(
//           userName: doc,
//           iterations: iters,
//           mode: 'continuous',
//           currentIndex: idx,
//           totalImages: total,
//         ),
//         const Spacer(),
//         // Center: ModeToolbar
//         ModeToolbar(
//           isSelectionMode: _isSelectionMode,
//           onToggleMode: () async {
//             setState(() {
//               _isSelectionMode = !_isSelectionMode;
//               if (!_isSelectionMode) {
//                 _regionKey.currentState?.clearSelection();
//               }
//             });
//             final prefs = await SharedPreferences.getInstance();
//             await prefs.setBool('continuousIsSelectionMode', _isSelectionMode);
//             // If switching to selection mode, reload regions for current image
//             if (_isSelectionMode) {
//               await _loadEvent();
//             }
//           },
//           onUndo: _isSelectionMode ? _undoLastShape : null,
//         ),
//         const Spacer(),
//         // Right: Actions card with 6 icons
//         AppBarActionsCard(
//           onDownload: () async {
//             try {
//               final doc = Provider.of<DoctorProvider>(
//                 context,
//                 listen: false,
//               ).name;
//               final iters = Provider.of<DoctorProvider>(
//                 context,
//                 listen: false,
//               ).iterations;
//               final sessionId = '${doc}_$iters';
//               final events = await ContinuousDbService.fetchEvents();
//               final regions = await ContinuousDbService.fetchRegions();
//               // Group regions by image/iteration
//               Map<String, List<RegionSelection>> regionMap = {};
//               for (var r in regions) {
//                 if (r.sessionId == sessionId) {
//                   final key = '${r.fileName}_${r.iteration}';
//                   regionMap.putIfAbsent(key, () => []).add(r);
//                 }
//               }
//               // Prepare CSV rows
//               List<List<String>> rows = [];
//               // Header
//               int maxRegions = regionMap.values.fold(
//                 0,
//                 (prev, list) => list.length > prev ? list.length : prev,
//               );
//               List<String> header = [
//                 'Image Name',
//                 'Time',
//                 'Color A',
//                 'Percent A',
//                 'Color B',
//                 'Percent B',
//                 'Ambient Light (Lux)',
//               ];
//               for (int i = 0; i < maxRegions; i++) {
//                 header.add('Region ${i + 1}');
//               }
//               rows.add(header);
//               // Data rows
//               for (var e in events) {
//                 if (e.sessionId != sessionId) continue;
//                 final key = '${e.fileName}_${e.iteration}';
//                 final regionList = regionMap[key] ?? [];
//                 List<String> row = [
//                   e.fileName,
//                   DateFormat('yyyy-MM-dd HH:mm:ss').format(e.timestamp),
//                   e.colorA,
//                   e.percentA.toStringAsFixed(2),
//                   e.colorB,
//                   e.percentB.toStringAsFixed(2),
//                   e.ambientLux?.toString() ?? 'N/A',
//                 ];
//                 for (var r in regionList) {
//                   row.add(r.pathJson);
//                 }
//                 // Pad with empty strings if fewer regions
//                 while (row.length < header.length) {
//                   row.add('');
//                 }
//                 rows.add(row);
//               }
//               // Convert to CSV string
//               String csv = rows
//                   .map(
//                     (r) =>
//                         r.map((v) => '"${v.replaceAll('"', '""')}"').join(','),
//                   )
//                   .join('\n');
//               // Get Downloads directory
//               final now = DateTime.now();
//               final fileName =
//                   'continuous_${doc}_$sessionId${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';
//               final downloadsPath = await DownloadsPath.getDownloadsDirectory();
//               if (downloadsPath == null) {
//                 throw Exception('Downloads directory not found');
//               }
//               final file = File('$downloadsPath/$fileName');
//               await file.writeAsString(csv);
//               // Show dialog with both actions
//               showDialog(
//                 context: context,
//                 builder: (context) => AlertDialog(
//                   title: const Text('Export Complete'),
//                   content: Text('Exported to ${file.path}'),
//                   actions: [
//                     TextButton(
//                       onPressed: () {
//                         OpenFile.open(file.path);
//                         Navigator.of(context).pop();
//                       },
//                       child: const Text('Open File'),
//                     ),
//                     TextButton(
//                       onPressed: () {
//                         OpenFile.open(downloadsPath);
//                         Navigator.of(context).pop();
//                       },
//                       child: const Text('Open Folder'),
//                     ),
//                     TextButton(
//                       onPressed: () => Navigator.of(context).pop(),
//                       child: const Text('Close'),
//                     ),
//                   ],
//                 ),
//               );
//             } catch (e) {
//               ScaffoldMessenger.of(
//                 context,
//               ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
//             }
//           },
//           otherIcons: [
//             IconButton(
//               icon: const Icon(Icons.visibility, color: Colors.deepPurple),
//               tooltip: 'Preview Regions',
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => RegionPreviewScreen(
//                       fileName: img,
//                       doctorName: doc,
//                       iteration: iteration,
//                       mode: 'continuous',
//                     ),
//                   ),
//                 );
//               },
//             ),
//             IconButton(
//               icon: const Icon(Icons.storage, color: Colors.deepPurple),
//               tooltip: 'View DB',
//               onPressed: () => Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) => const ContinuousDatabaseViewScreen(),
//                 ),
//               ),
//             ),
//             IconButton(
//               icon: const Icon(Icons.grid_on, color: Colors.deepPurple),
//               tooltip: 'Switch to Discrete Mode',
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (_) => const LabelScreen()),
//                 );
//               },
//             ),
//             IconButton(
//               icon: const Icon(Icons.delete_forever, color: Colors.deepPurple),
//               tooltip: 'Reset Database',
//               onPressed: () async {
//                 final confirmed = await showDialog<bool>(
//                   context: context,
//                   builder: (ctx) => AlertDialog(
//                     title: const Text('Delete all data?'),
//                     content: const Text(
//                       'This will permanently delete all labeling and region data for Continuous mode. Are you sure?',
//                     ),
//                     actions: [
//                       TextButton(
//                         onPressed: () => Navigator.of(ctx).pop(false),
//                         child: const Text('Cancel'),
//                       ),
//                       TextButton(
//                         onPressed: () => Navigator.of(ctx).pop(true),
//                         child: const Text(
//                           'Delete',
//                           style: TextStyle(color: Colors.red),
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//                 if (confirmed == true) {
//                   await ContinuousDbService.clearAllData();
//                   if (mounted) {
//                     setState(() {
//                       _sliderValue0 = 0.0;
//                       _sliderValue1 = 0.0;
//                       _sliderValue2 = 0.0;
//                       _selectedSlider = null;
//                     });
//                     _regionKey.currentState?.clearSelection();
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(
//                         content: Text('Continuous mode database cleared.'),
//                         duration: Duration(seconds: 2),
//                       ),
//                     );
//                   }
//                 }
//               },
//             ),
//             IconButton(
//               icon: const Icon(Icons.logout, color: Colors.deepPurple),
//               tooltip: 'Logout',
//               onPressed: () async {
//                 final prefs = await SharedPreferences.getInstance();
//                 await prefs.remove('currentUser');
//                 await prefs.remove('currentIterations');
//                 Navigator.pushNamedAndRemoveUntil(
//                   context,
//                   '/login',
//                   (route) => false,
//                 );
//               },
//             ),
//           ],
//         ),
//       ],
//     );

//     return LabelingScreenScaffold(
//       appBarContent: appBarContent,
//       regionSelector: regionSelector,
//       regionSavedMessage: regionSavedMessage,
//       modeControls: const SizedBox.shrink(),
//       navigationButtons: navigationButtons,
//       imageBoxWidth: 400,
//       imageBoxAspectRatio: 0.9, // Make image slightly less tall
//       topSpacing: 24,
//       controlsSpacing: 18,
//     );
//   }

//   Widget _buildSliderBox() {
//     // No longer used in new layout
//     return const SizedBox.shrink();
//   }

//   // Widget _buildStyledSlider(
//   //   int idx,
//   //   String left,
//   //   String right, {
//   //   double labelFontSize = 14,
//   // }) {
//   //   final isActive = _selectedSlider == idx;
//   //   double value = 0.0;
//   //   if (idx == 0) value = _sliderValue0;
//   //   if (idx == 1) value = _sliderValue1;
//   //   if (idx == 2) value = _sliderValue2;
//   //   return Column(
//   //     crossAxisAlignment: CrossAxisAlignment.stretch,
//   //     children: [
//   //       Row(
//   //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//   //         children: [
//   //           Text(
//   //             left,
//   //             style: TextStyle(
//   //               fontWeight: FontWeight.bold,
//   //               fontSize: labelFontSize,
//   //             ),
//   //           ),
//   //           Text(
//   //             right,
//   //             style: TextStyle(
//   //               fontWeight: FontWeight.bold,
//   //               fontSize: labelFontSize,
//   //             ),
//   //           ),
//   //         ],
//   //       ),
//   //       GestureDetector(
//   //         behavior: HitTestBehavior.translucent,
//   //         onTap: () {
//   //           setState(() {
//   //             _selectedSlider = idx;
//   //           });
//   //         },
//   //         child: SliderTheme(
//   //           data: SliderTheme.of(context).copyWith(
//   //             activeTrackColor: isActive ? Colors.deepPurple : Colors.grey[300],
//   //             inactiveTrackColor: Colors.grey[200],
//   //             trackHeight: 6.0,
//   //             thumbColor: isActive ? Colors.pink : Colors.grey[400],
//   //             thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
//   //             overlayColor: isActive
//   //                 ? Colors.pink.withOpacity(0.2)
//   //                 : Colors.transparent,
//   //             valueIndicatorColor: Colors.deepPurple,
//   //           ),
//   //           child: Slider(
//   //             value: value,
//   //             onChanged: isActive
//   //                 ? (v) {
//   //                     setState(() {
//   //                       if (idx == 0) _sliderValue0 = v;
//   //                       if (idx == 1) _sliderValue1 = v;
//   //                       if (idx == 2) _sliderValue2 = v;
//   //                     });
//   //                   }
//   //                 : null,
//   //             onChangeStart: (_) async {
//   //               if (!isActive && _selectedSlider != null) {
//   //                 String prevColorA = '', prevColorB = '';
//   //                 if (_selectedSlider == 0) {
//   //                   prevColorA = 'Pale';
//   //                   prevColorB = 'Pink';
//   //                 } else if (_selectedSlider == 1) {
//   //                   prevColorA = 'Pink';
//   //                   prevColorB = 'Red';
//   //                 } else if (_selectedSlider == 2) {
//   //                   prevColorA = 'Red';
//   //                   prevColorB = 'DeepRed';
//   //                 }
//   //                 final doc = Provider.of<DoctorProvider>(
//   //                   context,
//   //                   listen: false,
//   //                 ).name;
//   //                 final iters = Provider.of<DoctorProvider>(
//   //                   context,
//   //                   listen: false,
//   //                 ).iterations;
//   //                 final sessionId = '${doc}_${iters}';
//   //                 final img = _sequence[idx].fileName;
//   //                 final iteration = _sequence[idx].iteration;
//   //                 setState(() {
//   //                   if (_selectedSlider == 0) _sliderValue0 = 0.0;
//   //                   if (_selectedSlider == 1) _sliderValue1 = 0.0;
//   //                   if (_selectedSlider == 2) _sliderValue2 = 0.0;
//   //                 });
//   //                 await ContinuousDbService.deleteEvent(
//   //                   doctorName: doc,
//   //                   fileName: img,
//   //                   iteration: iteration,
//   //                   colorA: prevColorA,
//   //                   colorB: prevColorB,
//   //                   sessionId: sessionId,
//   //                 );
//   //               }
//   //               setState(() {
//   //                 _selectedSlider = idx;
//   //               });
//   //             },
//   //             onChangeEnd: isActive
//   //                 ? (v) async {
//   //                     await _saveOrUpdateColorEvent(idx, v);
//   //                   }
//   //                 : null,
//   //             min: 0.0,
//   //             max: 1.0,
//   //             divisions: 100,
//   //           ),
//   //         ),
//   //       ),
//   //     ],
//   //   );
//   // }
//   Widget _buildStyledSlider(
//     int idx,
//     String left,
//     String right, {
//     double labelFontSize = 14,
//     Color labelColor = Colors.deepPurple,
//     double labelBottomPadding = 0,
//   }) {
//     final isActive = _selectedSlider == idx;
//     double value = 0.0;
//     if (idx == 0) value = _sliderValue0;
//     if (idx == 1) value = _sliderValue1;
//     if (idx == 2) value = _sliderValue2;

//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 8.0),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           _buildColorBall(
//             left,
//             idx == 0
//                 ? 1 - value
//                 : idx == 1
//                 ? 1 - value
//                 : 1 - value,
//             Colors.deepPurple,
//             isActive: isActive,
//           ),
//           const SizedBox(width: 2),
//           Expanded(
//             child: SliderTheme(
//               data: SliderTheme.of(context).copyWith(
//                 activeTrackColor: isActive
//                     ? Colors.deepPurple
//                     : Colors.grey[400],
//                 inactiveTrackColor: Colors.grey[200],
//                 trackHeight: 6.0,
//                 thumbColor: isActive ? Colors.deepPurple : Colors.grey[500],
//                 thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
//                 overlayColor: isActive
//                     ? Colors.deepPurple.withOpacity(0.05)
//                     : Colors.grey.withOpacity(0.02),
//                 valueIndicatorColor: Colors.deepPurple,
//               ),
//               child: Slider(
//                 value: value,
//                 onChanged: (v) {
//                   setState(() {
//                     if (idx == 0) _sliderValue0 = v;
//                     if (idx == 1) _sliderValue1 = v;
//                     if (idx == 2) _sliderValue2 = v;
//                   });
//                 },
//                 onChangeStart: (v) async {
//                   // Clear previous selection and reset other sliders
//                   if (_selectedSlider != null && _selectedSlider != idx) {
//                     String prevColorA = '', prevColorB = '';
//                     if (_selectedSlider == 0) {
//                       prevColorA = 'Pale';
//                       prevColorB = 'Pink';
//                     } else if (_selectedSlider == 1) {
//                       prevColorA = 'Pink';
//                       prevColorB = 'Red';
//                     } else if (_selectedSlider == 2) {
//                       prevColorA = 'Red';
//                       prevColorB = 'DeepRed';
//                     }

//                     final doc = Provider.of<DoctorProvider>(
//                       context,
//                       listen: false,
//                     ).name;
//                     final iters = Provider.of<DoctorProvider>(
//                       context,
//                       listen: false,
//                     ).iterations;
//                     final sessionId = '${doc}_$iters';
//                     final img = _sequence[this.idx].fileName;
//                     final iteration = _sequence[this.idx].iteration;

//                     // Reset the previous slider value
//                     setState(() {
//                       if (_selectedSlider == 0) _sliderValue0 = 0.0;
//                       if (_selectedSlider == 1) _sliderValue1 = 0.0;
//                       if (_selectedSlider == 2) _sliderValue2 = 0.0;
//                     });

//                     // Delete previous event from database
//                     await ContinuousDbService.deleteEvent(
//                       doctorName: doc,
//                       fileName: img,
//                       iteration: iteration,
//                       colorA: prevColorA,
//                       colorB: prevColorB,
//                       sessionId: sessionId,
//                     );
//                   }

//                   // Set current slider as selected
//                   setState(() {
//                     _selectedSlider = idx;
//                   });
//                 },
//                 onChangeEnd: (v) async {
//                   await _saveOrUpdateColorEvent(idx, v);
//                 },
//                 min: 0.0,
//                 max: 1.0,
//                 divisions: 100,
//               ),
//             ),
//           ),
//           const SizedBox(width: 2),
//           _buildColorBall(right, value, Colors.deepPurple, isActive: isActive),
//         ],
//       ),
//     );
//   }

//   Widget _buildColorBall(
//     String colorName,
//     double percent,
//     Color color, {
//     bool isActive = true,
//   }) {
//     final double minSize = 22;
//     final double maxSize = 38;
//     final double size = minSize + (maxSize - minSize) * percent;
//     final Color fillColor = isActive ? Colors.deepPurple : Colors.grey[300]!;
//     final Color textColor = isActive ? Colors.white : Colors.grey[500]!;
//     return Container(
//       width: size,
//       height: size,
//       decoration: BoxDecoration(color: fillColor, shape: BoxShape.circle),
//       alignment: Alignment.center,
//       child: FittedBox(
//         fit: BoxFit.scaleDown,
//         child: Text(
//           colorName,
//           style: TextStyle(
//             color: textColor,
//             fontWeight: FontWeight.bold,
//             fontSize: 10,
//           ),
//           textAlign: TextAlign.center,
//         ),
//       ),
//     );
//   }

//   Widget _buildSliderPercentagesCard() {
//     // No longer used in new layout
//     return const SizedBox.shrink();
//   }
// }

// class ImageIteration {
//   final String fileName;
//   final int iteration;
//   ImageIteration(this.fileName, this.iteration);
// }
import 'package:flutter/material.dart';
import 'label_screen.dart';
import '../widgets/region_selector.dart';
import '../providers/doctor_provider.dart';
import '../services/continuous_db_service.dart';
import 'preview_screen.dart';
import 'package:provider/provider.dart';
import 'database_view.dart' show ContinuousDatabaseViewScreen;
import 'dart:convert';
import '../services/db_service.dart' show RegionSelection;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:async';
import '../widgets/labeling_screen_scaffold.dart';
import '../widgets/mode_toolbar.dart';
import '../widgets/user_info_card.dart';
import '../widgets/appbar_actions_card.dart';
import '../utils/downloads_path.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:light/light.dart';
import '../utils/app_constants.dart';
import 'package:open_file/open_file.dart';

/// Map each English color to its single Korean label.
const Map<String, String> _koreanColor = {
  'Pale': '백색',
  'Pink': '담홍색',
  'Red': '홍색',
  'DeepRed': '강홍색',
};

class ContinuousModeScreen extends StatefulWidget {
  const ContinuousModeScreen({super.key});

  @override
  State<ContinuousModeScreen> createState() => _ContinuousModeScreenState();
}

class _ContinuousModeScreenState extends State<ContinuousModeScreen> {
  bool _isSelectionMode = false;
  int idx = 0;
  List<ImageIteration> _sequence = [];
  ContinuousLabelEvent? currentEvent;
  final GlobalKey<RegionSelectorState> _regionKey =
      GlobalKey<RegionSelectorState>();
  bool _showRegionSavedMsg = false;
  int? _selectedSlider; // 0: Pale-Pink, 1: Pink-Red, 2: Red-DeepRed
  double _sliderValue0 = 0.0;
  double _sliderValue1 = 0.0;
  double _sliderValue2 = 0.0;

  // Ambient light sensor
  Light? _light;
  StreamSubscription<int>? _lightSubscription;
  int? _currentLux;
  int? _savedLuxForCurrentImage;
  String? _currentImageKey;

  @override
  void initState() {
    super.initState();
    _initAsync();
    _startLightSensor();
  }

  Future<void> _initAsync() async {
    await _buildSequence();
    await _loadLastIndexAndEvent();
  }

  void _startLightSensor() {
    _light = Light();
    _lightSubscription = _light!.lightSensorStream.listen(
      (luxValue) {
        setState(() {
          _currentLux = luxValue;
        });
      },
      onError: (err) {
        // Optionally handle sensor errors
        _currentLux = null;
      },
    );
  }

  @override
  void dispose() {
    _lightSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadLastIndexAndEvent() async {
    final prefs = await SharedPreferences.getInstance();
    final doc = Provider.of<DoctorProvider>(context, listen: false).name;
    final iters = Provider.of<DoctorProvider>(
      context,
      listen: false,
    ).iterations;
    final idxKey = 'lastContinuousIdx_${doc}_$iters';
    final lastIdx = prefs.getInt(idxKey) ?? 0;
    final lastMode = prefs.getBool('continuousIsSelectionMode') ?? false;
    final seqKey = 'labelingSequence_${doc}_$iters';
    final savedSeq = prefs.getString(seqKey);
    if (savedSeq == null) {
      await _buildSequence();
    } else {
      final decoded = jsonDecode(savedSeq) as List;
      _sequence = decoded
          .map((e) => ImageIteration(e['fileName'], e['iteration']))
          .toList();
    }
    setState(() {
      idx = lastIdx;
      _isSelectionMode = lastMode;
    });
    _loadEvent();
  }

  Future<void> _buildSequence() async {
    final base = List.generate(
      2000,
      (i) => 'assets/images/${(i + 1).toString().padLeft(4, '0')}.png',
    );
    final iters = Provider.of<DoctorProvider>(
      context,
      listen: false,
    ).iterations;
    final prefs = await SharedPreferences.getInstance();
    final doc = Provider.of<DoctorProvider>(context, listen: false).name;
    final seqKey = 'labelingSequence_${doc}_$iters';
    final savedSeq = prefs.getString(seqKey);
    if (savedSeq != null) {
      // Restore saved sequence
      final decoded = jsonDecode(savedSeq) as List;
      _sequence = decoded
          .map((e) => ImageIteration(e['fileName'], e['iteration']))
          .toList();
    } else {
      // Shuffle base list ONCE with fixed seed
      final shuffled = List<String>.from(base);
      shuffled.shuffle(Random(42));
      // Repeat for each iteration, grouping by pass
      final seq = [
        for (var n = 1; n <= iters; n++)
          for (var img in shuffled) ImageIteration(img, n),
      ];
      _sequence = seq;
      final toSave = _sequence
          .map((e) => {'fileName': e.fileName, 'iteration': e.iteration})
          .toList();
      await prefs.setString(seqKey, jsonEncode(toSave));
    }
  }

  Future<void> _loadEvent() async {
    final doc = Provider.of<DoctorProvider>(context, listen: false).name;
    final iters = Provider.of<DoctorProvider>(
      context,
      listen: false,
    ).iterations;
    final sessionId = '${doc}_$iters';
    final img = _sequence[idx].fileName;
    final iteration = _sequence[idx].iteration;
    // Load regions
    final regions = await ContinuousDbService.fetchRegions();
    final currentImageRegions = regions
        .where(
          (r) =>
              r.sessionId == sessionId &&
              r.fileName == img &&
              r.iteration == iteration,
        )
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _regionKey.currentState?.loadExistingRegions(currentImageRegions);
    });
    // Load last color event
    final events = await ContinuousDbService.fetchEvents();
    final matchingEvents = events
        .where(
          (e) =>
              e.sessionId == sessionId &&
              e.fileName == img &&
              e.iteration == iteration,
        )
        .toList();
    final last = matchingEvents.isNotEmpty ? matchingEvents.last : null;
    if (last != null) {
      int? restoredSlider;
      double v0 = 0.0, v1 = 0.0, v2 = 0.0;
      if (last.colorA == 'Pale' && last.colorB == 'Pink') {
        restoredSlider = 0;
        v0 = last.percentB / 100.0;
      } else if (last.colorA == 'Pink' && last.colorB == 'Red') {
        restoredSlider = 1;
        v1 = last.percentB / 100.0;
      } else if (last.colorA == 'Red' && last.colorB == 'DeepRed') {
        restoredSlider = 2;
        v2 = last.percentB / 100.0;
      }
      setState(() {
        _sliderValue0 = v0;
        _sliderValue1 = v1;
        _sliderValue2 = v2;
        _selectedSlider = restoredSlider;
      });
    } else {
      setState(() {
        _sliderValue0 = 0.0;
        _sliderValue1 = 0.0;
        _sliderValue2 = 0.0;
        _selectedSlider = null;
      });
    }
  }

  Future<void> _saveOrUpdateColorEvent(int sliderIdx, double value) async {
    if (!mounted) return;

    final doc = Provider.of<DoctorProvider>(context, listen: false).name;
    final iters = Provider.of<DoctorProvider>(
      context,
      listen: false,
    ).iterations;
    final sessionId = '${doc}_$iters';
    final img = _sequence[idx].fileName;
    final iteration = _sequence[idx].iteration;
    final imageKey = '${img}_$iteration';

    // Capture ambient light value for this image if not already set
    if (_currentImageKey != imageKey) {
      _currentImageKey = imageKey;
      _savedLuxForCurrentImage = _currentLux;
    }

    // Delete all previous events for this image/iteration
    await ContinuousDbService.deleteAllEventsForImage(
      doctorName: doc,
      fileName: img,
      iteration: iteration,
      sessionId: sessionId,
    );
    String colorA = '', colorB = '';
    if (sliderIdx == 0) {
      colorA = 'Pale';
      colorB = 'Pink';
    } else if (sliderIdx == 1) {
      colorA = 'Pink';
      colorB = 'Red';
    } else if (sliderIdx == 2) {
      colorA = 'Red';
      colorB = 'DeepRed';
    }
    final event = ContinuousLabelEvent(
      doctorName: doc,
      fileName: img,
      iteration: iteration,
      timestamp: DateTime.now(),
      ambientLux: _savedLuxForCurrentImage,
      colorA: colorA,
      percentA: 100 - (value * 100),
      colorB: colorB,
      percentB: value * 100,
      sessionId: sessionId,
    );
    await ContinuousDbService.insertEvent(event);
  }

  void _handleNext(int total) async {
    // Only check in selection mode
    if (_isSelectionMode) {
      // Check if a slider is selected
      final hasColor = _selectedSlider != null;
      // Check if at least one region exists
      final doc = Provider.of<DoctorProvider>(context, listen: false).name;
      final iters = Provider.of<DoctorProvider>(
        context,
        listen: false,
      ).iterations;
      final sessionId = '${doc}_$iters';
      final img = _sequence[idx].fileName;
      final iteration = _sequence[idx].iteration;
      final regions = await ContinuousDbService.fetchRegions();
      final currentImageRegions = regions
          .where(
            (r) =>
                r.sessionId == sessionId &&
                r.fileName == img &&
                r.iteration == iteration,
          )
          .toList();
      final hasRegion = currentImageRegions.isNotEmpty;
      if (!hasColor || !hasRegion) {
        // Show warning as SnackBar (orange, like overlap)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please select a color and draw at least one region to continue.',
              ),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }
    // Save color event if a slider is selected
    if (_selectedSlider != null) {
      double value = 0.0;
      if (_selectedSlider == 0) value = _sliderValue0;
      if (_selectedSlider == 1) value = _sliderValue1;
      if (_selectedSlider == 2) value = _sliderValue2;
      await _saveOrUpdateColorEvent(_selectedSlider!, value);
    }
    if (idx < total - 1) {
      setState(() {
        idx++;
        _selectedSlider = null;
        _sliderValue0 = 0.0;
        _sliderValue1 = 0.0;
        _sliderValue2 = 0.0;
        // Reset ambient light tracking for new image
        _currentImageKey = null;
        _savedLuxForCurrentImage = null;
      });
      final doc = Provider.of<DoctorProvider>(context, listen: false).name;
      final iters = Provider.of<DoctorProvider>(
        context,
        listen: false,
      ).iterations;
      final idxKey = 'lastContinuousIdx_${doc}_$iters';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(idxKey, idx);
      _loadEvent();
    }
  }

  void _undoLastShape() {
    if (_regionKey.currentState != null) {
      final success = _regionKey.currentState!.undoLastStroke();
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No shapes to undo'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _handleRegionComplete(List<Offset> poly) async {
    if (!_isSelectionMode || poly.isEmpty) return;
    final doc = Provider.of<DoctorProvider>(context, listen: false).name;
    final iters = Provider.of<DoctorProvider>(
      context,
      listen: false,
    ).iterations;
    final sessionId = '${doc}_$iters';
    final jsonPoly = jsonEncode(
      poly.map((o) => {'x': o.dx, 'y': o.dy}).toList(),
    );
    await ContinuousDbService.insertRegion(
      RegionSelection(
        doctorName: doc,
        fileName: _sequence[idx].fileName,
        pathJson: jsonPoly,
        iteration: _sequence[idx].iteration,
        timestamp: DateTime.now(),
        ambientLux: null,
        sessionId: sessionId,
      ),
    );
    await _loadEvent(); // reload regions
    setState(() {
      _showRegionSavedMsg = true;
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showRegionSavedMsg = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sequence.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final total = _sequence.length;
    final img = _sequence[idx].fileName;
    final doc = Provider.of<DoctorProvider>(context, listen: false).name;
    final iters = Provider.of<DoctorProvider>(
      context,
      listen: false,
    ).iterations;
    final sessionId = '${doc}_$iters';
    final iteration = _sequence[idx].iteration;

    // RegionSelector widget
    final regionSelector = RegionSelector(
      key: _regionKey,
      enabled: _isSelectionMode,
      imagePath: img,
      onComplete: _handleRegionComplete,
      onOverlapDetected: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot select overlapping areas. Please select a different region.',
            ),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      },
      samplingTolerance: 6.0,
      doctorName: doc,
      fileName: img,
      iteration: iteration,
      mode: 'continuous',
      sessionId: sessionId,
      child: Image.asset(img),
    );

    // Region saved message
    final regionSavedMessage = _showRegionSavedMsg
        ? Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: AnimatedOpacity(
              opacity: _showRegionSavedMsg ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Region saved!',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          )
        : null;

    // Navigation buttons
    final navigationButtons = Padding(
      padding: const EdgeInsets.only(left: 32, right: 32, bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: idx > 0
                ? () async {
                    setState(() {
                      idx--;
                      _selectedSlider = null;
                      _sliderValue0 = 0.0;
                      _sliderValue1 = 0.0;
                      _sliderValue2 = 0.0;
                      // Reset ambient light tracking for new image
                      _currentImageKey = null;
                      _savedLuxForCurrentImage = null;
                    });
                    final doc = Provider.of<DoctorProvider>(
                      context,
                      listen: false,
                    ).name;
                    final iters = Provider.of<DoctorProvider>(
                      context,
                      listen: false,
                    ).iterations;
                    final idxKey = 'lastContinuousIdx_${doc}_$iters';
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt(idxKey, idx);
                    _loadEvent();
                  }
                : null,
            child: Card(
              elevation: AppConstants.cardElevation,
              color: AppConstants.cardBackgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppConstants.cardBorderRadius,
                ),
              ),
              child: SizedBox(
                height: AppConstants.standardCardHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Center(
                    child: Text(
                      'Previous',
                      style: TextStyle(
                        fontSize: 16,
                        color: idx > 0
                            ? Colors.deepPurple
                            : Colors.deepPurple.withValues(alpha: 0.4),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          // Sliders in the middle
          if (_isSelectionMode) ...[
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppConstants.cardBorderRadius,
                ),
              ),
              child: Container(
                width: 200,
                height: 70,
                padding: const EdgeInsets.all(4),
                child: _buildStyledSlider(
                  0,
                  _koreanColor['Pale']!,
                  _koreanColor['Pink']!,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppConstants.cardBorderRadius,
                ),
              ),
              child: Container(
                width: 200,
                height: 70,
                padding: const EdgeInsets.all(4),
                child: _buildStyledSlider(
                  1,
                  _koreanColor['Pink']!,
                  _koreanColor['Red']!,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppConstants.cardBorderRadius,
                ),
              ),
              child: Container(
                width: 200,
                height: 70,
                padding: const EdgeInsets.all(4),
                child: _buildStyledSlider(
                  2,
                  _koreanColor['Red']!,
                  _koreanColor['DeepRed']!,
                ),
              ),
            ),
          ],
          const Spacer(),
          GestureDetector(
            onTap: () => _handleNext(total),
            child: Card(
              elevation: AppConstants.cardElevation,
              color: AppConstants.cardBackgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppConstants.cardBorderRadius,
                ),
              ),
              child: SizedBox(
                height: AppConstants.standardCardHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Center(
                    child: Text(
                      'Next',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final appBarContent = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: User info card
        UserInfoCard(
          userName: doc,
          iterations: iters,
          mode: 'continuous',
          currentIndex: idx,
          totalImages: total,
        ),
        const Spacer(),
        // Center: ModeToolbar
        ModeToolbar(
          isSelectionMode: _isSelectionMode,
          onToggleMode: () async {
            setState(() {
              _isSelectionMode = !_isSelectionMode;
              if (!_isSelectionMode) {
                _regionKey.currentState?.clearSelection();
              }
            });
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('continuousIsSelectionMode', _isSelectionMode);
            // If switching to selection mode, reload regions for current image
            if (_isSelectionMode) {
              await _loadEvent();
            }
          },
          onUndo: _isSelectionMode ? _undoLastShape : null,
        ),
        const Spacer(),
        // Right: Actions card with 6 icons
        AppBarActionsCard(
          onDownload: () async {
            try {
              final doc = Provider.of<DoctorProvider>(
                context,
                listen: false,
              ).name;
              final iters = Provider.of<DoctorProvider>(
                context,
                listen: false,
              ).iterations;
              final sessionId = '${doc}_$iters';
              final events = await ContinuousDbService.fetchEvents();
              final regions = await ContinuousDbService.fetchRegions();
              // Group regions by image/iteration
              Map<String, List<RegionSelection>> regionMap = {};
              for (var r in regions) {
                if (r.sessionId == sessionId) {
                  final key = '${r.fileName}_${r.iteration}';
                  regionMap.putIfAbsent(key, () => []).add(r);
                }
              }
              // Prepare CSV rows
              List<List<String>> rows = [];
              // Header
              int maxRegions = regionMap.values.fold(
                0,
                (prev, list) => list.length > prev ? list.length : prev,
              );
              List<String> header = [
                'Image Name',
                'Time',
                'Color A',
                'Percent A',
                'Color B',
                'Percent B',
                'Ambient Light (Lux)',
              ];
              for (int i = 0; i < maxRegions; i++) {
                header.add('Region ${i + 1}');
              }
              rows.add(header);
              // Data rows
              for (var e in events) {
                if (e.sessionId != sessionId) continue;
                final key = '${e.fileName}_${e.iteration}';
                final regionList = regionMap[key] ?? [];
                List<String> row = [
                  e.fileName,
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(e.timestamp),
                  e.colorA,
                  e.percentA.toStringAsFixed(2),
                  e.colorB,
                  e.percentB.toStringAsFixed(2),
                  e.ambientLux?.toString() ?? 'N/A',
                ];
                for (var r in regionList) {
                  row.add(r.pathJson);
                }
                // Pad with empty strings if fewer regions
                while (row.length < header.length) {
                  row.add('');
                }
                rows.add(row);
              }
              // Convert to CSV string
              String csv = rows
                  .map(
                    (r) =>
                        r.map((v) => '"${v.replaceAll('"', '""')}"').join(','),
                  )
                  .join('\n');
              // Get Downloads directory
              final now = DateTime.now();
              final fileName =
                  'continuous_${doc}_$sessionId${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';
              final downloadsPath = await DownloadsPath.getDownloadsDirectory();
              if (downloadsPath == null) {
                throw Exception('Downloads directory not found');
              }
              final file = File('$downloadsPath/$fileName');
              await file.writeAsString(csv);
              // Show dialog with both actions
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Export Complete'),
                    content: Text('Exported to ${file.path}'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          OpenFile.open(file.path);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Open File'),
                      ),
                      TextButton(
                        onPressed: () {
                          OpenFile.open(downloadsPath);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Open Folder'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
              }
            }
          },
          otherIcons: [
            IconButton(
              icon: const Icon(Icons.visibility, color: Colors.deepPurple),
              tooltip: 'Preview Regions',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegionPreviewScreen(
                      fileName: img,
                      doctorName: doc,
                      iteration: iteration,
                      mode: 'continuous',
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.storage, color: Colors.deepPurple),
              tooltip: 'View DB',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ContinuousDatabaseViewScreen(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.grid_on, color: Colors.deepPurple),
              tooltip: 'Switch to Discrete Mode',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LabelScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.deepPurple),
              tooltip: 'Reset Database',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete all data?'),
                    content: const Text(
                      'This will permanently delete all labeling and region data for Continuous mode. Are you sure?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ContinuousDbService.clearAllData();
                  if (mounted) {
                    setState(() {
                      _sliderValue0 = 0.0;
                      _sliderValue1 = 0.0;
                      _sliderValue2 = 0.0;
                      _selectedSlider = null;
                    });
                    _regionKey.currentState?.clearSelection();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Continuous mode database cleared.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.deepPurple),
              tooltip: 'Logout',
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('currentUser');
                await prefs.remove('currentIterations');
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ],
    );

    return LabelingScreenScaffold(
      appBarContent: appBarContent,
      regionSelector: regionSelector,
      regionSavedMessage: regionSavedMessage,
      modeControls: const SizedBox.shrink(),
      navigationButtons: navigationButtons,
      imageBoxWidth: 400,
      imageBoxAspectRatio: 0.9, // Make image slightly less tall
      topSpacing: 24,
      controlsSpacing: 18,
    );
  }

  Widget _buildStyledSlider(int idx, String left, String right) {
    final isActive = _selectedSlider == idx;
    double value = 0.0;
    if (idx == 0) value = _sliderValue0;
    if (idx == 1) value = _sliderValue1;
    if (idx == 2) value = _sliderValue2;

    // Simplified marks to prevent overflow
    final List<String> marks = ['-50', '-25', '0', '+25', '+50'];
    final int divisions = 100; // Keep fine control

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color indicators row
          Row(
            children: [
              _buildImprovedColorBall(
                left,
                1 - value,
                isActive: isActive,
                isLeft: true,
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Custom pointed slider
                      SizedBox(
                        height: 40,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: isActive
                                ? Colors.deepPurple
                                : Colors.grey[300],
                            inactiveTrackColor: Colors.grey[200],
                            trackHeight: 8.0,
                            thumbColor: isActive
                                ? Colors.deepPurple
                                : Colors.grey[400],
                            thumbShape: CustomPointedThumbShape(
                              enabledThumbRadius: 16.0,
                              isActive: isActive,
                            ),
                            overlayColor: isActive
                                ? Colors.deepPurple.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.05),
                            trackShape: CustomRoundedRectSliderTrackShape(),
                          ),
                          child: Slider(
                            value: value,
                            onChanged: (v) {
                              setState(() {
                                if (idx == 0) _sliderValue0 = v;
                                if (idx == 1) _sliderValue1 = v;
                                if (idx == 2) _sliderValue2 = v;
                              });
                            },
                            onChangeStart: (v) async {
                              // Clear previous selection logic (keep your existing logic)
                              if (_selectedSlider != null &&
                                  _selectedSlider != idx) {
                                String prevColorA = '', prevColorB = '';
                                if (_selectedSlider == 0) {
                                  prevColorA = 'Pale';
                                  prevColorB = 'Pink';
                                } else if (_selectedSlider == 1) {
                                  prevColorA = 'Pink';
                                  prevColorB = 'Red';
                                } else if (_selectedSlider == 2) {
                                  prevColorA = 'Red';
                                  prevColorB = 'DeepRed';
                                }

                                final doc = Provider.of<DoctorProvider>(
                                  context,
                                  listen: false,
                                ).name;
                                final iters = Provider.of<DoctorProvider>(
                                  context,
                                  listen: false,
                                ).iterations;
                                final sessionId = '${doc}_$iters';
                                final img = _sequence[this.idx].fileName;
                                final iteration = _sequence[this.idx].iteration;

                                setState(() {
                                  if (_selectedSlider == 0) _sliderValue0 = 0.0;
                                  if (_selectedSlider == 1) _sliderValue1 = 0.0;
                                  if (_selectedSlider == 2) _sliderValue2 = 0.0;
                                });

                                await ContinuousDbService.deleteEvent(
                                  doctorName: doc,
                                  fileName: img,
                                  iteration: iteration,
                                  colorA: prevColorA,
                                  colorB: prevColorB,
                                  sessionId: sessionId,
                                );
                              }

                              setState(() {
                                _selectedSlider = idx;
                              });
                            },
                            onChangeEnd: (v) async {
                              await _saveOrUpdateColorEvent(idx, v);
                            },
                            min: 0.0,
                            max: 1.0,
                            divisions: divisions,
                          ),
                        ),
                      ),
                      // Simplified scale labels
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: marks
                            .map(
                              (mark) => Text(
                                mark,
                                style: TextStyle(
                                  fontSize: 8,
                                  color: isActive
                                      ? Colors.deepPurple.withValues(alpha: 0.8)
                                      : Colors.grey[400],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              _buildImprovedColorBall(
                right,
                value,
                isActive: isActive,
                isLeft: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImprovedColorBall(
    String colorName,
    double percent, {
    bool isActive = true,
    bool isLeft = true,
  }) {
    final double minSize = 24;
    final double maxSize = 36;
    final double size = minSize + (maxSize - minSize) * percent;

    final Color fillColor = isActive
        ? Colors.deepPurple.withValues(alpha: 0.1 + 0.8 * percent)
        : Colors.grey[200]!;
    final Color borderColor = isActive
        ? Colors.deepPurple.withValues(alpha: 0.3 + 0.7 * percent)
        : Colors.grey[300]!;
    final Color textColor = isActive ? Colors.deepPurple : Colors.grey[500]!;

    return Container(
      width: 40, // Fixed width to prevent layout shifts
      height: 40,
      alignment: Alignment.center,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fillColor,
          border: Border.all(color: borderColor, width: 2),
          shape: BoxShape.circle,
          boxShadow: isActive && percent > 0.3
              ? [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.2),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: Text(
              colorName,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class ImageIteration {
  final String fileName;
  final int iteration;
  ImageIteration(this.fileName, this.iteration);
}

// Custom thumb shape for pointed slider - FIXED METHOD SIGNATURE
class CustomPointedThumbShape extends SliderComponentShape {
  final double enabledThumbRadius;
  final bool isActive;

  const CustomPointedThumbShape({
    required this.enabledThumbRadius,
    required this.isActive,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(enabledThumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final paint = Paint()
      ..color = isActive ? Colors.deepPurple : Colors.grey[400]!
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    // Draw shadow
    if (isActive) {
      final shadowPath = _createDiamondPath(
        center + const Offset(1, 1),
        enabledThumbRadius - 2,
      );
      canvas.drawPath(shadowPath, shadowPaint);
    }

    // Draw diamond/pointed shape
    final path = _createDiamondPath(center, enabledThumbRadius - 2);
    canvas.drawPath(path, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = isActive ? Colors.white : Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, borderPaint);
  }

  Path _createDiamondPath(Offset center, double radius) {
    final path = Path();
    path.moveTo(center.dx, center.dy - radius); // Top point
    path.lineTo(center.dx + radius, center.dy); // Right point
    path.lineTo(center.dx, center.dy + radius); // Bottom point
    path.lineTo(center.dx - radius, center.dy); // Left point
    path.close();
    return path;
  }
}

// Custom track shape with rounded ends - FIXED METHOD SIGNATURE
class CustomRoundedRectSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    if (sliderTheme.trackHeight == null || sliderTheme.trackHeight! <= 0) {
      return;
    }

    final activeTrackColor = sliderTheme.activeTrackColor!;
    final inactiveTrackColor = sliderTheme.inactiveTrackColor!;
    final Paint activePaint = Paint()..color = activeTrackColor;
    final Paint inactivePaint = Paint()..color = inactiveTrackColor;

    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final radius = trackRect.height / 2;

    // Draw inactive track
    final inactiveRRect = RRect.fromRectAndRadius(
      trackRect,
      Radius.circular(radius),
    );
    context.canvas.drawRRect(inactiveRRect, inactivePaint);

    // Draw active track
    final activeRect = Rect.fromLTRB(
      trackRect.left,
      trackRect.top,
      thumbCenter.dx,
      trackRect.bottom,
    );
    if (activeRect.width > 0) {
      final activeRRect = RRect.fromRectAndRadius(
        activeRect,
        Radius.circular(radius),
      );
      context.canvas.drawRRect(activeRRect, activePaint);
    }
  }
}
