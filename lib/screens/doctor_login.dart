import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/doctor_provider.dart';
import 'mode_selection_screen.dart';

class DoctorLogin extends StatefulWidget {
  const DoctorLogin({super.key});
  @override
  State<DoctorLogin> createState() => _DoctorLoginState();
}

class _DoctorLoginState extends State<DoctorLogin> {
  final TextEditingController _nameCtrl = TextEditingController();
  int _iters = 1;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Evaluator & Settings')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Enter your name'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Iterations:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _iters,
                  items: [1, 2, 3, 4, 5]
                      .map(
                        (n) =>
                            DropdownMenuItem<int>(value: n, child: Text('$n')),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _iters = v);
                  },
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final name = _nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final prov = context.read<DoctorProvider>();
                  prov.name = name;
                  prov.iterations = _iters;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ModeSelectionScreen(),
                    ),
                  );
                },
                child: const Text('Start Labeling'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
