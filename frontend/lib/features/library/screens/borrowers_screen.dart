import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/library/widgets/digital_library_card_widget.dart';

class BorrowersScreen extends StatefulWidget {
  const BorrowersScreen({super.key});

  @override
  State<BorrowersScreen> createState() => _BorrowersScreenState();
}

class _BorrowersScreenState extends State<BorrowersScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _borrowers = [];
  String _searchQuery = '';
  String _typeFilter = 'ALL'; // ALL, STUDENT, FACULTY

  // Dropdown filters requested in Image 3
  String _selectedSemester = 'All Semesters';
  String _selectedDepartment = 'All Departments';

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

  @override
  void initState() {
    super.initState();
    _fetchBorrowers();
  }

  Future<void> _fetchBorrowers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/cards/borrowers_list/');
      final List list = res.data is List ? res.data : [];
      if (mounted) {
        setState(() {
          _borrowers = List<Map<String, dynamic>>.from(list);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load borrowers: $e";
        });
      }
    }
  }

  void _showCard(Map<String, dynamic> card) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DigitalLibraryCardWidget(cardData: card),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text("Close Card View"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _borrowers.where((b) {
      final name = (b['borrower_name'] ?? b['student_name'] ?? '').toString().toLowerCase();
      final idNum = (b['borrower_id_number'] ?? b['student_usn'] ?? '').toString().toLowerCase();
      final cardNo = (b['card_number'] ?? '').toString().toLowerCase();
      final dept = (b['department_name'] ?? '').toString();
      final bType = (b['borrower_type'] ?? 'STUDENT').toString().toUpperCase();
      final sem = b['semester']?.toString() ?? '';

      final matchesQuery = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          idNum.contains(_searchQuery.toLowerCase()) ||
          cardNo.contains(_searchQuery.toLowerCase()) ||
          dept.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesType = _typeFilter == 'ALL' || bType == _typeFilter;

      final matchesDept = _selectedDepartment == 'All Departments' ||
          dept.toLowerCase().trim() == _selectedDepartment.toLowerCase().trim();

      final matchesSem = bType == 'FACULTY' ||
          _typeFilter == 'FACULTY' ||
          _selectedSemester == 'All Semesters' ||
          ("Semester $sem" == _selectedSemester);

      return matchesQuery && matchesType && matchesDept && matchesSem;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.people_alt_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              "Library Borrowers Directory",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Refresh Borrowers",
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchBorrowers,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF13246E)))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade700),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                        onPressed: _fetchBorrowers,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Search & Filters matching Image 3
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        children: [
                          TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: InputDecoration(
                              hintText: "Search borrowers by Name, USN, Staff ID, or Card Number...",
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF13246E)),
                              filled: true,
                              fillColor: const Color(0xFFF1F5F9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Type Pills and Dropdowns Row
                          Row(
                            children: [
                              _buildTypeChip('ALL', 'All Borrowers (${_borrowers.length})'),
                              const SizedBox(width: 8),
                              _buildTypeChip('STUDENT', 'Students'),
                              const SizedBox(width: 8),
                              _buildTypeChip('FACULTY', 'Faculty Members'),
                              const Spacer(),

                              // Select Department Dropdown Filter
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

                    // Borrower Cards List matching Image 3
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_off_rounded, size: 56, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text("No active borrowers matching your filters.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final b = filtered[i];
                                final isFaculty = (b['borrower_type'] ?? 'STUDENT').toString().toUpperCase() == 'FACULTY';
                                final cardNo = b['card_number'] ?? 'Unissued';
                                final name = b['borrower_name'] ?? b['student_name'] ?? 'Borrower';
                                final idNum = b['borrower_id_number'] ?? b['student_usn'] ?? 'N/A';
                                final dept = b['department_name'] ?? 'General';
                                final status = b['status'] ?? 'ACTIVE';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      radius: 22,
                                      backgroundColor: isFaculty ? const Color(0xFF13246E) : const Color(0xFFF7CA18),
                                      foregroundColor: isFaculty ? Colors.white : Colors.brown.shade900,
                                      child: Icon(isFaculty ? Icons.school_rounded : Icons.person_rounded, size: 22),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(width: 8),
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
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "ID / USN: $idNum • Dept: $dept${b['semester'] != null ? ' • Sem: ${b['semester']}' : ''}",
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "Card No: $cardNo • Status: $status • Free Borrowing Eligible",
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF13246E),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      onPressed: () => _showCard(b),
                                      icon: const Icon(Icons.badge_rounded, size: 16),
                                      label: const Text("View Card", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
}
