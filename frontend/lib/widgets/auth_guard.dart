import 'package:flutter/material.dart';
import '../services/storage_service.dart'; // Requires your storage service
import '../models/admin_models.dart';

class AuthGuard extends StatefulWidget {
  final Widget child;
  final List<String>? allowedRoles;

  const AuthGuard({
    Key? key,
    required this.child,
    this.allowedRoles,
  }) : super(key: key);

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _isLoading = true;
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final isLoggedIn = await StorageService.isLoggedIn();
    
    if (!isLoggedIn) {
      if (mounted) _redirectToLogin();
      return;
    }
    final userData = await StorageService.getUserData();
    print("Current User Role: ${userData?.role}, Is Admin: ${userData?.isAdmin}");

    if (widget.allowedRoles != null) {
      if (userData != null && (widget.allowedRoles!.contains(userData.role) || userData.isAdmin == true)) {
        if (mounted) setState(() { _isAuthorized = true; _isLoading = false; });
      } else {
         if (mounted) _redirectToLogin(message: 'Accès non autorisé');
      }
    } else {
      if (mounted) setState(() { _isAuthorized = true; _isLoading = false; });
    }
  }

  void _redirectToLogin({String? message}) {
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    if (message != null) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_isAuthorized) return widget.child;
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}