import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:go_router/go_router.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:frontend/core/network/api_client.dart';

import 'package:frontend/core/constants/api_constants.dart';

import 'package:frontend/core/widgets/app_pagination_bar.dart';

import '../models/faculty_model.dart';

import '../widgets/edit_faculty_dialog.dart';

const _storage = FlutterSecureStorage();

class FacultyListScreen extends StatefulWidget {

  final String? filterType;

  final String? customTitle;

  const FacultyListScreen({super.key, this.filterType, this.customTitle});

  @override

  State<FacultyListScreen> createState() => _FacultyListScreenState();

}

class _FacultyListScreenState extends State<FacultyListScreen> {

  List<Faculty> _allFaculty = [];

  List<DepartmentOption> _departments = [];

  bool _isLoading = true;

  String? _error;

  String? _userRole;

  // Filter & Search states

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  String? _selectedDepartment; // 'all' or department name/id

  String _selectedStatus = 'all';
  String _selectedFacultyType = 'all'; // 'all', 'regular', 'guest' // 'all', 'approved', 'pending_office', 'rejected'

  String _selectedSort = 'name'; // 'name', 'id', 'department'

  // Pagination states

  int _currentPage = 1;

  static const int _pageSize = 10;

  @override

  void initState() {

    super.initState();

    _loadUserRole();

    _fetchDepartments();

    _fetchFaculty();

  }

  @override

  void dispose() {

    _searchController.dispose();

    super.dispose();

  }

  Future<void> _loadUserRole() async {

    final role = await _storage.read(key: 'role');

    if (mounted) {

      setState(() {

        _userRole = (role ?? '').toUpperCase();

      });

    }

  }

  Future<void> _fetchDepartments() async {

    try {

      final dio = ApiClient().dio;

      final response = await dio.get('/academics/departments/');

      List data = [];

      if (response.data is List) {

        data = response.data;

      } else if (response.data is Map && response.data['results'] is List) {

        data = response.data['results'];

      }

      if (mounted) {

        setState(() {

          _departments = data.map((e) => DepartmentOption.fromMap(e)).toList();

        });

      }

    } catch (_) {}

  }

  Future<void> _fetchFaculty() async {

    setState(() {

      _isLoading = true;

      _error = null;

    });

    try {

      final dio = ApiClient().dio;

      // Pass include_all=true so HOD and other roles can see full list and filter dynamically

      final Map<String, dynamic> qParams = {};
      if (_userRole != 'HOD') {
        qParams['include_all'] = 'true';
      }
      final response = await dio.get(
        '/faculty/faculties/',
        queryParameters: qParams.isNotEmpty ? qParams : null,
      );

      List data = [];

      if (response.data is List) {

        data = response.data;

      } else if (response.data is Map && response.data['results'] is List) {

        data = response.data['results'];

      }

      if (mounted) {

        setState(() {

          _allFaculty = data.map((e) => Faculty.fromMap(e)).toList();

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

  List<Faculty> _getFilteredFaculty() {

    List<Faculty> list = List.from(_allFaculty);

    // Initial filterType (e.g. 'pending') if passed from route

    if (widget.filterType == 'pending') {

      list = list.where((f) => f.status.toLowerCase().contains('pending')).toList();

    }

    // Status filter

    if (_selectedStatus != 'all') {

      list = list.where((f) {

        final s = f.status.toLowerCase();

        if (_selectedStatus == 'approved') return s == 'approved';

        if (_selectedStatus == 'pending_office') return s.contains('pending');

        if (_selectedStatus == 'rejected') return s == 'rejected';

        return s == _selectedStatus.toLowerCase();

      }).toList();

    }

    // Department filter (works for HOD, Principal, Admission, Admin)

    if (_selectedDepartment != null && _selectedDepartment != 'all') {

      list = list.where((f) {

        final fDept = f.department.toLowerCase().trim();

        final selDept = _selectedDepartment!.toLowerCase().trim();

        return fDept == selDept || f.departmentId.toString() == _selectedDepartment;

      }).toList();

    }

    // Faculty Type filter (All, Regular, Guest)
    if (_selectedFacultyType == 'guest') {
      list = list.where((f) => f.isGuestFaculty || f.employmentType == 'GUEST' || (f.designation != null && f.designation!.toLowerCase().contains('guest'))).toList();
    } else if (_selectedFacultyType == 'regular') {
      list = list.where((f) => !f.isGuestFaculty && f.employmentType != 'GUEST' && !(f.designation != null && f.designation!.toLowerCase().contains('guest'))).toList();
    }

    // Search query (name, department, employee ID)

    if (_searchQuery.isNotEmpty) {

      final q = _searchQuery.toLowerCase();

      list = list.where((f) {

        final matchName = f.name.toLowerCase().contains(q);

        final matchDept = f.department.toLowerCase().contains(q);

        final matchId = f.facultyId.toLowerCase().contains(q);

        return matchName || matchDept || matchId;

      }).toList();

    }

    // Sorting

    if (_selectedSort == 'name') {

      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    } else if (_selectedSort == 'id') {

      list.sort((a, b) => a.facultyId.toLowerCase().compareTo(b.facultyId.toLowerCase()));

    } else if (_selectedSort == 'department') {

      list.sort((a, b) => a.department.toLowerCase().compareTo(b.department.toLowerCase()));

    }

    return list;

  }

  @override

  Widget build(BuildContext context) {

    final filtered = _getFilteredFaculty();

    final totalItems = filtered.length;

    final totalPages = totalItems == 0 ? 1 : (totalItems / _pageSize).ceil();

    final safePage = _currentPage > totalPages ? totalPages : (_currentPage < 1 ? 1 : _currentPage);

    final startIndex = (safePage - 1) * _pageSize;

    final pagedList = totalItems == 0 ? <Faculty>[ ] : filtered.skip(startIndex).take(_pageSize).toList();

    return Scaffold(

      backgroundColor: const Color(0xFFF8FAFC),

      body: SingleChildScrollView(

        padding: EdgeInsets.all(MediaQuery.of(context).size.width < 480 ? 12 : 20),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            // Top Header: Title & Subtitle + Refresh Button (Image 1)

            Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: const [

                    Text(

                      "Faculty List",

                      style: TextStyle(

                        fontSize: 22,

                        fontWeight: FontWeight.bold,

                        color: Color(0xFF0F172A),

                        letterSpacing: -0.3,

                      ),

                    ),

                    SizedBox(height: 2),

                    Text(

                      "Faculty Directory",

                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),

                    ),

                  ],

                ),

                Container(

                  decoration: BoxDecoration(

                    color: Colors.white,

                    shape: BoxShape.circle,

                    border: Border.all(color: const Color(0xFFE2E8F0)),

                    boxShadow: [

                      BoxShadow(

                        color: Colors.black.withValues(alpha: 0.03),

                        blurRadius: 4,

                        offset: const Offset(0, 1),

                      ),

                    ],

                  ),

                  child: IconButton(

                    icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF13246E)),

                    tooltip: "Refresh Directory",

                    onPressed: () {

                      _fetchDepartments();

                      _fetchFaculty();

                    },

                  ),

                ),

              ],

            ),

            const SizedBox(height: 16),

            // Hero Banner: Blue gradient banner with illustration (Image 1)

            _buildHeroBanner(),

            const SizedBox(height: 16),

            // Search and Filters Bar (Image 1)

            _buildFilterBar(),

            const SizedBox(height: 16),

            // Faculty List Content

            if (_isLoading)

              const Padding(

                padding: EdgeInsets.all(40),

                child: Center(child: CircularProgressIndicator(color: Color(0xFF13246E))),

              )

            else if (_error != null)

              Container(

                width: double.infinity,

                padding: const EdgeInsets.all(28),

                decoration: BoxDecoration(

                  color: Colors.white,

                  borderRadius: BorderRadius.circular(12),

                  border: Border.all(color: Colors.red.shade200),

                ),

                child: Column(

                  children: [

                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),

                    const SizedBox(height: 8),

                    Text("Error loading faculty: $_error", style: const TextStyle(color: Colors.red)),

                    const SizedBox(height: 12),

                    ElevatedButton(

                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),

                      onPressed: _fetchFaculty,

                      child: const Text("Retry"),

                    ),

                  ],

                ),

              )

            else if (filtered.isEmpty)

              Container(

                width: double.infinity,

                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),

                decoration: BoxDecoration(

                  color: Colors.white,

                  borderRadius: BorderRadius.circular(12),

                  border: Border.all(color: const Color(0xFFE2E8F0)),

                ),

                child: Column(

                  children: const [

                    Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),

                    SizedBox(height: 12),

                    Text(

                      "No Faculty Records Found",

                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),

                    ),

                    SizedBox(height: 4),

                    Text(

                      "Try adjusting your department filter, status, or search terms.",

                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),

                    ),

                  ],

                ),

              )

            else

              ListView.separated(

                shrinkWrap: true,

                physics: const NeverScrollableScrollPhysics(),

                itemCount: pagedList.length,

                separatorBuilder: (ctx, i) => const SizedBox(height: 12),

                itemBuilder: (ctx, index) {

                  return _buildFacultyCard(pagedList[index]);

                },

              ),

            const SizedBox(height: 16),

            // Pagination Bar

            if (!_isLoading && filtered.isNotEmpty)

              AppPaginationBar(

                currentPage: safePage,

                totalPages: totalPages,

                totalItems: totalItems,

                pageSize: _pageSize,

                activeColor: const Color(0xFF13246E),

                onPageChanged: (newPage) {

                  setState(() {

                    _currentPage = newPage;

                  });

                },

              ),

          ],

        ),

      ),

    );

  }

  Widget _buildHeroBanner() {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),

      decoration: BoxDecoration(

        gradient: const LinearGradient(

          colors: [Color(0xFFEBF3FE), Color(0xFFE0EDFC)],

          begin: Alignment.topLeft,

          end: Alignment.bottomRight,

        ),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: const Color(0xFFD6E6F9)),

      ),

      child: LayoutBuilder(

        builder: (context, constraints) {

          final isWide = constraints.maxWidth > 650;

          return Row(

            children: [

              Container(

                padding: const EdgeInsets.all(12),

                decoration: const BoxDecoration(

                  color: Color(0xFFD0E2F9),

                  shape: BoxShape.circle,

                ),

                child: const Icon(

                  Icons.people_alt_rounded,

                  size: 26,

                  color: Color(0xFF13246E),

                ),

              ),

              const SizedBox(width: 16),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: const [

                    Text(

                      "Faculty Directory",

                      style: TextStyle(

                        fontSize: 19,

                        fontWeight: FontWeight.bold,

                        color: Color(0xFF0F172A),

                      ),

                    ),

                    SizedBox(height: 4),

                    Text(

                      "View and manage faculty members, their departments, and details.",

                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),

                    ),

                  ],

                ),

              ),

              if (isWide)

                Opacity(

                  opacity: 0.8,

                  child: Row(

                    mainAxisSize: MainAxisSize.min,

                    children: [

                      Icon(Icons.person_outline_rounded, size: 40, color: Colors.blue.shade300),

                      Transform.translate(

                        offset: const Offset(-8, -4),

                        child: Icon(Icons.person_rounded, size: 54, color: const Color(0xFF13246E).withValues(alpha: 0.8)),

                      ),

                      Transform.translate(

                        offset: const Offset(-16, 0),

                        child: Icon(Icons.person_outline_rounded, size: 40, color: Colors.blue.shade300),

                      ),

                    ],

                  ),

                ),

            ],

          );

        },

      ),

    );

  }

  Widget _buildFilterBar() {

    final canRegister = _userRole == AppRoles.admission ||

        _userRole == AppRoles.principal ||

        _userRole == AppRoles.system ||

        _userRole == AppRoles.hod;

    return LayoutBuilder(

      builder: (context, constraints) {

        final isMobile = constraints.maxWidth < 950;

        // Search Input Widget

        final searchWidget = TextField(

          controller: _searchController,

          decoration: InputDecoration(

            hintText: "Search faculty by name, department, or employee ID...",

            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),

            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),

            filled: true,

            fillColor: Colors.white,

            isDense: true,

            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),

            border: OutlineInputBorder(

              borderRadius: BorderRadius.circular(10),

              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),

            ),

            enabledBorder: OutlineInputBorder(

              borderRadius: BorderRadius.circular(10),

              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),

            ),

            focusedBorder: OutlineInputBorder(

              borderRadius: BorderRadius.circular(10),

              borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5),

            ),

          ),

          onChanged: (val) {

            setState(() {

              _searchQuery = val.trim();

              _currentPage = 1;

            });

          },

        );

        final bool isHodUser = _userRole == 'HOD';

        // Faculty Type Dropdown
        final facultyTypeDropdown = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFacultyType,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.badge_outlined, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Text("All Faculty Types", style: TextStyle(fontSize: 13, color: Color(0xFF334155))),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'regular',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_rounded, size: 16, color: Color(0xFF13246E)),
                      SizedBox(width: 8),
                      Text("Regular Faculty", style: TextStyle(fontSize: 13, color: Color(0xFF13246E))),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'guest',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_rounded, size: 16, color: Color(0xFF7C3AED)),
                      SizedBox(width: 8),
                      Text("Guest Faculty", style: TextStyle(fontSize: 13, color: Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedFacultyType = val;
                    _currentPage = 1;
                  });
                }
              },
            ),
          ),
        );

        // Department Dropdown

        final departmentDropdown = Container(

          padding: const EdgeInsets.symmetric(horizontal: 12),

          decoration: BoxDecoration(

            color: Colors.white,

            borderRadius: BorderRadius.circular(10),

            border: Border.all(color: const Color(0xFFE2E8F0)),

          ),

          child: DropdownButtonHideUnderline(

            child: DropdownButton<String?>(

              value: _selectedDepartment,

              isDense: true,

              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),

              hint: Row(

                mainAxisSize: MainAxisSize.min,

                children: const [

                  Icon(Icons.account_balance_outlined, size: 16, color: Color(0xFF64748B)),

                  SizedBox(width: 8),

                  Text("All Departments", style: TextStyle(fontSize: 13, color: Color(0xFF334155))),

                ],

              ),

              items: [

                DropdownMenuItem<String?>(

                  value: 'all',

                  child: Row(

                    mainAxisSize: MainAxisSize.min,

                    children: const [

                      Icon(Icons.account_balance_outlined, size: 16, color: Color(0xFF64748B)),

                      SizedBox(width: 8),

                      Text("All Departments", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),

                    ],

                  ),

                ),

                ..._departments.map(

                  (d) => DropdownMenuItem<String?>(

                    value: d.name,

                    child: Row(

                      mainAxisSize: MainAxisSize.min,

                      children: [

                        const Icon(Icons.account_balance_outlined, size: 16, color: Color(0xFF64748B)),

                        const SizedBox(width: 8),

                        Text(d.name, style: const TextStyle(fontSize: 13)),

                      ],

                    ),

                  ),

                ),

              ],

              onChanged: (val) {

                setState(() {

                  _selectedDepartment = val;

                  _currentPage = 1;

                });

              },

            ),

          ),

        );

        // Status Dropdown

        final statusDropdown = Container(

          padding: const EdgeInsets.symmetric(horizontal: 12),

          decoration: BoxDecoration(

            color: Colors.white,

            borderRadius: BorderRadius.circular(10),

            border: Border.all(color: const Color(0xFFE2E8F0)),

          ),

          child: DropdownButtonHideUnderline(

            child: DropdownButton<String>(

              value: _selectedStatus,

              isDense: true,

              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),

              items: [

                DropdownMenuItem(

                  value: 'all',

                  child: Row(

                    mainAxisSize: MainAxisSize.min,

                    children: const [

                      Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF64748B)),

                      SizedBox(width: 8),

                      Text("All Status", style: TextStyle(fontSize: 13, color: Color(0xFF334155))),

                    ],

                  ),

                ),

                DropdownMenuItem(

                  value: 'approved',

                  child: Row(

                    mainAxisSize: MainAxisSize.min,

                    children: const [

                      Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),

                      SizedBox(width: 8),

                      Text("Approved", style: TextStyle(fontSize: 13, color: Color(0xFF16A34A))),

                    ],

                  ),

                ),

                DropdownMenuItem(

                  value: 'pending_office',

                  child: Row(

                    mainAxisSize: MainAxisSize.min,

                    children: const [

                      Icon(Icons.access_time_rounded, size: 16, color: Color(0xFFD97706)),

                      SizedBox(width: 8),

                      Text("Pending Office", style: TextStyle(fontSize: 13, color: Color(0xFFD97706))),

                    ],

                  ),

                ),

                DropdownMenuItem(

                  value: 'rejected',

                  child: Row(

                    mainAxisSize: MainAxisSize.min,

                    children: const [

                      Icon(Icons.cancel_outlined, size: 16, color: Colors.red),

                      SizedBox(width: 8),

                      Text("Rejected", style: TextStyle(fontSize: 13, color: Colors.red)),

                    ],

                  ),

                ),

              ],

              onChanged: (val) {

                if (val != null) {

                  setState(() {

                    _selectedStatus = val;

                    _currentPage = 1;

                  });

                }

              },

            ),

          ),

        );

        // Sort Dropdown

        final sortDropdown = Container(

          padding: const EdgeInsets.symmetric(horizontal: 12),

          decoration: BoxDecoration(

            color: Colors.white,

            borderRadius: BorderRadius.circular(10),

            border: Border.all(color: const Color(0xFFE2E8F0)),

          ),

          child: DropdownButtonHideUnderline(

            child: DropdownButton<String>(

              value: _selectedSort,

              isDense: true,

              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),

              items: const [

                DropdownMenuItem(

                  value: 'name',

                  child: Row(

                    mainAxisSize: MainAxisSize.min,

                    children: [

                      Icon(Icons.swap_vert_rounded, size: 16, color: Color(0xFF64748B)),

                      SizedBox(width: 8),

                      Text("Sort by Name", style: TextStyle(fontSize: 13, color: Color(0xFF334155))),

                    ],

                  ),

                ),

                DropdownMenuItem(

                  value: 'id',

                  child: Row(

                    mainAxisSize: MainAxisSize.min,

                    children: [

                      Icon(Icons.swap_vert_rounded, size: 16, color: Color(0xFF64748B)),

                      SizedBox(width: 8),

                      Text("Sort by ID", style: TextStyle(fontSize: 13, color: Color(0xFF334155))),

                    ],

                  ),

                ),

                DropdownMenuItem(

                  value: 'department',

                  child: Row(

                    mainAxisSize: MainAxisSize.min,

                    children: [

                      Icon(Icons.swap_vert_rounded, size: 16, color: Color(0xFF64748B)),

                      SizedBox(width: 8),

                      Text("Sort by Dept", style: TextStyle(fontSize: 13, color: Color(0xFF334155))),

                    ],

                  ),

                ),

              ],

              onChanged: (val) {

                if (val != null) {

                  setState(() {

                    _selectedSort = val;

                  });

                }

              },

            ),

          ),

        );

        // Register Button

        final registerButton = ElevatedButton.icon(

          style: ElevatedButton.styleFrom(

            backgroundColor: const Color(0xFF13246E),

            foregroundColor: Colors.white,

            elevation: 0,

            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),

            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

          ),

          icon: const Icon(Icons.add, size: 16, color: Colors.white),

          label: const Text(

            "Register New Faculty",

            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),

          ),

          onPressed: canRegister

              ? () => context.push('/faculty/register').then((_) => _fetchFaculty())

              : null,

        );

        if (isMobile) {

          return Column(

            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [

              searchWidget,

              const SizedBox(height: 10),

              Wrap(

                spacing: 10,

                runSpacing: 10,

                alignment: WrapAlignment.start,

                crossAxisAlignment: WrapCrossAlignment.center,

                children: [
                  if (!isHodUser) departmentDropdown,
                  facultyTypeDropdown,
                  statusDropdown,
                  sortDropdown,
                  if (canRegister) registerButton,
                ],

              ),

            ],

          );

        } else {

          return Row(

            children: [
              Expanded(child: searchWidget),
              if (!isHodUser) ...[
                const SizedBox(width: 10),
                departmentDropdown,
              ],
              const SizedBox(width: 10),
              facultyTypeDropdown,
              const SizedBox(width: 10),
              statusDropdown,
              const SizedBox(width: 10),
              sortDropdown,
              if (canRegister) ...[
                const SizedBox(width: 10),
                registerButton,
              ],
            ],

          );

        }

      },

    );

  }

  Color _getAvatarBg(String name) {

    final upper = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    final code = upper.codeUnitAt(0);

    final bgs = [

      const Color(0xFFE0F2FE), // Blue

      const Color(0xFFF3E8FF), // Purple

      const Color(0xFFDCFCE7), // Green

      const Color(0xFFFEF3C7), // Amber

      const Color(0xFFFCE7F3), // Pink

      const Color(0xFFF1F5F9), // Slate

    ];

    return bgs[code % bgs.length];

  }

  Color _getAvatarTextColor(String name) {

    final upper = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    final code = upper.codeUnitAt(0);

    final texts = [

      const Color(0xFF0284C7),

      const Color(0xFF7E22CE),

      const Color(0xFF15803D),

      const Color(0xFFD97706),

      const Color(0xFFBE185D),

      const Color(0xFF334155),

    ];

    return texts[code % texts.length];

  }

  Widget _buildFacultyCard(Faculty item) {

    final isApproved = item.status.toLowerCase() == 'approved';

    final isRejected = item.status.toLowerCase() == 'rejected';

    // Status pill colors (Image 1)

    Color statusBg = const Color(0xFFFEF3C7);

    Color statusText = const Color(0xFFD97706);

    IconData statusIcon = Icons.access_time_rounded;

    String statusLabel = "PENDING OFFICE";

    if (isApproved) {

      statusBg = const Color(0xFFDCFCE7);

      statusText = const Color(0xFF15803D);

      statusIcon = Icons.check_circle_rounded;

      statusLabel = "APPROVED";

    } else if (isRejected) {

      statusBg = const Color(0xFFFEE2E2);

      statusText = const Color(0xFFDC2626);

      statusIcon = Icons.cancel_rounded;

      statusLabel = "REJECTED";

    } else if (item.status.toLowerCase().contains('principal')) {

      statusLabel = "PENDING PRINCIPAL";

    }

    final roleLabel = item.isGuestFaculty

        ? "Guest Faculty"

        : (item.role.isNotEmpty ? item.role : "Professor");

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: const Color(0xFFE2E8F0)),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withValues(alpha: 0.02),

            blurRadius: 6,

            offset: const Offset(0, 2),

          ),

        ],

      ),

      child: LayoutBuilder(

        builder: (context, constraints) {

          final isWide = constraints.maxWidth > 750;

          final avatarWidget = CircleAvatar(

            radius: 22,

            backgroundColor: _getAvatarBg(item.name),

            backgroundImage: item.photoUrl != null && item.photoUrl!.isNotEmpty

                ? NetworkImage(item.photoUrl!)

                : null,

            child: (item.photoUrl == null || item.photoUrl!.isEmpty)

                ? Text(

                    item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',

                    style: TextStyle(

                      fontWeight: FontWeight.bold,

                      fontSize: 18,

                      color: _getAvatarTextColor(item.name),

                    ),

                  )

                : null,

          );

          final nameSection = Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Row(

                mainAxisSize: MainAxisSize.min,

                children: [

                  Flexible(

                    child: Text(

                      item.name,

                      style: const TextStyle(

                        fontWeight: FontWeight.bold,

                        fontSize: 15,

                        color: Color(0xFF0F172A),

                      ),

                      overflow: TextOverflow.ellipsis,

                    ),

                  ),

                  const SizedBox(width: 8),

                  Container(

                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),

                    decoration: BoxDecoration(

                      color: const Color(0xFFE0F2FE),

                      borderRadius: BorderRadius.circular(12),

                    ),

                    child: Text(

                      roleLabel,

                      style: const TextStyle(

                        color: Color(0xFF0284C7),

                        fontWeight: FontWeight.bold,

                        fontSize: 11,

                      ),

                    ),

                  ),

                ],

              ),

              const SizedBox(height: 5),

              Row(

                mainAxisSize: MainAxisSize.min,

                children: [

                  const Icon(Icons.account_balance_outlined, size: 14, color: Color(0xFF64748B)),

                  const SizedBox(width: 6),

                  Flexible(

                    child: Text(

                      item.department,

                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),

                      overflow: TextOverflow.ellipsis,

                    ),

                  ),

                ],

              ),

              const SizedBox(height: 2),

              Text(
                "Employee ID: ${item.facultyId}",
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              Builder(
                builder: (context) {
                  final isCompleted = item.passwordSetupStatus == "Password Reset Completed" ||
                      item.passwordSetupCompletedAt != null;

                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCompleted ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isCompleted ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isCompleted ? Icons.check_circle_outline_rounded : Icons.pending_actions_rounded,
                                size: 13,
                                color: isCompleted ? const Color(0xFF047857) : const Color(0xFFB45309),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isCompleted ? "Password Reset Completed" : "Password Setup Pending",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted ? const Color(0xFF065F46) : const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isCompleted && item.tempPassword != null && item.tempPassword!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.key_rounded, size: 13, color: Color(0xFF475569)),
                                const SizedBox(width: 4),
                                Text(
                                  "Temp Pwd: ${item.tempPassword}",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: item.tempPassword!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Temporary password copied to clipboard!"),
                                        backgroundColor: Color(0xFF13246E),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: const Tooltip(
                                    message: "Copy Temporary Password",
                                    child: Icon(Icons.copy_rounded, size: 13, color: Color(0xFF475569)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

            ],

          );

          final contactSection = Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              Row(

                mainAxisSize: MainAxisSize.min,

                children: [

                  const Icon(Icons.mail_outline_rounded, size: 14, color: Color(0xFF64748B)),

                  const SizedBox(width: 6),

                  Flexible(

                    child: Text(

                      item.email,

                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),

                      overflow: TextOverflow.ellipsis,

                    ),

                  ),

                ],

              ),

              const SizedBox(height: 4),

              Row(

                mainAxisSize: MainAxisSize.min,

                children: [

                  const Icon(Icons.call_outlined, size: 14, color: Color(0xFF64748B)),

                  const SizedBox(width: 6),

                  Text(

                    item.phone,

                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),

                  ),

                ],

              ),

            ],

          );

          final statusBadge = Container(

            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),

            decoration: BoxDecoration(

              color: statusBg,

              borderRadius: BorderRadius.circular(16),

            ),

            child: Row(

              mainAxisSize: MainAxisSize.min,

              children: [

                Icon(statusIcon, size: 13, color: statusText),

                const SizedBox(width: 5),

                Text(

                  statusLabel,

                  style: TextStyle(

                    fontSize: 11,

                    fontWeight: FontWeight.bold,

                    color: statusText,

                    letterSpacing: 0.2,

                  ),

                ),

              ],

            ),

          );

          final actionButtons = Row(

            mainAxisSize: MainAxisSize.min,

            children: [
              // Edit button

              InkWell(

                onTap: () => EditFacultyDialog.show(context, item).then((_) => _fetchFaculty()),

                borderRadius: BorderRadius.circular(8),

                child: Container(

                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),

                  decoration: BoxDecoration(

                    color: const Color(0xFFF1F5F9),

                    borderRadius: BorderRadius.circular(8),

                    border: Border.all(color: const Color(0xFFE2E8F0)),

                  ),

                  child: Row(

                    mainAxisSize: MainAxisSize.min,

                    children: const [

                      Icon(Icons.edit_outlined, size: 14, color: Color(0xFF334155)),

                      SizedBox(width: 4),

                      Text("Edit", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),

                    ],

                  ),

                ),

              ),

              const SizedBox(width: 8),

              // View > button

              InkWell(

                onTap: () => context.push('/faculty/detail/${item.id}'),

                borderRadius: BorderRadius.circular(8),

                child: Container(

                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),

                  decoration: BoxDecoration(

                    color: const Color(0xFFEFF6FF),

                    borderRadius: BorderRadius.circular(8),

                    border: Border.all(color: const Color(0xFFBFDBFE)),

                  ),

                  child: Row(

                    mainAxisSize: MainAxisSize.min,

                    children: const [

                      Text("View", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),

                      SizedBox(width: 2),

                      Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF1D4ED8)),

                    ],

                  ),

                ),

              ),

            ],

          );

          if (isWide) {

            return Row(

              children: [

                avatarWidget,

                const SizedBox(width: 14),

                Expanded(flex: 3, child: nameSection),

                const SizedBox(width: 14),

                Expanded(flex: 2, child: contactSection),

                const SizedBox(width: 14),

                statusBadge,

                const SizedBox(width: 16),

                actionButtons,

              ],

            );

          } else {

            return Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Row(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    avatarWidget,

                    const SizedBox(width: 12),

                    Expanded(child: nameSection),

                    statusBadge,

                  ],

                ),

                const SizedBox(height: 10),

                const Divider(height: 1),

                const SizedBox(height: 8),

                Row(

                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [

                    Expanded(child: contactSection),

                    actionButtons,

                  ],

                ),

              ],

            );

          }

        },

      ),

    );

  }

}

