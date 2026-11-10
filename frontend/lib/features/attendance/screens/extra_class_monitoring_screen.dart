import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' as p;
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/widgets/app_pagination_bar.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';

class ExtraClassMonitoringScreen extends StatefulWidget {
  const ExtraClassMonitoringScreen({super.key});

  @override
  State<ExtraClassMonitoringScreen> createState() => _ExtraClassMonitoringScreenState();
}

class _ExtraClassMonitoringScreenState extends State<ExtraClassMonitoringScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  // Data
  List<Map<String, dynamic>> _extraClasses = [];
  Map<String, dynamic> _stats = {
    'total_extra_classes': 0,
    'conducted_classes': 0,
    'theory_classes': 0,
    'lab_classes': 0,
    'scheduled_classes': 0,
    'cancelled_classes': 0,
  };

  // Filter options
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _faculties = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _academicYears = [
    {"id": 2, "year_name": "2026-2027"},
    {"id": 1, "year_name": "2025-2026"},
  ];

  // Active filters
  String _searchQuery = "";
  int? _selectedDeptId;
  String? _selectedFacultyName;
  int? _selectedSubjectId;
  String? _selectedAcademicYear;
  String? _selectedClassType; // null, 'THEORY', 'LAB'
  String? _selectedStatus; // null, 'Conducted', 'Scheduled', 'Cancelled'
  DateTime? _dateFrom;
  DateTime? _dateTo;

  // Sorting
  String _sortBy = "date"; // 'date', 'faculty', 'subject', 'status'
  bool _sortAscending = false;

  // Pagination
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadInitialFilterData();
    _fetchExtraClasses();
  }

  Future<void> _loadInitialFilterData() async {
    try {
      final dio = ApiClient().dio;
      final deptFuture = dio.get('/academics/departments/').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: []));
      final facFuture = dio.get('/faculty/faculties/').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: []));
      final subFuture = dio.get('/subjects/').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: []));
      final ayFuture = dio.get('/academics/academic-years/').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: []));

      final results = await Future.wait([deptFuture, facFuture, subFuture, ayFuture]);

      List<Map<String, dynamic>> toList(dynamic data) {
        if (data is Map && data['results'] is List) {
          return List<Map<String, dynamic>>.from(data['results']);
        }
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        return [];
      }

      if (mounted) {
        setState(() {
          _departments = toList(results[0].data);
          _faculties = toList(results[1].data);
          _subjects = toList(results[2].data);
          final loadedAys = toList(results[3].data);
          if (loadedAys.isNotEmpty) {
            _academicYears = loadedAys;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchExtraClasses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final queryParams = <String, dynamic>{};

      if (_selectedDeptId != null) queryParams['department_id'] = _selectedDeptId;
      if (_selectedFacultyName != null && _selectedFacultyName!.isNotEmpty) {
        queryParams['faculty_name'] = _selectedFacultyName;
      }
      if (_selectedSubjectId != null) queryParams['subject_id'] = _selectedSubjectId;
      if (_selectedAcademicYear != null && _selectedAcademicYear!.isNotEmpty) {
        queryParams['academic_year'] = _selectedAcademicYear;
      }
      if (_selectedClassType != null && _selectedClassType!.isNotEmpty) {
        queryParams['class_type'] = _selectedClassType;
      }
      if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
        queryParams['effective_status'] = _selectedStatus;
      }
      if (_dateFrom != null) {
        queryParams['date_from'] = DateFormat('yyyy-MM-dd').format(_dateFrom!);
      }
      if (_dateTo != null) {
        queryParams['date_to'] = DateFormat('yyyy-MM-dd').format(_dateTo!);
      }
      if (_searchQuery.trim().isNotEmpty) {
        queryParams['search'] = _searchQuery.trim();
      }

      // 1. Fetch Extra Classes List
      final listFuture = dio.get('/attendance/extra-classes/', queryParameters: queryParams);
      // 2. Fetch Aggregated Stats
      final statsFuture = dio.get('/attendance/extra-classes/stats/', queryParameters: queryParams).catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: {}));

      final responses = await Future.wait([listFuture, statsFuture]);

      List<Map<String, dynamic>> items = [];
      final listData = responses[0].data;
      if (listData is Map && listData['results'] is List) {
        items = List<Map<String, dynamic>>.from(listData['results']);
      } else if (listData is List) {
        items = List<Map<String, dynamic>>.from(listData);
      }

      Map<String, dynamic> statsData = {};
      if (responses[1].data is Map) {
        statsData = Map<String, dynamic>.from(responses[1].data);
      }

      // Compute fallback stats if backend stats endpoint returns empty
      if (statsData.isEmpty && items.isNotEmpty) {
        int conducted = 0;
        int theory = 0;
        int lab = 0;
        int cancelled = 0;
        for (final item in items) {
          final st = (item['effective_status'] ?? item['status'] ?? '').toString().toUpperCase();
          if (st == 'CONDUCTED' || item['conducted_attendance_session_id'] != null) {
            conducted++;
          } else if (st == 'CANCELLED') {
            cancelled++;
          }
          final type = (item['session_type'] ?? '').toString().toUpperCase();
          if (type == 'THEORY') theory++;
          if (type == 'LAB') lab++;
        }
        statsData = {
          'total_extra_classes': items.length,
          'conducted_classes': conducted,
          'theory_classes': theory,
          'lab_classes': lab,
          'scheduled_classes': items.length - conducted - cancelled,
          'cancelled_classes': cancelled,
        };
      }

      if (mounted) {
        setState(() {
          _extraClasses = items;
          if (statsData.isNotEmpty) _stats = statsData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load extra classes: $e";
          _isLoading = false;
        });
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = "";
      _selectedDeptId = null;
      _selectedFacultyName = null;
      _selectedSubjectId = null;
      _selectedAcademicYear = null;
      _selectedClassType = null;
      _selectedStatus = null;
      _dateFrom = null;
      _dateTo = null;
      _currentPage = 1;
    });
    _fetchExtraClasses();
  }

  List<Map<String, dynamic>> _getProcessedList() {
    var list = List<Map<String, dynamic>>.from(_extraClasses);

    // Client-side search check
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((item) {
        final facName = (item['faculty_name'] ?? '').toString().toLowerCase();
        final empId = (item['faculty_employee_id'] ?? '').toString().toLowerCase();
        final subCode = (item['subject_code'] ?? '').toString().toLowerCase();
        final subName = (item['subject_name'] ?? '').toString().toLowerCase();
        final reason = (item['reason'] ?? '').toString().toLowerCase();
        final room = (item['room'] ?? '').toString().toLowerCase();
        return facName.contains(q) || empId.contains(q) || subCode.contains(q) || subName.contains(q) || reason.contains(q) || room.contains(q);
      }).toList();
    }

    // Sort
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortBy) {
        case "faculty":
          cmp = (a['faculty_name'] ?? '').toString().compareTo((b['faculty_name'] ?? '').toString());
          break;
        case "subject":
          cmp = (a['subject_code'] ?? '').toString().compareTo((b['subject_code'] ?? '').toString());
          break;
        case "status":
          cmp = (a['effective_status'] ?? '').toString().compareTo((b['effective_status'] ?? '').toString());
          break;
        case "date":
        default:
          cmp = (a['date'] ?? '').toString().compareTo((b['date'] ?? '').toString());
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final auth = p.Provider.of<AuthProvider>(context);
    final userRole = (auth.role ?? '').toUpperCase();
    final isHod = userRole == 'HOD';
    final userDeptId = auth.userData?['department'] is int
        ? auth.userData!['department'] as int
        : int.tryParse(auth.userData?['department']?.toString() ?? '');
    final userDeptName = auth.userData?['department_name']?.toString() ?? 'Department';

    // Auto-lock HOD department
    if (isHod && _selectedDeptId == null && userDeptId != null) {
      _selectedDeptId = userDeptId;
    }

    final processedList = _getProcessedList();
    final totalItems = processedList.length;
    final totalPages = totalItems == 0 ? 1 : (totalItems / _pageSize).ceil();
    final safePage = _currentPage > totalPages ? totalPages : (_currentPage < 1 ? 1 : _currentPage);
    final pageItems = totalItems == 0 ? <Map<String, dynamic>>[] : processedList.skip((safePage - 1) * _pageSize).take(_pageSize).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 1. Navy Top Header Bar
          Container(
            color: const Color(0xFF13246E),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.more_time_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Extra Class Monitoring",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isHod ? "Department of $userDeptName • HOD Oversight" : "Campus-Wide Faculty Extra Class Sessions",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _fetchExtraClasses,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text("Refresh"),
                ),
              ],
            ),
          ),

          // 2. Scrollable Body
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchExtraClasses,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 4 KPI Summary Cards
                    _buildKPICards(),
                    const SizedBox(height: 24),

                    // Filter Toolbar
                    _buildFilterToolbar(isHod: isHod, userDeptName: userDeptName),
                    const SizedBox(height: 20),

                    // Table Card
                    _buildTableCard(processedList: processedList, pageItems: pageItems, safePage: safePage, totalPages: totalPages, totalItems: totalItems),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4 KPI CARDS ---
  Widget _buildKPICards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final cardWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: "Total Extra Classes",
                value: "${_stats['total_extra_classes'] ?? 0}",
                subtitle: "All recorded sessions",
                icon: Icons.more_time_rounded,
                iconColor: const Color(0xFF13246E),
                bgColor: const Color(0xFFEEF2FF),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: "Conducted Classes",
                value: "${_stats['conducted_classes'] ?? 0}",
                subtitle: "Attendance recorded",
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: "Theory Extra Classes",
                value: "${_stats['theory_classes'] ?? 0}",
                subtitle: "Lecture sessions",
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: "Lab Extra Classes",
                value: "${_stats['lab_classes'] ?? 0}",
                subtitle: "Practical sessions",
                icon: Icons.biotech_rounded,
                iconColor: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFF3E8FF),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  // --- FILTER TOOLBAR ---
  Widget _buildFilterToolbar({required bool isHod, required String userDeptName}) {
    return Container(
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
          const Row(
            children: [
              Icon(Icons.filter_list_rounded, size: 20, color: Color(0xFF13246E)),
              SizedBox(width: 8),
              Text(
                "Filter Extra Classes",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 1. Search Box
              SizedBox(
                width: 240,
                height: 42,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search faculty, subject, reason...",
                    hintStyle: const TextStyle(fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _currentPage = 1;
                    });
                  },
                ),
              ),

              // 2. Department Dropdown
              Container(
                height: 42,
                constraints: const BoxConstraints(maxWidth: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                  color: isHod ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedDeptId,
                    hint: Text(isHod ? userDeptName : "All Departments", style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                    items: isHod
                        ? [DropdownMenuItem(value: _selectedDeptId, child: Text(userDeptName, overflow: TextOverflow.ellipsis))]
                        : [
                            const DropdownMenuItem(value: null, child: Text("All Departments")),
                            ..._departments.map((d) => DropdownMenuItem(value: d['id'] as int?, child: Text(d['name']?.toString() ?? '', overflow: TextOverflow.ellipsis))),
                          ],
                    onChanged: isHod
                        ? null
                        : (val) {
                            setState(() {
                              _selectedDeptId = val;
                              _currentPage = 1;
                            });
                            _fetchExtraClasses();
                          },
                  ),
                ),
              ),

              // 2b. Faculty Filter Dropdown
              Container(
                height: 42,
                constraints: const BoxConstraints(maxWidth: 190),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFF8FAFC),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedFacultyName,
                    hint: const Text("All Faculty", style: TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("All Faculty")),
                      ..._faculties.map((f) {
                        final name = f['name']?.toString() ?? 'Faculty';
                        return DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis));
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedFacultyName = val;
                        _currentPage = 1;
                      });
                      _fetchExtraClasses();
                    },
                  ),
                ),
              ),

              // 2c. Subject Filter Dropdown
              Container(
                height: 42,
                constraints: const BoxConstraints(maxWidth: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFF8FAFC),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedSubjectId,
                    hint: const Text("All Subjects", style: TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("All Subjects")),
                      ..._subjects.map((s) {
                        final code = s['subject_code'] ?? '';
                        final name = s['subject_name'] ?? '';
                        return DropdownMenuItem(
                          value: s['id'] as int?,
                          child: Text("$code - $name", overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedSubjectId = val;
                        _currentPage = 1;
                      });
                      _fetchExtraClasses();
                    },
                  ),
                ),
              ),

              // 3. Class Type Filter (Theory / Lab)
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFF8FAFC),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedClassType,
                    hint: const Text("All Class Types", style: TextStyle(fontSize: 12.5)),
                    items: const [
                      DropdownMenuItem(value: null, child: Text("All Class Types")),
                      DropdownMenuItem(value: "THEORY", child: Text("Theory Only")),
                      DropdownMenuItem(value: "LAB", child: Text("Lab Only")),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedClassType = val;
                        _currentPage = 1;
                      });
                      _fetchExtraClasses();
                    },
                  ),
                ),
              ),

              // 4. Status Filter (Scheduled, Conducted, Cancelled)
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFF8FAFC),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    hint: const Text("All Statuses", style: TextStyle(fontSize: 12.5)),
                    items: const [
                      DropdownMenuItem(value: null, child: Text("All Statuses")),
                      DropdownMenuItem(value: "Conducted", child: Text("Conducted")),
                      DropdownMenuItem(value: "Scheduled", child: Text("Scheduled")),
                      DropdownMenuItem(value: "Cancelled", child: Text("Cancelled")),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedStatus = val;
                        _currentPage = 1;
                      });
                      _fetchExtraClasses();
                    },
                  ),
                ),
              ),

              // 5. Academic Year Filter
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFF8FAFC),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedAcademicYear,
                    hint: const Text("All Academic Years", style: TextStyle(fontSize: 12.5)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("All Academic Years")),
                      ..._academicYears.map((ay) {
                        final yName = ay['year_name']?.toString() ?? '';
                        return DropdownMenuItem(value: yName, child: Text(yName));
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedAcademicYear = val;
                        _currentPage = 1;
                      });
                      _fetchExtraClasses();
                    },
                  ),
                ),
              ),

              // 6. Date Range Picker Button
              InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: (_dateFrom != null || _dateTo != null) ? const Color(0xFF13246E) : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                    color: (_dateFrom != null || _dateTo != null) ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16, color: (_dateFrom != null || _dateTo != null) ? const Color(0xFF13246E) : const Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text(
                        _formatDateRangeLabel(),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: (_dateFrom != null || _dateTo != null) ? FontWeight.bold : FontWeight.normal,
                          color: (_dateFrom != null || _dateTo != null) ? const Color(0xFF13246E) : const Color(0xFF334155),
                        ),
                      ),
                      if (_dateFrom != null || _dateTo != null) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _dateFrom = null;
                              _dateTo = null;
                              _currentPage = 1;
                            });
                            _fetchExtraClasses();
                          },
                          child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 7. Reset Filters Button
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: const Text("Reset Filters"),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateRangeLabel() {
    if (_dateFrom != null && _dateTo != null) {
      return "${DateFormat('dd/MM/yy').format(_dateFrom!)} - ${DateFormat('dd/MM/yy').format(_dateTo!)}";
    } else if (_dateFrom != null) {
      return "From ${DateFormat('dd/MM/yy').format(_dateFrom!)}";
    } else if (_dateTo != null) {
      return "To ${DateFormat('dd/MM/yy').format(_dateTo!)}";
    }
    return "Date Range";
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDateRange: _dateFrom != null && _dateTo != null
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF13246E),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
        _currentPage = 1;
      });
      _fetchExtraClasses();
    }
  }

  // --- TABLE CARD ---
  Widget _buildTableCard({
    required List<Map<String, dynamic>> processedList,
    required List<Map<String, dynamic>> pageItems,
    required int safePage,
    required int totalPages,
    required int totalItems,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      "Extra Class Records",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "$totalItems entries",
                        style: const TextStyle(color: Color(0xFF13246E), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                // Sort Menu
                PopupMenuButton<String>(
                  tooltip: "Sort records",
                  onSelected: (val) {
                    setState(() {
                      if (_sortBy == val) {
                        _sortAscending = !_sortAscending;
                      } else {
                        _sortBy = val;
                        _sortAscending = false;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort_rounded, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          "Sort: ${_sortBy.toUpperCase()} ${_sortAscending ? '▲' : '▼'}",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: "date", child: Text("Sort by Date")),
                    PopupMenuItem(value: "faculty", child: Text("Sort by Faculty Name")),
                    PopupMenuItem(value: "subject", child: Text("Sort by Subject")),
                    PopupMenuItem(value: "status", child: Text("Sort by Status")),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(48.0),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF13246E))),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
                    const SizedBox(height: 12),
                    Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _fetchExtraClasses, child: const Text("Retry")),
                  ],
                ),
              ),
            )
          else if (pageItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(56.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_busy_rounded, size: 54, color: Colors.grey.shade400),
                    const SizedBox(height: 14),
                    const Text(
                      "No Extra Classes Found",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "No extra class sessions match your active filter criteria.",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: _resetFilters,
                      child: const Text("Clear Filters"),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                dataRowMinHeight: 52,
                dataRowMaxHeight: 64,
                columns: const [
                  DataColumn(label: Text("Faculty Name", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Employee ID", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Department", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Subject", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Class Type", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Date", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Period / Time", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Duration", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Reason", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Action", style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: pageItems.map((item) {
                  final facName = item['faculty_name'] ?? item['professor_name'] ?? 'Faculty';
                  final empId = item['faculty_employee_id'] ?? 'N/A';
                  final deptName = item['department_name'] ?? 'Department';
                  final subCode = item['subject_code'] ?? 'N/A';
                  final subName = item['subject_name'] ?? 'N/A';
                  final classType = (item['session_type'] ?? 'THEORY').toString().toUpperCase();
                  final date = item['date'] ?? 'N/A';
                  final startTime = item['start_time']?.toString() ?? '';
                  final endTime = item['end_time']?.toString() ?? '';
                  final duration = item['duration_minutes'] != null ? "${item['duration_minutes']} mins" : '60 mins';
                  final reason = item['reason'] ?? 'Extra syllabus coverage';
                  final effectiveStatus = item['effective_status'] ?? (item['status'] == 'APPROVED' ? 'Scheduled' : (item['status'] ?? 'Scheduled'));

                  final isConducted = effectiveStatus == 'Conducted';
                  final isCancelled = effectiveStatus == 'Cancelled';

                  Color badgeColor = isConducted
                      ? const Color(0xFF059669)
                      : (isCancelled ? const Color(0xFFDC2626) : const Color(0xFF0284C7));
                  Color badgeBg = isConducted
                      ? const Color(0xFFECFDF5)
                      : (isCancelled ? const Color(0xFFFEF2F2) : const Color(0xFFE0F2FE));

                  return DataRow(
                    cells: [
                      // Faculty Name
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF13246E).withValues(alpha: 0.1),
                              child: Text(
                                facName.isNotEmpty ? facName[0].toUpperCase() : 'F',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF13246E)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(facName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),

                      // Employee ID
                      DataCell(Text(empId, style: const TextStyle(fontWeight: FontWeight.w500))),

                      // Department
                      DataCell(Text(deptName)),

                      // Subject (Code + Name)
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                              child: Text(subCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E293B))),
                            ),
                            const SizedBox(height: 2),
                            Text(subName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),

                      // Class Type
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: classType == 'LAB' ? const Color(0xFFF3E8FF) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            classType,
                            style: TextStyle(
                              color: classType == 'LAB' ? const Color(0xFF7C3AED) : const Color(0xFF1D4ED8),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),

                      // Date
                      DataCell(Text(date, style: const TextStyle(fontWeight: FontWeight.w500))),

                      // Period / Time
                      DataCell(
                        Text(
                          startTime.isNotEmpty && endTime.isNotEmpty ? "$startTime - $endTime" : "Scheduled Slot",
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),

                      // Duration
                      DataCell(Text(duration, style: const TextStyle(fontSize: 12.5))),

                      // Reason
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Tooltip(
                            message: reason,
                            child: Text(
                              reason,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                            ),
                          ),
                        ),
                      ),

                      // Status Badge
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            effectiveStatus,
                            style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11.5),
                          ),
                        ),
                      ),

                      // Action (View Details Modal)
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF13246E), size: 20),
                          tooltip: "View Details",
                          onPressed: () => _showExtraClassDetailsDialog(item),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),

          // Pagination Bar at Bottom
          if (!_isLoading && pageItems.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: AppPaginationBar(
                currentPage: safePage,
                totalPages: totalPages,
                totalItems: totalItems,
                pageSize: _pageSize,
                onPageChanged: (newPage) => setState(() => _currentPage = newPage),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- DETAILS DIALOG ---
  void _showExtraClassDetailsDialog(Map<String, dynamic> item) {
    final facName = item['faculty_name'] ?? item['professor_name'] ?? 'Faculty';
    final empId = item['faculty_employee_id'] ?? 'N/A';
    final facEmail = item['faculty_email'] ?? 'N/A';
    final deptName = item['department_name'] ?? 'Department';
    final subCode = item['subject_code'] ?? 'N/A';
    final subName = item['subject_name'] ?? 'N/A';
    final semNo = item['semester_no']?.toString() ?? 'N/A';
    final sessionType = (item['session_type'] ?? 'THEORY').toString().toUpperCase();
    final batchName = item['batch_name'] ?? '';
    final date = item['date'] ?? 'N/A';
    final startTime = item['start_time'] ?? '';
    final endTime = item['end_time'] ?? '';
    final duration = item['duration_minutes'] != null ? "${item['duration_minutes']} mins" : '60 mins';
    final room = (item['room'] ?? '').toString().trim();
    final reason = item['reason'] ?? 'Extra syllabus coverage';
    final effectiveStatus = item['effective_status'] ?? (item['status'] == 'APPROVED' ? 'Scheduled' : (item['status'] ?? 'Scheduled'));
    final attSessionId = item['conducted_attendance_session_id'];
    final attRecordsCount = item['conducted_attendance_records_count'] ?? 0;
    final academicYear = item['academic_year'] ?? '2026-2027';

    final isConducted = effectiveStatus == 'Conducted';
    final isCancelled = effectiveStatus == 'Cancelled';

    Color statusColor = isConducted
        ? const Color(0xFF059669)
        : (isCancelled ? const Color(0xFFDC2626) : const Color(0xFF0284C7));
    Color statusBg = isConducted
        ? const Color(0xFFECFDF5)
        : (isCancelled ? const Color(0xFFFEF2F2) : const Color(0xFFE0F2FE));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 20, 12),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.event_note_rounded, color: Color(0xFF13246E), size: 24),
                SizedBox(width: 10),
                Text("Extra Class Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isConducted ? Icons.check_circle_rounded : (isCancelled ? Icons.cancel_rounded : Icons.schedule_rounded),
                        color: statusColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Status: $effectiveStatus",
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        "Academic Year: $academicYear",
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Faculty Details Section
                _dialogSectionTitle("Faculty Details"),
                const SizedBox(height: 8),
                _detailRow("Faculty Name", facName),
                _detailRow("Employee / Faculty ID", empId),
                _detailRow("Department", deptName),
                if (facEmail.isNotEmpty && facEmail != 'N/A') _detailRow("Email", facEmail),
                const Divider(height: 24),

                // Subject Details Section
                _dialogSectionTitle("Subject & Course Information"),
                const SizedBox(height: 8),
                _detailRow("Subject Name", subName),
                _detailRow("Subject Code", subCode),
                _detailRow("Semester", "Semester $semNo"),
                _detailRow("Class Type", sessionType == 'LAB' ? "Practical / Lab" : "Theory Session"),
                if (batchName.isNotEmpty) _detailRow("Batch", batchName),
                const Divider(height: 24),

                // Schedule Details Section
                _dialogSectionTitle("Session Schedule"),
                const SizedBox(height: 8),
                _detailRow("Date", date),
                _detailRow("Time Slot", "$startTime - $endTime"),
                _detailRow("Duration", duration),
                if (room.isNotEmpty) _detailRow("Room / Venue", room),
                const Divider(height: 24),

                // Conducted Attendance Details
                _dialogSectionTitle("Attendance Execution"),
                const SizedBox(height: 8),
                if (isConducted) ...[
                  _detailRow("Attendance Session", attSessionId != null ? "Session #$attSessionId (Recorded)" : "Attendance Conducted"),
                  _detailRow("Students Marked", "$attRecordsCount records"),
                ] else if (isCancelled) ...[
                  const Text("This extra class session was cancelled.", style: TextStyle(color: Colors.red, fontSize: 13, fontStyle: FontStyle.italic)),
                ] else ...[
                  const Text(
                    "This class is scheduled. Attendance will be recorded during or immediately after the session.",
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
                const Divider(height: 24),

                // Reason Section
                _dialogSectionTitle("Reason for Extra Class"),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    reason,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CLOSE"),
          ),
        ],
      ),
    );
  }

  Widget _dialogSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E293B)),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
