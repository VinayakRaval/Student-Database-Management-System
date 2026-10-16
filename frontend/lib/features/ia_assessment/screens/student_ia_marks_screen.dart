import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';

class StudentIAMarksScreen extends StatefulWidget {
  const StudentIAMarksScreen({super.key});

  @override
  State<StudentIAMarksScreen> createState() => _StudentIAMarksScreenState();
}

class _StudentIAMarksScreenState extends State<StudentIAMarksScreen> {
  List<Map<String, dynamic>> _iaMarks = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStudentIAMarks();
  }

  Future<void> _fetchStudentIAMarks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/ia_assessment/student/ia-marks/');
      final dynamic raw = res.data;
      final List list = raw is List ? raw : (raw is Map && raw['results'] is List ? raw['results'] : []);

      setState(() {
        _iaMarks = List<Map<String, dynamic>>.from(list);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load IA marks: $e";
        });
      }
    }
  }

  double _parseDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    // Group marks by subject
    final Map<String, List<Map<String, dynamic>>> bySubject = {};
    for (final item in _iaMarks) {
      final subName = item['subject_name']?.toString() ?? 'Subject ${item['ia_test'] ?? ''}';
      bySubject.putIfAbsent(subName, () => []).add(item);
    }

    // Calculations
    double totalPctSum = 0;
    int subjectsWithMarks = 0;
    double highestScore = 0;
    int belowThreshold = 0;

    bySubject.forEach((sub, marks) {
      double subObtained = 0;
      double subMax = 0;
      for (final m in marks) {
        final obt = _parseDouble(m['obtained_marks']);
        final maxM = _parseDouble(m['max_marks'], 30.0);
        subObtained += obt;
        subMax += maxM;
        if (obt > highestScore) highestScore = obt;
      }
      if (subMax > 0) {
        final pct = (subObtained / subMax) * 100;
        totalPctSum += pct;
        subjectsWithMarks++;
        if (pct < 50) belowThreshold++;
      }
    });

    final overallAverage = subjectsWithMarks > 0 ? (totalPctSum / subjectsWithMarks) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Internal Assessment (IA) Marks",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh IA Marks",
            onPressed: _fetchStudentIAMarks,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Metric Cards
            Row(
              children: [
                _buildKpiCard(
                  title: "AVERAGE SCORE",
                  value: "${overallAverage.toStringAsFixed(1)}%",
                  icon: Icons.pie_chart_outline_rounded,
                  color: const Color(0xFF13246E),
                ),
                const SizedBox(width: 14),
                _buildKpiCard(
                  title: "SUBJECTS RECORDED",
                  value: "${bySubject.length}",
                  icon: Icons.menu_book_rounded,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 14),
                _buildKpiCard(
                  title: "HIGHEST IA MARK",
                  value: "${highestScore.toStringAsFixed(0)} pts",
                  icon: Icons.star_outline_rounded,
                  color: const Color(0xFF059669),
                ),
                const SizedBox(width: 14),
                _buildKpiCard(
                  title: "ATTENTION NEEDED",
                  value: "$belowThreshold",
                  icon: Icons.warning_amber_rounded,
                  color: belowThreshold > 0 ? Colors.red.shade700 : Colors.grey.shade700,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Content Area
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(60),
                  child: CircularProgressIndicator(color: Color(0xFF13246E)),
                ),
              )
            else if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: Colors.red.shade700),
                    const SizedBox(height: 10),
                    Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800)),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                      onPressed: _fetchStudentIAMarks,
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              )
            else if (bySubject.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(60),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.assignment_outlined, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      "No IA Marks Published Yet",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Your professors have not published Internal Assessment marks for your current semester yet.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: bySubject.entries.map((entry) {
                  final subjectName = entry.key;
                  final marks = entry.value;

                  double subObt = 0;
                  double subMax = 0;
                  for (final m in marks) {
                    subObt += _parseDouble(m['obtained_marks']);
                    subMax += _parseDouble(m['max_marks'], 30.0);
                  }
                  final subPct = subMax > 0 ? ((subObt / subMax) * 100) : 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.menu_book_rounded, color: Color(0xFF13246E), size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    subjectName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                  ),
                                  if (marks.isNotEmpty && marks.first['subject_code'] != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF13246E).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        marks.first['subject_code'].toString(),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF13246E)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: subPct >= 75
                                          ? Colors.green.shade50
                                          : (subPct >= 50 ? Colors.blue.shade50 : Colors.red.shade50),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "Average: ${subPct.toStringAsFixed(1)}%",
                                      style: TextStyle(
                                        color: subPct >= 75
                                            ? Colors.green.shade800
                                            : (subPct >= 50 ? Colors.blue.shade800 : Colors.red.shade800),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Table of IA Tests
                        DataTable(
                          headingRowHeight: 42,
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 52,
                          columns: const [
                            DataColumn(label: Text("TEST NAME", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                            DataColumn(label: Text("TYPE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                            DataColumn(label: Text("MAX MARKS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                            DataColumn(label: Text("OBTAINED", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                            DataColumn(label: Text("PERCENTAGE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                            DataColumn(label: Text("STATUS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                          ],
                          rows: marks.map((m) {
                            final testName = m['ia_name']?.toString() ?? 'IA Test';
                            final testType = m['ia_type']?.toString() ?? 'THEORY';
                            final maxM = _parseDouble(m['max_marks'], 30.0);
                            final obt = _parseDouble(m['obtained_marks']);
                            final pct = maxM > 0 ? ((obt / maxM) * 100) : 0.0;
                            final isPass = pct >= 40;

                            return DataRow(
                              cells: [
                                DataCell(Text(testName, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
                                DataCell(Text(testType, style: const TextStyle(color: Color(0xFF475569)))),
                                DataCell(Text(maxM.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w500))),
                                DataCell(Text(obt.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF13246E)))),
                                DataCell(Text("${pct.toStringAsFixed(1)}%", style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isPass ? Colors.green.shade50 : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isPass ? "Satisfactory" : "Needs Support",
                                      style: TextStyle(
                                        color: isPass ? Colors.green.shade800 : Colors.red.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
