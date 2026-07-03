import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/storage_service.dart';
import 'screens/splash_screen.dart';
import 'providers/settings_provider.dart';
import 'core/theme/da_vinci_theme.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();

  // Preload handwriting fonts used by the AI to prevent "flashing" from sans-serif
  try {
    GoogleFonts.nanumPenScript();
    GoogleFonts.galada();
    GoogleFonts.cormorantGaramond();
    GoogleFonts.cinzel();
    GoogleFonts.crimsonText();
    await GoogleFonts.pendingFonts();
  } catch (e) {
    debugPrint("Warning: Failed to preload fonts: $e");
  }

  runApp(const ProviderScope(child: VinciBoardApp()));
}

class VinciBoardApp extends ConsumerWidget {
  const VinciBoardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Vinci Board',
      debugShowCheckedModeBanner: false,
      theme: DaVinciTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
