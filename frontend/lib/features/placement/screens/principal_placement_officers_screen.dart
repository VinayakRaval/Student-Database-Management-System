import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

class PrincipalPlacementOfficersScreen extends StatefulWidget {
  const PrincipalPlacementOfficersScreen({super.key});

  @override
  State<PrincipalPlacementOfficersScreen> createState() =>
      _PrincipalPlacementOfficersScreenState();
}

class _PrincipalPlacementOfficersScreenState
    extends State<PrincipalPlacementOfficersScreen> {
  final Dio _dio = ApiClient().dio;

  // Department Dropdown Options (4 Engineering Departments)
  final List<Map<String, dynamic>> _departments = [
    {'id': 2, 'name': 'Computer Science and Engineering (CSE)', 'code': 'CSE'},
    {'id': 3, 'name': 'Electronics and Communication (ECE)', 'code': 'ECE'},
    {'id': 6, 'name': 'Civil Engineering', 'code': 'CIVIL'},
    {'id': 5, 'name': 'Mechanical Engineering', 'code': 'MECH'},
  ];

  int? _selectedDepartmentId;
  List<Map<String, dynamic>> _facultyList = [];
  bool _isLoadingFaculty = false;

  Map<String, dynamic>? _selectedFaculty;
  final TextEditingController _facultyIdCtrl = TextEditingController();
  final TextEditingController _designationCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  String _originalRegisteredEmail = '';

  bool _isSubmitting = false;
  String? _formError;

  // Existing assignments list
  List<Map<String, dynamic>> _assignments = [];
  bool _isLoadingAssignments = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAssignments();
  }

  @override
  void dispose() {
    _facultyIdCtrl.dispose();
    _designationCtrl.dispose();
    _emailCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAssignments() async {
    setState(() => _isLoadingAssignments = true);
    try {
      final res = await _dio.get('/placement/officers/');
      final raw = res.data is List
          ? res.data
          : (res.data is Map && res.data['results'] is List ? res.data['results'] : []);
      setState(() {
        _assignments = List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map)));
        _isLoadingAssignments = false;
      });
    } catch (_) {
      setState(() => _isLoadingAssignments = false);
    }
  }

  Future<void> _onDepartmentSelected(int? deptId) async {
    setState(() {
      _selectedDepartmentId = deptId;
      _selectedFaculty = null;
      _facultyList = [];
      _facultyIdCtrl.clear();
      _designationCtrl.clear();
      _emailCtrl.clear();
      _originalRegisteredEmail = '';
      _formError = null;
    });

    if (deptId == null) return;

    setState(() => _isLoadingFaculty = true);
    try {
      final res = await _dio.get('/placement/faculty-by-department/', queryParameters: {
        'department_id': deptId,
      });
      final raw = res.data is List
          ? res.data
          : (res.data is Map && res.data['results'] is List ? res.data['results'] : []);
      setState(() {
        _facultyList = List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map)));
        _isLoadingFaculty = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingFaculty = false;
        _formError = "Failed to load faculty for the selected department.";
      });
    }
  }

  void _onFacultySelected(Map<String, dynamic>? faculty) {
    setState(() {
      _selectedFaculty = faculty;
      _formError = null;
      if (faculty != null) {
        _facultyIdCtrl.text = faculty['faculty_id']?.toString() ?? '';
        _designationCtrl.text = faculty['designation']?.toString() ?? 'Professor';
        final regEmail = (faculty['email'] ?? '').toString();
        _emailCtrl.text = regEmail;
        _originalRegisteredEmail = regEmail;
      } else {
        _facultyIdCtrl.clear();
        _designationCtrl.clear();
        _emailCtrl.clear();
        _originalRegisteredEmail = '';
      }
    });
  }

  Future<void> _submitAssignment() async {
    if (_selectedDepartmentId == null) {
      setState(() => _formError = "Please select a department.");
      return;
    }
    if (_selectedFaculty == null) {
      setState(() => _formError = "Please select an eligible faculty member.");
      return;
    }

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _formError = "Official Placement Officer email address is required.");
      return;
    }

    final emailRegExp = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(email)) {
      setState(() => _formError = "Please enter a valid official email address format.");
      return;
    }

    if (_selectedFaculty!['is_placement_officer'] == true) {
      setState(() => _formError = "Faculty member '${_selectedFaculty!['name']}' already has an active Placement Officer assignment.");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _formError = null;
    });

    try {
      final res = await _dio.post('/placement/officers/assign/', data: {
        'department_id': _selectedDepartmentId,
        'faculty_id': _selectedFaculty!['id'],
        'email': email,
      });

      final tempPass = res.data['temporary_password']?.toString() ?? '';
      final facName = _selectedFaculty!['name']?.toString() ?? 'Faculty Member';
      final facId = _selectedFaculty!['faculty_id']?.toString() ?? '';

      setState(() => _isSubmitting = false);

      if (mounted) {
        _showSuccessCredentialsDialog(
          facultyName: facName,
          facultyId: facId,
          email: email,
          temporaryPassword: tempPass,
        );
      }

      // Refresh form & lists
      _onDepartmentSelected(_selectedDepartmentId);
      _fetchAssignments();
    } on DioException catch (dioErr) {
      setState(() {
        _isSubmitting = false;
        final d = dioErr.response?.data;
        if (d is Map && d['error'] != null) {
          _formError = d['error'].toString();
        } else if (d is Map && d['detail'] != null) {
          _formError = d['detail'].toString();
        } else {
          _formError = "Failed to assign Placement Officer role. Please verify input and retry.";
        }
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _formError = "An unexpected error occurred: $e";
      });
    }
  }

  void _showSuccessCredentialsDialog({
    required String facultyName,
    required String facultyId,
    required String email,
    required String temporaryPassword,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 28),
            SizedBox(width: 10),
            Text(
              "Placement Officer Assigned!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Placement Officer role assigned successfully for $facultyName (ID: $facultyId).",
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.vpn_key_rounded, color: Color(0xFF16A34A), size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Initial credentials generated successfully. Share this temporary password securely with the faculty member. It will not be shown again.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF166534),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Official Login Email:",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 4),
              SelectableText(
                email,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 14),
              const Text(
                "Generated Temporary Password:",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SelectableText(
                      temporaryPassword,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: Color(0xFF13246E),
                        letterSpacing: 1.2,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20, color: Color(0xFF13246E)),
                      tooltip: "Copy Temporary Password",
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: temporaryPassword));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Temporary password copied to clipboard!"),
                            backgroundColor: Color(0xFF13246E),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.security_rounded, size: 18, color: Color(0xFF92400E)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Identity & Role Notice: The faculty member retains their existing faculty identity and department responsibilities. They will be required to change their temporary password upon first login as Placement Officer.",
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeAssignment(Map<String, dynamic> assignment) async {
    final aId = assignment['id'];
    final name = assignment['faculty_name'] ?? 'Faculty Member';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Revoke Placement Officer Assignment?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          "Are you sure you want to revoke the Placement Officer role from $name?\n\nThey will retain their faculty profile and departmental duties, but will lose access to placement cell coordination and drives.",
          style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Revoke Assignment"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _dio.post('/placement/officers/$aId/revoke/');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Placement Officer role revoked for $name."),
          backgroundColor: Colors.black87,
        ),
      );
      _fetchAssignments();
      if (_selectedDepartmentId != null) {
        _onDepartmentSelected(_selectedDepartmentId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to revoke assignment: $e"),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredAssignments {
    if (_searchQuery.trim().isEmpty) return _assignments;
    final q = _searchQuery.toLowerCase();
    return _assignments.where((a) {
      final name = (a['faculty_name'] ?? '').toString().toLowerCase();
      final id = (a['faculty_id_code'] ?? '').toString().toLowerCase();
      final email = (a['official_email'] ?? '').toString().toLowerCase();
      final dept = (a['department_name'] ?? '').toString().toLowerCase();
      final st = (a['status'] ?? '').toString().toLowerCase();
      return name.contains(q) || id.contains(q) || email.contains(q) || dept.contains(q) || st.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Assign Placement Officer",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: () {
              if (_selectedDepartmentId != null) {
                _onDepartmentSelected(_selectedDepartmentId);
              }
              _fetchAssignments();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Image 1 Form Card
                _buildAssignmentFormCard(isDesktop),

                const SizedBox(height: 36),

                // 2. Existing Placement Officers Table Section
                _buildAssignmentsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentFormCard(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFEAEAEA),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Text(
              "Assign Placement Officer",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              "Principal Role • Designate Department Faculty as Placement Officers",
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 28),

          if (_formError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formError!,
                      style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildLeftColumn(),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      flex: 2,
                      child: _buildRightColumn(),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildRightColumn(),
                    const SizedBox(height: 24),
                    _buildLeftColumn(),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    final cleanLabel = label.replaceAll(" *", "").trim();
    return SizedBox(
      width: 140,
      child: RichText(
        text: TextSpan(
          text: cleanLabel,
          style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500),
          children: const [
            TextSpan(
              text: " *",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Department Dropdown
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _buildFieldLabel("Department *"),
              ),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedDepartmentId,
                  hint: const Text("Select Department", style: TextStyle(fontSize: 13, color: Colors.black45)),
                  isExpanded: true,
                  items: _departments
                      .map((d) => DropdownMenuItem<int>(
                            value: d['id'] as int,
                            child: Text(
                              d['name'].toString(),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (val) => _onDepartmentSelected(val),
                  decoration: _buildInputDecoration(),
                ),
              ),
            ],
          ),
        ),

        // 2. Faculty Member Dropdown
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _buildFieldLabel("Faculty Member *"),
              ),
              Expanded(
                child: _isLoadingFaculty
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: const [
                            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text("Loading department faculty...", style: TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      )
                    : DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedFaculty,
                        hint: Text(
                          _selectedDepartmentId == null ? "Select department first" : "Select Faculty Member",
                          style: const TextStyle(fontSize: 13, color: Colors.black45),
                        ),
                        isExpanded: true,
                        items: _facultyList.map((f) {
                          final isAssigned = f['is_placement_officer'] == true;
                          final status = f['assignment_status'] ?? '';
                          final suffix = isAssigned ? " (Already Assigned: $status)" : "";
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: f,
                            child: Text(
                              "${f['faculty_id']} - ${f['name']}$suffix",
                              style: TextStyle(
                                fontSize: 13,
                                color: isAssigned ? const Color(0xFFD97706) : Colors.black87,
                                fontWeight: isAssigned ? FontWeight.w600 : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => _onFacultySelected(val),
                        decoration: _buildInputDecoration(),
                      ),
              ),
            ],
          ),
        ),

        // 3. Faculty ID (Read-only)
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _buildFieldLabel("Faculty ID *"),
              ),
              Expanded(
                child: TextFormField(
                  controller: _facultyIdCtrl,
                  readOnly: true,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  decoration: _buildInputDecoration(
                    suffixIcon: const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 4. Designation (Read-only)
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _buildFieldLabel("Designation *"),
              ),
              Expanded(
                child: TextFormField(
                  controller: _designationCtrl,
                  readOnly: true,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                  decoration: _buildInputDecoration(),
                ),
              ),
            ],
          ),
        ),

        // 5. Email-ID (Editable official email with reference)
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _buildFieldLabel("Email-ID *"),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 14),
                      decoration: _buildInputDecoration(
                        hintText: "official.placement@campusflow.edu",
                      ),
                    ),
                    if (_originalRegisteredEmail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Faculty registered email: $_originalRegisteredEmail",
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // 6. Account Status Row
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _buildFieldLabel("Account Status *"),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _selectedFaculty != null
                              ? (_selectedFaculty!['is_placement_officer'] == true ? const Color(0xFFD97706) : const Color(0xFF059669))
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedFaculty == null
                            ? "Select a faculty member"
                            : (_selectedFaculty!['is_placement_officer'] == true
                                ? "Already Assigned as Placement Officer (${_selectedFaculty!['assignment_status']})"
                                : "Eligible for Placement Officer Assignment (${_selectedFaculty!['account_status'] ?? 'Active'})"),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _selectedFaculty != null
                              ? (_selectedFaculty!['is_placement_officer'] == true ? const Color(0xFFB45309) : const Color(0xFF065F46))
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn() {
    final photoUrl = _selectedFaculty?['photo_url'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 190,
          width: 190,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF13246E),
              width: 1.5,
            ),
          ),
          child: photoUrl != null && photoUrl.toString().trim().isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.network(
                    photoUrl.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildAvatarPlaceholder(),
                  ),
                )
              : _buildAvatarPlaceholder(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 240,
          height: 42,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitAssignment,
            icon: _isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.vpn_key_rounded, size: 18, color: Colors.white),
            label: Text(
              _isSubmitting ? "Generating..." : "Generate Password & Assign",
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.person, size: 75, color: Colors.grey.shade400),
        const SizedBox(height: 6),
        const Text(
          "Placement Officer Role Preview",
          style: TextStyle(
            color: Color(0xFF13246E),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5)),
      isDense: true,
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildAssignmentsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Active & Past Placement Officer Assignments",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF13246E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${_assignments.length}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF13246E),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 260,
                height: 38,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: "Search officers...",
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (_isLoadingAssignments)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: Color(0xFF13246E)),
              ),
            )
          else if (_filteredAssignments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(36),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.badge_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    "No Placement Officers Assigned Yet",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Select a department and faculty member above to assign your institution's Placement Officers.",
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            _buildAssignmentsTable(),
        ],
      ),
    );
  }

  Widget _buildAssignmentsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        dataRowMinHeight: 52,
        dataRowMaxHeight: 58,
        columns: const [
          DataColumn(label: Text("Faculty Name & ID", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          DataColumn(label: Text("Department", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          DataColumn(label: Text("Official Email", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          DataColumn(label: Text("Assigned Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        ],
        rows: _filteredAssignments.map((a) {
          final facultyName = a['faculty_name'] ?? 'Faculty';
          final facId = a['faculty_id_code'] ?? '';
          final dept = a['department_name'] ?? '';
          final email = a['official_email'] ?? '';
          final status = (a['status'] ?? 'ACTIVE').toString().toUpperCase();
          final assignedDate = a['assigned_date'] ?? '';

          Color statusBg;
          Color statusFg;
          String statusLabel;

          if (status == 'INVITATION_PENDING') {
            statusBg = const Color(0xFFFEF3C7);
            statusFg = const Color(0xFFB45309);
            statusLabel = "Invitation Pending";
          } else if (status == 'ACTIVE') {
            statusBg = const Color(0xFFECFDF5);
            statusFg = const Color(0xFF047857);
            statusLabel = "Active";
          } else {
            statusBg = const Color(0xFFF1F5F9);
            statusFg = const Color(0xFF64748B);
            statusLabel = "Inactive";
          }

          final canRevoke = status == 'ACTIVE' || status == 'INVITATION_PENDING';

          return DataRow(
            cells: [
              DataCell(
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facultyName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      facId,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              DataCell(
                Text(
                  dept,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                ),
              ),
              DataCell(
                Text(
                  email,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusFg),
                  ),
                ),
              ),
              DataCell(
                Text(
                  assignedDate,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
              DataCell(
                canRevoke
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.block_rounded, size: 13),
                        label: const Text("Revoke", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _revokeAssignment(a),
                      )
                    : const Text("—", style: TextStyle(color: Colors.grey)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
