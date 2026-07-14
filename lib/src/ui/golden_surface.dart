import 'package:flutter/widgets.dart';

final class GoldenSurface extends StatelessWidget {
  const GoldenSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: const MediaQueryData(
        size: Size(360, 800),
        devicePixelRatio: 1,
        textScaler: TextScaler.noScaling,
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
        alwaysUse24HourFormat: true,
      ),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );
  }
}
