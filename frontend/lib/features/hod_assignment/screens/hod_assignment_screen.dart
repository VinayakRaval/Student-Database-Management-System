import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hod_provider.dart';
import '../models/hod_model.dart';
import '../../faculty/models/faculty_model.dart'; 

class HODAssignmentScreen extends ConsumerWidget {
  const HODAssignmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hodState = ref.watch(hodProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text("HOD Management", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Color(0xFF13246E),
            indicatorColor: Color(0xFF13246E),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "Current HODs"),
              Tab(text: "History"),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(hodProvider.notifier).fetchAllData(),
            )
          ],
        ),
        body: hodState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildList(hodState.currentHODs, isHistory: false),
                  _buildList(hodState.previousHODs, isHistory: true),
                ],
              ),
        
        // --- FIX: Always show button ---
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF13246E),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text("Assign New HOD", style: TextStyle(color: Colors.white)),
          onPressed: () {
            // Check if dropdown data is ready before opening dialog
            if (hodState.departments.isEmpty || hodState.faculties.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Data not loaded yet. Please click Refresh (Top Right).")),
              );
              ref.read(hodProvider.notifier).fetchAllData(); 
            } else {
              _showAssignDialog(context, ref, hodState);
            }
          },
        ),
      ),
    );
  }

  // ... (Keep _buildList and _showAssignDialog same as before) ...
  Widget _buildList(List<HODAssignment> list, {required bool isHistory}) {
    if (list.isEmpty) {
      return const Center(child: Text("No records found", style: TextStyle(color: Colors.grey)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = list[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isHistory ? Colors.grey.shade200 : const Color(0xFFE0E7FF),
                child: Icon(
                  Icons.person, 
                  color: isHistory ? Colors.grey : const Color(0xFF13246E)
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.departmentName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF13246E)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.facultyName,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isHistory 
                        ? "Served: ${item.assignedDate} to ${item.endDate}" 
                        : "Assigned: ${item.assignedDate}",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (!isHistory)
                const Chip(
                  label: Text("Active", style: TextStyle(fontSize: 10, color: Colors.green)),
                  backgroundColor: Color(0xFFE8F5E9),
                  padding: EdgeInsets.zero,
                )
            ],
          ),
        );
      },
    );
  }

  void _showAssignDialog(BuildContext context, WidgetRef ref, HODState state) {
    int? selectedDept;
    int? selectedFaculty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Assign HOD"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Assigning a new HOD will automatically end the term of the current HOD.", 
                  style: TextStyle(fontSize: 12, color: Colors.grey)
                ),
                const SizedBox(height: 20),
                
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: "Select Department", border: OutlineInputBorder()),
                  items: state.departments.map((dept) {
                    return DropdownMenuItem(value: dept.id, child: Text(dept.name));
                  }).toList(),
                  onChanged: (val) => setState(() => selectedDept = val),
                ),
                
                const SizedBox(height: 16),

                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: "Select Faculty", border: OutlineInputBorder()),
                  items: state.faculties.map((Faculty fac) {
                    return DropdownMenuItem(
                      value: fac.id, 
                      child: Text("${fac.name} (${fac.department})", overflow: TextOverflow.ellipsis)
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedFaculty = val),
                  isExpanded: true,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E)),
                onPressed: () async {
                  if (selectedDept == null || selectedFaculty == null) return;
                  Navigator.pop(ctx);
                  
                  final success = await ref.read(hodProvider.notifier).assignHOD(selectedDept!, selectedFaculty!);
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("HOD Assigned Successfully"), backgroundColor: Colors.green)
                    );
                  }
                },
                child: const Text("Assign", style: TextStyle(color: Colors.white)),
              )
            ],
          );
        }
      ),
    );
  }
}