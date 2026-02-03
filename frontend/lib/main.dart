import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/home_screen.dart';
import 'screens/guide_verification_screen.dart';
import 'screens/map_screen.dart';


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
      
      // Configuration du thème global
      theme: ThemeData(
        primaryColor: const Color(0xFF2D6A4F),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        fontFamily: 'Poppins', // Ou 'Montserrat'
      ),
      
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
  case '/map':
  final args = settings.arguments as Map<String, dynamic>?;
  return MaterialPageRoute(
    builder: (_) => MapScreen(
      mode: args?['mode'] ?? 'edit',
      savedRoute: args?['savedRoute'],
    ),
  );
    
    default:
      return MaterialPageRoute(builder: (_) => const LoginScreen());

    
  }
},
    );
  }
}