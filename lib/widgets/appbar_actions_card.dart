import 'package:flutter/material.dart';

class AppBarActionsCard extends StatelessWidget {
  final VoidCallback onDownload;
  final List<Widget> otherIcons;

  const AppBarActionsCard({
    super.key,
    required this.onDownload,
    required this.otherIcons,
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
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.download, color: Colors.deepPurple),
                tooltip: 'Download Excel',
                onPressed: onDownload,
              ),
              ...otherIcons,
            ],
          ),
        ),
      ),
    );
  }
}
