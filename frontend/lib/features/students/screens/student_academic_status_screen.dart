import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';

class StudentAcademicStatusScreen extends StatefulWidget {
  const StudentAcademicStatusScreen({super.key});

  @override
  State<StudentAcademicStatusScreen> createState() => _StudentAcademicStatusScreenState();
}

class _StudentAcademicStatusScreenState extends State<StudentAcademicStatusScreen> {
  Map<String, dynamic>? _studentData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStudentStatus();
  }

  Future<void> _fetchStudentStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/students/me/');
      if (mounted) {
        setState(() {
          _studentData = Map<String, dynamic>.from(res.data as Map);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load academic status: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _studentData;
    final semNum = s?['semester_name'] ?? (s?['semester'] != null ? s!['semester'].toString() : 'N/A');
    final deptName = s?['department_name'] ?? 'Assigned Department';
    final usn = s?['usn'] ?? 'Pending Assignment';
    final admissionId = s?['admission_id'] ?? 'N/A';
    final yearName = s?['academic_year_name'] ?? 'Current Year';
    final regStatus = (s?['registration_status'] ?? 'pending').toString().toUpperCase();
    final isActive = s?['status'] == 'active';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Academic Status & Semester Progression",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh Status",
            onPressed: _fetchStudentStatus,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.timeline_rounded, color: Color(0xFF13246E), size: 28),
                        SizedBox(width: 10),
                        Text(
                          "Academic Status & Progression",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF13246E),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Current semester standing, enrollment eligibility, and academic history",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13246E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _fetchStudentStatus,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text("Refresh"),
                ),
              ],
            ),
            const SizedBox(height: 24),

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
                      onPressed: _fetchStudentStatus,
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              )
            else ...[
              // Summary KPI Grid
              Row(
                children: [
                  _buildStatusCard(
                    title: "CURRENT SEMESTER",
                    value: "Semester $semNum",
                    subtitle: "Department: $deptName",
                    icon: Icons.school_rounded,
                    color: const Color(0xFF13246E),
                  ),
                  const SizedBox(width: 14),
                  _buildStatusCard(
                    title: "UNIVERSITY NUMBER (USN)",
                    value: usn,
                    subtitle: "Admission ID: $admissionId",
                    icon: Icons.badge_rounded,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 14),
                  _buildStatusCard(
                    title: "ENROLLMENT STATUS",
                    value: isActive ? "Active Student" : "Inactive",
                    subtitle: "Approval: $regStatus",
                    icon: Icons.verified_user_rounded,
                    color: isActive ? const Color(0xFF059669) : Colors.amber.shade800,
                  ),
                  const SizedBox(width: 14),
                  _buildStatusCard(
                    title: "ACADEMIC YEAR",
                    value: yearName,
                    subtitle: "Curriculum Regulation: CBCS",
                    icon: Icons.date_range_rounded,
                    color: Colors.indigo.shade700,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Progression Timeline Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.stairs_rounded, color: Color(0xFF13246E), size: 22),
                        SizedBox(width: 10),
                        Text(
                          "Semester Progression Track",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Track your degree progression from Semester 1 to Semester 8 Graduation",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // Semester visual steps
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(8, (i) {
                          final stepSem = i + 1;
                          final curInt = int.tryParse(semNum.toString()) ?? 1;
                          final isCompleted = stepSem < curInt;
                          final isCurrent = stepSem == curInt;

                          Color circleColor;
                          Color iconColor;
                          if (isCompleted) {
                            circleColor = Colors.green.shade600;
                            iconColor = Colors.white;
                          } else if (isCurrent) {
                            circleColor = const Color(0xFF13246E);
                            iconColor = Colors.white;
                          } else {
                            circleColor = const Color(0xFFE2E8F0);
                            iconColor = const Color(0xFF94A3B8);
                          }

                          return Row(
                            children: [
                              Column(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: circleColor,
                                    child: isCompleted
                                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                                        : Text(
                                            "$stepSem",
                                            style: TextStyle(color: iconColor, fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Sem $stepSem",
                                    style: TextStyle(
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 12,
                                      color: isCurrent ? const Color(0xFF13246E) : const Color(0xFF64748B),
                                    ),
                                  ),
                                  if (isCurrent)
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF13246E),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text("Current", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              if (stepSem < 8)
                                Container(
                                  width: 44,
                                  height: 3,
                                  margin: const EdgeInsets.only(bottom: 22),
                                  color: isCompleted ? Colors.green.shade600 : const Color(0xFFE2E8F0),
                                ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Academic Details & Promotion Rules
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "ADMISSION & PROFILE RECORD",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF13246E), letterSpacing: 0.5),
                          ),
                          const Divider(height: 20),
                          _buildDetailRow("Full Name", s?['name'] ?? '-'),
                          _buildDetailRow("Department", deptName),
                          _buildDetailRow("CET / Entrance No", s?['cet_no'] ?? '-'),
                          _buildDetailRow("Seat Type", s?['seat_type'] ?? 'General Merit'),
                          _buildDetailRow("Date of Admission", s?['date_of_admission'] ?? '-'),
                          _buildDetailRow("Registration Approval", regStatus),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "SEMESTER PROMOTION REQUIREMENTS",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF13246E), letterSpacing: 0.5),
                          ),
                          const Divider(height: 20),
                          _buildRequirementItem(
                            title: "Minimum Attendance Requirement",
                            description: "Must maintain at least 75% subject-wise and 85% aggregate attendance to be eligible for semester end exams.",
                            icon: Icons.pie_chart_outline_rounded,
                            isPassed: true,
                          ),
                          const SizedBox(height: 14),
                          _buildRequirementItem(
                            title: "Internal Assessment Completion",
                            description: "Must complete IA-1, IA-2, and IA-3 with satisfactory scores submitted by professors.",
                            icon: Icons.assignment_turned_in_rounded,
                            isPassed: true,
                          ),
                          const SizedBox(height: 14),
                          _buildRequirementItem(
                            title: "Fee Clearance & Library Dues",
                            description: "All semester fee dues and library book returns must be cleared prior to semester progression approval.",
                            icon: Icons.account_balance_wallet_rounded,
                            isPassed: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String value,
    required String subtitle,
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildRequirementItem({
    required String title,
    required String description,
    required IconData icon,
    required bool isPassed,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFF13246E).withValues(alpha: 0.08),
          child: Icon(icon, size: 16, color: const Color(0xFF13246E)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}
