import 'package:flutter/material.dart';
import '../utils/app_constants.dart';

class ModeToolbar extends StatelessWidget {
  final bool isSelectionMode;
  final VoidCallback onToggleMode;
  final VoidCallback? onUndo;

  const ModeToolbar({
    super.key,
    required this.isSelectionMode,
    required this.onToggleMode,
    this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppConstants.standardCardHeight,
      child: Card(
        elevation: AppConstants.standardElevation,
        color: AppConstants.cardBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                isSelectionMode ? Icons.touch_app : Icons.visibility,
                color: Colors.deepPurple,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isSelectionMode ? 'Selection Mode' : 'View Mode',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 32,
                child: ElevatedButton.icon(
                  icon: Icon(
                    isSelectionMode ? Icons.visibility : Icons.touch_app,
                    size: 18,
                    color: Colors.deepPurple,
                  ),
                  label: Text(
                    isSelectionMode ? 'View' : 'Select',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.deepPurple,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: AppConstants.noElevation,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: onToggleMode,
                ),
              ),
              if (isSelectionMode && onUndo != null) ...[
                const SizedBox(width: 12),
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    icon: const Icon(
                      Icons.undo,
                      size: 18,
                      color: Colors.deepPurple,
                    ),
                    label: const Text(
                      'Undo',
                      style: TextStyle(fontSize: 14, color: Colors.deepPurple),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: AppConstants.noElevation,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: onUndo,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
