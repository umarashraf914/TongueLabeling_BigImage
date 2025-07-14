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
  // Remove _loadedRegions and _checkOverlapWithLoadedRegions logic
  // Add state for warning
  bool _showNextWarning = false;

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  Future<void> _initAsync() async {
    await _buildSequence();
    await _loadLastIndexAndEvent();
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
      (i) => 'assets/images/' + (i + 1).toString().padLeft(4, '0') + '.png',
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
    final sessionId = '${doc}_${iters}';
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
    // No need to update _loadedRegions
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

  void _onSliderTap(int sliderIdx) async {
    setState(() {
      _selectedSlider = sliderIdx;
      _sliderValue0 = 0.0;
      _sliderValue1 = 0.0;
      _sliderValue2 = 0.0;
    });
    await _saveOrUpdateColorEvent(sliderIdx, 0.0);
  }

  Future<void> _saveOrUpdateColorEvent(int sliderIdx, double value) async {
    final doc = Provider.of<DoctorProvider>(context, listen: false).name;
    final iters = Provider.of<DoctorProvider>(
      context,
      listen: false,
    ).iterations;
    final sessionId = '${doc}_${iters}';
    final img = _sequence[this.idx].fileName;
    final iteration = _sequence[this.idx].iteration;
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
      ambientLux: null,
      colorA: colorA,
      percentA: 100 - (value * 100),
      colorB: colorB,
      percentB: value * 100,
      sessionId: sessionId,
    );
    await ContinuousDbService.insertEvent(event);
  }

  void _onSliderChange(int idx, double value) {
    setState(() {
      _selectedSlider = idx;
      if (idx == 0) _sliderValue0 = value;
      if (idx == 1) _sliderValue1 = value;
      if (idx == 2) _sliderValue2 = value;
    });
    _saveOrUpdateColorEvent(idx, value);
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
      final sessionId = '${doc}_${iters}';
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
        setState(() {
          _showNextWarning = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showNextWarning = false;
            });
          }
        });
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
      });
      final doc = Provider.of<DoctorProvider>(context, listen: false).name;
      final iters = Provider.of<DoctorProvider>(
        context,
        listen: false,
      ).iterations;
      final sessionId = '${doc}_${iters}';
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
    final sessionId = '${doc}_${iters}';
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

  // Remove _checkOverlapWithLoadedRegions and related code
  // Remove _isPointInPolygon and _doPolygonsIntersect and related code
  // Remove _doLinesIntersect and related code

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
    final sessionId = '${doc}_${iters}';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('[Continuous]  ${idx + 1}/$total'),
            Text('Session: $sessionId', style: const TextStyle(fontSize: 13)),
          ],
        ),
        centerTitle: false,
        flexibleSpace: Center(
          child: Padding(
            padding: const EdgeInsets.only(
              top: 38.0,
            ), // adjust as needed for vertical alignment
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.touch_app, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Selection Mode',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 28,
                  child: ElevatedButton.icon(
                    icon: Icon(
                      _isSelectionMode ? Icons.visibility : Icons.touch_app,
                      size: 16,
                    ),
                    label: Text(
                      _isSelectionMode ? 'View' : 'Select',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () async {
                      setState(() {
                        _isSelectionMode = !_isSelectionMode;
                        if (!_isSelectionMode) {
                          _regionKey.currentState?.clearSelection();
                        }
                      });
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(
                        'continuousIsSelectionMode',
                        _isSelectionMode,
                      );
                    },
                  ),
                ),
                if (_isSelectionMode) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 28,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Undo', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[300],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 0,
                        ),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _undoLastShape,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility),
            tooltip: 'Preview Regions',
            onPressed: () {
              final doc = Provider.of<DoctorProvider>(
                context,
                listen: false,
              ).name;
              final iteration = _sequence[idx].iteration;
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
            icon: const Icon(Icons.storage),
            tooltip: 'View DB',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ContinuousDatabaseViewScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.grid_on),
            tooltip: 'Switch to Discrete Mode',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LabelScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
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
                    // _loadedRegions = []; // No longer needed
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
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('currentUser');
              await prefs.remove('currentIterations');
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 25), // Space between AppBar and image
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 320,
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Stack(
                          children: [
                            RegionSelector(
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
                              }, // match discrete mode
                              samplingTolerance: 6.0,
                              child: Image.asset(img),
                              doctorName: Provider.of<DoctorProvider>(
                                context,
                                listen: false,
                              ).name,
                              fileName: img,
                              iteration: _sequence[idx].iteration,
                              mode: 'continuous',
                              sessionId: sessionId,
                            ),
                            if (_showRegionSavedMsg)
                              Positioned(
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
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Text(
                                        'Region saved!',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 25,
                    ), // Space between image and sliders
                    if (_isSelectionMode) ...[
                      // Three sliders in a horizontal row below the image, each in its own card
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: SizedBox(
                              width: 220,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 6,
                                ),
                                child: _buildStyledSlider(
                                  0,
                                  'Pale',
                                  'Pink',
                                  labelFontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: SizedBox(
                              width: 220,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 6,
                                ),
                                child: _buildStyledSlider(
                                  1,
                                  'Pink',
                                  'Red',
                                  labelFontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: SizedBox(
                              width: 220,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 6,
                                ),
                                child: _buildStyledSlider(
                                  2,
                                  'Red',
                                  'DeepRed',
                                  labelFontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: idx > 0
                        ? () async {
                            setState(() {
                              idx--;
                              _selectedSlider = null;
                              _sliderValue0 = 0.0;
                              _sliderValue1 = 0.0;
                              _sliderValue2 = 0.0;
                            });
                            final doc = Provider.of<DoctorProvider>(
                              context,
                              listen: false,
                            ).name;
                            final iters = Provider.of<DoctorProvider>(
                              context,
                              listen: false,
                            ).iterations;
                            final sessionId = '${doc}_${iters}';
                            final idxKey = 'lastContinuousIdx_${doc}_$iters';
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setInt(idxKey, idx);
                            _loadEvent();
                          }
                        : null,
                    child: const Text('Previous'),
                  ),
                  TextButton(
                    onPressed: () => _handleNext(total),
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
            if (_isSelectionMode && _showNextWarning)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Please select a color and draw at least one region to continue.',
                  style: TextStyle(color: Colors.red[700], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderBox() {
    // No longer used in new layout
    return const SizedBox.shrink();
  }

  // Widget _buildStyledSlider(
  //   int idx,
  //   String left,
  //   String right, {
  //   double labelFontSize = 14,
  // }) {
  //   final isActive = _selectedSlider == idx;
  //   double value = 0.0;
  //   if (idx == 0) value = _sliderValue0;
  //   if (idx == 1) value = _sliderValue1;
  //   if (idx == 2) value = _sliderValue2;
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.stretch,
  //     children: [
  //       Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //         children: [
  //           Text(
  //             left,
  //             style: TextStyle(
  //               fontWeight: FontWeight.bold,
  //               fontSize: labelFontSize,
  //             ),
  //           ),
  //           Text(
  //             right,
  //             style: TextStyle(
  //               fontWeight: FontWeight.bold,
  //               fontSize: labelFontSize,
  //             ),
  //           ),
  //         ],
  //       ),
  //       GestureDetector(
  //         behavior: HitTestBehavior.translucent,
  //         onTap: () {
  //           setState(() {
  //             _selectedSlider = idx;
  //           });
  //         },
  //         child: SliderTheme(
  //           data: SliderTheme.of(context).copyWith(
  //             activeTrackColor: isActive ? Colors.deepPurple : Colors.grey[300],
  //             inactiveTrackColor: Colors.grey[200],
  //             trackHeight: 6.0,
  //             thumbColor: isActive ? Colors.pink : Colors.grey[400],
  //             thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
  //             overlayColor: isActive
  //                 ? Colors.pink.withOpacity(0.2)
  //                 : Colors.transparent,
  //             valueIndicatorColor: Colors.deepPurple,
  //           ),
  //           child: Slider(
  //             value: value,
  //             onChanged: isActive
  //                 ? (v) {
  //                     setState(() {
  //                       if (idx == 0) _sliderValue0 = v;
  //                       if (idx == 1) _sliderValue1 = v;
  //                       if (idx == 2) _sliderValue2 = v;
  //                     });
  //                   }
  //                 : null,
  //             onChangeStart: (_) async {
  //               if (!isActive && _selectedSlider != null) {
  //                 String prevColorA = '', prevColorB = '';
  //                 if (_selectedSlider == 0) {
  //                   prevColorA = 'Pale';
  //                   prevColorB = 'Pink';
  //                 } else if (_selectedSlider == 1) {
  //                   prevColorA = 'Pink';
  //                   prevColorB = 'Red';
  //                 } else if (_selectedSlider == 2) {
  //                   prevColorA = 'Red';
  //                   prevColorB = 'DeepRed';
  //                 }
  //                 final doc = Provider.of<DoctorProvider>(
  //                   context,
  //                   listen: false,
  //                 ).name;
  //                 final iters = Provider.of<DoctorProvider>(
  //                   context,
  //                   listen: false,
  //                 ).iterations;
  //                 final sessionId = '${doc}_${iters}';
  //                 final img = _sequence[idx].fileName;
  //                 final iteration = _sequence[idx].iteration;
  //                 setState(() {
  //                   if (_selectedSlider == 0) _sliderValue0 = 0.0;
  //                   if (_selectedSlider == 1) _sliderValue1 = 0.0;
  //                   if (_selectedSlider == 2) _sliderValue2 = 0.0;
  //                 });
  //                 await ContinuousDbService.deleteEvent(
  //                   doctorName: doc,
  //                   fileName: img,
  //                   iteration: iteration,
  //                   colorA: prevColorA,
  //                   colorB: prevColorB,
  //                   sessionId: sessionId,
  //                 );
  //               }
  //               setState(() {
  //                 _selectedSlider = idx;
  //               });
  //             },
  //             onChangeEnd: isActive
  //                 ? (v) async {
  //                     await _saveOrUpdateColorEvent(idx, v);
  //                   }
  //                 : null,
  //             min: 0.0,
  //             max: 1.0,
  //             divisions: 100,
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }
  Widget _buildStyledSlider(
    int idx,
    String left,
    String right, {
    double labelFontSize = 14,
  }) {
    final isActive = _selectedSlider == idx;
    double value = 0.0;
    if (idx == 0) value = _sliderValue0;
    if (idx == 1) value = _sliderValue1;
    if (idx == 2) value = _sliderValue2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              left,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: labelFontSize,
              ),
            ),
            Text(
              right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: labelFontSize,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: isActive ? Colors.deepPurple : Colors.grey[400],
            inactiveTrackColor: Colors.grey[200],
            trackHeight: 6.0,
            thumbColor: isActive ? Colors.pink : Colors.grey[500],
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayColor: isActive
                ? Colors.pink.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            valueIndicatorColor: Colors.deepPurple,
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
              // Clear previous selection and reset other sliders
              if (_selectedSlider != null && _selectedSlider != idx) {
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
                final sessionId = '${doc}_${iters}';
                final img = _sequence[this.idx].fileName;
                final iteration = _sequence[this.idx].iteration;

                // Reset the previous slider value
                setState(() {
                  if (_selectedSlider == 0) _sliderValue0 = 0.0;
                  if (_selectedSlider == 1) _sliderValue1 = 0.0;
                  if (_selectedSlider == 2) _sliderValue2 = 0.0;
                });

                // Delete previous event from database
                await ContinuousDbService.deleteEvent(
                  doctorName: doc,
                  fileName: img,
                  iteration: iteration,
                  colorA: prevColorA,
                  colorB: prevColorB,
                  sessionId: sessionId,
                );
              }

              // Set current slider as selected
              setState(() {
                _selectedSlider = idx;
              });
            },
            onChangeEnd: (v) async {
              await _saveOrUpdateColorEvent(idx, v);
            },
            min: 0.0,
            max: 1.0,
            divisions: 100,
          ),
        ),
      ],
    );
  }

  Widget _buildSliderPercentagesCard() {
    // No longer used in new layout
    return const SizedBox.shrink();
  }
}

class ImageIteration {
  final String fileName;
  final int iteration;
  ImageIteration(this.fileName, this.iteration);
}
