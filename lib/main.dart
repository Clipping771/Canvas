import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();

  runApp(const ProviderScope(child: NoteSketchProApp()));
}

class NoteSketchProApp extends ConsumerWidget {
  const NoteSketchProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final fontName = settings.selectedFont;
    final fontFamily = GoogleFonts.getFont(fontName).fontFamily;

    return MaterialApp(
      title: 'NoteSketch Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Colors.black, // Sleek black
          onPrimary: Colors.white,
          secondary: Color(0xFF5856D6), // Apple purple
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        fontFamily: fontFamily,
        scaffoldBackgroundColor: const Color(
          0xFFFBFBFD,
        ), // Apple-like off-white
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0, // Prevent Material 3 color tint on scroll
          iconTheme: const IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
