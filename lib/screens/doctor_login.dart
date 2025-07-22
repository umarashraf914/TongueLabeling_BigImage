import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/doctor_provider.dart';
import 'mode_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_constants.dart';

class DoctorLogin extends StatefulWidget {
  const DoctorLogin({super.key});
  @override
  State<DoctorLogin> createState() => _DoctorLoginState();
}

class _DoctorLoginState extends State<DoctorLogin> {
  final TextEditingController _nameCtrl = TextEditingController();
  int _iters = 1;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
    _nameCtrl.addListener(() {
      setState(() {}); // Update UI when text changes
    });
  }

  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('currentUser');
    final iters = prefs.getInt('currentIterations');
    if (user != null && iters != null) {
      final prov = context.read<DoctorProvider>();
      prov.name = user;
      prov.iterations = iters;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Title card in the center
                Center(
                  child: Card(
                    elevation: AppConstants.cardElevation,
                    color: AppConstants.cardBackgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.cardBorderRadius,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.settings,
                            color: AppConstants.primaryPurple,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Evaluator Settings',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryPurple,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 120), // Equal spacing after title
                // Name and iterations input group (treated as one element)
                Column(
                  children: [
                    // Name input field with card styling
                    Center(
                      child: SizedBox(
                        height: 70, // Same height as Start Labeling button
                        width: 300, // Fixed width for consistent sizing
                        child: Card(
                          elevation: AppConstants.cardElevation,
                          color: AppConstants.cardBackgroundColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.cardBorderRadius,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 4,
                            ),
                            child: Center(
                              child: TextField(
                                controller: _nameCtrl,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  hintText: 'Please Enter Your Name',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(
                                    color: AppConstants.primaryPurple,
                                  ),
                                ),
                                style: const TextStyle(
                                  color: AppConstants.primaryPurple,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ), // Small spacing within the input group
                    // Iterations selection with card styling
                    Center(
                      child: IntrinsicWidth(
                        child: SizedBox(
                          height: 70, // Same height as other elements
                          child: Card(
                            elevation: AppConstants.cardElevation,
                            color: AppConstants.cardBackgroundColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppConstants.cardBorderRadius,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 4,
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Iterations:',
                                      style: TextStyle(
                                        color: AppConstants.primaryPurple,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    DropdownButton<int>(
                                      value: _iters,
                                      underline:
                                          const SizedBox(), // Remove default underline
                                      dropdownColor:
                                          AppConstants.cardBackgroundColor,
                                      style: const TextStyle(
                                        color: AppConstants.primaryPurple,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      items: [1, 2, 3, 4, 5]
                                          .map(
                                            (n) => DropdownMenuItem<int>(
                                              value: n,
                                              child: Text('$n'),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _iters = v);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 120), // Equal spacing before button
                Center(
                  child: IntrinsicWidth(
                    child: GestureDetector(
                      onTap: () async {
                        final name = _nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter your name to continue.',
                              ),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        final prov = context.read<DoctorProvider>();
                        prov.name = name;
                        prov.iterations = _iters;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('currentUser', name);
                        await prefs.setInt('currentIterations', _iters);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ModeSelectionScreen(),
                          ),
                        );
                      },
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
                                'Start Labeling',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _nameCtrl.text.trim().isNotEmpty
                                      ? AppConstants.primaryPurple
                                      : AppConstants.primaryPurple.withOpacity(
                                          0.4,
                                        ),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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
    );
  }
}
