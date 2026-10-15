import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:provider/provider.dart' as p;
import 'package:frontend/features/auth/providers/auth_provider.dart';

import 'package:frontend/core/constants/api_constants.dart';
import '../providers/timetable_provider.dart';
import '../models/timetable_model.dart';

final _roleProvider = FutureProvider<String?>((ref) async {
  const storage = FlutterSecureStorage();
  return storage.read(key: 'role');
});

class TimetableListScreen extends ConsumerWidget {
  final String? filterType;

  const TimetableListScreen({super.key, this.filterType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = p.Provider.of<AuthProvider>(context);
    final roleAsync = ref.watch(_roleProvider);
    final role = (auth.role ?? roleAsync.value ?? 'HOD').toUpperCase();

    var filter = filterType ?? 'all';

    if (filterType == null) {
      if (role == AppRoles.principal || role == AppRoles.system) {
        filter = 'pending';
      } else if (role == AppRoles.hod) {
        filter = 'hod';
      } else if (role == AppRoles.professor) {
        filter = 'faculty';
      } else if (role == AppRoles.student) {
        filter = 'student';
      } else {
        filter = 'hod';
      }
    }

    final timetableAsync = ref.watch(timetableListProvider(filter));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Timetables',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh timetables',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(timetableListProvider(filter));
            },
          ),
        ],
      ),
      body: timetableAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Unable to load timetables',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(timetableListProvider(filter));
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (timetables) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(timetableListProvider(filter));
              await ref.read(timetableListProvider(filter).future);
            },
            child: timetables.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 200),
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 56,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 12),
                      Center(
                        child: Text(
                          'No timetables found.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: timetables.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _TimetableCard(item: timetables[index]);
                    },
                  ),
          );
        },
      ),
      floatingActionButton: (role == AppRoles.hod || role == AppRoles.system)
          ? FloatingActionButton.extended(
              heroTag: 'timetable_create_fab',
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Create New'),
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
    final status = item.status.toLowerCase();

    final statusColor = status == 'approved'
        ? Colors.green
        : status == 'rejected'
        ? Colors.red
        : Colors.orange;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          context.push('/timetable/detail/${item.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.departmentName} - Sem ${item.semesterNo}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'AY: ${item.academicYearLabel} • v${item.version}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
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
              if (item.isActive) ...[
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(Icons.check_circle, size: 15, color: Colors.green),
                    SizedBox(width: 5),
                    Text(
                      'Active',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
