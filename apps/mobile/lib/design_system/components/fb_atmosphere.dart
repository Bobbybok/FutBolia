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
  });

  final Widget child;
  final String asset;
  final double overlayOpacity;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final content = safeArea ? SafeArea(child: child) : child;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: FutBoliaColors.surfaceDark,
            image: DecorationImage(
              image: AssetImage(asset),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Color.fromRGBO(5, 18, 12, overlayOpacity),
                BlendMode.darken,
              ),
            ),
          ),
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
        content,
      ],
    );
  }
}
