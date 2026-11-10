import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/screens/forgot_password_page.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _identifierFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _isLoggingIn = false;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _identifierFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isLoading || _isLoggingIn) return; // Prevent duplicate submissions

    final identifier = _identifierCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    // Do not trigger action when required fields are empty or validation fails
    if (identifier.isEmpty) {
      _identifierFocus.requestFocus();
      return;
    }
    if (password.isEmpty) {
      _passwordFocus.requestFocus();
      return;
    }

    setState(() => _isLoggingIn = true);
    TextInput.finishAutofillContext();
    try {
      final success = await auth.login(identifier, password);
      if (success && mounted) {
        _navigateToDashboard(auth.role);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  void _navigateToDashboard(String? role) {
    if (!mounted) return;
    switch (role) {
      case 'ACCOUNTS':
        context.go('/fees/dashboard');
        break;
      case 'STUDENT':
      case 'PROFESSOR':
      case 'HOD':
      case 'PRINCIPAL':
      case 'SYSTEM':
      case 'ADMISSION':
      case 'EXAM':
      case 'SCHOLARSHIP':
      case 'LIBRARY':
        context.go('/dashboard');
        break;
      default:
        context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1628), Color(0xFF0D2158), Color(0xFF1565C0)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double screenW = constraints.maxWidth;
              final double screenH = constraints.maxHeight;

              final bool isMobile = screenW < 600;
              final bool isShortScreen = screenH < 680;
              final bool isVeryShort = screenH < 540;

              // Proportional element sizing to ensure 0-scroll on any viewport >= 540px
              final double logoSize = isVeryShort ? 46.0 : (isShortScreen ? 58.0 : 72.0);
              final double collegeTitleSize = isVeryShort ? 16.0 : (isShortScreen ? 18.0 : 20.0);
              final double collegeSubtitleSize = isVeryShort ? 11.0 : (isShortScreen ? 12.0 : 13.5);
              final double cardPaddingH = isMobile ? 18.0 : (isShortScreen ? 22.0 : 28.0);
              final double cardPaddingV = isVeryShort ? 12.0 : (isShortScreen ? 15.0 : 20.0);
              final double fieldSpacing = isVeryShort ? 6.0 : (isShortScreen ? 9.0 : 13.0);
              final double buttonHeight = isVeryShort ? 38.0 : (isShortScreen ? 44.0 : 48.0);
              final double cardMaxWidth = isMobile ? (screenW - 32).clamp(280.0, 420.0) : 420.0;

              Widget contentColumn = Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                          blurRadius: isShortScreen ? 14 : 22,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(
                            'GEC',
                            style: TextStyle(
                              color: const Color(0xFF0D2158),
                              fontWeight: FontWeight.w900,
                              fontSize: logoSize * 0.35,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isVeryShort ? 4 : (isShortScreen ? 6 : 10)),

                  // College name & subtitle
                  Text(
                    'GEC Chamarajanagara',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: collegeTitleSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Government Engineering College',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: collegeSubtitleSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: isVeryShort ? 4 : (isShortScreen ? 6 : 8)),
                  Container(
                    width: 44,
                    height: 2.5,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFC107)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: isVeryShort ? 8 : (isShortScreen ? 12 : 18)),

                  // Login card
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardMaxWidth),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: cardPaddingH,
                        vertical: cardPaddingV,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome Back',
                            style: TextStyle(
                              color: const Color(0xFF1E293B),
                              fontSize: isVeryShort ? 18 : (isShortScreen ? 20 : 22),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sign in to your account',
                            style: TextStyle(
                              color: const Color(0xFF64748B).withValues(alpha: 0.85),
                              fontSize: isVeryShort ? 11 : 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: fieldSpacing),

                          CallbackShortcuts(
                            bindings: <ShortcutActivator, VoidCallback>{
                              const SingleActivator(LogicalKeyboardKey.enter): _submitLogin,
                              const SingleActivator(LogicalKeyboardKey.numpadEnter): _submitLogin,
                            },
                            child: AutofillGroup(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Identifier field
                                  _buildLabel('Login ID / Email / Phone', isShortScreen),
                                  const SizedBox(height: 4),
                                  _buildTextField(
                                    controller: _identifierCtrl,
                                    focusNode: _identifierFocus,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) {
                                      if (_passwordCtrl.text.trim().isEmpty) {
                                        _passwordFocus.requestFocus();
                                      } else {
                                        _submitLogin();
                                      }
                                    },
                                    hint: 'Enter your login ID or email',
                                    icon: Icons.email_outlined,
                                    isShort: isShortScreen,
                                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                                  ),
                                  SizedBox(height: fieldSpacing),

                                  // Password field
                                  _buildLabel('Password', isShortScreen),
                                  const SizedBox(height: 4),
                                  _buildTextField(
                                    controller: _passwordCtrl,
                                    focusNode: _passwordFocus,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submitLogin(),
                                    hint: 'Enter your password',
                                    icon: Icons.lock_outline,
                                    obscure: _obscure,
                                    isShort: isShortScreen,
                                    autofillHints: const [AutofillHints.password],
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: const Color(0xFF9AA6B5),
                                        size: 18,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordPage(),
                                  ),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    color: Color(0xFF0D2158),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: fieldSpacing),

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            height: buttonHeight,
                            child: Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                final isBusy = auth.isLoading || _isLoggingIn;
                                return ElevatedButton(
                                  onPressed: isBusy ? null : _submitLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0D2158),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: const Color(0xFF0D2158).withValues(alpha: 0.7),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: isBusy
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                );
                              },
                            ),
                          ),

                          // Sign Up link
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  color: const Color(0xFF64748B),
                                  fontSize: isVeryShort ? 11.5 : 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  context.push('/signup');
                                },
                                child: Text(
                                  "Sign Up",
                                  style: TextStyle(
                                    color: const Color(0xFF0D2158),
                                    fontSize: isVeryShort ? 11.5 : 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Error message
                          Consumer<AuthProvider>(
                            builder: (context, auth, _) {
                              if (auth.error == null) return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFECACA)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          auth.error!,
                                          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: isVeryShort ? 4 : (isShortScreen ? 6 : 10)),
                  Text(
                    '© 2025 GEC Chamarajanagara',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              );

              Widget backButtonWidget = Padding(
                padding: const EdgeInsets.only(left: 20, top: 14),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
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
                          Text(
                            'Back',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              // If screen height is tight or keyboard opens, allow vertical scroll only
              final bool needsScroll = isVeryShort || screenH < 480;

              return Stack(
                children: [
                  Positioned.fill(
                    child: needsScroll
                        ? SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 56),
                            child: Center(child: contentColumn),
                          )
                        : Center(
                            child: SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              child: contentColumn,
                            ),
                          ),
                  ),
                  // Back button stays pinned at top left, always accessible!
                  Positioned(
                    top: 0,
                    left: 0,
                    child: backButtonWidget,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isShort) {
    return Text(
      text,
      style: TextStyle(
        color: const Color(0xFF1E293B),
        fontSize: isShort ? 12 : 12.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    bool isShort = false,
    Widget? suffix,
    Iterable<String>? autofillHints,
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
      autofillHints: autofillHints,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9AA6B5), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF9AA6B5), size: 18),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0D2158), width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: isShort ? 10 : 12,
        ),
        isDense: true,
      ),
    );
  }
}
