import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';

class SetupPasswordScreen extends StatefulWidget {
  final String? token;

  const SetupPasswordScreen({super.key, this.token});

  @override
  State<SetupPasswordScreen> createState() => _SetupPasswordScreenState();
}

class _SetupPasswordScreenState extends State<SetupPasswordScreen> {
  final _tokenInputController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _activeToken;
  bool _isVerifying = false;
  bool _isTokenValid = false;
  String? _verificationError;
  Map<String, dynamic>? _recipientData;

  bool _isSubmitting = false;
  bool _isCompleted = false;
  String? _submitError;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    // Resolve token from widget, or fallback to query parameter in URL (Web)
    final qToken = widget.token ?? Uri.base.queryParameters['token'];
    if (qToken != null && qToken.trim().isNotEmpty) {
      _activeToken = qToken.trim();
      _tokenInputController.text = _activeToken!;
      _verifyToken(_activeToken!);
    }
  }

  @override
  void dispose() {
    _tokenInputController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyToken(String token) async {
    setState(() {
      _isVerifying = true;
      _verificationError = null;
      _isTokenValid = false;
      _recipientData = null;
      _activeToken = token;
    });

    try {
      final dio = ApiClient().dio;
      final response = await dio.post(
        '/userlogin/setup-password/verify-token/',
        data: {'token': token},
      );

      if (mounted) {
        if (response.data['valid'] == true) {
          setState(() {
            _isTokenValid = true;
            _recipientData = response.data['user'] as Map<String, dynamic>?;
            _isVerifying = false;
          });
        } else {
          setState(() {
            _isTokenValid = false;
            _verificationError = response.data['detail']?.toString() ?? "Invalid invitation token.";
            _isVerifying = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = "Could not verify password setup token.";
        if (e is DioException && e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map && data.containsKey('detail')) {
            msg = data['detail'].toString();
          } else if (data is Map && data.containsKey('error')) {
            msg = data['error'].toString();
          }
        }
        setState(() {
          _isTokenValid = false;
          _verificationError = msg;
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _confirmPassword() async {
    final pwd = _passwordController.text;
    final conf = _confirmPasswordController.text;

    if (pwd.length < 8) {
      setState(() => _submitError = "Password must be at least 8 characters long.");
      return;
    }
    if (!RegExp(r'[A-Z]').hasMatch(pwd)) {
      setState(() => _submitError = "Password must contain at least one uppercase letter (A-Z).");
      return;
    }
    if (!RegExp(r'[a-z]').hasMatch(pwd)) {
      setState(() => _submitError = "Password must contain at least one lowercase letter (a-z).");
      return;
    }
    if (!RegExp(r'\d').hasMatch(pwd)) {
      setState(() => _submitError = "Password must contain at least one number (0-9).");
      return;
    }
    if (pwd != conf) {
      setState(() => _submitError = "Passwords do not match.");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final dio = ApiClient().dio;
      final response = await dio.post(
        '/userlogin/setup-password/confirm/',
        data: {
          'token': _activeToken,
          'password': pwd,
          'confirm_password': conf,
        },
      );

      final data = response.data as Map<String, dynamic>;

      if (mounted) {
        // Log in user directly with received credentials
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await auth.setAuthData(data);

        setState(() {
          _isSubmitting = false;
          _isCompleted = true;
        });
      }
    } catch (e) {
      if (mounted) {
        String msg = "Failed to update password.";
        if (e is DioException && e.response?.data != null) {
          final d = e.response!.data;
          if (d is Map && d.containsKey('error')) {
            msg = d['error'].toString();
          } else if (d is Map && d.containsKey('detail')) {
            msg = d['detail'].toString();
          }
        }
        setState(() {
          _isSubmitting = false;
          _submitError = msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryNavy = Color(0xFF0D2158);
    const accentGold = Color(0xFFF7CA18);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.shield_rounded, color: accentGold, size: 22),
            SizedBox(width: 10),
            Text(
              "SDMS Security Portal",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text("Go to Login"),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _buildBodyContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isCompleted) {
      return _buildSuccessView();
    }

    if (_isVerifying) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(height: 24),
          CircularProgressIndicator(color: Color(0xFF0D2158), strokeWidth: 3),
          SizedBox(height: 24),
          Text(
            "Verifying security token...",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
          ),
          SizedBox(height: 8),
          Text(
            "Checking one-time cryptographic invitation validity.",
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          SizedBox(height: 24),
        ],
      );
    }

    if (_verificationError != null || !_isTokenValid) {
      return _buildInvalidTokenView();
    }

    return _buildPasswordSetupForm();
  }

  Widget _buildInvalidTokenView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 48),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Setup Link Expired or Invalid",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 10),
        Text(
          _verificationError ?? "This one-time password setup token has already been used or has expired.",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Have a new token?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tokenInputController,
                      decoration: InputDecoration(
                        hintText: "Paste token here...",
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D2158),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final t = _tokenInputController.text.trim();
                      if (t.isNotEmpty) _verifyToken(t);
                    },
                    child: const Text("Verify"),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0D2158),
            side: const BorderSide(color: Color(0xFF0D2158)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text("Back to Login"),
        ),
      ],
    );
  }

  Widget _buildPasswordSetupForm() {
    final name = _recipientData?['name'] ?? 'User';
    final role = _recipientData?['role'] ?? 'Student';
    final dept = _recipientData?['department'] ?? 'College of Engineering';
    final email = _recipientData?['email'] ?? '';

    final pwd = _passwordController.text;
    final hasLength = pwd.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(pwd);
    final hasLower = RegExp(r'[a-z]').hasMatch(pwd);
    final hasNum = RegExp(r'\d').hasMatch(pwd);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Welcome Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2158).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF0D2158), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome, $name!",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Create your private password to activate portal access.",
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Recipient Identity Summary Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildIdentityRow("Role", role),
              _buildIdentityRow("Department", dept),
              _buildIdentityRow("Email", email),
            ],
          ),
        ),
        const Divider(height: 32),

        if (_submitError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red.shade800, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _submitError!,
                    style: TextStyle(color: Colors.red.shade900, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // New Password Field
        const Text("New Password", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: "Enter strong password",
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Confirm Password Field
        const Text("Confirm Password", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            hintText: "Re-enter new password",
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Password requirements checklist
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Password Requirements:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              _buildRuleIndicator("At least 8 characters", hasLength),
              _buildRuleIndicator("Uppercase & lowercase letters", hasUpper && hasLower),
              _buildRuleIndicator("At least one number (0-9)", hasNum),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Submit Button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D2158),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSubmitting ? null : _confirmPassword,
          child: _isSubmitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text("Activate Account & Set Password", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            color: Color(0xFFECFDF5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 54),
        ),
        const SizedBox(height: 20),
        const Text(
          "Account Activated Successfully!",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        Text(
          "Your password has been securely configured and your portal session is ready.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D2158),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => context.go('/dashboard'),
          child: const Text("Proceed to Dashboard", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildIdentityRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildRuleIndicator(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 14, color: met ? const Color(0xFF059669) : const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: met ? FontWeight.bold : FontWeight.normal,
              color: met ? const Color(0xFF059669) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
