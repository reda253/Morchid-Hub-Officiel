import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';


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
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
      },
    );
  }
}