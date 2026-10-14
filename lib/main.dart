import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ANTI-OOM POLICY: Limit Flutter engine in-memory image cache
  // Prevents crash when loading very large or numerous comic pages.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 128 * 1024 * 1024; // 128 MB max
  PaintingBinding.instance.imageCache.maximumSize = 80; // 80 image entries max

  // Set system overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF12121A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const CbzReaderApp());
}

class CbzReaderApp extends StatelessWidget {
  const CbzReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CBZ Comic Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF12121A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF4834DF),
          surface: Color(0xFF1E1E2C),
          onPrimary: Colors.white,
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A26),
          foregroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
