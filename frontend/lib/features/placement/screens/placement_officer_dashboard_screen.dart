import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/api_client.dart';

class PlacementOfficerDashboardScreen extends StatefulWidget {
  const PlacementOfficerDashboardScreen({super.key});

  @override
  State<PlacementOfficerDashboardScreen> createState() =>
      _PlacementOfficerDashboardScreenState();
}

class _PlacementOfficerDashboardScreenState
    extends State<PlacementOfficerDashboardScreen> {
  final Dio _dio = ApiClient().dio;
  bool _isLoading = true;

  int _companiesCount = 0;
  int _drivesCount = 0;
  int _applicationsCount = 0;
  int _offersCount = 0;
  String _avgPackage = "0.0 LPA";
  String _highestPackage = "0.0 LPA";
  List<Map<String, dynamic>> _recentDrives = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _dio.get('/placement/stats/');
      if (res.data is Map) {
        final d = res.data;
        _companiesCount = d['companies_count'] ?? 0;
        _drivesCount = d['drives_count'] ?? 0;
        _applicationsCount = d['applications_count'] ?? 0;
        _offersCount = d['offers_count'] ?? 0;
        _avgPackage = d['avg_package_lpa'] != null ? "${d['avg_package_lpa']} LPA" : "0.0 LPA";
        _highestPackage = d['highest_package_lpa'] != null ? "${d['highest_package_lpa']} LPA" : "0.0 LPA";
        final rawDrives = d['recent_drives'];
        if (rawDrives is List) {
          _recentDrives = rawDrives.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (_) {}

    if (_recentDrives.isEmpty) {
      try {
        final dRes = await _dio.get('/placement/drives/');
        final raw = dRes.data is List ? dRes.data : (dRes.data is Map && dRes.data['results'] is List ? dRes.data['results'] : []);
        _recentDrives = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _drivesCount = _recentDrives.length;
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Placement Officer Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: _loadDashboardData,
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
                // Hero Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13246E),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF13246E).withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Campus Placement & Career Hub",
                              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Coordinate corporate hiring drives, monitor student applications, and finalize job offers (Avg: $_avgPackage | Highest: $_highestPackage)",
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF13246E),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.add_business_rounded, size: 16),
                            label: const Text("Companies", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () => context.push('/placement/companies'),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.event_available_rounded, size: 16),
                            label: const Text("Drives", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () => context.push('/placement/drives'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Stat KPI Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 750;
                    return GridView.count(
                      crossAxisCount: isMobile ? 2 : 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: isMobile ? 1.3 : 1.7,
                      children: [
                        _buildKpiCard("Partner Companies", "$_companiesCount", Icons.business_rounded, const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
                        _buildKpiCard("Placement Drives", "$_drivesCount", Icons.event_note_rounded, const Color(0xFFF0FDF4), const Color(0xFF15803D)),
                        _buildKpiCard("Applications", "$_applicationsCount", Icons.assignment_ind_rounded, const Color(0xFFFAF5FF), const Color(0xFF7E22CE)),
                        _buildKpiCard("Offers Released", "$_offersCount", Icons.workspace_premium_rounded, const Color(0xFFFFF7ED), const Color(0xFFC2410C)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Active Drives Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Active Placement Drives",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text("View All Drives"),
                      onPressed: () => context.push('/placement/drives'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFF13246E))))
                else if (_recentDrives.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text("No active drives scheduled", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        const SizedBox(height: 4),
                        Text("Create a new drive to start accepting student applications.", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  )
                else
                  ..._recentDrives.take(5).map((drive) {
                    final role = (drive['job_role'] ?? 'Software Engineer').toString();
                    final comp = (drive['company_name'] ?? drive['company'] ?? 'Partner Company').toString();
                    final lpa = drive['package_lpa'] != null ? "${drive['package_lpa']} LPA" : "Undisclosed";
                    final status = (drive['status'] ?? 'PUBLISHED').toString().toUpperCase();

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
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13246E).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.work_rounded, color: Color(0xFF13246E), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(role, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                                const SizedBox(height: 3),
                                Text(comp, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              lpa,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1D4ED8)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'PUBLISHED' ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: status == 'PUBLISHED' ? const Color(0xFF15803D) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13246E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => context.push('/placement/applications?drive_id=${drive['id']}'),
                            child: const Text("Applications", style: TextStyle(fontSize: 12)),
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

  Widget _buildKpiCard(String label, String value, IconData icon, Color bg, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }
}
