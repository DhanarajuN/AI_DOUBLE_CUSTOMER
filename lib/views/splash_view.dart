import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import '../routes/app_routes.dart';
import '../services/librechat_service.dart';
import '../theme/app_theme.dart';

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
      LibreChatService.loginAndCacheToken(),
      Future.delayed(const Duration(milliseconds: 900)),
    ]);
    if (!mounted) return;
    final loggedIn = authRepository.status == AuthStatus.authenticated;
    Navigator.of(context).pushReplacementNamed(loggedIn ? AppRoutes.chatList : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.app,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.tealGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.forum_outlined, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(
                style: AppFonts.display(size: 26),
                children: [
                  const TextSpan(text: 'AI '),
                  TextSpan(
                    text: 'Double',
                    style: AppFonts.display(size: 26, weight: FontWeight.w400, color: AppColors.gold)
                        .copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.teal),
            ),
          ],
        ),
      ),
    );
  }
}
