import 'package:flutter/material.dart';

class FadeSlide extends StatelessWidget {
  final Widget child;
  final double offsetY;
  final Duration duration;

  const FadeSlide({
    super.key,
    required this.child,
    this.offsetY = 20,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: offsetY, end: 0),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: 1 - (value / offsetY),
          child: Transform.translate(
            offset: Offset(0, value),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
