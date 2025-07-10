import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoadingAnimationOverLay extends StatelessWidget {
  const LoadingAnimationOverLay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Lottie.asset(
            'assets/system/animation/loading/loading.json',
            width: 150,
            height: 150,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class LoadingAnimation extends StatelessWidget {
  const LoadingAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Center(
        child: Lottie.asset(
          'assets/system/animation/loading/loading.json',
          width: 150,
          height: 150,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
