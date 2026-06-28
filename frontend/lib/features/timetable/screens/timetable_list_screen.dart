import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:frontend/core/constants/api_constants.dart';
import '../providers/timetable_provider.dart';
import '../models/timetable_model.dart';

final _roleProvider = FutureProvider<String?>((ref) async {
  const storage = FlutterSecureStorage();
  return await storage.read(key: 'role');
});

class TimetableListScreen extends ConsumerWidget {
  final String? filterType;

  const TimetableListScreen({super.key, this.filterType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(_roleProvider);
    final role = roleAsync.value ?? 'STUDENT';

    String filter = filterType ?? 'all';
    if (filterType == null) {
      if (role == AppRoles.principal) {
        filter = 'pending';
      } else if (role == AppRoles.hod) {
        filter = 'hod';
      } else if (role == AppRoles.professor) {
        filter = 'faculty';
      } else if (role == AppRoles.student) {
        filter = 'student';
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Timetables",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
                .read(timetableProvider.notifier)
                .fetchTimetables(filter: filter),
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(timetableProvider);
          if (state.timetables.isEmpty &&
              !state.isLoading &&
              state.errorMessage == null) {
            Future.microtask(
              () => ref
                  .read(timetableProvider.notifier)
                  .fetchTimetables(filter: filter),
            );
          }
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.errorMessage != null) {
            return Center(child: Text("Error: ${state.errorMessage}"));
          }
          if (state.timetables.isEmpty) {
            return const Center(
              child: Text(
                "No timetables found.",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.timetables.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = state.timetables[index];
              return _TimetableCard(item: item);
            },
          );
        },
      ),
      floatingActionButton: role == AppRoles.hod
          ? FloatingActionButton.extended(
              heroTag: 'timetable_create_fab',
              backgroundColor: const Color(0xFF13246E),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Create New",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => context.push('/timetable/create'),
            )
          : null,
    );
  }
}

class _TimetableCard extends StatelessWidget {
  final TimeTable item;
  const _TimetableCard({required this.item});

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.orange;
    if (item.status == 'Approved') statusColor = Colors.green;
    if (item.status == 'Rejected') statusColor = Colors.red;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => context.push('/timetable/detail/${item.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "${item.departmentName} - Sem ${item.semesterNo}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    "AY: ${item.academicYearLabel} • v${item.version}",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              if (item.isActive)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle, size: 14, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        "Active",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
