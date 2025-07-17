import 'package:flutter/material.dart';

class UserInfoCard extends StatelessWidget {
  final String userName;
  final int iterations;
  final String mode;
  final int currentIndex;
  final int totalImages;

  const UserInfoCard({
    super.key,
    required this.userName,
    required this.iterations,
    required this.mode,
    required this.currentIndex,
    required this.totalImages,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Card(
        elevation: 8,
        color: const Color(0xFFF3EFFF), // Soft white-purplish background
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.person, color: Colors.deepPurple, size: 20),
              const SizedBox(width: 6),
              Text(
                userName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.repeat, color: Colors.deepPurple, size: 18),
              const SizedBox(width: 4),
              Text(
                'x$iterations',
                style: const TextStyle(color: Colors.deepPurple, fontSize: 14),
              ),
              const SizedBox(width: 16),
              Icon(
                mode == 'continuous' ? Icons.timeline : Icons.grid_on,
                color: Colors.deepPurple,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                mode[0].toUpperCase() + mode.substring(1),
                style: const TextStyle(color: Colors.deepPurple, fontSize: 14),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.image, color: Colors.deepPurple, size: 18),
              const SizedBox(width: 4),
              Text(
                '${currentIndex + 1}/$totalImages',
                style: const TextStyle(color: Colors.deepPurple, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
