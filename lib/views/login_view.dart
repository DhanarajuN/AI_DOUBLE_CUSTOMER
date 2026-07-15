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
      borderSide: const BorderSide(color: AppColors.appBorderColor),
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
