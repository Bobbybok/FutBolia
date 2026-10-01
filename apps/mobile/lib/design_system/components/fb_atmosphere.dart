import 'package:flutter/material.dart';
import '../tokens/colors.dart';

/// Full-bleed sports atmosphere (photo + dark green veil).
class FbAtmosphere extends StatelessWidget {
  const FbAtmosphere({
    super.key,
    required this.child,
    this.asset = 'assets/images/bg_stadium_night.jpg',
    this.overlayOpacity = 0.72,
    this.safeArea = true,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    /// Keep the photo fixed to the full screen size so the keyboard
    /// / focus insets never reflow or "zoom" the background.
    this.lockToScreen = false,
  });

  final Widget child;
  final String asset;
  final double overlayOpacity;
  final bool safeArea;
  final BoxFit fit;
  final Alignment alignment;
  final bool lockToScreen;

  @override
  Widget build(BuildContext context) {
    final content = safeArea ? SafeArea(child: child) : child;
    final media = MediaQuery.of(context);
    // Full physical screen — ignore keyboard viewInsets.
    final screenSize = media.size;

    final background = IgnorePointer(
      child: lockToScreen
          ? SizedBox(
              width: screenSize.width,
              height: screenSize.height,
              child: _BackgroundLayers(
                asset: asset,
                overlayOpacity: overlayOpacity,
                fit: fit,
                alignment: alignment,
              ),
            )
          : _BackgroundLayers(
              asset: asset,
              overlayOpacity: overlayOpacity,
              fit: fit,
              alignment: alignment,
            ),
    );

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        if (lockToScreen)
          Positioned(
            left: 0,
            top: 0,
            width: screenSize.width,
            height: screenSize.height,
            child: background,
          )
        else
          Positioned.fill(child: background),
        content,
      ],
    );
  }
}

class _BackgroundLayers extends StatelessWidget {
  const _BackgroundLayers({
    required this.asset,
    required this.overlayOpacity,
    required this.fit,
    required this.alignment,
  });

  final String asset;
  final double overlayOpacity;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: FutBoliaColors.surfaceDark),
        Image.asset(
          asset,
          fit: fit,
          alignment: alignment,
          width: double.infinity,
          height: double.infinity,
          filterQuality: FilterQuality.high,
          color: Color.fromRGBO(5, 18, 12, overlayOpacity),
          colorBlendMode: BlendMode.darken,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66000000),
                Color(0xCC070B09),
                FutBoliaColors.surfaceDark,
              ],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
      ],
    );
  }
}
