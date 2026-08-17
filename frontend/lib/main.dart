import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/home_screen.dart';
import 'screens/guide_verification_screen.dart';
import 'screens/map_screen.dart';
import 'screens/admin_screen.dart';
import 'widgets/auth_guard.dart';
import 'screens/available_routes_screen.dart';
import 'screens/admin_analytics_screen.dart';
import 'screens/pricing_screen.dart';
import 'theme/app_theme.dart';


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
      initialRoute: '/login',
      onGenerateRoute: (settings) {
  switch (settings.name) {
    case '/login':
      return MaterialPageRoute(builder: (_) => const LoginScreen());
    
    case '/signup':
      return MaterialPageRoute(builder: (_) => const SignupScreen());
    
    case '/forgot-password':
      return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
    
    case '/email-verification':
      final args = settings.arguments as Map<String, String>;
      return MaterialPageRoute(
        builder: (_) => EmailVerificationScreen(
          email: args['email']!,
          fullName: args['fullName']!,
        ),
      );
    
    case '/home':
      return MaterialPageRoute(builder: (_) => const HomeScreen());

    case '/verify-guide':
      return MaterialPageRoute(
        builder: (_) => const GuideVerificationScreen()
      );
    
    case '/available_routes_screen':
      return MaterialPageRoute(builder: (_) => const AvailableRoutesScreen());

    case '/pricing':
      return MaterialPageRoute(builder: (_) => const PricingScreen());

    case '/map':
  final args = settings.arguments as Map<String, dynamic>?;
  return MaterialPageRoute(
    builder: (_) => MapScreen(
      mode: args?['mode'] ?? 'edit',
      savedRoute: args?['savedRoute'],
    ),
  );
  case '/admin':
            return MaterialPageRoute(
              builder: (_) => AuthGuard(
                allowedRoles: const ['admin', 'administrator'],
                child: const AdminScreen(),
              ),
            );

    case '/admin/analytics':
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