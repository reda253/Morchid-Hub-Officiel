import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/email_verification_screen.dart';
import 'shell/main_shell.dart';
import 'screens/guide_verification_screen.dart';
import 'screens/map_screen.dart';
import 'screens/admin_screen.dart';
import 'widgets/auth_guard.dart';
import 'screens/available_routes_screen.dart';
import 'screens/admin_analytics_screen.dart';
import 'screens/pricing_screen.dart';
import 'screens/guide_profile_screen.dart';
import 'screens/review_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/search_screen.dart';
import 'theme/app_theme.dart';
import 'routes/app_routes.dart';


void main() {
  runApp(const MorchidHubApp());
}

class MorchidHubApp extends StatelessWidget {
  const MorchidHubApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Morchid Hub',
      debugShowCheckedModeBanner: false,
      
      // Thème global — design system Stitch (Atlantic Blue / Manrope + Epilogue)
      theme: AppTheme.light,
      
      // Routes de navigation
      initialRoute: AppRoutes.splash,
      onGenerateRoute: (settings) {
  switch (settings.name) {
    case AppRoutes.splash:
      return MaterialPageRoute(builder: (_) => const SplashScreen());

    case AppRoutes.login:
      return MaterialPageRoute(builder: (_) => const LoginScreen());

    case AppRoutes.signup:
      return MaterialPageRoute(builder: (_) => const SignupScreen());

    case AppRoutes.forgotPassword:
      return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());

    case AppRoutes.emailVerification:
      final args = settings.arguments as EmailVerificationArgs;
      return MaterialPageRoute(
        builder: (_) => EmailVerificationScreen(
          email: args.email,
          fullName: args.fullName,
        ),
      );

    case AppRoutes.shell:
      return MaterialPageRoute(builder: (_) => const MainShell());

    case AppRoutes.verifyGuide:
      return MaterialPageRoute(
        builder: (_) => const GuideVerificationScreen()
      );

    case AppRoutes.availableRoutes:
      return MaterialPageRoute(builder: (_) => const AvailableRoutesScreen());

    case AppRoutes.pricing:
      return MaterialPageRoute(builder: (_) => const PricingScreen());

    case AppRoutes.map:
      final args = settings.arguments as MapArgs? ?? const MapArgs();
      return MaterialPageRoute(
        builder: (_) => MapScreen(
          mode: args.mode,
          savedRoute: args.savedRoute,
        ),
      );

    case AppRoutes.guideProfile:
      final args = settings.arguments as GuideProfileArgs;
      return MaterialPageRoute(
        builder: (_) => GuideProfileScreen(guide: args.guide),
      );

    case AppRoutes.review:
      final args = settings.arguments as ReviewArgs;
      return MaterialPageRoute(
        builder: (_) => ReviewScreen(
          guideId: args.guideId,
          guideName: args.guideName,
          guidePhotoUrl: args.guidePhotoUrl,
        ),
      );

    case AppRoutes.payment:
      final args = settings.arguments as PaymentArgs;
      return MaterialPageRoute(
        builder: (_) => PaymentScreen(
          amount: args.amount,
          planName: args.planName,
        ),
      );

    case AppRoutes.search:
      return MaterialPageRoute(builder: (_) => const SearchScreen());

    case AppRoutes.admin:
            return MaterialPageRoute(
              builder: (_) => AuthGuard(
                allowedRoles: const ['admin', 'administrator'],
                child: const AdminScreen(),
              ),
            );

    case AppRoutes.adminAnalytics:
            return MaterialPageRoute(
              builder: (_) => AuthGuard(
                allowedRoles: const ['admin', 'administrator'],
                child: const AdminAnalyticsScreen(),
              ),
            );


    default:
      return MaterialPageRoute(builder: (_) => const LoginScreen());


  }
},
    );
  }
}