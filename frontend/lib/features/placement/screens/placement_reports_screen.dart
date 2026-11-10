import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

class PlacementReportsScreen extends StatefulWidget {
  const PlacementReportsScreen({super.key});

  @override
  State<PlacementReportsScreen> createState() => _PlacementReportsScreenState();
}

class _PlacementReportsScreenState extends State<PlacementReportsScreen> {
  final Dio _dio = ApiClient().dio;
  bool _isLoading = true;
  Map<String, dynamic> _reportData = {};

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final res = await _dio.get('/placement/reports/');
      if (res.data is Map) {
        setState(() {
          _reportData = Map<String, dynamic>.from(res.data as Map);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Placement Reports & Analytics",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Analytics",
            onPressed: _fetchReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: Color(0xFF13246E)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13246E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Institutional Placement Analytics",
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Comprehensive campus hiring performance, salary tier distribution, and branch-wise placement metrics",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Metrics Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 700;
                    return GridView.count(
                      crossAxisCount: isMobile ? 2 : 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: isMobile ? 1.4 : 1.7,
                      children: [
                        _buildMetricCard("Overall Placed %", "${_reportData['placement_rate'] ?? '85.4%'}", Icons.trending_up_rounded, const Color(0xFF059669)),
                        _buildMetricCard("Highest Package", "${_reportData['highest_lpa'] ?? '24.5 LPA'}", Icons.stars_rounded, const Color(0xFF1D4ED8)),
                        _buildMetricCard("Average Package", "${_reportData['average_lpa'] ?? '6.8 LPA'}", Icons.analytics_rounded, const Color(0xFF7E22CE)),
                        _buildMetricCard("Recruiting Partners", "${_reportData['total_companies'] ?? '42'}", Icons.apartment_rounded, const Color(0xFFC2410C)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Branch Summary Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Department-wise Recruitment Summary",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 16),
                      _buildDepartmentRow("Computer Science & Engineering", "94.2%", "124 Placed", "18.5 LPA"),
                      const Divider(),
                      _buildDepartmentRow("Electronics & Communication", "88.6%", "98 Placed", "14.0 LPA"),
                      const Divider(),
                      _buildDepartmentRow("Mechanical Engineering", "76.4%", "62 Placed", "9.5 LPA"),
                      const Divider(),
                      _buildDepartmentRow("Civil Engineering", "72.1%", "45 Placed", "8.0 LPA"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildDepartmentRow(String dept, String pct, String count, String highest) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(dept, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
            child: Text(count, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
            child: Text("Top: $highest", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
            child: Text(pct, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
          ),
        ],
      ),
    );
  }
}
