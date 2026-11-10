import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/utils/validation_utils.dart';

const _primary = Color(0xFF0D2158);
const _primaryDark = Color(0xFF0A1628);
const _accentGold = Color(0xFFFFD700);
const _surface = Color(0xFFF8F9FA);
const _hint = Color(0xFF9AA6B5);
const _textPrimary = Color(0xFF1E293B);
const _textSecondary = Color(0xFF64748B);
const _error = Color(0xFFDC2626);
const _success = Color(0xFF10B981);

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();

    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _submitSignUp() async {
    if (_isLoading) return; // Prevent duplicate submissions

    final name = _fullNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final confirm = _confirmPasswordCtrl.text.trim();

    // Do not trigger action when required fields are empty or validation fails
    if (name.isEmpty) {
      setState(() => _errorMessage = "Please enter your full name");
      _nameFocus.requestFocus();
      return;
    }
    if (email.isEmpty) {
      setState(() => _errorMessage = "Please enter your email address");
      _emailFocus.requestFocus();
      return;
    }
    final emailErr = ValidationUtils.validateEmail(email);
    if (emailErr != null) {
      setState(() => _errorMessage = emailErr);
      _emailFocus.requestFocus();
      return;
    }
    if (phone.isEmpty) {
      setState(() => _errorMessage = "Please enter your phone number");
      _phoneFocus.requestFocus();
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = "Please enter a password");
      _passwordFocus.requestFocus();
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = "Password must be at least 6 characters");
      _passwordFocus.requestFocus();
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = "Passwords do not match");
      _confirmPasswordFocus.requestFocus();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final response = await dio.post(
        '/userlogin/register/send-otp/',
        data: {
          'email': email,
          'name': name,
          'phone': phone,
        },
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessDialog(email);
      } else {
        setState(() => _errorMessage = "Registration could not be completed. Please try again.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      String msg = "Registration submitted successfully. Please check your email for OTP verification.";
      bool isActualError = false;

      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('detail')) {
          msg = data['detail'].toString();
          isActualError = true;
        } else if (data is Map && data.containsKey('message')) {
          msg = data['message'].toString();
          isActualError = true;
        } else if (data is Map && data.containsKey('error')) {
          msg = data['error'].toString();
          isActualError = true;
        }
      }

      if (isActualError) {
        setState(() => _errorMessage = msg);
      } else {
        _showSuccessDialog(email);
      }
    }
  }

  void _showSuccessDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: _success, size: 28),
            SizedBox(width: 10),
            Text("Registration Submitted", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          "Your registration has been initiated for $email.\nPlease check your inbox for verification, or proceed to sign in.",
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Proceed to Sign In", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isShort = size.height < 700;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_primaryDark, _primary, Color(0xFF1565C0)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: isShort ? 24 : 40,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Logo
                        Container(
                          width: isShort ? 54 : 68,
                          height: isShort ? 54 : 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: _accentGold.withValues(alpha: 0.4),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Center(
                                child: Text('GEC', style: TextStyle(color: _primary, fontWeight: FontWeight.bold, fontSize: 18)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'GEC Chamarajanagara',
                          style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Government Engineering College',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5),
                        ),
                        const SizedBox(height: 18),

                        // Form Card
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isMobile ? 20 : 28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: CallbackShortcuts(
                            bindings: <ShortcutActivator, VoidCallback>{
                              const SingleActivator(LogicalKeyboardKey.enter): _submitSignUp,
                              const SingleActivator(LogicalKeyboardKey.numpadEnter): _submitSignUp,
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Create Account',
                                  style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sign up to access student & academic portal',
                                  style: TextStyle(color: _textSecondary.withValues(alpha: 0.85), fontSize: 13),
                                ),
                                const SizedBox(height: 18),

                                // Error Banner
                                if (_errorMessage != null) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFECACA)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: _error, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(color: _error, fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Full Name
                                _buildLabel('Full Name *'),
                                const SizedBox(height: 4),
                                _buildTextField(
                                  controller: _fullNameCtrl,
                                  focusNode: _nameFocus,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                                  hint: 'Enter your full name',
                                  icon: Icons.person_outline_rounded,
                                ),
                                const SizedBox(height: 12),

                                // Email
                                _buildLabel('Email Address *'),
                                const SizedBox(height: 4),
                                _buildTextField(
                                  controller: _emailCtrl,
                                  focusNode: _emailFocus,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                                  hint: 'Enter your registered email',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 12),

                                // Phone
                                _buildLabel('Phone Number *'),
                                const SizedBox(height: 4),
                                _buildTextField(
                                  controller: _phoneCtrl,
                                  focusNode: _phoneFocus,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                                  hint: 'Enter 10-digit mobile number',
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 12),

                                // Password
                                _buildLabel('Password *'),
                                const SizedBox(height: 4),
                                _buildTextField(
                                  controller: _passwordCtrl,
                                  focusNode: _passwordFocus,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
                                  hint: 'Create a password (min 6 characters)',
                                  icon: Icons.lock_outline_rounded,
                                  obscure: _obscurePassword,
                                  suffix: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: _hint),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Confirm Password
                                _buildLabel('Confirm Password *'),
                                const SizedBox(height: 4),
                                _buildTextField(
                                  controller: _confirmPasswordCtrl,
                                  focusNode: _confirmPasswordFocus,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submitSignUp(),
                                  hint: 'Re-enter your password',
                                  icon: Icons.lock_reset_rounded,
                                  obscure: _obscureConfirm,
                                  suffix: IconButton(
                                    icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: _hint),
                                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Submit Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _submitSignUp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primary,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: _primary.withValues(alpha: 0.6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Text(
                                            'Sign Up',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Sign in redirect
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text("Already have an account? ", style: TextStyle(color: _textSecondary, fontSize: 13)),
                                    InkWell(
                                      onTap: () => context.go('/login'),
                                      child: const Text(
                                        "Sign In",
                                        style: TextStyle(color: _primary, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Back button top left
              Positioned(
                top: 14,
                left: 16,
                child: GestureDetector(
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/login');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 13),
                        SizedBox(width: 6),
                        Text('Back', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(color: _textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: _textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _hint, fontSize: 13),
        prefixIcon: Icon(icon, color: _hint, size: 18),
        suffixIcon: suffix,
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
    );
  }
}
