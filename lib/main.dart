import 'package:flutter/material.dart';
import 'core/app_language.dart';
import 'core/app_storage.dart';
import 'core/api_client.dart';
import 'core/notification_permission_service.dart';
import 'features/auth/language_choice_screen.dart';
import 'features/auth/landing_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/browse/browse_profiles_screen.dart';
import 'features/contact/contact_inbox_screen.dart';
import 'features/home/home_screen.dart';
import 'features/matrimony_profile/view_profile_screen.dart';
import 'features/onboarding/models/onboarding_status.dart';
import 'features/onboarding/smart_onboarding_screen.dart';

// RouteObserver for RouteAware lifecycle management
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

const Color _brandMaroon = Color(0xFFDC2626);
const Color _brandGold = Color(0xFFC79A3B);
const Color _screenBackground = Color(0xFFF8F4EF);
const String _brandLogoAsset = 'assets/images/navri_logo.png';
const String _startupHeroAsset = 'assets/images/landing_hero.jpg';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      initialRoute: '/bootstrap',

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
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const LandingScreen(),
        '/home': (context) => const HomeScreen(),
        '/matches': (context) => const BrowseProfilesScreen(),
        '/contact-inbox': (context) => const ContactInboxScreen(),
        '/create-profile': (context) => const SmartOnboardingScreen(),
        '/view-profile': (context) => const ViewProfileScreen(),
        '/smart-onboarding': (context) => const SmartOnboardingScreen(),
      },
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
    await NotificationPermissionService.requestOnStartup();
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

    final nextStep = (status.nextStep ?? status.draft?.currentStep)
        ?.trim()
        .toLowerCase();
    return nextStep != null && nextStep != 'activation';
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
