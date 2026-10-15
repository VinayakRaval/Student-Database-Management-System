import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class StudentItem {
  final int id;
  final String name;
  final String admissionId;
  final String? usn;
  final String? cetNo;
  final String email;
  final String phone;
  final String? dob;
  final String? gender;
  final String? fatherName;
  final String? motherName;
  final String? address;
  final String? permanentAddress;
  final String? seatType;
  final String? admissionQuota;
  final String? rank;
  final String? dateOfAdmission;
  final String departmentName;
  final String semesterName;
  final String academicYearName;
  final String registrationStatus;
  final String status;
  final String? sslcReg;
  final int? sslcObtained;
  final int? sslcTotal;
  final String? pucReg;
  final int? pucObtained;
  final int? pucTotal;
  final String? diplomaReg;
  final int? diplomaObtained;
  final int? diplomaTotal;
  final Map<String, dynamic>? documents;

  StudentItem({
    required this.id,
    required this.name,
    required this.admissionId,
    this.usn,
    this.cetNo,
    required this.email,
    required this.phone,
    this.dob,
    this.gender,
    this.fatherName,
    this.motherName,
    this.address,
    this.permanentAddress,
    this.seatType,
    this.admissionQuota,
    this.rank,
    this.dateOfAdmission,
    required this.departmentName,
    required this.semesterName,
    required this.academicYearName,
    required this.registrationStatus,
    required this.status,
    this.sslcReg,
    this.sslcObtained,
    this.sslcTotal,
    this.pucReg,
    this.pucObtained,
    this.pucTotal,
    this.diplomaReg,
    this.diplomaObtained,
    this.diplomaTotal,
    this.documents,
  });

  factory StudentItem.fromJson(Map<String, dynamic> json) {
    return StudentItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown Student',
      admissionId: json['admission_id'] ?? '',
      usn: json['usn'],
      cetNo: json['cet_no'],
      email: json['email'] ?? '',
      phone: json['mobile_no'] ?? json['phone'] ?? '',
      dob: json['dob']?.toString(),
      gender: json['gender']?.toString(),
      fatherName: json['father_name']?.toString(),
      motherName: json['mother_name']?.toString(),
      address: json['address']?.toString(),
      permanentAddress: json['permanent_address']?.toString(),
      seatType: json['seat_type']?.toString(),
      admissionQuota: json['admission_quota']?.toString(),
      rank: json['rank']?.toString(),
      dateOfAdmission: json['date_of_admission']?.toString(),
      departmentName: json['department_name'] ?? json['department']?.toString() ?? '',
      semesterName: json['semester_name'] ?? (json['semester'] != null ? "Sem ${json['semester']}" : ''),
      academicYearName: json['academic_year_name'] ?? json['academic_year']?.toString() ?? '',
      registrationStatus: (json['registration_status'] ?? 'registered').toString().toLowerCase(),
      status: (json['status'] ?? 'active').toString().toLowerCase(),
      sslcReg: json['sslc_regno']?.toString(),
      sslcObtained: json['sslc_obtain_marks'] is int ? json['sslc_obtain_marks'] : int.tryParse(json['sslc_obtain_marks']?.toString() ?? ''),
      sslcTotal: json['sslc_total_marks'] is int ? json['sslc_total_marks'] : int.tryParse(json['sslc_total_marks']?.toString() ?? ''),
      pucReg: json['puc_regno']?.toString(),
      pucObtained: json['puc_obtain_marks'] is int ? json['puc_obtain_marks'] : int.tryParse(json['puc_obtain_marks']?.toString() ?? ''),
      pucTotal: json['puc_total_marks'] is int ? json['puc_total_marks'] : int.tryParse(json['puc_total_marks']?.toString() ?? ''),
      diplomaReg: json['diploma_regno']?.toString(),
      diplomaObtained: json['diploma_obtain_marks'] is int ? json['diploma_obtain_marks'] : int.tryParse(json['diploma_obtain_marks']?.toString() ?? ''),
      diplomaTotal: json['diploma_total_marks'] is int ? json['diploma_total_marks'] : int.tryParse(json['diploma_total_marks']?.toString() ?? ''),
      documents: json['documents'] is Map<String, dynamic> ? json['documents'] : null,
    );
  }
}

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  List<StudentItem> _students = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ApiClient().dio;
      final response = await dio.get('/students/list/');
      List data = [];
      if (response.data is List) {
        data = response.data;
      } else if (response.data is Map && response.data['results'] is List) {
        data = response.data['results'];
      }

      if (mounted) {
        setState(() {
          _students = data.map((e) => StudentItem.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyStudent(int id) async {
    try {
      final dio = ApiClient().dio;
      await dio.put('/students/$id/verify/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student registration verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchStudents();
      }
    } catch (e) {
      if (mounted) {
        String err = 'Verification failed';
        if (e is DioException && e.response?.data != null) {
          err = e.response?.data is Map && (e.response!.data as Map).containsKey('error')
              ? (e.response!.data as Map)['error'].toString()
              : e.response!.data.toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveStudent(int id, String action) async {
    try {
      final dio = ApiClient().dio;
      await dio.put(
        '/students/$id/approve/',
        data: {'action': action},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Student ${action}d successfully!'),
            backgroundColor: action == 'approve' ? Colors.green : Colors.red,
          ),
        );
        _fetchStudents();
      }
    } catch (e) {
      if (mounted) {
        String err = 'Action failed';
        if (e is DioException && e.response?.data != null) {
          err = e.response?.data is Map && (e.response!.data as Map).containsKey('error')
              ? (e.response!.data as Map)['error'].toString()
              : e.response!.data.toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignUsnDialog(StudentItem student) async {
    final usnCtrl = TextEditingController(text: student.usn ?? '');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.badge_outlined, color: Color(0xFF13246E), size: 26),
            const SizedBox(width: 8),
            Text(student.usn == null || student.usn!.isEmpty ? "Assign USN" : "Edit USN", style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Student: ${student.name}", style: const TextStyle(fontWeight: FontWeight.w600)),
              Text("Admission ID: ${student.admissionId}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 16),
              TextFormField(
                controller: usnCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: "University Seat Number (USN)",
                  hintText: "e.g. 1GE21CS001",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "USN is required";
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text("Save USN"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final dio = ApiClient().dio;
        final response = await dio.put(
          '/students/${student.id}/assign-usn/',
          data: {'usn': usnCtrl.text.trim()},
        );
        if (mounted) {
          final msg = response.data is Map && (response.data as Map).containsKey('status')
              ? "USN assigned successfully: ${usnCtrl.text.trim()}"
              : "USN assigned successfully!";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.green),
          );
          _fetchStudents();
        }
      } on DioException catch (e) {
        if (mounted) {
          String err = "Failed to assign USN";
          if (e.response?.data != null) {
            err = e.response?.data is Map && (e.response!.data as Map).containsKey('error')
                ? (e.response!.data as Map)['error'].toString()
                : e.response!.data.toString();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteStudentDialog(StudentItem student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text("Delete Student", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Are you sure you want to delete student '${student.name}' (${student.admissionId})?\n\nThis will permanently remove the student record and login account.",
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final dio = ApiClient().dio;
        await dio.delete('/students/${student.id}/');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Student deleted successfully."), backgroundColor: Colors.green),
          );
          _fetchStudents();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to delete: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showStudentDetailsModal(StudentItem student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StudentDetailsSheet(
        student: student,
        onVerify: () {
          Navigator.pop(ctx);
          _verifyStudent(student.id);
        },
        onAssignUsn: () {
          Navigator.pop(ctx);
          _assignUsnDialog(student);
        },
        onApprove: () {
          Navigator.pop(ctx);
          _approveStudent(student.id, 'approve');
        },
        onReject: () {
          Navigator.pop(ctx);
          _approveStudent(student.id, 'reject');
        },
        onDelete: () {
          Navigator.pop(ctx);
          _deleteStudentDialog(student);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = (auth.role ?? '').toUpperCase();
    final isHod = role == AppRoles.hod;
    final isPrincipal = role == AppRoles.principal || role == AppRoles.system;
    final isAdmission = role == AppRoles.admission || isPrincipal;

    final filteredStudents = _students.where((s) {
      if (_selectedFilter != 'all') {
        if (_selectedFilter == 'pending' && s.registrationStatus != 'registered' && s.registrationStatus != 'pending') {
          return false;
        } else if (_selectedFilter != 'pending' && s.registrationStatus != _selectedFilter) {
          return false;
        }
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = s.name.toLowerCase().contains(query);
        final matchUsn = s.usn != null && s.usn!.toLowerCase().contains(query);
        final matchAdm = s.admissionId.toLowerCase().contains(query);
        final matchDept = s.departmentName.toLowerCase().contains(query);
        return matchName || matchUsn || matchAdm || matchDept;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(isHod ? "Department Students" : (role == AppRoles.admission ? "Admission - Student Directory" : "Students")),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
            onPressed: _fetchStudents,
          ),
        ],
      ),
      floatingActionButton: isAdmission
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add),
              label: const Text("Register Student"),
              onPressed: () => context.push('/admissions/register').then((_) => _fetchStudents()),
            )
          : null,
      body: Column(
        children: [
          // Search & Filter header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: "Search student by name, USN, Admission ID, or Dept...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xFFF0F4F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All (${_students.length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('pending', 'Pending Verification'),
                      const SizedBox(width: 8),
                      _buildFilterChip('verified', 'Verified'),
                      const SizedBox(width: 8),
                      _buildFilterChip('approved', 'Approved'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              Text("Error: $_error", textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _fetchStudents, child: const Text("Retry")),
                            ],
                          ),
                        ),
                      )
                    : filteredStudents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? "No students match your search."
                                      : "No students registered yet.",
                                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredStudents.length,
                            itemBuilder: (context, index) {
                              return _buildStudentCard(filteredStudents[index], isHod, isPrincipal, isAdmission);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = filterKey);
      },
      selectedColor: const Color(0xFF13246E),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildStudentCard(StudentItem student, bool isHod, bool isPrincipal, bool isAdmission) {
    Color badgeColor = Colors.orange;
    String badgeText = "Pending Verification";
    if (student.registrationStatus == 'verified') {
      badgeColor = Colors.blue;
      badgeText = "Verified";
    } else if (student.registrationStatus == 'approved') {
      badgeColor = Colors.green;
      badgeText = "Approved";
    } else if (student.registrationStatus == 'rejected') {
      badgeColor = Colors.red;
      badgeText = "Rejected";
    }

    final isPendingVerification = student.registrationStatus == 'registered' || student.registrationStatus == 'pending';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showStudentDetailsModal(student),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFE8EAF6),
                    foregroundColor: const Color(0xFF13246E),
                    child: Text(
                      student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Row(
                          children: [
                            if (student.admissionId.isNotEmpty)
                              Text(
                                "ID: ${student.admissionId}",
                                style: TextStyle(color: Colors.grey[700], fontSize: 12),
                              ),
                            if (student.usn != null && student.usn!.isNotEmpty) ...[
                              const Text(" • ", style: TextStyle(color: Colors.grey)),
                              Text(
                                "USN: ${student.usn}",
                                style: const TextStyle(color: Color(0xFF13246E), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: badgeColor),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Dept: ${student.departmentName}",
                      style: TextStyle(color: Colors.grey[800], fontSize: 13),
                    ),
                  ),
                  if (student.semesterName.isNotEmpty)
                    Text(
                      student.semesterName,
                      style: TextStyle(color: Colors.grey[800], fontSize: 13),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.email_outlined, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(student.email, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const Spacer(),
                  if (student.phone.isNotEmpty) ...[
                    Icon(Icons.phone_outlined, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(student.phone, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ],
              ),

              // Action Buttons Row
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Verification for HOD or Admission Officer
                  if ((isHod || isAdmission) && isPendingVerification)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text("Verify"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13246E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _verifyStudent(student.id),
                    ),

                  // Assign / Edit USN for Admission Officer or Admin
                  if (isAdmission)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.badge_outlined, size: 16),
                      label: Text(student.usn == null || student.usn!.isEmpty ? "Assign USN" : "Edit USN"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF13246E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _assignUsnDialog(student),
                    ),

                  // Principal Approval Actions
                  if (isPrincipal && student.registrationStatus != 'approved') ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text("Approve"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _approveStudent(student.id, 'approve'),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text("Reject"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _approveStudent(student.id, 'reject'),
                    ),
                  ],

                  // Details Button
                  TextButton.icon(
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text("Details"),
                    onPressed: () => _showStudentDetailsModal(student),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentDetailsSheet extends StatelessWidget {
  final StudentItem student;
  final VoidCallback onVerify;
  final VoidCallback onAssignUsn;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  const _StudentDetailsSheet({
    required this.student,
    required this.onVerify,
    required this.onAssignUsn,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final role = (auth.role ?? '').toUpperCase();
    final isHod = role == AppRoles.hod;
    final isPrincipal = role == AppRoles.principal || role == AppRoles.system;
    final isAdmission = role == AppRoles.admission || isPrincipal;
    final isPendingVerification = student.registrationStatus == 'registered' || student.registrationStatus == 'pending';

    Color badgeColor = Colors.orange;
    String badgeText = "Pending Verification";
    if (student.registrationStatus == 'verified') {
      badgeColor = Colors.blue;
      badgeText = "Verified";
    } else if (student.registrationStatus == 'approved') {
      badgeColor = Colors.green;
      badgeText = "Approved";
    } else if (student.registrationStatus == 'rejected') {
      badgeColor = Colors.red;
      badgeText = "Rejected";
    }

    return Container(
      padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF13246E),
                foregroundColor: Colors.white,
                child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 2),
                    Text("Admission ID: ${student.admissionId}", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    if (student.usn != null && student.usn!.isNotEmpty)
                      Text("USN: ${student.usn}", style: const TextStyle(color: Color(0xFF13246E), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor),
                ),
                child: Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          const Divider(height: 24),

          // Action Buttons
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if ((isHod || isAdmission) && isPendingVerification)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13246E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text("Verify Registration"),
                  onPressed: onVerify,
                ),
              if (isAdmission)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.badge_outlined, size: 18),
                  label: Text(student.usn == null || student.usn!.isEmpty ? "Assign USN" : "Edit USN"),
                  onPressed: onAssignUsn,
                ),
              if (isPrincipal && student.registrationStatus != 'approved') ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text("Approve"),
                  onPressed: onApprove,
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text("Reject"),
                  onPressed: onReject,
                ),
              ],
              if (isAdmission || isPrincipal)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text("Delete Student"),
                  onPressed: onDelete,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Scrollable Info Sections
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("Academic Information"),
                  _buildInfoRow("Department", student.departmentName),
                  _buildInfoRow("Semester", student.semesterName),
                  _buildInfoRow("Academic Year", student.academicYearName),
                  _buildInfoRow("Seat Type", student.seatType ?? "N/A"),
                  _buildInfoRow("Admission Quota", student.admissionQuota ?? "N/A"),
                  if (student.rank != null && student.rank!.isNotEmpty)
                    _buildInfoRow("Rank / Score", student.rank!),
                  if (student.dateOfAdmission != null && student.dateOfAdmission!.isNotEmpty)
                    _buildInfoRow("Date of Admission", student.dateOfAdmission!),

                  const SizedBox(height: 16),
                  _buildSectionHeader("Contact & Personal Details"),
                  _buildInfoRow("Email", student.email),
                  _buildInfoRow("Mobile Phone", student.phone),
                  if (student.fatherName != null && student.fatherName!.isNotEmpty)
                    _buildInfoRow("Father's Name", student.fatherName!),
                  if (student.motherName != null && student.motherName!.isNotEmpty)
                    _buildInfoRow("Mother's Name", student.motherName!),
                  if (student.dob != null && student.dob!.isNotEmpty)
                    _buildInfoRow("Date of Birth", student.dob!),
                  if (student.gender != null && student.gender!.isNotEmpty)
                    _buildInfoRow("Gender", student.gender!.toUpperCase()),
                  if (student.permanentAddress != null && student.permanentAddress!.isNotEmpty)
                    _buildInfoRow("Permanent Address", student.permanentAddress!),

                  const SizedBox(height: 16),
                  _buildSectionHeader("Prior Qualification"),
                  if (student.sslcReg != null && student.sslcReg!.isNotEmpty) ...[
                    _buildInfoRow("SSLC Reg No", student.sslcReg!),
                    _buildInfoRow("SSLC Marks", "${student.sslcObtained ?? 0} / ${student.sslcTotal ?? 0}"),
                  ],
                  if (student.pucReg != null && student.pucReg!.isNotEmpty) ...[
                    _buildInfoRow("PUC Reg No", student.pucReg!),
                    _buildInfoRow("PUC Marks", "${student.pucObtained ?? 0} / ${student.pucTotal ?? 0}"),
                  ],
                  if (student.diplomaReg != null && student.diplomaReg!.isNotEmpty) ...[
                    _buildInfoRow("Diploma Reg No", student.diplomaReg!),
                    _buildInfoRow("Diploma Marks", "${student.diplomaObtained ?? 0} / ${student.diplomaTotal ?? 0}"),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF13246E)),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value.isEmpty ? "N/A" : value, style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
