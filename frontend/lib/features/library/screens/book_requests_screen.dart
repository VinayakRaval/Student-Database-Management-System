import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/api_client.dart';

class BookRequestsScreen extends StatefulWidget {
  const BookRequestsScreen({super.key});

  @override
  State<BookRequestsScreen> createState() => _BookRequestsScreenState();
}

class _BookRequestsScreenState extends State<BookRequestsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _requests = [];

  // Filter state
  String _searchQuery = '';
  String _typeFilter = 'ALL'; // ALL, STUDENT, FACULTY
  String _selectedStatus = 'ALL';
  String _selectedDepartment = 'All Departments';
  String _selectedSemester = 'All Semesters';

  final List<String> _departments = [
    'All Departments',
    'Computer Science and Engineering',
    'Electronics and Communication Engineering',
    'Civil Engineering',
    'Mechanical Engineering',
  ];

  final List<String> _semesters = [
    'All Semesters',
    'Semester 1',
    'Semester 2',
    'Semester 3',
    'Semester 4',
    'Semester 5',
    'Semester 6',
    'Semester 7',
    'Semester 8',
  ];

  final List<String> _statusFilters = [
    'ALL',
    'PENDING',
    'VERIFIED',
    'APPROVED',
    'PURCHASED',
    'REJECTED',
  ];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/requests/');
      final List list = res.data is List ? res.data : (res.data is Map && res.data['results'] is List ? res.data['results'] : []);
      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(list);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load book reservations: $e";
        });
      }
    }
  }

  Future<void> _markReady(int requestId) async {
    try {
      final dio = ApiClient().dio;
      await dio.post('/library/requests/$requestId/mark_ready/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Reservation marked as Ready for Collection! Requester notified."),
            backgroundColor: Color(0xFF059669),
          ),
        );
        _fetchRequests();
      }
    } catch (e) {
      // Fallback to verify
      _verifyRequest(requestId);
    }
  }

  Future<void> _verifyRequest(int requestId) async {
    try {
      final dio = ApiClient().dio;
      await dio.post('/library/requests/$requestId/verify/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request verified and marked Ready for Collection!"),
            backgroundColor: Color(0xFF059669),
          ),
        );
        _fetchRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Action failed: $e"), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _markPurchased(int requestId) async {
    try {
      final dio = ApiClient().dio;
      await dio.post('/library/requests/$requestId/mark_purchased/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Book marked as purchased / received into library stock!"),
            backgroundColor: Color(0xFF059669),
          ),
        );
        _fetchRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Action failed: $e"), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _rejectRequest(int requestId) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Cancel / Reject Reservation"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Provide an optional reason for the requester:"),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: "Cancellation Reason",
                hintText: "e.g. Book currently unavailable or loan quota exceeded",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Keep Reservation")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirm Cancellation"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dio = ApiClient().dio;
        await dio.post('/library/requests/$requestId/reject/', data: {'reason': reasonCtrl.text.trim()});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Reservation cancelled."), backgroundColor: Colors.orange),
          );
          _fetchRequests();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Action failed: $e"), backgroundColor: Colors.red.shade700),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 5 Stat counts for top cards
    final totalCount = _requests.length;
    final pendingCount = _requests.where((r) => (r['status'] ?? '').toString().toUpperCase() == 'PENDING').length;
    final readyCount = _requests.where((r) => ['VERIFIED', 'APPROVED', 'PURCHASED'].contains((r['status'] ?? '').toString().toUpperCase())).length;
    final expiredCount = _requests.where((r) => (r['status'] ?? '').toString().toUpperCase() == 'REJECTED').length;
    final facultyCount = _requests.where((r) => (r['requester_role'] ?? '').toString().toUpperCase() == 'FACULTY').length;

    // Filtered list
    final filtered = _requests.where((r) {
      final title = (r['title'] ?? '').toString().toLowerCase();
      final authors = (r['authors'] ?? '').toString().toLowerCase();
      final requesterName = (r['requester_name'] ?? '').toString().toLowerCase();
      final idNum = (r['requester_id_number'] ?? '').toString().toLowerCase();
      final status = (r['status'] ?? '').toString().toUpperCase();
      final role = (r['requester_role'] ?? 'STUDENT').toString().toUpperCase();
      final dept = (r['requester_department'] ?? 'General').toString();
      final sem = r['requester_semester']?.toString() ?? '';

      final matchesQuery = _searchQuery.isEmpty ||
          title.contains(_searchQuery.toLowerCase()) ||
          authors.contains(_searchQuery.toLowerCase()) ||
          requesterName.contains(_searchQuery.toLowerCase()) ||
          idNum.contains(_searchQuery.toLowerCase()) ||
          dept.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesType = _typeFilter == 'ALL' || role == _typeFilter;

      final matchesStatus = _selectedStatus == 'ALL' ||
          status == _selectedStatus ||
          (_selectedStatus == 'READY' && ['VERIFIED', 'APPROVED', 'PURCHASED'].contains(status));

      final matchesDept = _selectedDepartment == 'All Departments' ||
          dept.toLowerCase().trim() == _selectedDepartment.toLowerCase().trim();

      final matchesSem = role == 'FACULTY' ||
          _typeFilter == 'FACULTY' ||
          _selectedSemester == 'All Semesters' ||
          ("Semester $sem" == _selectedSemester);

      return matchesQuery && matchesType && matchesStatus && matchesDept && matchesSem;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.bookmark_added_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              "Reservations & Hold Queue",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Refresh Reservations",
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchRequests,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF13246E)))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade700),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade800)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                          onPressed: _fetchRequests,
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Top 5 Metric Cards matching prompt requirements
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final isNarrow = constraints.maxWidth < 800;
                          return isNarrow
                              ? SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildStatCard("Total Reservations", totalCount.toString(), Icons.bookmark_rounded, const Color(0xFF13246E)),
                                      const SizedBox(width: 12),
                                      _buildStatCard("Pending", pendingCount.toString(), Icons.hourglass_top_rounded, const Color(0xFFD97706)),
                                      const SizedBox(width: 12),
                                      _buildStatCard("Ready for Collection", readyCount.toString(), Icons.check_circle_rounded, const Color(0xFF059669)),
                                      const SizedBox(width: 12),
                                      _buildStatCard("Expired", expiredCount.toString(), Icons.cancel_rounded, const Color(0xFFDC2626)),
                                      const SizedBox(width: 12),
                                      _buildStatCard("Faculty Reservations", facultyCount.toString(), Icons.school_rounded, const Color(0xFF4F46E5)),
                                    ],
                                  ),
                                )
                              : Row(
                                  children: [
                                    Expanded(child: _buildStatCard("Total Reservations", totalCount.toString(), Icons.bookmark_rounded, const Color(0xFF13246E))),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildStatCard("Pending", pendingCount.toString(), Icons.hourglass_top_rounded, const Color(0xFFD97706))),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildStatCard("Ready for Collection", readyCount.toString(), Icons.check_circle_rounded, const Color(0xFF059669))),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildStatCard("Expired", expiredCount.toString(), Icons.cancel_rounded, const Color(0xFFDC2626))),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildStatCard("Faculty Reservations", facultyCount.toString(), Icons.school_rounded, const Color(0xFF4F46E5))),
                                  ],
                                );
                        },
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Search & Filters matching Borrowers page
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Column(
                        children: [
                          TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: InputDecoration(
                              hintText: "Search reservations by book title, author, requester name, USN, or Staff ID...",
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF13246E)),
                              filled: true,
                              fillColor: const Color(0xFFF1F5F9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Type Pills, Faculty Button, and Dropdowns Row
                          Row(
                            children: [
                              _buildTypeChip('ALL', 'All ($totalCount)'),
                              const SizedBox(width: 8),
                              _buildTypeChip('STUDENT', 'Students (${totalCount - facultyCount})'),
                              const SizedBox(width: 8),
                              // Dedicated Faculty Reservations Button / Chip
                              _buildFacultyButton(facultyCount),
                              const Spacer(),

                              // Status Dropdown Filter
                              SizedBox(
                                width: 150,
                                height: 38,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedStatus,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                    filled: true,
                                    fillColor: const Color(0xFFF1F5F9),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  ),
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                  items: _statusFilters.map((s) => DropdownMenuItem(value: s, child: Text(s == 'ALL' ? 'All Statuses' : s, overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => setState(() => _selectedStatus = v ?? 'ALL'),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Select Department Dropdown Filter
                              SizedBox(
                                width: 200,
                                height: 38,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedDepartment,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                    filled: true,
                                    fillColor: const Color(0xFFF1F5F9),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  ),
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                  items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => setState(() => _selectedDepartment = v ?? 'All Departments'),
                                ),
                              ),
                              // Select Semester Dropdown Filter (Hidden for Faculty Members)
                              if (_typeFilter != 'FACULTY') ...[
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 140,
                                  height: 38,
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedSemester,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                      filled: true,
                                      fillColor: const Color(0xFFF1F5F9),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    ),
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                    items: _semesters.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                                    onChanged: (v) => setState(() => _selectedSemester = v ?? 'All Semesters'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Reservations List matching Borrowers Screen
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bookmark_remove_rounded, size: 56, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text("No book reservations matching your filters.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 6),
                                  Text("Try adjusting your search query or department/semester filters.", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final req = filtered[i];
                                final reqId = req['id'];
                                final status = (req['status'] ?? 'PENDING').toString().toUpperCase();
                                final isFaculty = (req['requester_role'] ?? 'STUDENT').toString().toUpperCase() == 'FACULTY';
                                final queuePos = req['queue_position'] ?? (i + 1);
                                final isReady = ['VERIFIED', 'APPROVED', 'PURCHASED'].contains(status);

                                Color statusColor = const Color(0xFFD97706);
                                Color statusBg = const Color(0xFFFEF3C7);
                                String statusLabel = "PENDING QUEUE";

                                if (isReady) {
                                  statusColor = const Color(0xFF059669);
                                  statusBg = const Color(0xFFD1FAE5);
                                  statusLabel = "READY FOR COLLECTION";
                                } else if (status == 'REJECTED') {
                                  statusColor = const Color(0xFFDC2626);
                                  statusBg = const Color(0xFFFEE2E2);
                                  statusLabel = "EXPIRED / CANCELLED";
                                }

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Leading Avatar (Matching Borrowers Screen)
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: isFaculty ? const Color(0xFF13246E) : const Color(0xFFF7CA18),
                                          foregroundColor: isFaculty ? Colors.white : Colors.brown.shade900,
                                          child: Icon(isFaculty ? Icons.school_rounded : Icons.person_rounded, size: 22),
                                        ),
                                        const SizedBox(width: 14),

                                        // Main Content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Book Title & Badges Row
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      req['title'] ?? 'Book Reservation',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Role Badge
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isFaculty ? Colors.blue.shade50 : Colors.amber.shade50,
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: isFaculty ? Colors.blue.shade200 : Colors.amber.shade300),
                                                    ),
                                                    child: Text(
                                                      isFaculty ? "FACULTY" : "STUDENT",
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: isFaculty ? Colors.blue.shade800 : Colors.amber.shade900,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  // Queue Position Badge
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                                    ),
                                                    child: Text(
                                                      "Queue #$queuePos",
                                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  // Status Pill
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(4)),
                                                    child: Text(
                                                      statusLabel,
                                                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10.5),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),

                                              // Author & Details
                                              Text(
                                                "Author: ${req['authors'] ?? 'General'} • Reserved on: ${req['created_at'] != null ? req['created_at'].toString().split('T').first : 'Recent'}",
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                              ),
                                              const SizedBox(height: 4),

                                              // Requester Info (Name, ID, Department, Semester)
                                              Text(
                                                "Requester: ${req['requester_name'] ?? 'User'} • ID/USN: ${req['requester_id_number'] ?? 'N/A'} • Dept: ${req['requester_department'] ?? 'General'}${req['requester_semester'] != null ? ' • Sem: ${req['requester_semester']}' : ''}",
                                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                              ),
                                              if (req['reason'] != null && req['reason'].toString().isNotEmpty) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  "Purpose: ${req['reason']}",
                                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Actions Column
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            if (status == 'PENDING') ...[
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF13246E),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                ),
                                                onPressed: () => _markReady(reqId),
                                                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                                label: const Text("Mark Ready", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                              ),
                                              const SizedBox(height: 6),
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red.shade700,
                                                  side: BorderSide(color: Colors.red.shade300),
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                ),
                                                onPressed: () => _rejectRequest(reqId),
                                                icon: const Icon(Icons.close_rounded, size: 16),
                                                label: const Text("Cancel", style: TextStyle(fontSize: 12)),
                                              ),
                                            ] else if (isReady) ...[
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF059669),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                ),
                                                onPressed: () {
                                                  context.go('/library/desk');
                                                },
                                                icon: const Icon(Icons.outbox_rounded, size: 16),
                                                label: const Text("Issue Book", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                              ),
                                              if (status == 'APPROVED') ...[
                                                const SizedBox(height: 6),
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF13246E),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                  ),
                                                  onPressed: () => _markPurchased(reqId),
                                                  icon: const Icon(Icons.inventory_2_outlined, size: 16),
                                                  label: const Text("Mark Received", style: TextStyle(fontSize: 12)),
                                                ),
                                              ],
                                              const SizedBox(height: 6),
                                              OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red.shade700,
                                                  side: BorderSide(color: Colors.red.shade200),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                ),
                                                onPressed: () => _rejectRequest(reqId),
                                                child: const Text("Expire Hold", style: TextStyle(fontSize: 11)),
                                              ),
                                            ] else ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                                                child: Text("Reservation Closed", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String key, String label) {
    final isSelected = _typeFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF13246E),
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF334155),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (v) {
        if (v) {
          setState(() {
            _typeFilter = key;
            if (key == 'FACULTY') {
              _selectedSemester = 'All Semesters';
            }
          });
        }
      },
    );
  }

  Widget _buildFacultyButton(int count) {
    final isSelected = _typeFilter == 'FACULTY';
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
        foregroundColor: isSelected ? Colors.white : const Color(0xFF334155),
        elevation: isSelected ? 2 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1)),
        ),
      ),
      onPressed: () {
        setState(() {
          _typeFilter = isSelected ? 'ALL' : 'FACULTY';
          _selectedSemester = 'All Semesters';
        });
      },
      icon: Icon(Icons.school_rounded, size: 16, color: isSelected ? Colors.white : const Color(0xFF4F46E5)),
      label: Text(
        "Faculty Reservations ($count)",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSelected ? Colors.white : const Color(0xFF0F172A)),
      ),
    );
  }
}
