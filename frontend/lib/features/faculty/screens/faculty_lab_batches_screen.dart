import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/secure_storage.dart';
import 'package:frontend/core/constants/api_constants.dart';

class FacultyLabBatchesScreen extends StatefulWidget {
  const FacultyLabBatchesScreen({super.key});

  @override
  State<FacultyLabBatchesScreen> createState() => _FacultyLabBatchesScreenState();
}

class _FacultyLabBatchesScreenState extends State<FacultyLabBatchesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = '';

  List<Map<String, dynamic>> _batches = [];
  List<Map<String, dynamic>> _subjects = [];

  int? _selectedSemesterFilter;
  int? _selectedSubjectFilter;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Selected batch for inline student list display
  int? _selectedBatchId;
  Map<String, dynamic>? _selectedBatch;
  Map<String, dynamic>? _selectedBatchSubject;
  String _batchStudentSearch = '';
  final TextEditingController _batchStudentSearchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _batchStudentSearchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;

      // 1. Fetch current user info safely from SecureStorage
      final storedRole = await SecureStorage().read('role');
      if (storedRole != null && storedRole.trim().isNotEmpty) {
        _userRole = storedRole.trim().toUpperCase();
      } else {
        try {
          final profileRes = await dio.get('/dashboard/');
          if (profileRes.data is Map && profileRes.data['role'] != null) {
            _userRole = profileRes.data['role'].toString().toUpperCase();
          }
        } catch (_) {
          _userRole = AppRoles.professor; // Default strictly to PROFESSOR, NOT HOD
        }
      }

      // 2. Fetch subjects
      final isHodRole = _userRole == AppRoles.hod || _userRole == AppRoles.principal || _userRole == 'ADMIN' || _userRole == 'SYSTEM';
      final subEndpoint = isHodRole ? '/subjects/getSubjects/' : '/subjects/professor/subjects/';
      final subRes = await dio.get(subEndpoint);
      final List rawSubjects = subRes.data is List
          ? subRes.data
          : (subRes.data is Map && subRes.data['results'] is List ? subRes.data['results'] : []);
      _subjects = rawSubjects.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        m['subject_code'] = m['subject_code'] ?? m['code'] ?? '';
        m['subject_name'] = m['subject_name'] ?? m['name'] ?? '';
        final sNo = m['semester_no'] ?? m['semester'] ?? m['sem_number'];
        m['semester_no'] = int.tryParse(sNo?.toString() ?? '');
        return m;
      }).toList();

      // By default show all semesters (_selectedSemesterFilter = null)

      // 3. Fetch lab batches
      await _fetchBatches();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load lab batches: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchBatches() async {
    try {
      final dio = ApiClient().dio;
      final queryParams = <String, dynamic>{};
      if (!_isHod) {
        queryParams['assigned_only'] = 'true';
      }
      if (_selectedSubjectFilter != null) {
        queryParams['subject_id'] = _selectedSubjectFilter;
      }
      if (_selectedSemesterFilter != null) {
        queryParams['semester_no'] = _selectedSemesterFilter;
      }
      final res = await dio.get('/attendance/batches/', queryParameters: queryParams);
      final List raw = res.data is List
          ? res.data
          : (res.data is Map && res.data['results'] is List ? res.data['results'] : []);
      if (mounted) {
        setState(() {
          _batches = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          // Update selected batch reference if already selected
          if (_selectedBatchId != null) {
            final found = _batches.where((b) => b['id'] == _selectedBatchId).toList();
            if (found.isNotEmpty) {
              _selectedBatch = found.first;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching lab batches: $e");
    }
  }

  void _selectBatch(Map<String, dynamic> batch, [Map<String, dynamic>? subject]) {
    setState(() {
      _selectedBatchId = batch['id'] as int;
      _selectedBatch = batch;
      if (subject != null) {
        _selectedBatchSubject = subject;
      }
      _batchStudentSearch = '';
      _batchStudentSearchCtrl.clear();
    });

    // Smooth scroll down to student section
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  bool get _isHod {
    final r = _userRole.trim().toUpperCase();
    return r == AppRoles.hod || r == AppRoles.principal || r == 'ADMIN' || r == 'SYSTEM';
  }

  List<Map<String, dynamic>> get _labSubjects {
    final labs = _subjects.where((s) {
      final hasLab = s['has_lab'] == true ||
          s['subject_type']?.toString().toUpperCase() == 'LAB' ||
          s['subject_type']?.toString().toUpperCase() == 'BOTH';
      if (!hasLab) return false;
      if (_selectedSemesterFilter != null) {
        final semNum = int.tryParse(s['semester_no']?.toString() ?? s['semester']?.toString() ?? s['sem_number']?.toString() ?? '');
        if (semNum != null && semNum != _selectedSemesterFilter) {
          return false;
        }
      }
      return true;
    }).toList();
    return labs;
  }

  List<Map<String, dynamic>> get _filteredBatches {
    return _batches.where((b) {
      if (_selectedSemesterFilter != null) {
        final bSem = b['semester_number'] ?? b['semester_no'] ?? b['semester_name'] ?? (b['semester'] is Map ? b['semester']['sem_number'] : b['semester']);
        final bSemInt = int.tryParse(bSem?.toString() ?? '');
        if (bSemInt != null && bSemInt != _selectedSemesterFilter) {
          return false;
        }
      }

      final bSub = b['subject'];
      bool matchesSub = true;
      if (_selectedSubjectFilter != null) {
        if (bSub != null) {
          matchesSub = (bSub == _selectedSubjectFilter);
        } else {
          // Shared batch: matches if it belongs to the selected subject's semester
          final targetSub = _labSubjects.firstWhere(
            (s) => (s['id'] ?? s['subject_id']) == _selectedSubjectFilter,
            orElse: () => {},
          );
          if (targetSub.isNotEmpty) {
            final sSem = (targetSub['semester_no'] ?? targetSub['semester'] ?? '').toString();
            final bSem = (b['semester_number'] ?? b['semester_no'] ?? b['semester_name'] ?? (b['semester'] is Map ? b['semester']['sem_number'] : b['semester']) ?? '').toString();
            if (sSem.isNotEmpty && bSem.isNotEmpty && sSem != bSem) {
              matchesSub = false;
            }
          }
        }
      }

      final q = _searchQuery.toLowerCase();
      final matchesQuery = q.isEmpty ||
          (b['name'] ?? '').toString().toLowerCase().contains(q) ||
          (b['subject_code'] ?? '').toString().toLowerCase().contains(q) ||
          (b['subject_name'] ?? '').toString().toLowerCase().contains(q) ||
          (b['faculty_name'] ?? '').toString().toLowerCase().contains(q);
      return matchesSub && matchesQuery;
    }).toList();
  }

  // --- Create Lab Batch Modal (HOD) ---
  // --- Complete Lab Batch Creation Workflow (HOD) ---
  Future<void> _openCreateBatchesWorkflow() async {
    final dio = ApiClient().dio;

    List<Map<String, dynamic>> academicYears = [];
    List<Map<String, dynamic>> semesters = [];
    String deptName = "CSE";
    int? deptId;

    try {
      final ayRes = await dio.get('/academics/academic-years/');
      final List rawAy = ayRes.data is List ? ayRes.data : (ayRes.data['results'] ?? []);
      academicYears = rawAy.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final semRes = await dio.get('/academics/semesters/');
      final List rawSem = semRes.data is List ? semRes.data : (semRes.data['results'] ?? []);
      semesters = rawSem.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      semesters.sort((a, b) => (int.tryParse(a['sem_number']?.toString() ?? '0') ?? 0)
          .compareTo(int.tryParse(b['sem_number']?.toString() ?? '0') ?? 0));

      final repRes = await dio.get('/academics/reports/department/?report_type=STUDENTS');
      if (repRes.data != null && repRes.data['department_info'] != null) {
        final dInfo = repRes.data['department_info'];
        deptName = dInfo['name'] ?? 'Department';
        deptId = dInfo['id'] as int?;
      }
    } catch (e) {
      debugPrint("Error loading batch creation metadata: $e");
    }

    if (academicYears.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No academic years found. Please check academic setup.")),
        );
      }
      return;
    }

    int? selectedAyId = academicYears.first['id'] as int?;
    int? selectedSemId = semesters.isNotEmpty ? (semesters.first['id'] as int?) : null;
    int numBatches = 3;
    String distributionMode = 'AUTO'; // 'AUTO' or 'MANUAL'
    String sortBy = 'usn_asc'; // 'usn_asc', 'attendance_desc', 'attendance_asc'

    bool isLoadingStudents = false;
    int totalEligibleStudents = 0;

    bool isGeneratingPreview = false;
    List<Map<String, dynamic>> previewBatches = [];
    bool isSavingBatches = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          // Trigger initial student count fetch if not done yet
          if (totalEligibleStudents == 0 && !isLoadingStudents && selectedSemId != null) {
            isLoadingStudents = true;
            dio.get(
              '/attendance/batches/eligible_students_count/',
              queryParameters: {
                if (deptId != null) 'department_id': deptId,
                'semester_id': selectedSemId,
                if (selectedAyId != null) 'academic_year_id': selectedAyId,
                'sort_by': sortBy,
              },
            ).then((res) {
              final data = Map<String, dynamic>.from(res.data as Map);
              final rawSt = data['students'] is List ? (data['students'] as List) : [];
              setDlgState(() {
                totalEligibleStudents = data['total_eligible_students'] ?? rawSt.length;
                isLoadingStudents = false;
              });
            }).catchError((_) {
              setDlgState(() => isLoadingStudents = false);
            });
          }

          Future<void> fetchStudentCount() async {
            if (selectedSemId == null) return;
            setDlgState(() {
              isLoadingStudents = true;
              previewBatches = [];
            });
            try {
              final res = await dio.get(
                '/attendance/batches/eligible_students_count/',
                queryParameters: {
                  if (deptId != null) 'department_id': deptId,
                  'semester_id': selectedSemId,
                  if (selectedAyId != null) 'academic_year_id': selectedAyId,
                  'sort_by': sortBy,
                },
              );
              final data = Map<String, dynamic>.from(res.data as Map);
              final rawSt = data['students'] is List ? (data['students'] as List) : [];
              setDlgState(() {
                totalEligibleStudents = data['total_eligible_students'] ?? rawSt.length;
                isLoadingStudents = false;
              });
            } catch (e) {
              setDlgState(() => isLoadingStudents = false);
            }
          }

          Future<void> runPreview() async {
            if (selectedSemId == null || totalEligibleStudents == 0) return;
            setDlgState(() => isGeneratingPreview = true);
            try {
              final res = await dio.post(
                '/attendance/batches/auto_distribute_preview/',
                data: {
                  if (deptId != null) 'department_id': deptId,
                  'semester_id': selectedSemId,
                  if (selectedAyId != null) 'academic_year_id': selectedAyId,
                  'num_batches': numBatches,
                  'sort_by': sortBy,
                },
              );
              final data = Map<String, dynamic>.from(res.data as Map);
              final rawBatches = data['batches'] is List ? (data['batches'] as List) : [];
              setDlgState(() {
                previewBatches = rawBatches.map((b) => Map<String, dynamic>.from(b as Map)).toList();
                isGeneratingPreview = false;
              });
            } catch (e) {
              setDlgState(() => isGeneratingPreview = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error generating preview: $e"), backgroundColor: Colors.red),
              );
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13246E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.group_add_rounded, color: Color(0xFF13246E), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Create Lab Batches", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(
                        "Shared across all laboratory subjects for the selected semester",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 700,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Department Info & Architecture Notice
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_rounded, size: 20, color: Color(0xFF1D4ED8)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Authorized Department: $deptName",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF)),
                                ),
                                const Text(
                                  "Batches created here are shared across all applicable lab subjects (e.g. Parallel Computing Lab, Computer Networks Lab) in this semester.",
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF3B82F6)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Inputs Row: Academic Year & Semester
                    Row(
                      children: [
                        // Academic Year
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Academic Year *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int?>(
                                value: selectedAyId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: academicYears.map((ay) {
                                  return DropdownMenuItem<int?>(
                                    value: ay['id'] as int?,
                                    child: Text(ay['year_name'] ?? 'Academic Year'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDlgState(() => selectedAyId = val);
                                    fetchStudentCount();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Semester
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Semester *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int?>(
                                value: selectedSemId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: semesters.map((sem) {
                                  final num = sem['sem_number'] ?? sem['id'];
                                  return DropdownMenuItem<int?>(
                                    value: sem['id'] as int?,
                                    child: Text("Semester $num"),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDlgState(() => selectedSemId = val);
                                    fetchStudentCount();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Eligible Students Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.people_alt_rounded, size: 20, color: Color(0xFF13246E)),
                              const SizedBox(width: 8),
                              const Text(
                                "Total Eligible Students:",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 6),
                              if (isLoadingStudents)
                                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF13246E),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "$totalEligibleStudents Students",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            totalEligibleStudents > 0
                                ? "Even distribution: ~${(totalEligibleStudents / numBatches).floor()} per batch"
                                : "No students found",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Number of Batches & Distribution Options
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Number of Batches selector
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Number of Batches (K) *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                                      color: numBatches > 1 ? const Color(0xFF13246E) : Colors.grey,
                                      onPressed: numBatches > 1
                                          ? () => setDlgState(() {
                                                numBatches--;
                                                previewBatches = [];
                                              })
                                          : null,
                                    ),
                                    Text(
                                      "$numBatches Batches",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 20),
                                      color: numBatches < 8 ? const Color(0xFF13246E) : Colors.grey,
                                      onPressed: numBatches < 8
                                          ? () => setDlgState(() {
                                                numBatches++;
                                                previewBatches = [];
                                              })
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Distribution Mode Radio
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Distribution Mode", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setDlgState(() => distributionMode = 'AUTO'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: distributionMode == 'AUTO' ? const Color(0xFF13246E) : Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFF13246E)),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "Auto (Recommended)",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: distributionMode == 'AUTO' ? Colors.white : const Color(0xFF13246E),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setDlgState(() => distributionMode = 'MANUAL'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: distributionMode == 'MANUAL' ? const Color(0xFF13246E) : Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFF13246E)),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "Manual Assignment",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: distributionMode == 'MANUAL' ? Colors.white : const Color(0xFF13246E),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Student Ordering options (For Auto Mode)
                    if (distributionMode == 'AUTO') ...[
                      Row(
                        children: [
                          const Text("Student Ordering:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: sortBy,
                              isExpanded: true,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'usn_asc', child: Text("USN Ascending (Default)")),
                                DropdownMenuItem(value: 'attendance_desc', child: Text("Attendance % (High to Low)")),
                                DropdownMenuItem(value: 'attendance_asc', child: Text("Attendance % (Low to High)")),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDlgState(() => sortBy = val);
                                  if (previewBatches.isNotEmpty) runPreview();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Remainder Rule: If $totalEligibleStudents students divided into $numBatches batches, remainder students are added to the first batches.",
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Preview Action Button
                    Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF13246E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: isGeneratingPreview
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.preview_rounded, size: 18),
                        label: Text(
                          previewBatches.isNotEmpty ? "Regenerate Preview" : "Generate Distribution Preview",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: isGeneratingPreview || totalEligibleStudents == 0 ? null : runPreview,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // PREVIEW CARDS SECTION
                    if (previewBatches.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Distribution Preview & Student Roster",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF13246E)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF059669)),
                                const SizedBox(width: 4),
                                Text(
                                  "${previewBatches.length} Batches • $totalEligibleStudents Students",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Grid of batch preview cards
                      ...previewBatches.map((b) {
                        final bName = b['name'] ?? 'Batch';
                        final count = b['count'] ?? 0;
                        final studentsList = (b['students'] as List? ?? []);

                        final String ayLabel = academicYears.firstWhere((a) => a['id'] == selectedAyId, orElse: () => {})['year_name'] ?? '2026–2027';
                        final semObj = semesters.firstWhere((s) => s['id'] == selectedSemId, orElse: () => {});
                        final semLabel = semObj['sem_number'] != null ? "Semester ${semObj['sem_number']}" : "Semester";
                        final deptCode = (deptName.split(' ').first.isNotEmpty ? deptName.split(' ').first : "CSE");
                        final previewIdentifier = "$deptCode – $ayLabel – $semLabel – $bName";

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF13246E),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        bName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      "$count Students Allocated",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  previewIdentifier,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            children: [
                              Container(
                                constraints: const BoxConstraints(maxHeight: 180),
                                padding: const EdgeInsets.all(8),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: studentsList.length,
                                  itemBuilder: (ctx, sIdx) {
                                    final st = studentsList[sIdx];
                                    final usn = st['usn'] ?? '';
                                    final name = st['name'] ?? '';
                                    final attDisp = st['attendance_display'] ?? (st['attendance_percentage'] != null ? "${st['attendance_percentage']}%" : "No Records");

                                    return Container(
                                      margin: const EdgeInsets.symmetric(vertical: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: sIdx % 2 == 0 ? const Color(0xFFF8FAFC) : Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            "${sIdx + 1}.",
                                            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            usn,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF13246E)),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: attDisp == "No Records" ? Colors.grey.shade100 : const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              "Att: $attDisp",
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: attDisp == "No Records" ? Colors.grey.shade600 : const Color(0xFF1D4ED8),
                                              ),
                                            ),
                                          ),
                                          // Move student dropdown (in manual mode or adjustments)
                                          if (previewBatches.length > 1) ...[
                                            const SizedBox(width: 6),
                                            PopupMenuButton<String>(
                                              tooltip: "Move to another batch",
                                              icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF64748B)),
                                              onSelected: (targetName) {
                                                setDlgState(() {
                                                  // Remove from current batch
                                                  final currentList = List<Map<String, dynamic>>.from(b['students'] as List);
                                                  final foundIdx = currentList.indexWhere((s) => s['id'] == st['id']);
                                                  if (foundIdx != -1) {
                                                    final removed = currentList.removeAt(foundIdx);
                                                    b['students'] = currentList;
                                                    b['count'] = currentList.length;

                                                    // Add to target batch
                                                    final targetB = previewBatches.firstWhere((tb) => tb['name'] == targetName);
                                                    final targetList = List<Map<String, dynamic>>.from(targetB['students'] as List);
                                                    targetList.add(removed);
                                                    targetB['students'] = targetList;
                                                    targetB['count'] = targetList.length;
                                                  }
                                                });
                                              },
                                              itemBuilder: (ctx) {
                                                return previewBatches
                                                    .where((otherB) => otherB['name'] != bName)
                                                    .map((otherB) => PopupMenuItem(
                                                          value: otherB['name'].toString(),
                                                          child: Text("Move to ${otherB['name']}"),
                                                        ))
                                                    .toList();
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSavingBatches ? null : () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: isSavingBatches
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 18),
                label: const Text("Confirm & Create Batches", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: isSavingBatches || previewBatches.isEmpty
                    ? null
                    : () async {
                        setDlgState(() => isSavingBatches = true);
                        try {
                          final payloadBatches = previewBatches.map((b) {
                            final stList = (b['students'] as List? ?? []);
                            final ids = stList.map((s) => s['id'] as int).toList();
                            return {
                              'name': b['name'],
                              'student_ids': ids,
                            };
                          }).toList();

                          await dio.post(
                            '/attendance/batches/create_shared_batches/',
                            data: {
                              if (deptId != null) 'department_id': deptId,
                              'semester_id': selectedSemId,
                              if (selectedAyId != null) 'academic_year_id': selectedAyId,
                              'batches': payloadBatches,
                              'replace_existing': true,
                            },
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            final bCount = previewBatches.length;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Successfully created and saved $bCount shared lab batches!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _fetchBatches();
                          }
                        } catch (e) {
                          setDlgState(() => isSavingBatches = false);
                          String err = "Failed to save batches: $e";
                          if (e is DioException && e.response?.data is Map && e.response?.data['error'] != null) {
                            err = e.response?.data['error'];
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(err), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }


  // --- Manage / Assign Students Modal (HOD) ---
  Future<void> _openAssignStudentsDialog(Map<String, dynamic> batch) async {
    final batchId = batch['id'] as int;
    final subjectId = batch['subject'] as int?;
    final batchName = batch['name'] ?? 'Batch';

    List<Map<String, dynamic>> eligibleStudents = [];
    Set<int> selectedStudentIds = {};
    bool isFetching = true;
    bool isSaving = false;
    String search = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          if (isFetching) {
            // Fetch eligible students across this department and semester
            ApiClient().dio.get(
              '/attendance/batches/eligible_students_for_subject/',
              queryParameters: {
                'batch_id': batchId,
                if (subjectId != null) 'subject_id': subjectId,
              },
            ).then((res) {
              final List raw = res.data is List ? res.data : [];
              final students = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
              // Sort eligible students by USN ascending
              students.sort((a, b) => (a['usn'] ?? '').toString().trim().compareTo((b['usn'] ?? '').toString().trim()));

              // Pre-select students currently in this batch
              final currentBatchStudents = (batch['students'] as List? ?? []);
              final currentIds = currentBatchStudents.map((s) => s['student_id'] as int).toSet();

              setDlgState(() {
                eligibleStudents = students;
                selectedStudentIds = currentIds;
                isFetching = false;
              });
            }).catchError((e) {
              setDlgState(() => isFetching = false);
            });
          }

          final filtered = eligibleStudents.where((s) {
            final q = search.toLowerCase();
            return q.isEmpty ||
                (s['name'] ?? '').toString().toLowerCase().contains(q) ||
                (s['usn'] ?? '').toString().toLowerCase().contains(q);
          }).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.group_add_rounded, color: Color(0xFF13246E)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Assign Students to $batchName",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 550,
              height: 480,
              child: isFetching
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Select students from this semester. Students already in another batch are protected to prevent duplicates.",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        // Search bar
                        TextField(
                          decoration: InputDecoration(
                            hintText: "Search students by Name or USN...",
                            prefixIcon: const Icon(Icons.search, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (val) => setDlgState(() => search = val.trim()),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Selected: ${selectedStudentIds.length} students",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF13246E)),
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setDlgState(() {
                                      for (final s in eligibleStudents) {
                                        final otherBatch = s['assigned_batch_id'];
                                        if (otherBatch == null || otherBatch == batchId) {
                                          selectedStudentIds.add(s['id'] as int);
                                        }
                                      }
                                    });
                                  },
                                  child: const Text("Select All Available", style: TextStyle(fontSize: 12)),
                                ),
                                TextButton(
                                  onPressed: () => setDlgState(() => selectedStudentIds.clear()),
                                  child: const Text("Clear", style: TextStyle(fontSize: 12, color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(),
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(child: Text("No students found."))
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (ctx, i) {
                                    final st = filtered[i];
                                    final sId = st['id'] as int;
                                    final assignedBatchId = st['assigned_batch_id'];
                                    final assignedBatchName = st['assigned_batch_name'];
                                    final isAssignedToOther = assignedBatchId != null && assignedBatchId != batchId;
                                    final isChecked = selectedStudentIds.contains(sId);

                                    return CheckboxListTile(
                                      value: isChecked,
                                      dense: true,
                                      enabled: !isAssignedToOther,
                                      activeColor: const Color(0xFF13246E),
                                      title: Text(
                                        st['name'] ?? 'Student',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: isAssignedToOther ? Colors.grey : Colors.black87,
                                        ),
                                      ),
                                      subtitle: Row(
                                        children: [
                                          Text(st['usn'] ?? '', style: const TextStyle(fontSize: 11)),
                                          if (isAssignedToOther) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade100,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                "In $assignedBatchName",
                                                style: TextStyle(color: Colors.orange.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      onChanged: isAssignedToOther
                                          ? null
                                          : (val) {
                                              setDlgState(() {
                                                if (val == true) {
                                                  selectedStudentIds.add(sId);
                                                } else {
                                                  selectedStudentIds.remove(sId);
                                                }
                                              });
                                            },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        setDlgState(() => isSaving = true);
                        try {
                          final dio = ApiClient().dio;
                          await dio.post(
                            '/attendance/batches/$batchId/assign_students/',
                            data: {'student_ids': selectedStudentIds.toList()},
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Updated ${selectedStudentIds.length} students for $batchName!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _fetchBatches();
                          }
                        } catch (e) {
                          setDlgState(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Failed to assign students: $e"), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Save Allocation"),
              ),
            ],
          );
        },
      ),
    );
  }


  // --- Delete Batch (HOD) ---
  Future<void> _deleteBatch(Map<String, dynamic> batch) async {
    final batchId = batch['id'] as int;
    final batchName = batch['name'] ?? 'Batch';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Lab Batch?"),
        content: Text("Are you sure you want to delete '$batchName'? Student assignments will be removed."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final dio = ApiClient().dio;
      await dio.delete('/attendance/batches/$batchId/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Batch '$batchName' deleted successfully!"), backgroundColor: Colors.green),
        );
        _fetchBatches();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete batch: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- Edit Lab Batch (HOD) ---
  Future<void> _openEditBatchDialog(Map<String, dynamic> batch) async {
    final batchId = batch['id'] as int;
    final nameCtrl = TextEditingController(text: batch['name'] ?? '');
    int? selectedSubjectId = batch['subject'] as int?;
    bool isSaving = false;

    List<Map<String, dynamic>> facultyList = [];
    int? selectedFacultyId = batch['faculty'] as int?;

    try {
      final facRes = await ApiClient().dio.get('/faculty/getProfessors/');
      final List rawFac = facRes.data is List ? facRes.data : (facRes.data['results'] ?? []);
      facultyList = rawFac.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13246E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: Color(0xFF13246E), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Edit Lab Batch",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        "Batch ID #${batch['id']}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: "Batch Name *",
                      hintText: "e.g. Batch A, Batch B, B1",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.group_work_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    value: _labSubjects.any((s) => (s['id'] ?? s['subject_id']) == selectedSubjectId)
                        ? selectedSubjectId
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Lab Subject",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.subject_rounded),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text("Shared Across All Department Labs"),
                      ),
                      ..._labSubjects.map((s) {
                        final id = (s['id'] ?? s['subject_id']) as int;
                        final code = s['subject_code'] ?? s['code'] ?? '';
                        final name = s['subject_name'] ?? s['name'] ?? 'Subject';
                        return DropdownMenuItem<int?>(
                          value: id,
                          child: Text(
                            code.isNotEmpty ? "$code - $name" : name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) => setDlgState(() => selectedSubjectId = val),
                  ),
                  const SizedBox(height: 16),
                  if (facultyList.isNotEmpty)
                    DropdownButtonFormField<int?>(
                      value: facultyList.any((f) => f['id'] == selectedFacultyId)
                          ? selectedFacultyId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Assigned Faculty",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text("Unassigned / Default Faculty"),
                        ),
                        ...facultyList.map((f) {
                          final fId = f['id'] as int;
                          final fName = f['name'] ?? f['faculty_name'] ?? 'Faculty';
                          final empId = f['employee_id'] ?? f['faculty_id'] ?? '';
                          return DropdownMenuItem<int?>(
                            value: fId,
                            child: Text(
                              empId.isNotEmpty ? "$fName (ID: $empId)" : fName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) => setDlgState(() => selectedFacultyId = val),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(isSaving ? "Saving..." : "Save Changes"),
                onPressed: isSaving
                    ? null
                    : () async {
                        final newName = nameCtrl.text.trim();
                        if (newName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Batch name cannot be empty."), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        setDlgState(() => isSaving = true);
                        try {
                          final dio = ApiClient().dio;
                          final data = <String, dynamic>{
                            'name': newName,
                            'subject': selectedSubjectId,
                          };
                          if (selectedFacultyId != null) {
                            data['faculty'] = selectedFacultyId;
                          }
                          await dio.patch('/attendance/batches/$batchId/', data: data);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Batch '$newName' updated successfully!"), backgroundColor: Colors.green),
                            );
                            _fetchBatches();
                          }
                        } catch (e) {
                          setDlgState(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Failed to update batch: $e"), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  void _openEditBatchesWorkflow() {
    if (_batches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No lab batches found to edit. Click 'Create Batches' first.")),
      );
      return;
    }

    if (_selectedBatch != null) {
      _openEditBatchDialog(_selectedBatch!);
      return;
    }

    // If no batch is selected, show a quick selection modal
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Color(0xFF13246E), size: 24),
            SizedBox(width: 10),
            Text("Select Batch to Edit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Choose a lab batch to edit details and assignments:", style: TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _batches.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final b = _batches[i];
                    final bName = b['name'] ?? 'Batch';
                    final subCode = b['subject_code'] ?? '';
                    final stCount = b['student_count'] ?? 0;
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF13246E).withValues(alpha: 0.1),
                        child: Text(bName.isNotEmpty ? bName[0] : 'B', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF13246E), fontSize: 12)),
                      ),
                      title: Text(bName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(subCode.isNotEmpty ? "$subCode • $stCount students" : "$stCount students", style: const TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openEditBatchDialog(b);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBatches;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.biotech_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text("Lab Batches", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        backgroundColor: const Color(0xFF13246E),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh Batches",
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadInitialData, child: const Text("Retry")),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF13246E), Color(0xFF1E3A8A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
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
                                    "Laboratory Batch Management",
                                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _isHod
                                        ? "Create and manage laboratory batches (Batch A, B, C, D), assign lab faculty, and allocate eligible students."
                                        : "View your assigned laboratory batches, student rosters, and experiment groups.",
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            if (_isHod) ...[
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  side: const BorderSide(color: Colors.white70),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.edit_note_rounded, size: 20),
                                label: const Text("Edit Batches", style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _openEditBatchesWorkflow,
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF13246E),
                                  elevation: 2,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 20),
                                label: const Text("Create Batches", style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _openCreateBatchesWorkflow,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Filter Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            // Semester Filter
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<int?>(
                                value: _selectedSemesterFilter,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: "Filter by Semester",
                                  prefixIcon: const Icon(Icons.school_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text("All Semesters"),
                                  ),
                                  ...List.generate(8, (i) => i + 1).map((sem) => DropdownMenuItem<int?>(
                                    value: sem,
                                    child: Text("Semester $sem"),
                                  )),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedSemesterFilter = val;
                                    // Reset selected subject if not available in selected semester
                                    if (_selectedSubjectFilter != null) {
                                      final availIds = _labSubjects.map((s) => (s['id'] ?? s['subject_id']) as int).toSet();
                                      if (!availIds.contains(_selectedSubjectFilter)) {
                                        _selectedSubjectFilter = null;
                                      }
                                    }
                                  });
                                  _fetchBatches();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Subject Filter
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int?>(
                                value: _selectedSubjectFilter,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: "Filter by Subject",
                                  prefixIcon: const Icon(Icons.subject_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text("All Laboratory Subjects"),
                                  ),
                                  ..._labSubjects.map((s) {
                                    final id = (s['id'] ?? s['subject_id']) as int;
                                    return DropdownMenuItem<int?>(
                                      value: id,
                                      child: Text("${s['subject_code']} - ${s['subject_name']}", overflow: TextOverflow.ellipsis),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  setState(() => _selectedSubjectFilter = val);
                                  _fetchBatches();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Search Box
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: InputDecoration(
                                  labelText: "Search Batches",
                                  prefixIcon: const Icon(Icons.search, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                onChanged: (val) {
                                  setState(() => _searchQuery = val.trim());
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Batches grouped by respective laboratory subjects
                      ..._buildSubjectGroupedBatches(filtered),
                      if (_selectedBatch != null) ...[
                        const SizedBox(height: 16),
                        _buildSelectedBatchStudentsSection(_selectedBatch!),
                      ],
                    ],
                  ),
                ),
    );
  }

  // --- Subject-Grouped Laboratory Batches View ---
  List<Widget> _buildSubjectGroupedBatches(List<Map<String, dynamic>> filtered) {
    final labSubs = _labSubjects;
    List<Map<String, dynamic>> targetSubjects = [];
    if (_selectedSubjectFilter != null) {
      targetSubjects = labSubs.where((s) => (s['id'] ?? s['subject_id']) == _selectedSubjectFilter).toList();
    } else {
      targetSubjects = labSubs;
    }

    if (targetSubjects.isEmpty && filtered.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              children: [
                Icon(Icons.biotech_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  _selectedSubjectFilter != null || _searchQuery.isNotEmpty
                      ? "No lab batches match your filter criteria."
                      : "No laboratory subjects or batches found in ${_selectedSemesterFilter != null ? 'Semester $_selectedSemesterFilter' : 'selected department'}. ${_isHod ? 'Click \'Create Lab Batch\' above to create one.' : ''}",
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ];
    }

    List<Widget> widgets = [];

    // 1. Render batches grouped by each laboratory subject
    for (final subj in targetSubjects) {
      final sId = subj['id'] ?? subj['subject_id'];
      final sCode = (subj['subject_code'] ?? subj['code'] ?? '').toString();
      final sName = (subj['subject_name'] ?? subj['name'] ?? '').toString();
      final sSem = subj['semester_no'] ?? subj['semester'] ?? '';
      final sCredits = subj['credits'];
      String sFaculty = (subj['assigned_faculty_name'] ?? 'Not Assigned').toString().trim();
      sFaculty = sFaculty.replaceAll(RegExp(r'Dr\.(?=[^\s])'), 'Dr. ');

      // Filter batches belonging to this subject:
      // Either explicitly assigned to this subject (b['subject'] == sId)
      // OR shared batch with subject == null (applies to all lab subjects in semester)
      final subjBatches = filtered.where((b) {
        final bSub = b['subject'];
        if (bSub != null && bSub != sId) return false;
        final bSem = (b['semester_number'] ?? b['semester_no'] ?? b['semester_name'] ?? (b['semester'] is Map ? b['semester']['sem_number'] : b['semester']) ?? '').toString();
        final sSemStr = sSem.toString();
        if (bSem.isNotEmpty && sSemStr.isNotEmpty && bSem != sSemStr) return false;
        return true;
      }).toList();

      final seenNames = <String>{};
      final uniqueSubjBatches = <Map<String, dynamic>>[];
      for (final b in subjBatches) {
        final name = (b['name'] ?? '').toString().trim().toLowerCase();
        if (name.isNotEmpty && seenNames.add(name)) {
          uniqueSubjBatches.add(b);
        }
      }

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Distinct Subject Header Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                    left: const BorderSide(color: Color(0xFF13246E), width: 4),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13246E).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.biotech_rounded, color: Color(0xFF13246E), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                sCode.isNotEmpty ? "$sCode - $sName" : sName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF13246E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Text(
                                  "Semester $sSem",
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                                ),
                              ),
                              if (sCredits != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF5FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE9D5FF)),
                                  ),
                                  child: Text(
                                    "$sCredits Credits",
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE)),
                                  ),
                                ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_rounded, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Faculty: $sFaculty",
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                  ),
                                ],
                              ),
                              Text(
                                "• ${uniqueSubjBatches.length} Batches",
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Batches Grid for this Subject
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: uniqueSubjBatches.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(
                          child: Text(
                            "No batches configured for $sName yet.",
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 520,
                          mainAxisExtent: 254,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: uniqueSubjBatches.length,
                        itemBuilder: (ctx, i) {
                          final b = uniqueSubjBatches[i];
                          return _buildBatchCard(b, subj);
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. If there are batches not covered by targetSubjects (e.g. general batches), show them
    final coveredBatchIds = <int>{};
    for (final subj in targetSubjects) {
      final sId = subj['id'] ?? subj['subject_id'];
      final sSemStr = (subj['semester_no'] ?? subj['semester'] ?? '').toString();
      for (final b in filtered) {
        final bSub = b['subject'] ?? b['subject_id'];
        final bSem = (b['semester_number'] ?? b['semester_no'] ?? b['semester_name'] ?? (b['semester'] is Map ? b['semester']['sem_number'] : b['semester']) ?? '').toString();
        if (bSub == sId || (bSub == null && (sSemStr.isEmpty || bSem.isEmpty || bSem == sSemStr))) {
          if (b['id'] != null) coveredBatchIds.add(b['id'] as int);
        }
      }
    }
    final remainingBatches = filtered.where((b) => b['id'] != null && !coveredBatchIds.contains(b['id'])).toList();
    if (remainingBatches.isNotEmpty) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("General Lab Batches", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF13246E))),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 520,
                  mainAxisExtent: 254,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: remainingBatches.length,
                itemBuilder: (ctx, i) => _buildBatchCard(remainingBatches[i], null),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildBatchCard(Map<String, dynamic> b, Map<String, dynamic>? subj) {
    final bId = b['id'] ?? 1;
    final bName = b['name'] ?? 'Batch';
    final subCode = (subj?['subject_code'] ?? subj?['code'] ?? b['subject_code'] ?? '').toString();
    final subName = (subj?['subject_name'] ?? subj?['name'] ?? b['subject_name'] ?? '').toString();

    String rawSem = (subj?['semester_no'] ?? b['semester_name'] ?? '').toString().trim();
    rawSem = rawSem.replaceAll(RegExp(r'^(Semester|Sem)\s*', caseSensitive: false), '').trim();
    final semDisplay = rawSem.isNotEmpty ? "Semester $rawSem" : "Semester";

    final String identifier = (b['identifier'] ?? '').toString().trim().isNotEmpty
        ? b['identifier'].toString().trim()
        : "${subj?['department'] ?? 'CSE'} \u2013 ${b['academic_year_name'] ?? '2026\u20132027'} \u2013 $semDisplay \u2013 $bName";

    String facultyName = (subj?['assigned_faculty_name'] ?? b['faculty_name'] ?? 'Unassigned').toString().trim();
    facultyName = facultyName.replaceAll(RegExp(r'Dr\.(?=[^\s])'), 'Dr. ');

    final studentCount = b['student_count'] ?? 0;
    final studentLabel = studentCount == 1 ? "1 Student" : "$studentCount Students";

    final isSelected = _selectedBatchId == b['id'] && (_selectedBatchSubject == null || subj == null || _selectedBatchSubject!['id'] == subj['id']);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _selectBatch(b, subj),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF0F4FF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF13246E) : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFF13246E).withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: isSelected ? 8 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Batch name + Unique ID badge + Student count badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF13246E)
                          : const Color(0xFF13246E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      bName,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF13246E),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      "ID #$bId",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF13246E)),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: studentCount > 0 ? const Color(0xFFECFDF5) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: studentCount > 0 ? const Color(0xFFA7F3D0) : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 12,
                          color: studentCount > 0 ? const Color(0xFF059669) : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          studentLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: studentCount > 0 ? const Color(0xFF047857) : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),

              // Batch Identifier (Department – Academic Year – Semester – Batch Name)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fingerprint_rounded, size: 12, color: Color(0xFF475569)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        identifier,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Subject row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: subCode.isNotEmpty
                          ? const Color(0xFF13246E).withValues(alpha: 0.08)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: subCode.isNotEmpty
                            ? const Color(0xFF13246E).withValues(alpha: 0.2)
                            : const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          subCode.isNotEmpty ? Icons.menu_book_rounded : Icons.share_rounded,
                          size: 13,
                          color: const Color(0xFF13246E),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          subCode.isNotEmpty ? subCode : "Shared Batch",
                          style: const TextStyle(
                            color: Color(0xFF13246E),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subName.isNotEmpty
                          ? subName
                          : "Shared across all lab subjects in $semDisplay",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: subName.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF1E40AF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Semester & Faculty metadata row
              Row(
                children: [
                  const Icon(Icons.school_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    semDisplay,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text("•", style: TextStyle(color: Color(0xFF94A3B8))),
                  const SizedBox(width: 10),
                  const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      facultyName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Actions row: Prominent, comfortable size for Students and Assign buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isSelected ? Colors.white : const Color(0xFF13246E),
                          backgroundColor: isSelected ? const Color(0xFF13246E) : Colors.transparent,
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF13246E) : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: Icon(isSelected ? Icons.check_circle_outline : Icons.group_outlined, size: 16),
                        label: Text(
                          isSelected ? "Viewing" : "Students",
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () => _selectBatch(b, subj),
                      ),
                    ),
                  ),
                  if (_isHod) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF13246E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                          label: const Text(
                            "Assign",
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () => _openAssignStudentsDialog(b),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: "Edit Batch",
                      child: InkWell(
                        onTap: () => _openEditBatchDialog(b),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF13246E)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Tooltip(
                      message: "Delete Batch",
                      child: InkWell(
                        onTap: () => _deleteBatch(b),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFFECDD3)),
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFFFFF1F2),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Inline Dedicated Selected Batch Students View ---
  Widget _buildSelectedBatchStudentsSection(Map<String, dynamic> batch) {
    final batchName = batch['name'] ?? 'Batch';
    final subCode = batch['subject_code'] ?? '';
    final subName = batch['subject_name'] ?? '';
    
    // Standardize Faculty Name spacing
    String facultyName = (batch['faculty_name'] ?? 'Unassigned').toString().trim();
    facultyName = facultyName.replaceAll(RegExp(r'Dr\.(?=[^\s])'), 'Dr. ');

    final rawStudents = (batch['students'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    // Sort batch students by USN in ascending order (lowest to highest)
    rawStudents.sort((a, b) => (a['usn'] ?? '').toString().trim().compareTo((b['usn'] ?? '').toString().trim()));

    final filteredStudents = rawStudents.where((s) {
      final q = _batchStudentSearch.toLowerCase();
      if (q.isEmpty) return true;
      return (s['name'] ?? '').toString().toLowerCase().contains(q) ||
          (s['usn'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF13246E).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF13246E).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF13246E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    batchName,
                    style: const TextStyle(color: Color(0xFF13246E), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$batchName Students Roster (${rawStudents.length} Assigned)",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${_selectedBatchSubject?['subject_code'] ?? _selectedBatchSubject?['code'] ?? subCode} - ${_selectedBatchSubject?['subject_name'] ?? _selectedBatchSubject?['name'] ?? subName} • Faculty: ${_selectedBatchSubject?['assigned_faculty_name'] ?? facultyName}",
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_isHod) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF13246E),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text("Manage / Assign", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () => _openAssignStudentsDialog(batch),
                  ),
                  const SizedBox(width: 10),
                ],
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: "Close",
                  onPressed: () => setState(() {
                    _selectedBatchId = null;
                    _selectedBatch = null;
                  }),
                ),
              ],
            ),
          ),

          // Search & Metrics Subheader
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _batchStudentSearchCtrl,
                    decoration: InputDecoration(
                      hintText: "Search students in $batchName by name or USN...",
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      suffixIcon: _batchStudentSearch.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _batchStudentSearchCtrl.clear();
                                setState(() => _batchStudentSearch = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) => setState(() => _batchStudentSearch = val.trim()),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 18, color: Color(0xFF13246E)),
                      const SizedBox(width: 8),
                      Text(
                        "${filteredStudents.length} / ${rawStudents.length} Students",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF13246E), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Students List
          if (filteredStudents.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.person_off_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      rawStudents.isEmpty
                          ? "No students have been assigned to $batchName yet."
                          : "No students match '$_batchStudentSearch'.",
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredStudents.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (ctx, idx) {
                final s = filteredStudents[idx];
                final usn = s['usn'] ?? 'N/A';
                final name = s['name'] ?? 'Student';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF13246E).withValues(alpha: 0.1),
                    child: Text(
                      "${idx + 1}",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                  subtitle: Text(
                    "USN: $usn",
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.black54),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      batchName,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue.shade900),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
