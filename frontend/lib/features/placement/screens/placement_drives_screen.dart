import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/api_client.dart';

class PlacementDrivesScreen extends StatefulWidget {
  const PlacementDrivesScreen({super.key});

  @override
  State<PlacementDrivesScreen> createState() => _PlacementDrivesScreenState();
}

class _PlacementDrivesScreenState extends State<PlacementDrivesScreen> {
  final Dio _dio = ApiClient().dio;
  bool _isLoading = true;
  List<Map<String, dynamic>> _drives = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchDrives();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDrives() async {
    setState(() => _isLoading = true);
    try {
      final res = await _dio.get('/placement/drives/');
      final raw = res.data is List
          ? res.data
          : (res.data is Map && res.data['results'] is List ? res.data['results'] : []);
      setState(() {
        _drives = List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map)));
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredDrives {
    return _drives.where((d) {
      if (_statusFilter != 'ALL') {
        final st = (d['status'] ?? 'PUBLISHED').toString().toUpperCase();
        if (st != _statusFilter) return false;
      }
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final role = (d['job_role'] ?? '').toString().toLowerCase();
      final comp = (d['company_name'] ?? d['company'] ?? '').toString().toLowerCase();
      return role.contains(q) || comp.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Campus Placement Drives",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Drives",
            onPressed: _fetchDrives,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Action Bar
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: "Search drive by job role or company...",
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _statusFilter,
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text("All Statuses")),
                        DropdownMenuItem(value: 'PUBLISHED', child: Text("Active / Published")),
                        DropdownMenuItem(value: 'CLOSED', child: Text("Closed")),
                        DropdownMenuItem(value: 'DRAFT', child: Text("Draft")),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _statusFilter = val);
                      },
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13246E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_task_rounded, size: 18),
                      label: const Text("Create Drive", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _showCreateDriveDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF13246E))))
                else if (_filteredDrives.isEmpty)
                  _buildEmptyState()
                else
                  ..._filteredDrives.map((d) {
                    final role = (d['job_role'] ?? 'Role').toString();
                    final comp = (d['company_name'] ?? d['company'] ?? 'Company').toString();
                    final lpa = d['package_lpa'] != null ? "${d['package_lpa']} LPA" : "TBD";
                    final minCgpa = d['min_cgpa'] != null ? "Min CGPA: ${d['min_cgpa']}" : "No CGPA cutoff";
                    final maxBklg = d['max_active_backlogs'] != null ? "Max Backlogs: ${d['max_active_backlogs']}" : "0 Backlogs";
                    final deadline = (d['application_deadline'] ?? d['deadline'] ?? 'Open').toString();
                    final status = (d['status'] ?? 'PUBLISHED').toString().toUpperCase();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13246E).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.work_rounded, color: Color(0xFF13246E), size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(role, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: status == 'PUBLISHED' ? const Color(0xFFECFDF5) : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: status == 'PUBLISHED' ? const Color(0xFFA7F3D0) : Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: status == 'PUBLISHED' ? const Color(0xFF047857) : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(comp, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.payments_outlined, size: 14, color: Color(0xFF1D4ED8)),
                                        const SizedBox(width: 4),
                                        Text(lpa, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.school_outlined, size: 14, color: Color(0xFF64748B)),
                                        const SizedBox(width: 4),
                                        Text(minCgpa, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.error_outline, size: 14, color: Color(0xFF64748B)),
                                        const SizedBox(width: 4),
                                        Text(maxBklg, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF64748B)),
                                        const SizedBox(width: 4),
                                        Text("Deadline: $deadline", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13246E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.assignment_ind, size: 16),
                            label: const Text("Applications", style: TextStyle(fontSize: 12)),
                            onPressed: () => context.push('/placement/applications?drive_id=${d['id']}'),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.event_note_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text("No Placement Drives Scheduled", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            "Schedule campus recruitment drives for eligible academic batches and departments.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text("Create Campus Drive"),
            onPressed: _showCreateDriveDialog,
          ),
        ],
      ),
    );
  }

  void _showCreateDriveDialog() {
    final roleCtrl = TextEditingController();
    final compCtrl = TextEditingController();
    final lpaCtrl = TextEditingController();
    final cgpaCtrl = TextEditingController();
    final deadlineCtrl = TextEditingController(text: "2026-11-15");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Schedule Placement Drive", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: roleCtrl, decoration: InputDecoration(labelText: "Job Designation / Role *", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 10),
              TextField(controller: compCtrl, decoration: InputDecoration(labelText: "Company Name *", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: lpaCtrl, decoration: InputDecoration(labelText: "Package (LPA)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: cgpaCtrl, decoration: InputDecoration(labelText: "Min CGPA Cutoff", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: deadlineCtrl, decoration: InputDecoration(labelText: "Application Deadline (YYYY-MM-DD)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
            onPressed: () async {
              if (roleCtrl.text.trim().isNotEmpty) {
                try {
                  await _dio.post('/placement/drives/', data: {
                    'job_role': roleCtrl.text.trim(),
                    'company_name': compCtrl.text.trim(),
                    'package_lpa': double.tryParse(lpaCtrl.text.trim()) ?? 0.0,
                    'min_cgpa': double.tryParse(cgpaCtrl.text.trim()) ?? 0.0,
                    'application_deadline': deadlineCtrl.text.trim(),
                    'status': 'PUBLISHED',
                  });
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx);
                _fetchDrives();
              }
            },
            child: const Text("Create Drive"),
          ),
        ],
      ),
    );
  }
}
