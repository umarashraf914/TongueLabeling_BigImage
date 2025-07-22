import 'package:flutter/material.dart';
import '../utils/app_constants.dart';

class NavigationCard extends StatelessWidget {
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool isPreviousEnabled;
  final bool isNextEnabled;

  const NavigationCard({
    super.key,
    required this.onPrevious,
    required this.onNext,
    this.isPreviousEnabled = true,
    this.isNextEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppConstants.standardElevation,
      color: AppConstants.cardBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: isPreviousEnabled ? onPrevious : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                elevation: AppConstants.noElevation,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
              ),
              child: const Text('Previous', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 24),
            ElevatedButton(
              onPressed: isNextEnabled ? onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                elevation: AppConstants.noElevation,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
              ),
              child: const Text('Next', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
