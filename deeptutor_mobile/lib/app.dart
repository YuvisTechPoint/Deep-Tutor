import 'package:flutter/material.dart';
import 'package:deeptutor_mobile/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_bootstrap.dart';
import 'core/widgets/design_system/ambient_mesh_background.dart';
import 'core/widgets/backend_unreachable_banner.dart';
import 'core/widgets/biometric_gate.dart';
import 'core/widgets/connectivity_banner.dart';
import 'core/network/realtime_hub.dart';
import 'features/settings/screens/settings_screen.dart';
import 'navigation/router.dart';
import 'services/deep_links.dart';

/// Root application widget.
///
/// Provides [ProviderScope] at the top, applies the Material 3 theme,
/// and delegates routing to [AppRouter].
class DeepTutorApp extends ConsumerWidget {
  const DeepTutorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(realtimeHubProvider);

    return MaterialApp.router(
      title: 'DeepTutor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      locale: Locale(ref.watch(languageProvider)),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        final brightness = themeMode == ThemeMode.system
            ? MediaQuery.platformBrightnessOf(context)
            : (themeMode == ThemeMode.dark
                ? Brightness.dark
                : Brightness.light);
        final rootBg = brightness == Brightness.dark
            ? AppColors.voidBlack
            : AppColors.backgroundLight;

        final size = MediaQuery.sizeOf(context);
        return ColoredBox(
          color: rootBg,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: AppBootstrap(
              child: AmbientMeshBackground(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ConnectivityBanner(),
                    const BackendUnreachableBanner(),
                    Expanded(
                      child: BiometricGate(
                        child: DeepLinkListener(
                          router: router,
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
