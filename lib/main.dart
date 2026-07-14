import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinci_board/adapters/storage/storage_service.dart';
import 'package:vinci_board/presentation/screens/splash_screen.dart';
import 'package:vinci_board/presentation/providers/settings_provider.dart';
import 'package:vinci_board/core/theme/da_vinci_theme.dart';
import 'package:vinci_board/core/event_logger.dart';
import 'package:vinci_board/core/canvas/stroke_render_cache.dart';

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
    // Activate EventLogger for the lifetime of this ProviderScope.
    // Reading the provider once wires it to the shared EventBus and
    // schedules disposal when the scope is destroyed.
    ref.read(eventLoggerProvider);

    final settings = ref.watch(settingsProvider);
    final fontName = settings.selectedFont;

    // Notify StrokeRenderCache of the current font and font size so canvas rendering updates
    StrokeRenderCache().setCurrentFont(fontName);
    StrokeRenderCache().setCurrentFontSize(settings.selectedFontSize);

    // Apply the user-selected font to the app theme
    ThemeData theme = DaVinciTheme.lightTheme;
    try {
      theme = theme.copyWith(
        textTheme: GoogleFonts.getTextTheme(fontName, theme.textTheme),
        primaryTextTheme: GoogleFonts.getTextTheme(
          fontName,
          theme.primaryTextTheme,
        ),
      );
    } catch (_) {
      // Font name not found — fall back to default theme
    }

    return MaterialApp(
      title: 'Vinci Board',
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(settings.selectedFontSize / 18.0),
          ),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}
