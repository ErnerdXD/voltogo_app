import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:voltogo_app/providers/theme_provider.dart';
import 'package:voltogo_app/utils/app_colors.dart';
import 'package:voltogo_app/utils/app_router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'Voltogo',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              textTheme: GoogleFonts.dmSansTextTheme(),
              colorScheme: ColorScheme.fromSeed(seedColor: AppColors.seed),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.appBarBackground,
                foregroundColor: AppColors.onAppBar,
                elevation: 0,
              ),
            ),
            darkTheme: ThemeData.dark().copyWith(
              textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
            themeMode: themeProvider.themeMode,
            routerConfig: goRouter,
          );
        },
      ),
    );
  }
}
