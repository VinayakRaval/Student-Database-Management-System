import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/library/widgets/digital_library_card_widget.dart';

class LibraryCardsDeskScreen extends StatefulWidget {
  const LibraryCardsDeskScreen({super.key});

  @override
  State<LibraryCardsDeskScreen> createState() => _LibraryCardsDeskScreenState();
}

class _LibraryCardsDeskScreenState extends State<LibraryCardsDeskScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _cards = [];
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // ALL, ACTIVE, HOD_APPROVED, PENDING_HOD
  String _borrowerTypeFilter = 'ALL'; // ALL, STUDENT, FACULTY

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

  // Library Configuration status
  bool _configChecking = true;
  bool _isConfigured = true;
  Map<String, dynamic>? _activeConfig;

  @override
  void initState() {
    super.initState();
    _fetchCards();
    _fetchActiveConfig();
  }

  Future<void> _fetchActiveConfig() async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/config/active/');
      if (mounted) {
        setState(() {
          _activeConfig = res.data is Map ? Map<String, dynamic>.from(res.data) : null;
          _isConfigured = _activeConfig != null && (_activeConfig!['is_active'] == true);
          _configChecking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isConfigured = false;
          _configChecking = false;
        });
      }
    }
  }

  Future<void> _fetchCards() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/cards/all_borrowers_directory/');
      final List list = res.data is List
          ? res.data
          : ((res.data is Map && res.data['results'] is List)
              ? res.data['results']
              : []);
      if (mounted) {
        setState(() {
          _cards = List<Map<String, dynamic>>.from(list);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load borrowers & library cards: $e";
        });
      }
    }
  }

  Future<void> _generateAndActivateCard(int cardId, String borrowerName) async {
    if (!_isConfigured) {
      _showMissingConfigAlert();
      return;
    }

    try {
      final dio = ApiClient().dio;
      final res = await dio.post('/library/cards/$cardId/generate_and_activate/');
      final cardNo = res.data['card_number'] ?? 'LC';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Library Card $cardNo successfully generated and activated for $borrowerName!"),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        _fetchCards();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Activation error: $e"), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  void _showMissingConfigAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 10),
            Text("Configuration Required", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          "Library configuration is incomplete. Please configure academic year, borrowing quotas, and rules before generating an issue card.",
          style: TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/library/configuration').then((_) => _fetchActiveConfig());
            },
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: const Text("Go to Configuration"),
          ),
        ],
      ),
    );
  }

  Future<void> _showDigitalCardDialog(Map<String, dynamic> card) async {
    final cardId = card['card_id'] ?? card['id'];
    Map<String, dynamic> resolvedCard = Map<String, dynamic>.from(card);
    if (cardId != null) {
      try {
        final dio = ApiClient().dio;
        final res = await dio.get('/library/cards/$cardId/');
        if (res.data is Map && mounted) {
          resolvedCard = Map<String, dynamic>.from(res.data);
        }
      } catch (_) {}
    }
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DigitalLibraryCardWidget(cardData: resolvedCard),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Sending Library Card ${resolvedCard['card_number'] ?? card['card_number']} to printer..."),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    },
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text("Print / PDF"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13246E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text("Close Card View"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openBorrowerDetailsDialog(Map<String, dynamic> item) {
    final hasCard = item['has_card'] == true;
    final bType = item['borrower_type'] ?? 'STUDENT';
    final isFaculty = bType == 'FACULTY';
    final cardData = item['card_data'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: isFaculty ? const Color(0xFF13246E) : const Color(0xFFF7CA18),
              child: Icon(isFaculty ? Icons.school_rounded : Icons.badge_rounded, color: isFaculty ? Colors.white : Colors.brown.shade900),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'] ?? 'Borrower Details', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("${item['borrower_type']} • ${item['identifier']}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow("Department", (item['department'] ?? item['department_name'] ?? 'Computer Science and Engineering').toString()),
            if (!isFaculty) ...[
              _detailRow("Semester", "Semester ${item['semester'] ?? '1'}"),
              _detailRow("Section", item['section'] ?? 'A'),
            ],
            _detailRow("Active Book Loans", "${item['active_loans_count'] ?? item['active_loans'] ?? 0} books currently issued"),
            _detailRow("Card Status", item['card_status'] ?? 'NO_CARD'),
            if (hasCard && item['card_number'] != null)
              _detailRow("Card Number", item['card_number']),
            if (item['missing_books_count'] != null && (item['missing_books_count'] as int) > 0)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.shade200)),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${item['missing_books_count']} issued books are missing from the library card.",
                        style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
          if (!hasCard)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13246E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/library/cards/create?identifier=${item['identifier']}&borrowerType=${item['borrower_type']}').then((_) => _fetchCards());
              },
              icon: const Icon(Icons.add_card_rounded, size: 18),
              label: const Text("Create Library Issue Card"),
            )
          else ...[
            if (cardData != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF13246E)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showDigitalCardDialog(cardData);
                },
                icon: const Icon(Icons.remove_red_eye_rounded, size: 16),
                label: const Text("View Card"),
              ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13246E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/library/cards/create?cardId=${item['card_id']}&identifier=${item['identifier']}&borrowerType=${item['borrower_type']}').then((_) => _fetchCards());
              },
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text("Edit / Add Books"),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _cards.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final id = (c['identifier'] ?? '').toString().toLowerCase();
      final cardNo = (c['card_number'] ?? '').toString().toLowerCase();
      final status = (c['card_status'] ?? 'NO_CARD').toString().toUpperCase();
      final dept = (c['department'] ?? c['department_name'] ?? 'Computer Science and Engineering').toString();
      final sem = c['semester']?.toString() ?? '';
      final bType = (c['borrower_type'] ?? 'STUDENT').toString().toUpperCase();

      final q = _searchQuery.toLowerCase().trim();
      final matchesQuery = q.isEmpty ||
          name.contains(q) ||
          id.contains(q) ||
          cardNo.contains(q) ||
          dept.toLowerCase().contains(q);

      bool matchesStatus = true;
      if (_statusFilter != 'ALL') {
        if (_statusFilter == 'NEEDS_ATTENTION') {
          matchesStatus = (status == 'NO_CARD') || ((c['missing_books_count'] as int?) ?? 0) > 0;
        } else if (_statusFilter == 'MISSING_BOOKS') {
          matchesStatus = (c['missing_books_count'] != null && (c['missing_books_count'] as int) > 0);
        } else {
          matchesStatus = status == _statusFilter;
        }
      }

      bool matchesType = true;
      if (_borrowerTypeFilter != 'ALL') {
        matchesType = bType == _borrowerTypeFilter;
      }

      bool matchesDept = true;
      if (_selectedDepartment != 'All Departments') {
        matchesDept = dept.trim().toLowerCase() == _selectedDepartment.trim().toLowerCase();
      }

      bool matchesSem = true;
      if (bType != 'FACULTY' && _selectedSemester != 'All Semesters') {
        matchesSem = "Semester $sem" == _selectedSemester || sem == _selectedSemester.replaceAll('Semester ', '');
      }

      return matchesQuery && matchesStatus && matchesType && matchesDept && matchesSem;
    }).toList();

    // Priority Sort:
    // 1. No Card (NO_CARD)
    // 2. Card Not Updated (missing_books_count > 0)
    // 3. Pending HOD Approval (PENDING_HOD)
    // 4. Approved & Active cards
    filtered.sort((a, b) {
      final aNoCard = a['card_status'] == 'NO_CARD';
      final bNoCard = b['card_status'] == 'NO_CARD';
      final aMissing = ((a['missing_books_count'] as int?) ?? 0) > 0;
      final bMissing = ((b['missing_books_count'] as int?) ?? 0) > 0;

      final aNeeds = aNoCard || aMissing;
      final bNeeds = bNoCard || bMissing;

      if (aNeeds && !bNeeds) return -1;
      if (!aNeeds && bNeeds) return 1;

      if (aNoCard && !bNoCard) return -1;
      if (!aNoCard && bNoCard) return 1;

      if (aMissing && !bMissing) return -1;
      if (!aMissing && bMissing) return 1;

      final aPending = a['card_status'] == 'PENDING_HOD';
      final bPending = b['card_status'] == 'PENDING_HOD';
      if (aPending && !bPending) return -1;
      if (!aPending && bPending) return 1;

      return (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase());
    });

    final totalCount = _cards.length;
    final noCardCount = _cards.where((c) => c['card_status'] == 'NO_CARD').length;
    final missingCount = _cards.where((c) => (c['missing_books_count'] != null && (c['missing_books_count'] as int) > 0)).length;
    final needsAttentionCount = _cards.where((c) => c['card_status'] == 'NO_CARD' || ((c['missing_books_count'] as int?) ?? 0) > 0).length;
    final approvedCount = _cards.where((c) => c['card_status'] == 'HOD_APPROVED').length;
    final activeCount = _cards.where((c) => c['card_status'] == 'ACTIVE').length;
    final pendingCount = _cards.where((c) => c['card_status'] == 'PENDING_HOD').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.badge_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              "Library Issue Cards",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF7CA18),
              foregroundColor: const Color(0xFF4A1504),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            icon: const Icon(Icons.add_card_rounded, size: 18),
            label: const Text("+ Create Library Issue Card"),
            onPressed: () {
              if (!_isConfigured) {
                _showMissingConfigAlert();
                return;
              }
              context.push('/library/cards/create').then((_) => _fetchCards());
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: "Refresh Cards",
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              _fetchCards();
              _fetchActiveConfig();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_card_rounded),
        label: const Text("Create Library Issue Card"),
        onPressed: () {
          if (!_isConfigured) {
            _showMissingConfigAlert();
            return;
          }
          context.push('/library/cards/create').then((_) => _fetchCards());
        },
      ),
      body: Column(
        children: [
          // Configuration Warning Banner if config incomplete
          if (!_configChecking && !_isConfigured)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                border: Border(bottom: BorderSide(color: Color(0xFFFCA5A5))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Library configuration is incomplete. Please configure library rules before generating an issue card.",
                      style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => context.push('/library/configuration').then((_) => _fetchActiveConfig()),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text("Configure Rules", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
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
                                onPressed: _fetchCards,
                                child: const Text("Retry"),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          // Search & Filters Bar
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Column(
                              children: [
                                TextField(
                                  onChanged: (v) => setState(() => _searchQuery = v),
                                  decoration: InputDecoration(
                                    hintText: "Search cards by borrower name, USN, Staff ID, or Card No...",
                                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF13246E)),
                                    filled: true,
                                    fillColor: const Color(0xFFF1F5F9),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildBorrowerTypeChip('ALL', 'All ($totalCount)'),
                                      const SizedBox(width: 8),
                                      _buildBorrowerTypeChip('STUDENT', 'Students'),
                                      const SizedBox(width: 8),
                                      _buildBorrowerTypeChip('FACULTY', 'Faculty'),
                                      const SizedBox(width: 14),
                                      Container(height: 24, width: 1, color: const Color(0xFFCBD5E1)),
                                      const SizedBox(width: 14),

                                      // Status dropdown filter
                                      SizedBox(
                                        width: 230,
                                        height: 38,
                                        child: DropdownButtonFormField<String>(
                                          value: _statusFilter,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            prefixIcon: const Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF13246E)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                            filled: true,
                                            fillColor: const Color(0xFFF1F5F9),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(6),
                                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(6),
                                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                            ),
                                          ),
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                          items: [
                                            DropdownMenuItem(
                                              value: 'ALL',
                                              child: Text("All Status ($totalCount)", style: const TextStyle(fontWeight: FontWeight.w600)),
                                            ),
                                            DropdownMenuItem(
                                              value: 'NEEDS_ATTENTION',
                                              child: Text("Needs Card / Update ($needsAttentionCount)", style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                                            ),
                                            DropdownMenuItem(
                                              value: 'NO_CARD',
                                              child: Text("No Card ($noCardCount)"),
                                            ),
                                            DropdownMenuItem(
                                              value: 'MISSING_BOOKS',
                                              child: Text("Missing Books ($missingCount)", style: const TextStyle(color: Color(0xFFD97706))),
                                            ),
                                            DropdownMenuItem(
                                              value: 'PENDING_HOD',
                                              child: Text("Pending HOD ($pendingCount)", style: const TextStyle(color: Color(0xFFEA580C))),
                                            ),
                                            DropdownMenuItem(
                                              value: 'HOD_APPROVED',
                                              child: Text("Approved ($approvedCount)", style: const TextStyle(color: Color(0xFF2563EB))),
                                            ),
                                            DropdownMenuItem(
                                              value: 'ACTIVE',
                                              child: Text("Active ($activeCount)", style: const TextStyle(color: Color(0xFF16A34A))),
                                            ),
                                          ],
                                          onChanged: (v) {
                                            if (v != null) setState(() => _statusFilter = v);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Container(height: 24, width: 1, color: const Color(0xFFCBD5E1)),
                                      const SizedBox(width: 14),

                                      // Department dropdown filter
                                      SizedBox(
                                        width: 220,
                                        height: 38,
                                        child: DropdownButtonFormField<String>(
                                          value: _selectedDepartment,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                            filled: true,
                                            fillColor: const Color(0xFFF1F5F9),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(6),
                                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                            ),
                                          ),
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                          items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
                                          onChanged: (v) => setState(() => _selectedDepartment = v ?? 'All Departments'),
                                        ),
                                      ),

                                      // Semester dropdown filter (only for students)
                                      if (_borrowerTypeFilter != 'FACULTY') ...[
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
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(6),
                                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                              ),
                                            ),
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                            items: _semesters.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                                            onChanged: (v) => setState(() => _selectedSemester = v ?? 'All Semesters'),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),

                          // Cards List
                          Expanded(
                            child: filtered.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.badge_outlined, size: 56, color: Colors.grey.shade400),
                                        const SizedBox(height: 12),
                                        const Text("No library card records found.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 6),
                                        const Text("Use '+ Create Library Issue Card' to issue a new card."),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(20),
                                    itemCount: filtered.length,
                                    itemBuilder: (ctx, i) {
                                      final item = filtered[i];
                                      final isFaculty = (item['borrower_type'] ?? 'STUDENT').toString().toUpperCase() == 'FACULTY';
                                      final hasCard = item['has_card'] == true;
                                      final status = (item['card_status'] ?? 'NO_CARD').toString().toUpperCase();
                                      final isApproved = status == 'HOD_APPROVED';
                                      final isActive = status == 'ACTIVE';
                                      final isNoCard = status == 'NO_CARD';
                                      final missingCount = (item['missing_books_count'] as int?) ?? 0;

                                      Color statusColor = Colors.orange.shade700;
                                      Color statusBg = Colors.orange.shade50;
                                      String statusDisplay = status;

                                      if (isNoCard) {
                                        statusColor = Colors.grey.shade700;
                                        statusBg = Colors.grey.shade100;
                                        statusDisplay = "NO CARD";
                                      } else if (isActive) {
                                        statusColor = const Color(0xFF059669);
                                        statusBg = Colors.green.shade50;
                                      } else if (isApproved) {
                                        statusColor = Colors.blue.shade700;
                                        statusBg = Colors.blue.shade50;
                                      } else if (status == 'REJECTED') {
                                        statusColor = Colors.red.shade700;
                                        statusBg = Colors.red.shade50;
                                      }

                                      final borrowerName = item['name'] ?? 'Borrower';
                                      final borrowerId = item['identifier'] ?? '';

                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 14),
                                        elevation: 1,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(color: isNoCard ? const Color(0xFFE2E8F0) : (missingCount > 0 ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0))),
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: () => _openBorrowerDetailsDialog(item),
                                          child: Padding(
                                            padding: const EdgeInsets.all(18),
                                            child: Row(
                                              children: [
                                                // Left Icon
                                                CircleAvatar(
                                                  radius: 22,
                                                  backgroundColor: isFaculty ? const Color(0xFF13246E) : const Color(0xFFF7CA18),
                                                  child: Icon(
                                                    isFaculty ? Icons.school_rounded : Icons.badge_rounded,
                                                    color: isFaculty ? Colors.white : Colors.brown.shade900,
                                                    size: 24,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),

                                                // Details
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          InkWell(
                                                            onTap: () {
                                                              if (!_isConfigured) {
                                                                _showMissingConfigAlert();
                                                                return;
                                                              }
                                                              context.push('/library/cards/create?identifier=${item['identifier']}&borrowerType=${item['borrower_type']}').then((_) => _fetchCards());
                                                            },
                                                            borderRadius: BorderRadius.circular(4),
                                                            child: Tooltip(
                                                              message: isNoCard
                                                                  ? "Click to create library issue card for $borrowerName"
                                                                  : (missingCount > 0
                                                                      ? "Click to update card & add missing books for $borrowerName"
                                                                      : "Click to manage library card for $borrowerName"),
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Text(
                                                                    borrowerName,
                                                                    style: const TextStyle(
                                                                      fontWeight: FontWeight.bold,
                                                                      fontSize: 16,
                                                                      color: Color(0xFF13246E),
                                                                      decoration: TextDecoration.underline,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 5),
                                                                  Icon(
                                                                    isNoCard ? Icons.add_card_rounded : (missingCount > 0 ? Icons.notification_important_rounded : Icons.open_in_new_rounded),
                                                                    size: 15,
                                                                    color: isNoCard ? const Color(0xFF13246E) : (missingCount > 0 ? const Color(0xFFD97706) : const Color(0xFF13246E)),
                                                                  ),
                                                                ],
                                                             ),
                                                            ),
                                                          ),
                                                          if (borrowerId.isNotEmpty)
                                                            Text(
                                                              " ($borrowerId)",
                                                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                                            ),
                                                          const SizedBox(width: 8),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: isFaculty ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                                                              borderRadius: BorderRadius.circular(4),
                                                              border: Border.all(
                                                                color: isFaculty ? const Color(0xFF93C5FD) : const Color(0xFFFDE68A),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              isFaculty ? "FACULTY" : "STUDENT",
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                                color: isFaculty ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                                                              ),
                                                            ),
                                                          ),
                                                          const Spacer(),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                                            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
                                                            child: Text(
                                                              statusDisplay,
                                                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      if (isFaculty)
                                                        Text(
                                                          "Dept: ${item['department'] ?? item['department_name'] ?? 'Computer Science and Engineering'} • Active Loans: ${item['active_loans_count'] ?? item['active_loans'] ?? 0} books • Academic Year: 2025-2026",
                                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                                        )
                                                      else
                                                        Text(
                                                          "Dept: ${item['department'] ?? item['department_name'] ?? 'Computer Science and Engineering'} • Sem: ${item['semester'] ?? '1'} • Sec: ${item['section'] ?? 'A'} • Active Loans: ${item['active_loans_count'] ?? item['active_loans'] ?? 0} books",
                                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                                        ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          if (item['card_number'] != null) ...[
                                                            Text(
                                                              "Card No: ${item['card_number']}  •  ",
                                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                                                            ),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: Colors.green.shade50,
                                                                borderRadius: BorderRadius.circular(4),
                                                                border: Border.all(color: Colors.green.shade200),
                                                              ),
                                                              child: Text(
                                                                "FREE BORROWING (₹0)",
                                                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                                              ),
                                                            ),
                                                          ] else ...[
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: Colors.grey.shade100,
                                                                borderRadius: BorderRadius.circular(4),
                                                                border: Border.all(color: Colors.grey.shade300),
                                                              ),
                                                              child: Text(
                                                                "No library issue card registered",
                                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                                                              ),
                                                            ),
                                                          ],
                                                          if (missingCount > 0) ...[
                                                            const SizedBox(width: 8),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFFFFBEB),
                                                                borderRadius: BorderRadius.circular(4),
                                                                border: Border.all(color: const Color(0xFFFDE68A)),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  const Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFD97706)),
                                                                  const SizedBox(width: 4),
                                                                  Text(
                                                                    "$missingCount Missing Book(s) Not on Card",
                                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 16),

                                                // Actions: Create Card / View Card / Edit / Print
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (!hasCard) ...[
                                                      ElevatedButton.icon(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFF13246E),
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                        ),
                                                        onPressed: () {
                                                          if (!_isConfigured) {
                                                            _showMissingConfigAlert();
                                                            return;
                                                          }
                                                          context.push('/library/cards/create?identifier=${item['identifier']}&borrowerType=${item['borrower_type']}').then((_) => _fetchCards());
                                                        },
                                                        icon: const Icon(Icons.add_card_rounded, size: 16),
                                                        label: const Text("Create Library Issue Card", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                      ),
                                                    ] else ...[
                                                      if (isApproved && !isFaculty) ...[
                                                        ElevatedButton.icon(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: const Color(0xFF059669),
                                                            foregroundColor: Colors.white,
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                          ),
                                                          onPressed: () => _generateAndActivateCard(item['card_id'], borrowerName),
                                                          icon: const Icon(Icons.verified_rounded, size: 16),
                                                          label: const Text("Generate Card", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                        ),
                                                        const SizedBox(width: 8),
                                                      ],
                                                      ElevatedButton.icon(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFFF7CA18),
                                                          foregroundColor: const Color(0xFF4A1504),
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                        ),
                                                        onPressed: () => _showDigitalCardDialog(item['card_data'] ?? item),
                                                        icon: const Icon(Icons.remove_red_eye_rounded, size: 16),
                                                        label: const Text("View Card", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      OutlinedButton.icon(
                                                        style: OutlinedButton.styleFrom(
                                                          foregroundColor: const Color(0xFF13246E),
                                                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                        ),
                                                        onPressed: () {
                                                          context.push('/library/cards/create?id=${item['card_id']}&identifier=${item['identifier']}&borrowerType=${item['borrower_type']}').then((_) => _fetchCards());
                                                        },
                                                        icon: Icon(missingCount > 0 ? Icons.add_rounded : Icons.edit_outlined, size: 16),
                                                        label: Text(missingCount > 0 ? "Add Missing Books" : "Edit", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      IconButton(
                                                        tooltip: "Print / PDF",
                                                        icon: const Icon(Icons.print_outlined, color: Color(0xFF059669), size: 20),
                                                        onPressed: () => _showDigitalCardDialog(item['card_data'] ?? item),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorrowerTypeChip(String key, String label) {
    final isSelected = _borrowerTypeFilter == key;
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
            _borrowerTypeFilter = key;
            if (key == 'FACULTY') {
              _selectedSemester = 'All Semesters';
            }
          });
        }
      },
    );
  }
}
