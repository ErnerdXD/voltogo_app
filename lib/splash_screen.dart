import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:voltogo_app/home_page.dart';

class AnimatedSplashScreenWidget extends StatelessWidget {
  const AnimatedSplashScreenWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
      splash: Center(
        child: Lottie.asset(
          'assets/ev-charging.json',
          width: 350,
          height: 200,
          fit: BoxFit.fill,
        ),
      ),
      nextScreen: MyHomePage(title: 'Voltogo'),
      splashIconSize: 300,
    );
  }
}
