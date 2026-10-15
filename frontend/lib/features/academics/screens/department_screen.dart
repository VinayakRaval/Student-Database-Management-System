import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class DepartmentScreen extends StatefulWidget {
  const DepartmentScreen({super.key});

  @override
  State<DepartmentScreen> createState() => _DepartmentScreenState();
}

class _DepartmentScreenState extends State<DepartmentScreen> {
  bool _isLoading = true;
  String? _error;
  String _departmentName = 'Department';
  int _facultyCount = 0;
  int _studentCount = 0;
  int _subjectCount = 0;
  int _pendingVerificationCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchDepartmentData();
  }

  Future<void> _fetchDepartmentData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ApiClient().dio;

      // 1. Fetch dashboard or user info to get department name
      try {
        final dashRes = await dio.get('/dashboard/');
        if (dashRes.data != null && dashRes.data['user'] != null) {
          final user = dashRes.data['user'];
          if (user['department'] != null) {
            _departmentName = user['department'].toString();
          }
        }
      } catch (_) {}

      // 2. Fetch department stats concurrently with independent catchError
      final results = await Future.wait([
        dio.get('/faculty/faculties/').catchError((e) => Response(requestOptions: RequestOptions(path: ''), data: [])),
        dio.get('/students/list/').catchError((e) => Response(requestOptions: RequestOptions(path: ''), data: [])),
        dio.get('/subjects/getSubjects/').catchError((e) => Response(requestOptions: RequestOptions(path: ''), data: [])),
      ]);

      List getList(dynamic resData) {
        if (resData is List) return resData;
        if (resData is Map && resData['results'] is List) return resData['results'];
        return [];
      }

      final facultyList = getList(results[0].data);
      final studentList = getList(results[1].data);
      final subjectList = getList(results[2].data);

      int pendingCount = 0;
      for (var s in studentList) {
        if (s is Map && (s['registration_status'] == 'registered')) {
          pendingCount++;
        }
      }

      if (mounted) {
        setState(() {
          _facultyCount = facultyList.length;
          _studentCount = studentList.length;
          _subjectCount = subjectList.length;
          _pendingVerificationCount = pendingCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userEmail = auth.userData?['email'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("My Department"),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
            onPressed: _fetchDepartmentData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text("Error: $_error", textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchDepartmentData,
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchDepartmentData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF13246E), Color(0xFF3B38A0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.account_balance_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "HEAD OF DEPARTMENT",
                                      style: TextStyle(
                                        color: Colors.amberAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _departmentName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (userEmail.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              "Logged in as: $userEmail",
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      "Department Statistics",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 12),

                    // Stats Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatTile(
                            title: "Students",
                            value: "$_studentCount",
                            icon: Icons.people_alt_rounded,
                            color: const Color(0xFF13246E),
                            onTap: () => context.push('/admissions/list'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatTile(
                            title: "Faculty",
                            value: "$_facultyCount",
                            icon: Icons.school_rounded,
                            color: const Color(0xFF00897B),
                            onTap: () => context.push('/faculty'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatTile(
                            title: "Subjects",
                            value: "$_subjectCount",
                            icon: Icons.menu_book_rounded,
                            color: const Color(0xFF1565C0),
                            onTap: () => context.push('/subjects'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatTile(
                            title: "Pending Verifications",
                            value: "$_pendingVerificationCount",
                            icon: Icons.pending_actions_rounded,
                            color: const Color(0xFFE65100),
                            onTap: () => context.push('/admissions/list'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),
                    const Text(
                      "Quick Actions",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 12),

                    // Quick Actions List
                    _buildActionTile(
                      title: "Department Timetable",
                      subtitle: "View and manage complete weekly timetable",
                      icon: Icons.grid_view_rounded,
                      color: const Color(0xFF13246E),
                      onTap: () => context.push('/timetable/list'),
                    ),
                    _buildActionTile(
                      title: "My Teaching Schedule",
                      subtitle: "View your personal teaching lecture slots",
                      icon: Icons.schedule_rounded,
                      color: const Color(0xFF3B38A0),
                      onTap: () => context.push('/timetable/my-schedule'),
                    ),
                    _buildActionTile(
                      title: "Manage Subjects",
                      subtitle: "View curriculum subjects and assign professors",
                      icon: Icons.library_books_rounded,
                      color: const Color(0xFF00897B),
                      onTap: () => context.push('/subjects'),
                    ),
                    _buildActionTile(
                      title: "Student Verification & Roster",
                      subtitle: "Verify new student registrations and manage records",
                      icon: Icons.how_to_reg_rounded,
                      color: const Color(0xFF1565C0),
                      onTap: () => context.push('/admissions/list'),
                    ),
                    _buildActionTile(
                      title: "Mark Class Attendance",
                      subtitle: "Record student attendance for assigned slots",
                      icon: Icons.fact_check_rounded,
                      color: const Color(0xFF2E7D32),
                      onTap: () => context.push('/attendance'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
