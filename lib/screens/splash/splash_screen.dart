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
        await Future.delayed(const Duration(seconds: 3));
        // This ensures the MainShell (with the bottom navigation bar) is loaded.
        if (context.mounted) {
          context.go('/map');
        }
        // Return a dummy widget; GoRouter's navigation will take over immediately.
        return const SizedBox.shrink();
      },
      splashIconSize: 300,
      splashTransition: SplashTransition.fadeTransition,
    );
  }
}

