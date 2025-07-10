import 'package:flutter/material.dart';
import '../services/db_service.dart' show LabelEvent, RegionSelection;
import '../services/discrete_db_service.dart';
import '../services/continuous_db_service.dart';
import '../services/continuous_db_service.dart' show ContinuousLabelEvent;

class DatabaseViewScreen extends StatelessWidget {
  const DatabaseViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔍 Database Contents')),
      body: FutureBuilder<List<dynamic>>(
        // fetch both tables in parallel
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

          final events = snap.data![0] as List<LabelEvent>;
          final regions = snap.data![1] as List<RegionSelection>;

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
                    '${e.fileName}  •  ${e.color}  •  pass ${e.iteration}',
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
                  title: Text('${r.fileName}  •  pass ${r.iteration}'),
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

class ContinuousDatabaseViewScreen extends StatelessWidget {
  const ContinuousDatabaseViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔍 Continuous Mode Database')),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          ContinuousDbService.fetchEvents(),
          ContinuousDbService.fetchRegions(),
        ]),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: \\${snap.error}'));
          }

          final events = snap.data![0] as List<ContinuousLabelEvent>;
          final regions = snap.data![1] as List<RegionSelection>;

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
                    '\\${e.fileName}  •  [\\${e.colorA} (\\${e.percentA.toStringAsFixed(1)}%) + \\${e.colorB} (\\${e.percentB.toStringAsFixed(1)}%)]  •  pass \\${e.iteration}',
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
                  title: Text('\\${r.fileName}  •  pass \\${r.iteration}'),
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
