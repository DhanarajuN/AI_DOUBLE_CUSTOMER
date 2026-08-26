import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

/// First screen shown on launch — restores any saved session while a
/// minimum-duration brand splash is on screen, then routes to the chat
/// list (already logged in) or the login screen.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final authRepository = context.read<AuthRepository>();
    await Future.wait([
      authRepository.restoreSession(),
      Future.delayed(const Duration(milliseconds: 900)),
    ]);
    if (!mounted) return;
    final loggedIn = authRepository.status == AuthStatus.authenticated;
    Navigator.of(context).pushReplacementNamed(loggedIn ? AppRoutes.chatList : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogoMark(size: 84),
            const SizedBox(height: 20),
            Text('AI Double', style: AppFonts.display(size: 26, weight: FontWeight.w800, color: AppColors.appBrandNavyColor)),
            const SizedBox(height: 28),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.appPrimaryColor),
            ),
          ],
        ),
      ),
    );
  }
}
