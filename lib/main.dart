import 'dart:async';

import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'core/app_language.dart';
import 'core/app_storage.dart';
import 'core/api_client.dart';
import 'core/app_strings.dart';
import 'core/notification_permission_service.dart';
import 'core/push_notification_service.dart';
import 'features/auth/language_choice_screen.dart';
import 'features/auth/landing_screen.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/biodata/biodata_intake_lab_screen.dart';
import 'features/biodata/biodata_export_screen.dart';
import 'features/browse/browse_profiles_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/contact/contact_inbox_screen.dart';
import 'features/home/home_screen.dart';
import 'features/matrimony_profile/profile_detail_screen.dart';
import 'features/matrimony_profile/view_profile_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/onboarding/models/onboarding_status.dart';
import 'features/onboarding/smart_onboarding_screen.dart';
import 'features/photo/photo_gallery_screen.dart';
import 'features/plans/plans_screen.dart';
import 'features/profile_lists/profile_lists_screen.dart';
import 'features/settings/notification_settings_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/suchak/suchak_requests_screen.dart';

// RouteObserver for RouteAware lifecycle management
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

/// Lets code outside the widget tree navigate — currently the push
/// notification service, which opens a screen when a notification is tapped.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

const Color _brandMaroon = Color(0xFFDC2626);
const Color _brandGold = Color(0xFFC79A3B);
const Color _screenBackground = Color(0xFFF8F4EF);
const String _brandLogoAsset = 'assets/images/navri_logo.png';
const String _startupHeroAsset = 'assets/images/landing_hero.jpg';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never blocks startup: the service swallows its own failures, so the app
  // still runs (without push) when Firebase is unreachable.
  await PushNotificationService.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    // Rebuild the whole app when the language switches, and hand Flutter the
    // matching locale so its own Localizations (and the generated
    // AppLocalizations) rebuild in step with the app's own copy.
    return ValueListenableBuilder<AppLanguage?>(
      valueListenable: appLanguage,
      builder: (context, _, _) => _buildApp(),
    );
  }

  Widget _buildApp() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      locale: Locale(appLanguageCode(currentAppLanguage)),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      initialRoute: '/bootstrap',

      navigatorKey: appNavigatorKey,
      navigatorObservers: [routeObserver],

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _brandMaroon,
          primary: _brandMaroon,
          secondary: _brandGold,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: _screenBackground,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: _brandMaroon,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _brandMaroon,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _brandMaroon,
            side: const BorderSide(color: _brandMaroon, width: 1.4),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _brandMaroon, width: 1.4),
          ),
        ),
      ),

      routes: {
        '/bootstrap': (context) => const BootstrapScreen(),
        '/language': (context) => const LanguageChoiceScreen(),
        '/landing': (context) => const LandingScreen(),
        // A member sent here from forgot-password carries her mobile number as
        // a route argument, so the OTP door opens on it instead of an empty
        // field. Every other push at '/login' passes nothing and is unchanged.
        '/login': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments;
          return LoginScreen(
            otpRequest: arguments is MobileOtpLoginRequest ? arguments : null,
          );
        },
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/register': (context) => const LandingScreen(),
        '/home': (context) => _authenticatedScreen(const HomeScreen()),
        '/matches': (context) =>
            _authenticatedScreen(const BrowseProfilesScreen()),
        '/chats': (context) => _authenticatedScreen(const ChatScreen()),
        '/contact-inbox': (context) =>
            _authenticatedScreen(const ContactInboxScreen()),
        '/suchak-requests': (context) =>
            _authenticatedScreen(const SuchakRequestsScreen()),
        '/plans': (context) => _authenticatedScreen(const PlansScreen()),
        '/biodata-export': (context) =>
            _authenticatedScreen(const BiodataExportScreen()),
        '/biodata-intake': (context) =>
            _authenticatedScreen(const BiodataIntakeScreen()),
        '/notifications': (context) =>
            _authenticatedScreen(const NotificationsScreen()),
        '/settings': (context) => _authenticatedScreen(const SettingsScreen()),
        '/notification-settings': (context) =>
            _authenticatedScreen(const NotificationSettingsScreen()),
        '/profile-lists': (context) =>
            _authenticatedScreen(const ProfileListsScreen()),
        '/photo-gallery': (context) =>
            _authenticatedScreen(const PhotoGalleryScreen()),
        '/create-profile': (context) => const SmartOnboardingScreen(),
        '/view-profile': (context) =>
            _authenticatedScreen(const ViewProfileScreen()),
        '/smart-onboarding': (context) => const SmartOnboardingScreen(),
      },
    );
  }
}

/// True while a member session exists. The single question every member-only
/// surface has to ask before it paints anything.
bool get isSignedIn {
  final token = ApiClient.authToken;
  return token != null && token.isNotEmpty;
}

/// Signs the member out and throws away every member screen behind them.
///
/// The old logout did `pushReplacementNamed('/login')`, which swaps only the
/// TOP route. A member who reached Home from Matches was dropped back onto a
/// still-alive Matches screen — with the profiles it had already loaded still
/// on it — the moment they pressed Back, and could carry on opening screens
/// from there. Signing out has to take the whole stack down, not just its top.
Future<void> signOutAndReturnToLogin(NavigatorState navigator) async {
  await ApiClient.logout();
  ProfileDetailScreen.clearSessionState();
  if (!navigator.mounted) return;
  navigator.pushNamedAndRemoveUntil('/login', (route) => false);
}

Widget _authenticatedScreen(Widget child) {
  return AuthenticatedRoute(child: child);
}

/// Gate in front of every member-only route.
///
/// Two jobs:
///  * a signed-out user must never see a member screen — the gate paints
///    nothing and sends them to the landing screen, which is also where
///    [BootstrapScreen] sends a signed-out start;
///  * a signed-in user sitting at the root of the stack must not back out of
///    the app by accident — they are told to use Logout instead.
class AuthenticatedRoute extends StatefulWidget {
  const AuthenticatedRoute({super.key, required this.child});

  final Widget child;

  @override
  State<AuthenticatedRoute> createState() => _AuthenticatedRouteState();
}

class _AuthenticatedRouteState extends State<AuthenticatedRoute> {
  bool _redirectScheduled = false;

  void _redirectIfSignedOut() {
    if (isSignedIn || _redirectScheduled) return;
    _redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // A route that is already on its way out — logout tears the stack down
      // while its screens still rebuild once — must not hijack navigation and
      // overwrite the destination the sign-out just chose.
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/landing', (route) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isSignedIn) {
      _redirectIfSignedOut();
      // Deliberately empty: the member surface must not be built at all, so
      // nothing it had loaded can flash on screen on the way out.
      return const Scaffold(body: SizedBox.shrink());
    }

    final route = ModalRoute.of(context);
    final blockRootBack = route?.isFirst ?? false;

    return PopScope<Object?>(
      canPop: !blockRootBack,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !blockRootBack) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(AppStrings.logoutToExit),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBootstrap();
    });
  }

  Future<void> _startBootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await _restoreAndRoute();
  }

  Future<void> _restoreAndRoute() async {
    final savedLanguage = await AppStorage.instance.readLanguage();

    if (!mounted) return;

    if (savedLanguage == null) {
      Navigator.pushReplacementNamed(context, '/language');
      return;
    }

    setAppLanguage(savedLanguage);
    await ApiClient.restoreSessionFromStorage();

    if (!mounted) return;

    var route = ApiClient.authToken == null ? '/landing' : '/home';
    if (ApiClient.authToken != null) {
      route = await _routeForAuthenticatedUser();
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, route);
    // Only now — this replaces the whole stack, so a notification-tap screen
    // opened any earlier would be thrown away.
    PushNotificationService.instance.handlePendingLaunchMessage();

    // Ask on app open, but only for a member whose session was restored: they
    // never pass through login again, so this was the one path where nobody was
    // ever asked and Android silently dropped every push. A signed-out start
    // deliberately asks nothing — a dialog on the language picker or the
    // landing screen has no context, and a denial there is close to permanent.
    // The device token is registered by `restoreSessionFromStorage` either way.
    if (ApiClient.authToken != null) {
      unawaited(NotificationPermissionService.ensureRequested());
    }
  }

  Future<String> _routeForAuthenticatedUser() async {
    try {
      final data = await ApiClient.getOnboardingStatus(
        locale: appLanguageCode(currentAppLanguage),
      );
      final status = OnboardingStatus.fromJson(data);
      if (status.success) {
        return _needsSmartOnboarding(status)
            ? '/smart-onboarding'
            : _completedProfileRoute();
      }
    } catch (_) {
      // Fall back to the older profile check below.
    }

    try {
      final profileResult = await ApiClient.getMyProfile();
      if (profileResult['statusCode'] == 404) {
        return '/smart-onboarding';
      }
    } catch (_) {
      return _completedProfileRoute();
    }

    return _completedProfileRoute();
  }

  Future<String> _completedProfileRoute() async {
    final shownDate = await AppStorage.instance
        .readDailyRecommendationShownDate();
    return shownDate == _todayKey() ? '/home' : '/matches';
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  bool _needsSmartOnboarding(OnboardingStatus status) {
    if (!status.hasProfile) return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(_startupHeroAsset, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.22),
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.28),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 76, 28, 0),
                child: Image.asset(
                  _brandLogoAsset,
                  width: 220,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
