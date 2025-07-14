import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:path/path.dart' as p;
import 'package:light/light.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/doctor_provider.dart';
import '../services/discrete_db_service.dart';
import '../widgets/region_selector.dart';
import 'preview_screen.dart';
import 'continuous_mode_screen.dart';

// Import with prefix to avoid conflicts
import '../services/db_service.dart' show LabelEvent, RegionSelection;

/// Map each English color to its single Korean label.
const Map<String, String> _koreanColor = {
  'Pale': '백색',
  'Pink': '담홍색',
  'Red': '홍색',
  'DeepRed': '강홍색',
};

class ImageIteration {
  final String fileName;
  final int iteration;
  ImageIteration(this.fileName, this.iteration);
}

class LabelScreen extends StatefulWidget {
  const LabelScreen({super.key});

  @override
  _LabelScreenState createState() => _LabelScreenState();
}

class _LabelScreenState extends State<LabelScreen> {
  List<ImageIteration> _sequence = [];
  int idx = 0;
  LabelEvent? currentEvent;

  /// toggle between view and selection
  bool _isSelectionMode = false;

  /// so we can clear the stroke when changing images or exiting selection mode
  final GlobalKey<RegionSelectorState> _regionKey =
      GlobalKey<RegionSelectorState>();

  // Add for fading region saved message
  bool _showRegionSavedMsg = false;

  // Add a state field for the warning
  bool _showNextWarning = false;

  // Ambient light sensor
  Light? _light;
  StreamSubscription<int>? _lightSubscription;
  int? _currentLux;

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

  @override
  void dispose() {
    _lightSubscription?.cancel();
    super.dispose();
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

  void _undoLastShape() {
    if (_regionKey.currentState != null) {
      final success = _regionKey.currentState!.undoLastStroke();
      if (!success) {
        // No shapes to undo
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No shapes to undo'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _buildSequence() async {
    final base = List.generate(
      2000,
      (i) => 'assets/images/${(i + 1).toString().padLeft(4, '0')}.png',
    );
    final iters = context.read<DoctorProvider>().iterations;
    final prefs = await SharedPreferences.getInstance();
    final doc = context.read<DoctorProvider>().name;
    final seqKey = 'labelingSequence_${doc}_$iters';
    final savedSeq = prefs.getString(seqKey);
    if (savedSeq != null) {
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
    debugPrint(
      'First 3 image paths: ${_sequence.take(3).map((e) => '${e.fileName} (iter ${e.iteration})').toList()}',
    );
  }

  Future<void> _loadEvent() async {
    final doc = context.read<DoctorProvider>().name;
    final iters = context.read<DoctorProvider>().iterations;
    final sessionId = '${doc}_$iters';
    final all = await DiscreteDbService.fetchEvents();
    final match = all.where(
      (e) =>
          e.sessionId == sessionId &&
          e.fileName == _sequence[idx].fileName &&
          e.iteration == _sequence[idx].iteration,
    );
    setState(() => currentEvent = match.isEmpty ? null : match.first);
    // Load regions after first frame
    final regions = await DiscreteDbService.fetchRegions();
    final currentImageRegions = regions
        .where(
          (r) =>
              r.sessionId == sessionId &&
              r.fileName == _sequence[idx].fileName &&
              r.iteration == _sequence[idx].iteration,
        )
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _regionKey.currentState?.loadExistingRegions(currentImageRegions);
    });
  }

  Future<void> _loadExistingRegions() async {
    final doc = context.read<DoctorProvider>().name;
    final regions = await DiscreteDbService.fetchRegions();
    final currentImageRegions = regions
        .where(
          (r) =>
              r.doctorName == doc &&
              r.fileName == _sequence[idx].fileName &&
              r.iteration == _sequence[idx].iteration,
        )
        .toList();
    _regionKey.currentState?.loadExistingRegions(currentImageRegions);
  }

  Future<void> _onColorTap(String color) async {
    final doc = context.read<DoctorProvider>().name;
    final iters = context.read<DoctorProvider>().iterations;
    final sessionId = '${doc}_$iters';
    if (currentEvent == null) {
      await DiscreteDbService.insertEvent(
        LabelEvent(
          doctorName: doc,
          fileName: _sequence[idx].fileName,
          color: color,
          iteration: _sequence[idx].iteration,
          timestamp: DateTime.now(),
          ambientLux: _currentLux,
          sessionId: sessionId,
        ),
      );
    } else {
      await DiscreteDbService.updateEvent(currentEvent!.id!, color);
    }
    await _loadEvent();
  }

  Future<void> _onRegionComplete(List<Offset> poly) async {
    if (!_isSelectionMode || poly.isEmpty) return;
    final doc = context.read<DoctorProvider>().name;
    final iters = context.read<DoctorProvider>().iterations;
    final sessionId = '${doc}_$iters';
    final jsonPoly = jsonEncode(
      poly.map((o) => {'x': o.dx, 'y': o.dy}).toList(),
    );
    await DiscreteDbService.insertRegion(
      RegionSelection(
        doctorName: doc,
        fileName: _sequence[idx].fileName,
        pathJson: jsonPoly,
        iteration: _sequence[idx].iteration,
        timestamp: DateTime.now(),
        ambientLux: _currentLux,
        sessionId: sessionId,
      ),
    );
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
    setState(() {});
  }

  void _onOverlapDetected() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Cannot select overlapping areas. Please select a different region.',
        ),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _buildImageWidget(String imagePath) {
    return Image.asset(
      imagePath,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 48, color: Colors.red),
                SizedBox(height: 8),
                Text('Image not found'),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _canGoNext {
    final hasColor = currentEvent?.color != null;
    final hasRegion =
        _regionKey.currentState?.strokeCount != null &&
        _regionKey.currentState!.strokeCount > 0;
    return hasColor && hasRegion;
  }

  void _handleNext(int total) {
    if (_isSelectionMode) {
      if (_canGoNext && idx < total - 1) {
        setState(() {
          idx++;
        });
        final doc = context.read<DoctorProvider>().name;
        final iters = context.read<DoctorProvider>().iterations;
        final idxKey = 'lastDiscreteIdx_${doc}_$iters';
        SharedPreferences.getInstance().then((prefs) {
          prefs.setInt(idxKey, idx);
        });
        _loadEvent();
      } else {
        // Show warning message for 1.5 seconds
        setState(() {
          _showNextWarning = true;
        });
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _showNextWarning = false;
            });
          }
        });
      }
    } else {
      // In view mode, always allow next if not at the end
      if (idx < total - 1) {
        setState(() {
          idx++;
        });
        final doc = context.read<DoctorProvider>().name;
        final iters = context.read<DoctorProvider>().iterations;
        final idxKey = 'lastDiscreteIdx_${doc}_$iters';
        SharedPreferences.getInstance().then((prefs) {
          prefs.setInt(idxKey, idx);
        });
        _loadEvent();
      }
    }
  }

  Future<void> _loadLastIndexAndEvent() async {
    final prefs = await SharedPreferences.getInstance();
    final doc = context.read<DoctorProvider>().name;
    final iters = context.read<DoctorProvider>().iterations;
    final idxKey = 'lastDiscreteIdx_${doc}_$iters';
    final lastIdx = prefs.getInt(idxKey) ?? 0;
    final lastMode = prefs.getBool('discreteIsSelectionMode') ?? false;
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

  @override
  Widget build(BuildContext context) {
    if (_sequence.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final total = _sequence.length;
    final doc = context.watch<DoctorProvider>().name;
    final iters = context.watch<DoctorProvider>().iterations;
    final sessionId = '${doc}_$iters';
    final img = _sequence[idx].fileName;
    final iteration = _sequence[idx].iteration;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('[$doc] ${idx + 1}/$total'),
            Text('Session: $sessionId', style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          // ← New Preview button
          IconButton(
            icon: const Icon(Icons.visibility),
            tooltip: 'Preview Regions',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RegionPreviewScreen(
                    fileName: img,
                    doctorName: doc,
                    iteration: iteration,
                    mode: 'discrete',
                  ),
                ),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.storage),
            tooltip: 'View DB',
            onPressed: () => Navigator.pushNamed(context, '/db'),
          ),
          IconButton(
            icon: const Icon(Icons.timeline),
            tooltip: 'Switch to Continuous Mode',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContinuousModeScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Reset Database',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset Database'),
                  content: const Text(
                    'Are you sure you want to delete ALL labeling data on this device? This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await DiscreteDbService.clearAllData();
                setState(() {
                  idx = 0;
                  currentEvent = null;
                  _regionKey.currentState?.clearSelection();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Database reset! All data deleted.'),
                  ),
                );
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
            // Selection / View mode toggle + image/selector
            Expanded(
              child: Column(
                children: [
                  Container(
                    color: _isSelectionMode
                        ? Colors.orange[100]
                        : Colors.blue[100],
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isSelectionMode ? Icons.touch_app : Icons.visibility,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isSelectionMode ? 'Selection Mode' : 'View Mode',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          icon: Icon(
                            _isSelectionMode
                                ? Icons.visibility
                                : Icons.touch_app,
                          ),
                          label: Text(_isSelectionMode ? 'View' : 'Select'),
                          onPressed: () async {
                            setState(() {
                              _isSelectionMode = !_isSelectionMode;
                              if (!_isSelectionMode) {
                                _regionKey.currentState?.clearSelection();
                              }
                            });
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(
                              'discreteIsSelectionMode',
                              _isSelectionMode,
                            );
                          },
                        ),
                        // NEW: Add the Undo button only in selection mode
                        if (_isSelectionMode) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.undo),
                            label: const Text('Undo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[300],
                            ),
                            onPressed: _undoLastShape,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        RegionSelector(
                          key: _regionKey,
                          enabled: _isSelectionMode,
                          imagePath: img,
                          onComplete: _onRegionComplete,
                          onOverlapDetected: _onOverlapDetected,
                          samplingTolerance: 6.0,
                          child: _buildImageWidget(img),
                          doctorName: doc,
                          fileName: img,
                          iteration: iteration,
                          mode: 'discrete',
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
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Color-selection buttons
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _koreanColor.entries.map((e) {
                    final eng = e.key;
                    final kor = e.value;
                    final selected = currentEvent?.color == eng;
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selected ? Colors.blueAccent : null,
                      ),
                      onPressed: () => _onColorTap(eng),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(eng),
                          Text('($kor)', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 12),

            // Previous / Next
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: idx > 0
                            ? () {
                                setState(() {
                                  idx--;
                                });
                                final doc = context.read<DoctorProvider>().name;
                                final iters = context
                                    .read<DoctorProvider>()
                                    .iterations;
                                final idxKey = 'lastDiscreteIdx_${doc}_$iters';
                                SharedPreferences.getInstance().then((prefs) {
                                  prefs.setInt(idxKey, idx);
                                });
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
                  if (_isSelectionMode && _showNextWarning)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Please select a color and draw at least one region to continue.',
                        style: TextStyle(color: Colors.red[700], fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
