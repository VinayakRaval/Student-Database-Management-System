import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

class StudentPlacementScreen extends StatefulWidget {
  const StudentPlacementScreen({super.key});

  @override
  State<StudentPlacementScreen> createState() => _StudentPlacementScreenState();
}

class _StudentPlacementScreenState extends State<StudentPlacementScreen>
    with SingleTickerProviderStateMixin {
  final Dio _dio = ApiClient().dio;
  late TabController _tabCtrl;
  bool _isLoading = true;

  List<Map<String, dynamic>> _eligibleDrives = [];
  List<Map<String, dynamic>> _myApplications = [];
  List<Map<String, dynamic>> _myOffers = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _fetchStudentPlacementData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStudentPlacementData() async {
    setState(() => _isLoading = true);
    try {
      final drivesRes = await _dio.get('/placement/drives/');
      final rawDrives = drivesRes.data is List
          ? drivesRes.data
          : (drivesRes.data is Map && drivesRes.data['results'] is List ? drivesRes.data['results'] : []);
      _eligibleDrives = List<Map<String, dynamic>>.from(rawDrives.map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (_) {}

    try {
      final appsRes = await _dio.get('/placement/applications/');
      final rawApps = appsRes.data is List
          ? appsRes.data
          : (appsRes.data is Map && appsRes.data['results'] is List ? appsRes.data['results'] : []);
      _myApplications = List<Map<String, dynamic>>.from(rawApps.map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (_) {}

    try {
      final offersRes = await _dio.get('/placement/offers/');
      final rawOffers = offersRes.data is List
          ? offersRes.data
          : (offersRes.data is Map && offersRes.data['results'] is List ? offersRes.data['results'] : []);
      _myOffers = List<Map<String, dynamic>>.from(rawOffers.map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (_) {}

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
          "Training & Placement Cell",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: "Active Drives (${_eligibleDrives.length})"),
            Tab(text: "My Applications (${_myApplications.length})"),
            Tab(text: "Offers (${_myOffers.length})"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF13246E)))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildDrivesTab(),
                _buildApplicationsTab(),
                _buildOffersTab(),
              ],
            ),
    );
  }

  Widget _buildDrivesTab() {
    if (_eligibleDrives.isEmpty) {
      return _buildEmptyState("No Active Placement Drives", "There are currently no active campus recruitment drives scheduled for your department.");
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _eligibleDrives.length,
      itemBuilder: (ctx, i) {
        final d = _eligibleDrives[i];
        final role = (d['job_role'] ?? 'Software Engineer').toString();
        final comp = (d['company_name'] ?? d['company'] ?? 'Partner Company').toString();
        final lpa = d['package_lpa'] != null ? "${d['package_lpa']} LPA" : "Undisclosed";
        final minCgpa = d['min_cgpa'] != null ? "Min CGPA: ${d['min_cgpa']}" : "No CGPA cutoff";

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                    Text(role, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    Text(comp, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: [
                        Text(lpa, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                        Text("•", style: TextStyle(color: Colors.grey.shade400)),
                        Text(minCgpa, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () async {
                  try {
                    await _dio.post('/placement/applications/', data: {'drive_id': d['id']});
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Successfully applied to $role at $comp!"), backgroundColor: Colors.green),
                    );
                    _fetchStudentPlacementData();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Application submitted or already in process."), backgroundColor: Colors.blue),
                    );
                  }
                },
                child: const Text("Apply Now", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApplicationsTab() {
    if (_myApplications.isEmpty) {
      return _buildEmptyState("No Applications Submitted", "You have not applied to any recruitment drives yet. Explore the Active Drives tab to apply.");
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _myApplications.length,
      itemBuilder: (ctx, i) {
        final app = _myApplications[i];
        final role = (app['job_role'] ?? 'Role').toString();
        final comp = (app['company_name'] ?? 'Company').toString();
        final status = (app['status'] ?? 'APPLIED').toString().toUpperCase();

        Color statusColor = const Color(0xFF2563EB);
        if (status == 'SELECTED') statusColor = const Color(0xFF059669);
        if (status == 'REJECTED') statusColor = const Color(0xFFDC2626);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Text(comp, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOffersTab() {
    if (_myOffers.isEmpty) {
      return _buildEmptyState("No Offers Yet", "When companies extend formal placement offers, they will be presented here with your compensation package.");
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _myOffers.length,
      itemBuilder: (ctx, i) {
        final off = _myOffers[i];
        final des = (off['designation'] ?? 'Software Engineer').toString();
        final comp = (off['company_name'] ?? 'Company').toString();
        final lpa = off['offered_package_lpa'] != null ? "${off['offered_package_lpa']} LPA" : "Offer Extended";

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF059669), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(des, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                    const SizedBox(height: 3),
                    Text(comp, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(lpa, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1D4ED8))),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline_rounded, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
