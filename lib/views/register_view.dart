import 'package:flutter/material.dart';
import '../services/app_logger.dart';
import '../services/registration_service.dart';
import '../theme/app_theme.dart';

/// Member registration form — two collapsible sections (Personal Details,
/// Member Location) matching the web portal's field set. Submit posts to
/// RegistrationService (GoSure's generic job-instance API) — see that
/// file's TODO for the still-unconfirmed jobTypeId and data-key names.
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  /// Slide-up + fade transition used when pushing this from the login
  /// screen's "Register" link.
  static Route<void> route() {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const RegisterView(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _nameRegex = RegExp(r"^[A-Za-z][A-Za-z\s.'-]*$");
  static final _postalCodeRegex = RegExp(r'^[A-Za-z0-9]{2,4}\s?[A-Za-z0-9]{2,4}$');
  static final _placeRegex = RegExp(r"^[A-Za-z][A-Za-z\s.'-]*$");
  static final _mobileRegex = RegExp(r'^[0-9]{7,15}$');

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  bool _companyExpanded = true;
  bool _locationExpanded = true;
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _emailCtrl,
      _mobileCtrl,
      _postalCodeCtrl,
      _addressCtrl,
      _cityCtrl,
      _countryCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _companyExpanded = true;
        _locationExpanded = true;
      });
      return;
    }
    setState(() => _submitting = true);
    try {
      await RegistrationService.submit({
        'Name': _nameCtrl.text.trim(),
        'Email': _emailCtrl.text.trim(),
        'Mobile No': _mobileCtrl.text.trim(),
        if (_addressCtrl.text.trim().isNotEmpty) 'Address': _addressCtrl.text.trim(),
        if (_cityCtrl.text.trim().isNotEmpty) 'City': _cityCtrl.text.trim(),
        if (_countryCtrl.text.trim().isNotEmpty) 'Country': _countryCtrl.text.trim(),
        if (_postalCodeCtrl.text.trim().isNotEmpty) 'Postal Code': _postalCodeCtrl.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      AppLogger.e('RegisterView', 'submit failed', e, st);
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  String? _validateRequired(String? v, String label, RegExp pattern, String patternError) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return '$label is required';
    if (!pattern.hasMatch(value)) return patternError;
    return null;
  }

  String? _validateOptional(String? v, RegExp pattern, String patternError) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return null;
    if (!pattern.hasMatch(value)) return patternError;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.appSurfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.appTextColor),
        title: Text('Register', style: AppFonts.display(size: 18)),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Section(
                      title: 'Personal Details',
                      expanded: _companyExpanded,
                      onToggle: () => setState(() => _companyExpanded = !_companyExpanded),
                      children: [
                        _field(
                          controller: _nameCtrl,
                          label: 'Name',
                          required: true,
                          keyboardType: TextInputType.name,
                          validator: (v) => _validateRequired(v, 'Name', _nameRegex, 'Letters only, please'),
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _emailCtrl,
                          label: 'Email',
                          required: true,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => _validateRequired(v, 'Email', _emailRegex, 'Enter a valid email'),
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _mobileCtrl,
                          label: 'Mobile No',
                          required: true,
                          keyboardType: TextInputType.phone,
                          validator: (v) => _validateRequired(v, 'Mobile No', _mobileRegex, 'Enter a valid mobile number'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'Member Location',
                      expanded: _locationExpanded,
                      onToggle: () => setState(() => _locationExpanded = !_locationExpanded),
                      children: [
                        _field(
                          controller: _addressCtrl,
                          label: 'Address',
                          maxLines: 4,
                          keyboardType: TextInputType.streetAddress,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _cityCtrl,
                          label: 'City',
                          keyboardType: TextInputType.text,
                          validator: (v) => _validateOptional(v, _placeRegex, 'Letters only, please'),
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _countryCtrl,
                          label: 'Country',
                          keyboardType: TextInputType.text,
                          validator: (v) => _validateOptional(v, _placeRegex, 'Letters only, please'),
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _postalCodeCtrl,
                          label: 'Postal Code',
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              _validateOptional(v, _postalCodeRegex, 'Enter a valid postal code'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.appPrimaryColor,
                        foregroundColor: AppColors.appOnPrimaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.appOnPrimaryColor),
                            )
                          : const Text('Submit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ],
                ),
              ),
            ),
            if (_submitted) const _SuccessOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool required = false,
    bool obscureText = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.appBorderColor),
    );
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      keyboardType: keyboardType,
      style: AppFonts.body(size: 14),
      validator: validator ?? (required ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null : null),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        labelStyle: AppFonts.body(size: 13, color: AppColors.appTextSecondaryColor),
        alignLabelWithHint: maxLines > 1,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.appSurfaceVariantColor,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.appPrimaryColor)),
        errorBorder: border.copyWith(borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: border.copyWith(borderSide: const BorderSide(color: Colors.redAccent)),
      ),
    );
  }
}

/// Collapsible card with an animated chevron and an animated height/opacity
/// transition for its body — the "advanced" feel comes from here rather
/// than from any single flashy effect.
class _Section extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.appSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.appBorderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: AppColors.appPrimaryColor.withOpacity(0.07),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppFonts.body(size: 14.5, weight: FontWeight.w700, color: AppColors.appPrimaryColor),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: const Icon(Icons.keyboard_arrow_down, color: AppColors.appPrimaryColor),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
            crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 260),
            sizeCurve: Curves.easeInOut,
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeIn,
          ),
        ],
      ),
    );
  }
}

/// Scale/fade-in confirmation shown over the form after a successful
/// client-side validation, before popping back to login.
class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          final clamped = value.clamp(0.0, 1.0);
          return Container(
            color: AppColors.appBackgroundColor.withOpacity(0.94 * clamped),
            alignment: Alignment.center,
            child: Opacity(
              opacity: clamped,
              child: Transform.scale(scale: 0.7 + 0.3 * value, child: child),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppColors.appSuccessColor, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 18),
            Text('Registration submitted', style: AppFonts.display(size: 17)),
            const SizedBox(height: 4),
            Text("We'll be in touch shortly", style: AppFonts.body(size: 13, color: AppColors.appTextSecondaryColor)),
          ],
        ),
      ),
    );
  }
}
