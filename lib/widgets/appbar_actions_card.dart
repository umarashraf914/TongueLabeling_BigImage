import 'package:flutter/material.dart';
import '../utils/app_constants.dart';

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
      height: AppConstants.standardCardHeight,
      child: Card(
        elevation: AppConstants.standardElevation,
        color: AppConstants.cardBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppConstants.standardBorderRadius,
          ),
        ),
        child: Padding(
          padding: AppConstants.standardCardPadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.download,
                  color: AppConstants.primaryPurple,
                ),
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
