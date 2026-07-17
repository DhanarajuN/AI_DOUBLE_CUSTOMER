import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../viewmodels/login_view_model.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => LoginViewModel(ctx.read<AuthRepository>()),
      child: const _LoginBody(),
    );
  }
}

class _LoginBody extends StatefulWidget {
  const _LoginBody();

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(LoginViewModel vm) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final success = await vm.login(username: _usernameCtrl.text.trim(), password: _passwordCtrl.text);
    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.chatList);
    }
  }

  Future<void> _submitGoogle(LoginViewModel vm) async {
    FocusScope.of(context).unfocus();
    final success = await vm.loginWithGoogle();
    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.chatList);
    } else if (!success && mounted && vm.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.errorMessage!), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();

    return Scaffold(
      backgroundColor: AppColors.appBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: AppColors.appPrimaryGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.forum_outlined, color: Colors.white, size: 30),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: AppFonts.display(size: 24),
                        children: [
                          const TextSpan(text: 'AI '),
                          TextSpan(
                            text: 'Double',
                            style: AppFonts.display(size: 24, weight: FontWeight.w400, color: AppColors.appSecondaryColor)
                                .copyWith(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text('Sign in to continue', style: AppFonts.body(size: 13.5, color: AppColors.appTextSecondaryColor)),
                  ),
                  const SizedBox(height: 32),
                  if (vm.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.appSecondaryColorDim,
                        border: Border.all(color: AppColors.appSecondaryColor.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(vm.errorMessage!, style: AppFonts.body(size: 12.5, color: AppColors.appSecondaryColor)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildField(
                    controller: _usernameCtrl,
                    label: 'Username',
                    keyboardType: TextInputType.text,
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Enter your username';
                      if (!_emailRegex.hasMatch(value)) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _passwordCtrl,
                    label: 'Password',
                    obscureText: vm.obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        vm.obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.appTextMutedColor,
                        size: 19,
                      ),
                      onPressed: vm.toggleObscurePassword,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter your password';
                      if (v.length < 6) return 'Must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.appPrimaryColor,
                      foregroundColor: AppColors.appOnPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: vm.isLoading ? null : () => _submit(vm),
                    child: vm.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.appOnPrimaryColor),
                          )
                        : const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.appBorderColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('OR', style: AppFonts.mono(size: 10.5, color: AppColors.appTextMutedColor)),
                      ),
                      Expanded(child: Divider(color: AppColors.appBorderColor)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFDADCE0)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: vm.isLoading ? null : () => _submitGoogle(vm),
                    child: vm.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF3C4043)),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              _GoogleLogo(size: 18),
                              SizedBox(width: 12),
                              Text(
                                'Continue with Google',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: Color(0xFF3C4043)),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.appBorderColor),
    );
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: AppFonts.body(size: 14),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppFonts.body(size: 13, color: AppColors.appTextSecondaryColor),
        filled: true,
        fillColor: AppColors.appSurfaceVariantColor,
        suffixIcon: suffixIcon,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.appPrimaryColor)),
        errorBorder: border.copyWith(borderSide: const BorderSide(color: Colors.redAccent)),
      ),
    );
  }
}

/// Google's official multi-color "G" mark, hand-drawn from its published
/// path data (the same shape used by every real "Continue with Google"
/// button) — no bundled image asset needed.
class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _GoogleLogoPainter()));
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 18.0, size.height / 18.0);

    final blue = Paint()..color = const Color(0xFF4285F4);
    canvas.drawPath(
      Path()
        ..moveTo(17.64, 9.2)
        ..cubicTo(17.64, 8.563, 17.583, 7.949, 17.476, 7.36)
        ..lineTo(9, 7.36)
        ..lineTo(9, 10.841)
        ..lineTo(13.844, 10.841)
        ..cubicTo(13.635, 11.966, 13.001, 12.919, 12.048, 13.558)
        ..lineTo(12.048, 15.817)
        ..lineTo(14.956, 15.817)
        ..cubicTo(16.658, 14.25, 17.64, 11.943, 17.64, 9.2)
        ..close(),
      blue,
    );

    final green = Paint()..color = const Color(0xFF34A853);
    canvas.drawPath(
      Path()
        ..moveTo(9, 18)
        ..cubicTo(11.43, 18, 13.467, 17.194, 14.956, 15.82)
        ..lineTo(12.048, 13.561)
        ..cubicTo(11.242, 14.101, 10.211, 14.421, 9.0, 14.421)
        ..cubicTo(6.656, 14.421, 4.672, 12.837, 3.964, 10.71)
        ..lineTo(0.957, 10.71)
        ..lineTo(0.957, 13.042)
        ..cubicTo(2.438, 15.983, 5.482, 18, 9, 18)
        ..close(),
      green,
    );

    final yellow = Paint()..color = const Color(0xFFFBBC05);
    canvas.drawPath(
      Path()
        ..moveTo(3.964, 10.71)
        ..cubicTo(3.784, 10.17, 3.682, 9.593, 3.682, 9.0)
        ..cubicTo(3.682, 8.407, 3.784, 7.83, 3.964, 7.29)
        ..lineTo(3.964, 4.958)
        ..lineTo(0.957, 4.958)
        ..cubicTo(0.347, 6.173, 0, 7.548, 0, 9)
        ..cubicTo(0, 10.452, 0.348, 11.827, 0.957, 13.042)
        ..lineTo(3.964, 10.71)
        ..close(),
      yellow,
    );

    final red = Paint()..color = const Color(0xFFEA4335);
    canvas.drawPath(
      Path()
        ..moveTo(9, 3.58)
        ..cubicTo(10.321, 3.58, 11.508, 4.034, 12.44, 4.925)
        ..lineTo(15.022, 2.345)
        ..cubicTo(13.463, 0.891, 11.426, 0, 9, 0)
        ..cubicTo(5.482, 0, 2.438, 2.017, 0.957, 4.958)
        ..lineTo(3.964, 6.29)
        ..cubicTo(4.672, 4.163, 6.656, 3.58, 9, 3.58)
        ..close(),
      red,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
