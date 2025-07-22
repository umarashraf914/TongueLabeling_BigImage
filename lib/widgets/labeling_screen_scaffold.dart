import 'package:flutter/material.dart';
import '../utils/app_constants.dart';

/// Shared scaffold for both Discrete and Continuous labeling screens.
/// Ensures identical layout, app bar, image box, and navigation.
/// Only the mode-specific controls (labels/sliders) differ.
class LabelingScreenScaffold extends StatelessWidget {
  final Widget appBarContent; // New: full custom app bar row
  final Widget regionSelector;
  final Widget? regionSavedMessage;
  final Widget modeControls; // labels or sliders (below image)
  final Widget navigationButtons;
  final double imageBoxWidth;
  final double imageBoxAspectRatio;
  final double topSpacing;
  final double controlsSpacing;

  const LabelingScreenScaffold({
    super.key,
    required this.appBarContent,
    required this.regionSelector,
    this.regionSavedMessage,
    required this.modeControls,
    required this.navigationButtons,
    this.imageBoxWidth = AppConstants.defaultImageBoxWidth,
    this.imageBoxAspectRatio = AppConstants.imageAspectRatio,
    this.topSpacing = AppConstants.standardSpacing,
    this.controlsSpacing = AppConstants.mediumSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: appBarContent,
        centerTitle: true,
        toolbarHeight: AppConstants.customToolbarHeight,
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: topSpacing),
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boxSize = [
                      AppConstants.maxImageBoxSize,
                      constraints.maxWidth,
                      constraints.maxHeight,
                    ].reduce((a, b) => a < b ? a : b);
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: boxSize,
                          height: boxSize,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Stack(
                              children: [
                                // regionSelector and image should use boxSize for 1:1 mapping
                                regionSelector,
                                if (regionSavedMessage != null)
                                  regionSavedMessage!,
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: controlsSpacing),
                        modeControls,
                      ],
                    );
                  },
                ),
              ),
            ),
            navigationButtons,
            SizedBox(height: controlsSpacing),
          ],
        ),
      ),
    );
  }
}
