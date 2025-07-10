// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'services/db_service.dart';
import 'providers/doctor_provider.dart';
import 'screens/doctor_login.dart';
import 'screens/label_screen.dart';
import 'screens/database_view.dart';
import 'screens/mode_selection_screen.dart';
import 'screens/continuous_mode_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await DbService.db;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DoctorProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        initialRoute: '/login',
        routes: {
          '/login': (_) => const DoctorLogin(),
          '/label': (_) => const LabelScreen(),
          '/db': (_) => const DatabaseViewScreen(),
          '/continuous': (_) => const ContinuousModeScreen(),
        },
      ),
    );
  }
}
