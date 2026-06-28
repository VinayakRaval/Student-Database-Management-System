import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/screens/login_page.dart';

const _primary = Color(0xFF0D2158);
const _primaryDark = Color(0xFF0A1628);
const _accentGold = Color(0xFFFFD700);
const _surface = Color(0xFFF8F9FA);
const _hint = Color(0xFF9AA6B5);
const _textPrimary = Color(0xFF1E293B);
const _textSecondary = Color(0xFF64748B);
const _error = Color(0xFFDC2626);
const _success = Color(0xFF10B981);
const _white = Color(0xFFFFFFFF);

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isOtpSent = false;
  bool _isSuccess = false;
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConf = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _error : _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_primaryDark, _primary, Color(0xFF1565C0)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Back to Login',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Logo
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: _accentGold.withValues(alpha: 0.4),
                          blurRadius: 25,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Text(
                                'GEC',
                                style: TextStyle(
                                  color: Color(0xFF0D2158),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28,
                                ),
                              ),
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'GEC Chamarajanagara',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Government Engineering College',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 60,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_accentGold, Color(0xFFFFC107)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // White card
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isMobile ? 24 : 32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: _isSuccess
                            ? _buildSuccess(isMobile)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isOtpSent
                                        ? 'Reset Password'
                                        : 'Forgot Password',
                                    style: const TextStyle(
                                      color: _textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isOtpSent
                                        ? 'Enter the OTP and set a new password'
                                        : 'Enter your registered email to receive an OTP',
                                    style: TextStyle(
                                      color: _textSecondary.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _isOtpSent
                                      ? _buildStep2(auth, isMobile)
                                      : _buildStep1(auth, isMobile),
                                ],
                              ),
                      ),
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

  Widget _buildStep1(AuthProvider auth, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Email Address'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _emailCtrl,
          hint: 'Enter your registered email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: _isLoading
              ? _loadingButton()
              : ElevatedButton(
                  onPressed: () async {
                    if (_emailCtrl.text.trim().isEmpty) {
                      _snack('Please enter your email', error: true);
                      return;
                    }
                    setState(() => _isLoading = true);
                    final res = await auth.sendResetOtp(_emailCtrl.text.trim());
                    setState(() => _isLoading = false);
                    if (res['success']) {
                      setState(() => _isOtpSent = true);
                      _snack('OTP sent to ${_emailCtrl.text.trim()}');
                    } else {
                      _snack(
                        res['message'] ?? 'Failed to send OTP',
                        error: true,
                      );
                    }
                  },
                  style: _primaryButtonStyle(),
                  child: const Text(
                    'Send OTP',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStep2(AuthProvider auth, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: _primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'OTP sent to ${_emailCtrl.text.trim()}',
                  style: const TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildLabel('6-Digit OTP'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: const TextStyle(
            fontSize: 18,
            color: _primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
          ),
          textAlign: TextAlign.center,
          decoration: _inputDecoration(
            hint: '------',
            icon: Icons.pin_outlined,
          ),
        ),
        const SizedBox(height: 20),

        _buildLabel('New Password'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _newPassCtrl,
          hint: 'Enter new password',
          icon: Icons.lock_outline,
          obscure: _obscureNew,
          suffix: IconButton(
            icon: Icon(
              _obscureNew
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _hint,
              size: 20,
            ),
            onPressed: () => setState(() => _obscureNew = !_obscureNew),
          ),
        ),
        const SizedBox(height: 20),

        _buildLabel('Confirm Password'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _confirmCtrl,
          hint: 'Re-enter new password',
          icon: Icons.lock_reset_outlined,
          obscure: _obscureConf,
          suffix: IconButton(
            icon: Icon(
              _obscureConf
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _hint,
              size: 20,
            ),
            onPressed: () => setState(() => _obscureConf = !_obscureConf),
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        final res = await auth.sendResetOtp(
                          _emailCtrl.text.trim(),
                        );
                        setState(() => _isLoading = false);
                        _snack(
                          res['success'] ? 'OTP resent' : 'Failed to resend',
                          error: !res['success'],
                        );
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: BorderSide(
                    color: _primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Resend',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 52,
                child: _isLoading
                    ? _loadingButton()
                    : ElevatedButton(
                        onPressed: () async {
                          if (_otpCtrl.text.length != 6) {
                            _snack('Enter the 6-digit OTP', error: true);
                            return;
                          }
                          if (_newPassCtrl.text.isEmpty) {
                            _snack('Enter a new password', error: true);
                            return;
                          }
                          if (_newPassCtrl.text != _confirmCtrl.text) {
                            _snack('Passwords do not match', error: true);
                            return;
                          }
                          setState(() => _isLoading = true);
                          final res = await auth.verifyAndReset(
                            _emailCtrl.text.trim(),
                            _otpCtrl.text.trim(),
                            _newPassCtrl.text.trim(),
                          );
                          setState(() => _isLoading = false);
                          if (res['success']) {
                            setState(() => _isSuccess = true);
                          } else {
                            _snack(
                              res['message'] ?? 'Reset failed',
                              error: true,
                            );
                          }
                        },
                        style: _primaryButtonStyle(),
                        child: const Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccess(bool isMobile) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _success.withValues(alpha: 0.1),
          ),
          child: const Icon(Icons.check_circle, color: _success, size: 55),
        ),
        const SizedBox(height: 20),
        const Text(
          'Password Reset!',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your password has been updated successfully.\nYou can now sign in with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _textSecondary, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            ),
            style: _primaryButtonStyle(),
            child: const Text(
              'Back to Sign In',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: _textPrimary),
      decoration: _inputDecoration(hint: hint, icon: icon, suffixIcon: suffix),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _hint, fontSize: 14),
      prefixIcon: Icon(icon, color: _hint, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _loadingButton() {
    return Container(
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _primary,
      foregroundColor: _white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    );
  }
}
