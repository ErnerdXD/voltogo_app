import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';

class AnimatedSplashScreenWidget extends StatelessWidget {
  const AnimatedSplashScreenWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen.withScreenFunction(
      splash: Center(
        child: Lottie.asset(
          'assets/ev-charging.json',
          width: 350,
          height: 200,
          fit: BoxFit.fill,
        ),
      ),
      screenFunction: () async {
        // Wait for a small duration to ensure the animation shows
        await Future.delayed(const Duration(seconds: 3));
        
        // Use Future.microtask to ensure navigation happens after the build
        if (context.mounted) {
          Future.microtask(() {
            if (context.mounted) {
              context.go('/map');
            }
          });
        }
        
        // Return a dummy widget as the library requires it
        return const Scaffold(body: SizedBox.shrink());
      },
      splashIconSize: 300,
      splashTransition: SplashTransition.fadeTransition,
    );
  }
}
