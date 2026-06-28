import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/providers/auth_riverpod_bridge.dart';
import 'package:frontend/core/constants/api_constants.dart';
import '../providers/faculty_provider.dart';
import '../models/faculty_model.dart';

class FacultyDetailScreen extends ConsumerWidget {
  final int id;
  const FacultyDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFaculty = ref.watch(facultyDetailProvider(id));
    final role = ref.watch(authRoleProvider);
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
      ),
      body: asyncFaculty.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),

        data: (Faculty faculty) {
          // Logic: Principal can approve if status is pending_principal
          final canApprove =
              (role == AppRoles.principal) &&
              (faculty.status == 'pending_principal' ||
                  faculty.status == 'pending_office');

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
