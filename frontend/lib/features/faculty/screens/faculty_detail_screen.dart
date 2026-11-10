import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/providers/auth_riverpod_bridge.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/network/api_client.dart';
import '../providers/faculty_provider.dart';
import '../models/faculty_model.dart';
import '../widgets/edit_faculty_dialog.dart';

class FacultyDetailScreen extends ConsumerWidget {
  final int id;
  const FacultyDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFaculty = ref.watch(facultyDetailProvider(id));
    final role = ref.watch(authRoleProvider).value?.toUpperCase();
    final actionState = ref.watch(facultyActionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Faculty Profile",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          asyncFaculty.maybeWhen(
            data: (faculty) {
              final canEdit = role == AppRoles.hod ||
                  role == AppRoles.principal ||
                  role == AppRoles.system ||
                  role == AppRoles.admission;
              if (canEdit) {
                return IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF13246E)),
                  tooltip: "Edit Faculty",
                  onPressed: () => EditFacultyDialog.show(context, faculty),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: asyncFaculty.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),

        data: (Faculty faculty) {
          // Logic: Principal can approve if status is pending
          final canApprove =
              (role == AppRoles.principal || role == AppRoles.system) &&
              (faculty.status == 'pending_principal' ||
                  faculty.status == 'pending_office' ||
                  faculty.status == 'pending');
          final canEdit = role == AppRoles.hod ||
              role == AppRoles.principal ||
              role == AppRoles.system ||
              role == AppRoles.admission;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // --- HEADER ---
                      Container(
                        width: double.infinity,
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 30,
                          horizontal: 20,
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.blueGrey.shade100,
                              backgroundImage: faculty.photoUrl != null
                                  ? NetworkImage(faculty.photoUrl!)
                                  : null,
                              child: faculty.photoUrl == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              faculty.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${faculty.role} • ${faculty.department}",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _StatusBadge(status: faculty.status),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- DETAILS CARD ---
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Personal Information",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const Divider(height: 25),
                            _InfoRow(
                              icon: Icons.badge,
                              label: "Faculty ID",
                              value: faculty.facultyId,
                            ),
                            _InfoRow(
                              icon: Icons.email,
                              label: "Email",
                              value: faculty.email,
                            ),
                            _InfoRow(
                              icon: Icons.phone,
                              label: "Phone",
                              value: faculty.phone,
                            ),
                            _InfoRow(
                              icon: Icons.school,
                              label: "Qualification",
                              value: faculty.qualification ?? "N/A",
                            ),
                            _InfoRow(
                              icon: Icons.cake,
                              label: "Date of Birth",
                              value: faculty.dob ?? "N/A",
                            ),
                            _InfoRow(
                              icon: Icons.location_on,
                              label: "Address",
                              value: faculty.address ?? "N/A",
                            ),
                            _InfoRow(
                              icon: Icons.lock_outline_rounded,
                              label: "Password Status",
                              value: (faculty.passwordSetupStatus == "Password Reset Completed" || faculty.passwordSetupCompletedAt != null)
                                  ? "Password Reset Completed"
                                  : "Password Setup Pending",
                            ),
                            if (role == AppRoles.hod || role == AppRoles.principal || role == AppRoles.system)
                              _TemporaryPasswordRow(
                                tempPassword: faculty.tempPassword,
                                isCompleted: faculty.passwordSetupStatus == "Password Reset Completed" || faculty.passwordSetupCompletedAt != null,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // --- ACTION BAR (Principal Only) ---
              if (canApprove)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: actionState.isLoading
                                  ? null
                                  : () => _performAction(
                                      context,
                                      ref,
                                      faculty.id,
                                      'rejected',
                                    ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text("REJECT"),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: actionState.isLoading
                                  ? null
                                  : () => _performAction(
                                      context,
                                      ref,
                                      faculty.id,
                                      'approved',
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF13246E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: actionState.isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text("APPROVE"),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (canEdit && !canApprove)
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Column(
                    children: [
                      if (faculty.status.toLowerCase() == 'approved') ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.lock_reset_rounded, size: 18),
                            label: const Text(
                              "RESET PASSWORD",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13246E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _resetFacultyPassword(context, faculty),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          label: const Text(
                            "EDIT FACULTY DETAILS",
                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF13246E),
                            side: const BorderSide(color: Color(0xFF13246E)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => EditFacultyDialog.show(context, faculty),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _performAction(
    BuildContext context,
    WidgetRef ref,
    int id,
    String status,
  ) async {
    final success = await ref
        .read(facultyActionProvider.notifier)
        .updateStatus(id, status);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? "Faculty Approved Successfully"
                : "Faculty Rejected",
          ),
          backgroundColor: status == 'approved' ? Colors.green : Colors.red,
        ),
      );
      // Refresh list and details
      ref.invalidate(facultyListProvider);
      ref.invalidate(facultyDetailProvider(id));
      context.pop(); // Go back to list
    }
  }

  Future<void> _resetFacultyPassword(BuildContext context, Faculty faculty) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: const [
            Icon(Icons.lock_reset_rounded, color: Color(0xFF13246E), size: 24),
            SizedBox(width: 8),
            Text("Reset Faculty Password", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Are you sure you want to reset the password for ${faculty.name} (${faculty.facultyId})?\n\n"
          "This will immediately invalidate active sessions and generate a new temporary password.",
          style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Reset Password"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final dio = ApiClient().dio;
      dynamic res;
      try {
        res = await dio.post('/faculty/faculties/${faculty.id}/reset-password/');
      } catch (_) {
        res = await dio.post('/faculty/${faculty.id}/reset-password/');
      }

      final tempPassword = (res.data is Map && res.data['temporary_password'] != null)
          ? res.data['temporary_password'].toString()
          : null;

      if (!context.mounted) return;

      if (tempPassword != null && tempPassword.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 26),
                SizedBox(width: 8),
                Text("Password Reset Successful", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "A new temporary password has been generated for ${faculty.name} (${faculty.facultyId}).",
                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 14),
                const Text(
                  "New Temporary Password:",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SelectableText(
                        tempPassword,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: Color(0xFF13246E),
                          letterSpacing: 1.1,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF13246E)),
                        tooltip: "Copy Password",
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: tempPassword));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Password copied to clipboard!"),
                              backgroundColor: Color(0xFF13246E),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.security_rounded, size: 16, color: Color(0xFF92400E)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Important: Share this temporary password securely with the faculty member. They will be prompted to change it on their next login.",
                          style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: tempPassword));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Password copied to clipboard!"),
                      backgroundColor: Color(0xFF13246E),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text("Copy Password"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Done"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.data['message']?.toString() ?? "Password reset successfully."),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to reset password: $e"),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// --- HELPER WIDGETS ---

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TemporaryPasswordRow extends StatefulWidget {
  final String? tempPassword;
  final bool isCompleted;

  const _TemporaryPasswordRow({
    required this.tempPassword,
    required this.isCompleted,
  });

  @override
  State<_TemporaryPasswordRow> createState() => _TemporaryPasswordRowState();
}

class _TemporaryPasswordRowState extends State<_TemporaryPasswordRow> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final hasPassword = widget.tempPassword != null && widget.tempPassword!.trim().isNotEmpty;
    final displayText = widget.isCompleted
        ? "Setup Completed (Changed)"
        : (hasPassword
            ? (_obscured ? "••••••••••••" : widget.tempPassword!)
            : "Not Available");

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.key_rounded, size: 20, color: Colors.grey),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Temporary Password",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: hasPassword && !widget.isCompleted ? const Color(0xFF13246E) : Colors.black87,
                        letterSpacing: _obscured && hasPassword && !widget.isCompleted ? 2.0 : 0.5,
                      ),
                    ),
                    if (hasPassword && !widget.isCompleted) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _obscured = !_obscured;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 18,
                            color: const Color(0xFF13246E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.tempPassword!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Temporary password copied to clipboard!")),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: const Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
