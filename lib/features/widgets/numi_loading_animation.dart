import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

class NumiLoadingAnimation extends StatelessWidget {
  const NumiLoadingAnimation({
    super.key,
    this.size = 48,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        'loading.json',
        fit: BoxFit.contain,
        repeat: true,
      ),
    );
  }
}
