import 'package:flutter/material.dart';
import '../services/db_service.dart' show LabelEvent, RegionSelection;
import '../services/discrete_db_service.dart';
import '../services/continuous_db_service.dart';
import 'package:provider/provider.dart';
import '../providers/doctor_provider.dart';

class DatabaseViewScreen extends StatefulWidget {
  const DatabaseViewScreen({super.key});

  @override
  State<DatabaseViewScreen> createState() => _DatabaseViewScreenState();
}

class _DatabaseViewScreenState extends State<DatabaseViewScreen> {
  bool _showAll = false;

  Future<bool> _promptForAdminPassword(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin Password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Enter admin password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(controller.text == 'admin123');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final doc = Provider.of<DoctorProvider>(context, listen: false).name;
    final iters = Provider.of<DoctorProvider>(
      context,
      listen: false,
    ).iterations;
    final sessionId = '${doc}_$iters';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔍 Database Contents'),
            Text('Session: $sessionId', style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Global DB View (Admin)',
            onPressed: () async {
              final ok = await _promptForAdminPassword(context);
              if (ok) {
                setState(() => _showAll = true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect password.')),
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          DiscreteDbService.fetchEvents(),
          DiscreteDbService.fetchRegions(),
        ]),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          var events = snap.data![0] as List<LabelEvent>;
          var regions = snap.data![1] as List<RegionSelection>;

          if (!_showAll) {
            events = events.where((e) => e.sessionId == sessionId).toList();
            regions = regions.where((r) => r.sessionId == sessionId).toList();
          }

          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  '🖌️ Color-label Events',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...events.map(
                (e) => ListTile(
                  title: Text(
                    '${e.doctorName} | ${e.fileName} | [${e.color}] | pass ${e.iteration} | sessionId: ${e.sessionId}',
                  ),
                  subtitle: Text(e.timestamp.toIso8601String()),
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  '✏️ Region Selections',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...regions.map(
                (r) => ListTile(
                  title: Text(
                    '${r.doctorName} | ${r.fileName} | pass ${r.iteration} | sessionId: ${r.sessionId}',
                  ),
                  subtitle: Text(r.pathJson),
                  trailing: Text(r.timestamp.toIso8601String()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ContinuousDatabaseViewScreen extends StatefulWidget {
  const ContinuousDatabaseViewScreen({super.key});

  @override
  State<ContinuousDatabaseViewScreen> createState() =>
      _ContinuousDatabaseViewScreenState();
}

class _ContinuousDatabaseViewScreenState
    extends State<ContinuousDatabaseViewScreen> {
  bool _showAll = false;

  Future<bool> _promptForAdminPassword(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin Password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Enter admin password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(controller.text == 'admin123');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final doc = Provider.of<DoctorProvider>(context, listen: false).name;
    final iters = Provider.of<DoctorProvider>(
      context,
      listen: false,
    ).iterations;
    final sessionId = '${doc}_$iters';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔍 Continuous Mode Database'),
            Text('Session: $sessionId', style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Global DB View (Admin)',
            onPressed: () async {
              final ok = await _promptForAdminPassword(context);
              if (ok) {
                setState(() => _showAll = true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect password.')),
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          ContinuousDbService.fetchEvents(
            sessionId: _showAll ? null : sessionId,
          ),
          ContinuousDbService.fetchRegions(),
        ]),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          var events = snap.data![0] as List<ContinuousLabelEvent>;
          var regions = snap.data![1] as List<RegionSelection>;

          if (!_showAll) {
            regions = regions.where((r) => r.sessionId == sessionId).toList();
          }

          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  '🖌️ Continuous Color-label Events',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...events.map(
                (e) => ListTile(
                  title: Text(
                    '${e.doctorName} | ${e.fileName} | [${e.colorA} (${e.percentA.toStringAsFixed(1)}%) + ${e.colorB} (${e.percentB.toStringAsFixed(1)}%)] | pass ${e.iteration} | sessionId: ${e.sessionId}',
                  ),
                  subtitle: Text(e.timestamp.toIso8601String()),
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  '✏️ Region Selections',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...regions.map(
                (r) => ListTile(
                  title: Text(
                    '${r.doctorName} | ${r.fileName} | pass ${r.iteration} | sessionId: ${r.sessionId}',
                  ),
                  subtitle: Text(r.pathJson),
                  trailing: Text(r.timestamp.toIso8601String()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
