import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (_) => const ProfileView());
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.appSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log out?', style: AppFonts.display(size: 17)),
        content: Text(
          "You'll need to sign in again to access your chats.",
          style: AppFonts.body(size: 13.5, color: AppColors.appTextSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppFonts.body(size: 14, color: AppColors.appTextSecondaryColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Log out', style: AppFonts.body(size: 14, weight: FontWeight.w600, color: AppColors.appPrimaryColor)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthRepository>().logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthRepository>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.appBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.appSurfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.appTextColor,
        title: Text('Profile', style: AppFonts.display(size: 18)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.appSurfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.appBorderColor),
              ),
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(gradient: AppColors.appPrimaryGradient, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(user?.name ?? 'U'),
                      style: AppFonts.display(size: 22, weight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(user?.name ?? 'User', style: AppFonts.display(size: 18)),
                  const SizedBox(height: 3),
                  Text(user?.username ?? '', style: AppFonts.body(size: 13, color: AppColors.appTextSecondaryColor)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _infoTile(Icons.badge_outlined, 'Role', user?.roleName ?? '—'),
            const SizedBox(height: 10),
            _infoTile(Icons.alternate_email, 'Username', user?.username ?? '—'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.appBorderColor),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _confirmLogout(context),
                child: Text('Log out', style: AppFonts.body(size: 14, weight: FontWeight.w600, color: AppColors.appTextColor)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.appSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.appBorderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: AppColors.appSurfaceVariantColor, borderRadius: BorderRadius.circular(9)),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: AppColors.appPrimaryColor),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppFonts.body(size: 11, color: AppColors.appTextMutedColor)),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.body(size: 14, weight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
