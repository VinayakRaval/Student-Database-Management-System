import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userData ?? {};
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userId = user['user_id'] ?? "User";
    final fullName = user['full_name'] ?? user['name'] ?? (auth.role == 'LIBRARY' ? 'Library Officer' : userId);
    final deptName = user['department_name'] ?? (user['department'] != null ? "Department #${user['department']}" : "Central Administration / General");
    final roleDisplay = (auth.role ?? "Guest").replaceAll('_', ' ');
    final isActive = user['is_active'] != false;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF2E3AB5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: "Back to Dashboard",
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text(
          "My Profile",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 20, bottom: 35),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFF2E3AB5), const Color(0xFF13246E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: const CircleAvatar(
                      radius: 46,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 46,
                        color: Color(0xFF13246E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "ID: $userId",
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          roleDisplay,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.greenAccent.shade400, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 13, color: Colors.greenAccent),
                            const SizedBox(width: 4),
                            Text(
                              isActive ? "Active Account" : "Inactive",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _ProfileItem(
                    icon: Icons.badge_outlined,
                    title: "Full Name",
                    value: fullName,
                  ),
                  _ProfileItem(
                    icon: Icons.fingerprint_rounded,
                    title: "User / Staff ID",
                    value: userId,
                  ),
                  _ProfileItem(
                    icon: Icons.school_outlined,
                    title: "Role / Designation",
                    value: roleDisplay,
                  ),
                  _ProfileItem(
                    icon: Icons.apartment_rounded,
                    title: "Department",
                    value: deptName,
                  ),
                  _ProfileItem(
                    icon: Icons.verified_user_outlined,
                    title: "Account Status",
                    value: isActive ? "Active (Verified)" : "Inactive",
                  ),
                  _ProfileItem(
                    icon: Icons.email_outlined,
                    title: "Email Address",
                    value: user['email'] ?? "Not Provided",
                  ),
                  _ProfileItem(
                    icon: Icons.phone_outlined,
                    title: "Phone Number",
                    value: user['phone'] ?? "Not Provided",
                  ),
                  _ProfileItem(
                    icon: Icons.calendar_month_outlined,
                    title: "Date Joined",
                    value: _formatDate(user['date_joined']),
                  ),
                  const SizedBox(height: 24),
                  // Change Password Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _showChangePasswordDialog(context, auth),
                      icon: const Icon(Icons.lock_reset, color: Colors.white),
                      label: const Text(
                        "Change Password",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13246E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => auth.logout(),
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        "Logout",
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, AuthProvider auth) {
    final formKey = GlobalKey<FormState>();
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();

    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Widget buildInputField({
              required String label,
              required TextEditingController controller,
              required bool obscure,
              required VoidCallback toggleObscure,
              required String? Function(String?) validator,
              String? hint,
            }) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextFormField(
                        controller: controller,
                        obscureText: obscure,
                        validator: validator,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: hint,
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscure ? Icons.visibility_off : Icons.visibility,
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: toggleObscure,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Change Password",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Enter your current password and set a new secure password.",
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 22),

                          buildInputField(
                            label: "Current Password *",
                            controller: oldPasswordCtrl,
                            obscure: obscureOld,
                            hint: "Enter existing password",
                            toggleObscure: () => setDialogState(() => obscureOld = !obscureOld),
                            validator: (val) => val == null || val.isEmpty ? "Current password is required" : null,
                          ),

                          buildInputField(
                            label: "New Password *",
                            controller: newPasswordCtrl,
                            obscure: obscureNew,
                            hint: "At least 6 characters",
                            toggleObscure: () => setDialogState(() => obscureNew = !obscureNew),
                            validator: (val) {
                              if (val == null || val.isEmpty) return "New password is required";
                              if (val.length < 6) return "Password must be at least 6 characters";
                              if (val == oldPasswordCtrl.text) return "New password must be different from current password";
                              return null;
                            },
                          ),

                          buildInputField(
                            label: "Confirm New Password *",
                            controller: confirmPasswordCtrl,
                            obscure: obscureConfirm,
                            hint: "Re-enter new password",
                            toggleObscure: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                            validator: (val) {
                              if (val != newPasswordCtrl.text) return "Passwords do not match";
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  side: BorderSide(color: Colors.grey.shade500),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                                child: const Text("Cancel", style: TextStyle(color: Colors.black87)),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF13246E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        if (!formKey.currentState!.validate()) return;
                                        setDialogState(() => isSubmitting = true);

                                        final result = await auth.changePassword(
                                          oldPasswordCtrl.text,
                                          newPasswordCtrl.text,
                                        );

                                        if (ctx.mounted) {
                                          setDialogState(() => isSubmitting = false);
                                          if (result['success'] == true) {
                                            Navigator.pop(ctx);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(result['message'] ?? "Password changed successfully!"),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(result['message'] ?? "Failed to change password."),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                child: isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text("Update Password", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "Unknown";
    try {
      return dateStr.split('T')[0];
    } catch (e) {
      return dateStr;
    }
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _ProfileItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor),
        ),
        title: Text(
          title,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
