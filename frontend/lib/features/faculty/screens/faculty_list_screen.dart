import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:frontend/core/constants/api_constants.dart';
import '../providers/faculty_provider.dart';
import '../models/faculty_model.dart';
import '../widgets/edit_faculty_dialog.dart';

final _storage = const FlutterSecureStorage();

class FacultyListScreen extends ConsumerWidget {
  final String? filterType;
  final String? customTitle;

  const FacultyListScreen({super.key, this.filterType, this.customTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String filter = filterType ?? 'all';
    final listAsync = ref.watch(facultyListProvider(filter));

    String title = customTitle ?? "Faculty Directory";
    if (customTitle == null && filter == 'pending') {
      title = "Pending Approvals";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(facultyListProvider(filter)),
          ),
        ],
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text(
                "No records found.",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final Faculty item = list[index];
              return _FacultyCard(item: item);
            },
          );
        },
      ),
      floatingActionButton: _buildFAB(context, ref),
    );
  }

  Widget? _buildFAB(BuildContext context, WidgetRef ref) {
    // Use FutureBuilder to get role from storage
    return FutureBuilder<String?>(
      future: _storage.read(key: 'role'),
      builder: (context, snapshot) {
        final role = snapshot.data;
        if (role == AppRoles.admission) {
          return FloatingActionButton.extended(
            backgroundColor: const Color(0xFF13246E),
            foregroundColor: Colors.white,
            onPressed: () => context.push('/faculty/register'),
            label: const Text("Register New"),
            icon: const Icon(Icons.person_add),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _FacultyCard extends StatelessWidget {
  final Faculty item;
  const _FacultyCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isApproved = item.status.toLowerCase() == 'approved';
    final isRejected = item.status.toLowerCase() == 'rejected';

    Color statusColor = Colors.orange;
    if (isApproved) statusColor = Colors.green;
    if (isRejected) statusColor = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: item.photoUrl != null
                ? NetworkImage(item.photoUrl!)
                : null,
            child: item.photoUrl == null
                ? Text(
                    item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${item.role} • ${item.department}",
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  item.facultyId,
                  style: const TextStyle(
                    color: Color(0xFF13246E),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF13246E)),
                    tooltip: "Edit Faculty",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => EditFacultyDialog.show(context, item),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => context.push('/faculty/detail/${item.id}'),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Text(
                        "View >",
                        style: TextStyle(
                          color: Color(0xFF13246E),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
