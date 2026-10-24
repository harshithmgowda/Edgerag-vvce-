import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/network_service.dart';
import 'services/database_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/equipment_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize network sentinel probe and local database
  await NetworkService().init();
  await DatabaseService().appDb;

  // Check existing session
  final prefs = await SharedPreferences.getInstance();
  final userName = prefs.getString('user_name');
  final initialScreen = userName != null
      ? const EquipmentSelectionScreen()
      : const OnboardingScreen();

  runApp(EdgeRagMobileApp(initialScreen: initialScreen));
}

class EdgeRagMobileApp extends StatelessWidget {
  final Widget initialScreen;

  const EdgeRagMobileApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EdgeRAG Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFD),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B57D0),
          brightness: Brightness.light,
          primary: const Color(0xFF0B57D0),
          surface: Colors.white,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFF8FAFD),
          surfaceContainer: const Color(0xFFF0F4F9),
          surfaceContainerHigh: const Color(0xFFDADCE0),
          onSurface: const Color(0xFF202124),
          onSurfaceVariant: const Color(0xFF5F6368),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF202124),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Color(0xFF202124)),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFDADCE0)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFDADCE0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFDADCE0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFF0B57D0), width: 1.5)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0B57D0),
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: const StadiumBorder(),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48), shape: const StadiumBorder()),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: const Color(0xFF0B57D0),
            side: const BorderSide(color: Color(0xFFDADCE0)),
            shape: const StadiumBorder(),
          ),
        ),
        dividerTheme:
            const DividerThemeData(color: Color(0xFFE3E7ED), thickness: 1),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF0F4F9),
          selectedColor: const Color(0xFFD3E3FD),
          side: BorderSide.none,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
              fontFamily: 'Metropolis',
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: Color(0xFF202124)),
          titleLarge: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Color(0xFF202124)),
          bodySmall: TextStyle(
              fontFamily: 'OpenSans', height: 1.5, color: Color(0xFF5F6368)),
          bodyMedium: TextStyle(
              fontFamily: 'OpenSans', height: 1.6, color: Color(0xFF202124)),
          bodyLarge: TextStyle(
              fontFamily: 'OpenSans', height: 1.6, color: Color(0xFF202124)),
        ),
        fontFamily: 'Roboto',
      ),
      themeMode: ThemeMode.light,
      home: initialScreen,
    );
  }
}
