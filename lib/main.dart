//lib/main.dart
import 'package:trenda_shared/core/ads/ad_tracking_identity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:trenda_shared/core/logger.dart';
import 'package:trenda_shared/core/error_boundary.dart';
import 'package:trenda_shared/core/images/image_picker_service.dart';
import 'package:trenda_shared/widgets/app_config_gate.dart';
import 'package:trenda_shared/widgets/official_ad_slot.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_frontend/features/core/providers/municipality_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'features/core/widgets/app_overlay_manager.dart';
import 'features/core/router/app_router.dart';
import 'features/core/providers/theme_provider.dart';
import 'features/core/providers/websocket_provider.dart';
import 'features/chat/providers/chat_alerts_provider.dart';
import 'features/core/widgets/app_back_handler.dart';
import 'features/notifications/services/notification_service.dart';
import 'design_system/design_system.dart';
import 'firebase_options.dart';
import 'package:trenda_shared/core/taps/taps.dart';

// Global key for snackbar overlay
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  TrendaBinding.ensureInitialized();
  // Names this app on every ad view/tap ping (unique-audience stats by app).
  AdTrackingIdentity.app = 'frontend';

  // Disable the Android system Photo Picker app-wide (it crashes on some
  // OEM/ColorOS ROMs — "Volume external_primary not found", thrown in a separate
  // process so it's uncatchable — and closes the app on a gallery pick). Gallery
  // picks route through SAF/file_picker instead (see ImagePickerService).
  // Harmless no-op off Android.
  ImagePickerService.ensureConfigured();

  // Initialize global error handler
  AppErrorHandler.initialize(
    onError: (error, stack) {
      AppLogger.error('Uncaught error', error, stack);
    },
  );

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.info('Firebase initialized successfully');
  } catch (e) {
    AppLogger.error('Firebase initialization failed', e);
  }

  // Initialize local notifications
  try {
    await NotificationService.initialize();
    AppLogger.info('Notification service initialized successfully');
  } catch (e) {
    AppLogger.error('Notification service initialization failed', e);
  }

  // App version for the force-update gate (AppConfigGate reads this global).
  try {
    currentAppVersion = (await PackageInfo.fromPlatform()).version;
  } catch (_) {}

  // Enable store/product CTA deep-links on official ads (consumer app routes).
  officialAdDeepLinkHandler = (context, type, targetId) {
    if (type == 'store') {
      context.push('/store/$targetId');
    } else if (type == 'product') {
      context.push('/product/$targetId');
    }
  };

  runApp(
    ProviderScope(
      observers: [if (kDebugMode) _FrontendProviderLogger()],
      child: const MyApp(),
    ),
  );
}

// Riverpod observer for debugging
class _FrontendProviderLogger extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    final name = provider.name ?? provider.runtimeType.toString();

    // Skip AuthNotifier logs entirely - they spam too much
    if (name.contains('AuthNotifier') || name.contains('AuthState')) {
      return;
    }

    AppLogger.state(name, 'Updated');
  }

  @override
  void providerDidFail(
    ProviderBase provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    AppLogger.error(
      'Provider ${provider.name ?? provider.runtimeType} failed',
      error,
      stackTrace,
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeProvider);

    // Keep the shared official-ad municipality in sync with the selected area, so
    // municipality-targeted official ads are scoped to the consumer's municipality.
    officialAdMunicipality = ref.read(municipalityProvider);
    ref.listen(
        municipalityProvider, (_, next) => officialAdMunicipality = next);

    // Initialize WebSocket connection (auto-connects when authenticated)
    ref.watch(websocketInitProvider);
    // New chat messages: live unread badges + an in-app notification.
    ref.watch(chatAlertsProvider);

    return MaterialApp.router(
      title: 'Trenda',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      scaffoldMessengerKey: scaffoldMessengerKey,
      routerConfig: goRouter,
      // Phone back: previous page, else home, else the Shop tab — the app
      // only closes from the Shop tab (see AppBackHandler).
      builder: (context, child) => AppBackHandler(
        router: goRouter,
        child: AppConfigGate(
          appKey: 'consumer',
          child: AppOverlayManager(
            messengerKey: scaffoldMessengerKey,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
