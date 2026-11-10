import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

class PlacementApplicationsScreen extends StatefulWidget {
  final int? driveId;
  const PlacementApplicationsScreen({super.key, this.driveId});

  @override
  State<PlacementApplicationsScreen> createState() =>
      _PlacementApplicationsScreenState();
}

class _PlacementApplicationsScreenState
    extends State<PlacementApplicationsScreen> {
  final Dio _dio = ApiClient().dio;
  bool _isLoading = true;
  List<Map<String, dynamic>> _applications = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchApplications() async {
    setState(() => _isLoading = true);
    try {
      final queryParams = <String, dynamic>{};
      if (widget.driveId != null) {
        queryParams['drive_id'] = widget.driveId;
      }
      final res = await _dio.get('/placement/applications/', queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final raw = res.data is List
          ? res.data
          : (res.data is Map && res.data['results'] is List ? res.data['results'] : []);
      setState(() {
        _applications = List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map)));
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredApplications {
    return _applications.where((app) {
      if (_selectedStatus != 'ALL') {
        final st = (app['status'] ?? 'APPLIED').toString().toUpperCase();
        if (st != _selectedStatus) return false;
      }
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (app['student_name'] ?? app['student'] ?? '').toString().toLowerCase();
      final usn = (app['student_usn'] ?? app['usn'] ?? '').toString().toLowerCase();
      final comp = (app['company_name'] ?? '').toString().toLowerCase();
      final role = (app['job_role'] ?? '').toString().toLowerCase();
      return name.contains(q) || usn.contains(q) || comp.contains(q) || role.contains(q);
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SELECTED':
        return const Color(0xFF059669);
      case 'SHORTLISTED':
        return const Color(0xFF2563EB);
      case 'IN_PROCESS':
        return const Color(0xFFD97706);
      case 'REJECTED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF475569);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.driveId != null
        ? "Drive Applications (#${widget.driveId})"
        : "Student Placement Applications";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          titleText,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Applications",
            onPressed: _fetchApplications,
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
                // Search & Filter Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: "Search candidate by USN, name, company, or role...",
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
                    const SizedBox(width: 14),
                    DropdownButton<String>(
                      value: _selectedStatus,
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text("All Statuses")),
                        DropdownMenuItem(value: 'APPLIED', child: Text("Applied")),
                        DropdownMenuItem(value: 'SHORTLISTED', child: Text("Shortlisted")),
                        DropdownMenuItem(value: 'IN_PROCESS', child: Text("In Process")),
                        DropdownMenuItem(value: 'SELECTED', child: Text("Selected")),
                        DropdownMenuItem(value: 'REJECTED', child: Text("Rejected")),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatus = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF13246E))))
                else if (_filteredApplications.isEmpty)
                  _buildEmptyState()
                else
                  _buildApplicationsList(),
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
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text("No Applications Found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty ? "No student applications match your filter." : "No candidates have applied to this placement drive yet.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredApplications.length,
      itemBuilder: (ctx, i) {
        final app = _filteredApplications[i];
        final name = (app['student_name'] ?? 'Candidate Name').toString();
        final usn = (app['student_usn'] ?? 'USN').toString();
        final comp = (app['company_name'] ?? 'Company').toString();
        final role = (app['job_role'] ?? 'Role').toString();
        final cgpa = (app['cgpa'] ?? 'N/A').toString();
        final status = (app['status'] ?? 'APPLIED').toString().toUpperCase();
        final statusColor = _getStatusColor(status);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF13246E).withValues(alpha: 0.08),
                child: const Icon(Icons.person, color: Color(0xFF13246E), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                        const SizedBox(width: 8),
                        Text("($usn)", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("$role • $comp", style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text("CGPA: $cgpa", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: statusColor),
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                tooltip: "Change Status",
                icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
                onSelected: (newStatus) async {
                  try {
                    await _dio.patch('/placement/applications/${app['id']}/', data: {'status': newStatus});
                    _fetchApplications();
                  } catch (_) {}
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'SHORTLISTED', child: Text("Shortlist Candidate")),
                  PopupMenuItem(value: 'SELECTED', child: Text("Mark as Selected")),
                  PopupMenuItem(value: 'REJECTED', child: Text("Mark as Rejected")),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
