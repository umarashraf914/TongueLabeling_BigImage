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

class ContinuousModeScreen extends StatefulWidget {
  const ContinuousModeScreen({super.key});

  @override
  State<ContinuousModeScreen> createState() => _ContinuousModeScreenState();
}

class _ContinuousModeScreenState extends State<ContinuousModeScreen> {
  bool _isSelectionMode = false;
  int idx = 0;
  late final List<ImageIteration> _sequence;
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
    _buildSequence();
    _loadEvent();
  }

  void _buildSequence() {
    final base = List.generate(
      2000,
      (i) => 'assets/images/' + (i + 1).toString().padLeft(4, '0') + '.png',
    );
    final iters = 1; // Only 1 iteration for continuous mode
    _sequence = [
      for (var n = 1; n <= iters; n++)
        for (var img in base) ImageIteration(img, n),
    ];
  }

  Future<void> _loadEvent() async {
    final doc = Provider.of<DoctorProvider>(context, listen: false).name;
    final img = _sequence[idx].fileName;
    final iteration = _sequence[idx].iteration;
    // Load regions
    final regions = await ContinuousDbService.fetchRegions();
    final currentImageRegions = regions
        .where(
          (r) =>
              r.doctorName == doc &&
              r.fileName == img &&
              r.iteration == iteration,
        )
        .toList();
    _regionKey.currentState?.loadExistingRegions(currentImageRegions);
    // No need to update _loadedRegions
    // Load last color event
    final events = await ContinuousDbService.fetchEvents();
    final matchingEvents = events
        .where(
          (e) =>
              e.doctorName == doc &&
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
    final img = _sequence[this.idx].fileName;
    final iteration = _sequence[this.idx].iteration;
    // Delete all previous events for this image/iteration
    await ContinuousDbService.deleteAllEventsForImage(
      doctorName: doc,
      fileName: img,
      iteration: iteration,
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
      final img = _sequence[idx].fileName;
      final iteration = _sequence[idx].iteration;
      final regions = await ContinuousDbService.fetchRegions();
      final currentImageRegions = regions
          .where(
            (r) =>
                r.doctorName == doc &&
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
        _loadEvent();
        _selectedSlider = null;
        _sliderValue0 = 0.0;
        _sliderValue1 = 0.0;
        _sliderValue2 = 0.0;
      });
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
    final total = _sequence.length;
    final img = _sequence[idx].fileName;
    return Scaffold(
      appBar: AppBar(
        title: Text('[Continuous] ${idx + 1}/$total'),
        actions: [
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
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: _isSelectionMode ? Colors.orange[100] : Colors.blue[100],
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isSelectionMode ? Icons.touch_app : Icons.visibility),
                  const SizedBox(width: 8),
                  Text(
                    _isSelectionMode ? 'Selection Mode' : 'View Mode',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: Icon(
                      _isSelectionMode ? Icons.visibility : Icons.touch_app,
                    ),
                    label: Text(_isSelectionMode ? 'View' : 'Select'),
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = !_isSelectionMode;
                        if (!_isSelectionMode) {
                          _regionKey.currentState?.clearSelection();
                        }
                      });
                    },
                  ),
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
              child: Center(
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_isSelectionMode)
                        Padding(
                          padding: const EdgeInsets.only(right: 40.0),
                          child: _buildSliderBox(),
                        ),
                      Center(
                        child: SizedBox(
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
                                ),
                                if (_showRegionSavedMsg)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 12,
                                    child: AnimatedOpacity(
                                      opacity: _showRegionSavedMsg ? 1.0 : 0.0,
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                            horizontal: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.7,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
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
                      ),
                      if (_isSelectionMode)
                        Padding(
                          padding: const EdgeInsets.only(left: 40.0),
                          child: _buildSliderPercentagesCard(),
                        ),
                    ],
                  ),
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
                        ? () {
                            setState(() {
                              idx--;
                              _loadEvent();
                              _selectedSlider = null;
                              _sliderValue0 = 0.0;
                              _sliderValue1 = 0.0;
                              _sliderValue2 = 0.0;
                            });
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
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.white,
      child: SizedBox(
        width: 200,
        height: 300,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStyledSlider(0, 'Pale', 'Pink'),
              SizedBox(height: 12),
              _buildStyledSlider(1, 'Pink', 'Red'),
              SizedBox(height: 12),
              _buildStyledSlider(2, 'Red', 'DeepRed'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyledSlider(int idx, String left, String right) {
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
            Text(left, style: TextStyle(fontWeight: FontWeight.bold)),
            Text(right, style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            setState(() {
              _selectedSlider = idx;
            });
          },
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: isActive ? Colors.deepPurple : Colors.grey[300],
              inactiveTrackColor: Colors.grey[200],
              trackHeight: 6.0,
              thumbColor: isActive ? Colors.pink : Colors.grey[400],
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayColor: isActive
                  ? Colors.pink.withOpacity(0.2)
                  : Colors.transparent,
              valueIndicatorColor: Colors.deepPurple,
            ),
            child: Slider(
              value: value,
              onChanged: isActive
                  ? (v) {
                      setState(() {
                        if (idx == 0) _sliderValue0 = v;
                        if (idx == 1) _sliderValue1 = v;
                        if (idx == 2) _sliderValue2 = v;
                      });
                    }
                  : null,
              onChangeStart: (_) async {
                if (!isActive && _selectedSlider != null) {
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
                  final img = _sequence[idx].fileName;
                  final iteration = _sequence[idx].iteration;
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
                  );
                }
                setState(() {
                  _selectedSlider = idx;
                });
              },
              onChangeEnd: isActive
                  ? (v) async {
                      await _saveOrUpdateColorEvent(idx, v);
                    }
                  : null,
              min: 0.0,
              max: 1.0,
              divisions: 100,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderPercentagesCard() {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.white,
      child: SizedBox(
        width: 240,
        height: 140,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: _buildSliderPercentagesCardContent(),
        ),
      ),
    );
  }

  Widget _buildSliderPercentagesCardContent() {
    if (_selectedSlider == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          Icon(Icons.info_outline, color: Colors.deepPurple, size: 40),
          SizedBox(height: 10),
          Flexible(
            child: Text(
              'Please select a color from the sliders.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
                letterSpacing: 1.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    String left = '', right = '';
    double value = 0.0;
    switch (_selectedSlider) {
      case 0:
        left = 'Pale';
        right = 'Pink';
        value = _sliderValue0;
        break;
      case 1:
        left = 'Pink';
        right = 'Red';
        value = _sliderValue1;
        break;
      case 2:
        left = 'Red';
        right = 'DeepRed';
        value = _sliderValue2;
        break;
    }
    final rightPct = (value * 100).round();
    final leftPct = 100 - rightPct;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            '$leftPct% $left',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 10),
        Flexible(
          child: Text(
            '$rightPct% $right',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.pink,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class ImageIteration {
  final String fileName;
  final int iteration;
  ImageIteration(this.fileName, this.iteration);
}
