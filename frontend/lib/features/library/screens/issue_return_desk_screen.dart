import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

class IssueReturnDeskScreen extends StatefulWidget {
  final int? preselectedBookId;
  const IssueReturnDeskScreen({super.key, this.preselectedBookId});

  @override
  State<IssueReturnDeskScreen> createState() => _IssueReturnDeskScreenState();
}

class _IssueReturnDeskScreenState extends State<IssueReturnDeskScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Configuration
  Map<String, dynamic>? _libraryConfig;
  int _studentLoanDays = 14;
  int _facultyLoanDays = 30;

  // ---------------- ISSUE BOOK TAB STATE ----------------
  final _usnController = TextEditingController();
  final _borrowerNameController = TextEditingController();
  final _borrowerDeptController = TextEditingController();
  final _borrowerSemController = TextEditingController();
  final _borrowerTypeController = TextEditingController();
  final _loanDaysController = TextEditingController(text: "14");
  final _notesController = TextEditingController();

  bool _isVerifying = false;
  Map<String, dynamic>? _verifiedBorrower;
  String? _verifyError;

  // Dropdown filters for Issue Book tab
  String _selectedDepartmentFilter = 'All Departments';
  String _selectedSemesterFilter = 'All Semesters';

  // Dropdown filters for Return Book / Active Loans tab
  String _selectedReturnDepartment = 'All Departments';
  String _selectedReturnSemester = 'All Semesters';

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

  bool _isLoadingBooks = true;
  List<Map<String, dynamic>> _allBooks = [];
  Map<String, dynamic>? _selectedBook;
  int? _selectedBookId;

  List<Map<String, dynamic>> _availableCopies = [];
  int? _selectedCopyId;
  Map<String, dynamic>? _selectedCopy;

  DateTime _dueDate = DateTime.now().add(const Duration(days: 14));
  bool _isSubmittingIssue = false;

  // ---------------- RETURN BOOK TAB STATE ----------------
  bool _isLoadingLoans = true;
  String? _loanError;
  List<Map<String, dynamic>> _activeLoans = [];
  String _returnSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchConfig();
    _fetchBooks();
    _fetchActiveLoans();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usnController.dispose();
    _borrowerNameController.dispose();
    _borrowerDeptController.dispose();
    _borrowerSemController.dispose();
    _borrowerTypeController.dispose();
    _loanDaysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchConfig() async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/config/active/');
      if (res.data is Map && mounted) {
        setState(() {
          _libraryConfig = Map<String, dynamic>.from(res.data);
          _studentLoanDays = _libraryConfig?['loan_days_student'] ?? 14;
          _facultyLoanDays = _libraryConfig?['loan_days_faculty'] ?? 30;
          _loanDaysController.text = "$_studentLoanDays";
          _calculateDueDate();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchBooks() async {
    setState(() => _isLoadingBooks = true);
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/books/');
      final List list = res.data is List ? res.data : (res.data is Map && res.data['results'] is List ? res.data['results'] : []);
      if (mounted) {
        setState(() {
          _allBooks = List<Map<String, dynamic>>.from(list);
          _isLoadingBooks = false;

          if (widget.preselectedBookId != null) {
            _onBookSelected(widget.preselectedBookId);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBooks = false);
    }
  }

  Future<void> _fetchActiveLoans() async {
    setState(() {
      _isLoadingLoans = true;
      _loanError = null;
    });
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/issues/');
      final List list = res.data is List ? res.data : (res.data is Map && res.data['results'] is List ? res.data['results'] : []);
      if (mounted) {
        setState(() {
          _activeLoans = List<Map<String, dynamic>>.from(list);
          _isLoadingLoans = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLoans = false;
          _loanError = "Failed to load active loans: $e";
        });
      }
    }
  }

  // Verify borrower via backend
  Future<void> _verifyBorrower() async {
    final query = _usnController.text.trim();
    if (query.isEmpty) {
      setState(() => _verifyError = "Please enter borrower USN or Staff ID.");
      return;
    }

    setState(() {
      _isVerifying = true;
      _verifyError = null;
      _verifiedBorrower = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/issues/verify_borrower/', queryParameters: {'usn': query});
      if (mounted) {
        final data = Map<String, dynamic>.from(res.data);
        final isFaculty = (data['borrower_type'] ?? '').toString().toUpperCase() == 'FACULTY' || (data['is_faculty'] == true);
        setState(() {
          _verifiedBorrower = data;
          _isVerifying = false;
          _borrowerNameController.text = (data['name'] ?? '').toString();
          _borrowerDeptController.text = (data['department'] ?? '').toString();
          _borrowerSemController.text = isFaculty ? 'N/A (Faculty)' : (data['semester'] ?? '').toString();
          _borrowerTypeController.text = isFaculty ? 'Faculty' : 'Student';

          // Auto-set loan duration based on borrower type & config
          final days = isFaculty ? _facultyLoanDays : _studentLoanDays;
          _loanDaysController.text = "$days";
          _calculateDueDate();
        });
      }
    } catch (e) {
      if (mounted) {
        String msg = "Borrower with identifier \"$query\" not found or inactive.";
        if (e is DioException && e.response?.data != null) {
          final errData = e.response!.data;
          if (errData is Map && (errData['detail'] != null || errData['error'] != null)) {
            msg = (errData['detail'] ?? errData['error']).toString();
          }
        }
        setState(() {
          _isVerifying = false;
          _verifyError = msg;
          _borrowerNameController.clear();
          _borrowerDeptController.clear();
          _borrowerSemController.clear();
          _borrowerTypeController.clear();
        });
      }
    }
  }

  void _calculateDueDate() {
    final days = int.tryParse(_loanDaysController.text.trim()) ?? 14;
    setState(() {
      _dueDate = DateTime.now().add(Duration(days: days));
    });
  }

  List<Map<String, dynamic>> get _filteredCatalogBooks => _allBooks;

  void _onBookSelected(int? bookId) {
    if (bookId == null) {
      setState(() {
        _selectedBookId = null;
        _selectedBook = null;
        _availableCopies = [];
        _selectedCopyId = null;
        _selectedCopy = null;
      });
      return;
    }

    final bk = _allBooks.firstWhere((b) => b['id'] == bookId, orElse: () => {});
    final rawCopies = (bk['copies'] as List?) ?? [];
    final available = rawCopies
        .where((c) => (c['status'] ?? '').toString().toLowerCase() == 'available')
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();

    setState(() {
      _selectedBookId = bookId;
      _selectedBook = bk.isNotEmpty ? bk : null;
      _availableCopies = available;
      if (available.isNotEmpty) {
        _selectedCopyId = available.first['id'];
        _selectedCopy = available.first;
      } else {
        _selectedCopyId = null;
        _selectedCopy = null;
      }
    });
  }

  // Issue Book Submission with Confirmation Dialog & Receipt
  Future<void> _submitIssue() async {
    if (_verifiedBorrower == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please verify the borrower first!"), backgroundColor: Colors.red),
      );
      return;
    }

    if (_verifiedBorrower!['is_eligible'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_verifiedBorrower!['ineligible_reason'] ?? "Borrower is not eligible to borrow."), backgroundColor: Colors.red),
      );
      return;
    }

    if (_selectedBook == null || _selectedCopyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an available book copy!"), backgroundColor: Colors.red),
      );
      return;
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: const [
            Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF13246E)),
            SizedBox(width: 10),
            Text("Confirm Book Issue", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Borrower: ${_verifiedBorrower!['name']} (${_verifiedBorrower!['usn']})", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("Book Title: ${_selectedBook!['title']}"),
            Text("Copy Barcode: ${_selectedCopy?['barcode'] ?? _selectedCopyId}"),
            Text("Due Date: ${DateFormat('dd-MMM-yyyy').format(_dueDate)}"),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
              child: const Text("Policy: ₹0.00 Borrowing Fee • ₹0.00 Late Fine", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirm & Issue"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmittingIssue = true);
    try {
      final dio = ApiClient().dio;
      final res = await dio.post('/library/issues/', data: {
        'borrower_id': _verifiedBorrower!['user_id'],
        'copy_id': _selectedCopyId,
        'loan_days': int.tryParse(_loanDaysController.text.trim()) ?? 14,
        'due_date': DateFormat('yyyy-MM-dd').format(_dueDate),
        'notes': _notesController.text.trim(),
      });

      if (mounted) {
        setState(() => _isSubmittingIssue = false);
        final issueRecord = Map<String, dynamic>.from(res.data);
        _showIssueReceiptDialog(issueRecord);
        _fetchBooks();
        _fetchActiveLoans();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingIssue = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Issue failed: $e"), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  // Print-Ready Issue Receipt Modal
  void _showIssueReceiptDialog(Map<String, dynamic> issue) {
    final issueId = issue['issue_id'] ?? "ISS-${issue['id']}";
    final bookTitle = _selectedBook?['title'] ?? issue['book_title'] ?? 'Book';
    final borrowerName = _verifiedBorrower?['name'] ?? issue['borrower_name'] ?? 'Borrower';
    final borrowerId = _verifiedBorrower?['usn'] ?? 'N/A';
    final dept = _verifiedBorrower?['department'] ?? 'General';
    final sem = _verifiedBorrower?['semester'] ?? 'N/A';
    final copyBarcode = _selectedCopy?['barcode'] ?? issue['copy_barcode'] ?? _selectedCopyId;
    final issueDateStr = DateFormat('dd-MMM-yyyy').format(DateTime.now());
    final dueDateStr = DateFormat('dd-MMM-yyyy').format(_dueDate);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Receipt Header
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 48),
                    const SizedBox(height: 8),
                    const Text("CIRCULATION ISSUE RECEIPT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1, color: Color(0xFF13246E))),
                    Text("CampusFlow SDMS • College Library", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const Divider(height: 24),

              _buildReceiptRow("Transaction ID", issueId, isBold: true),
              _buildReceiptRow("Borrower Name", borrowerName),
              _buildReceiptRow("USN / Staff ID", borrowerId),
              _buildReceiptRow("Department & Sem", "$dept • $sem"),
              _buildReceiptRow("Book Title", bookTitle, isBold: true),
              _buildReceiptRow("Copy ID / Barcode", "$copyBarcode"),
              _buildReceiptRow("Issue Date", issueDateStr),
              _buildReceiptRow("Due Date", dueDateStr, isBold: true, color: const Color(0xFFDC2626)),
              _buildReceiptRow("Borrowing Fee", "₹0.00 (FREE)", color: const Color(0xFF059669)),
              const Divider(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF13246E),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Sending Receipt $issueId to printer..."), backgroundColor: const Color(0xFF059669)),
                      );
                    },
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text("Print Receipt"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13246E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedBook = null;
                        _selectedBookId = null;
                        _selectedCopy = null;
                        _selectedCopyId = null;
                        _availableCopies = [];
                        _notesController.clear();
                      });
                    },
                    child: const Text("Done"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  // Return Book Dialog with condition & remarks
  Future<void> _processReturn(Map<String, dynamic> issue) async {
    final issueId = issue['id'];
    final title = issue['book_title'] ?? issue['copy']?['book'] ?? 'Book';
    final borrower = issue['borrower_name'] ?? 'Borrower';

    String condition = 'GOOD';
    final remarksCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: const [
              Icon(Icons.keyboard_return_rounded, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text("Process Book Return", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Book: \"$title\"", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("Borrower: $borrower", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              const Divider(height: 20),
              const Text("Physical Condition of Book *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: condition,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                items: const [
                  DropdownMenuItem(value: 'GOOD', child: Text("Good Condition")),
                  DropdownMenuItem(value: 'DAMAGED', child: Text("Damaged (Needs Repair / Binding)")),
                  DropdownMenuItem(value: 'LOST', child: Text("Lost by Borrower")),
                ],
                onChanged: (v) => setDialogState(() => condition = v ?? 'GOOD'),
              ),
              const SizedBox(height: 12),
              const Text("Circulation Remarks (Optional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              const SizedBox(height: 6),
              TextField(
                controller: remarksCtrl,
                decoration: const InputDecoration(hintText: "e.g. Returned on time, pages intact", border: OutlineInputBorder(), contentPadding: EdgeInsets.all(10)),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                child: const Text("Policy: ₹0.00 overdue penalty fine applied under college free policy.", style: TextStyle(fontSize: 11.5, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Complete Return"),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        final dio = ApiClient().dio;
        await dio.post('/library/issues/$issueId/return_book/', data: {
          'book_condition': condition,
          'remarks': remarksCtrl.text.trim(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Book return processed successfully with ₹0.00 late fines!"),
              backgroundColor: Color(0xFF059669),
            ),
          );
          _fetchActiveLoans();
          _fetchBooks();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Return failed: $e"), backgroundColor: Colors.red.shade700),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        elevation: 0,
        title: const Text(
          "Circulation Desk - Issue & Return Books",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF7CA18),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.outbox_rounded), text: "Issue Book"),
            Tab(icon: Icon(Icons.move_to_inbox_rounded), text: "Return Book / Active Loans"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildIssueBookTab(),
          _buildReturnBookTab(),
        ],
      ),
    );
  }

  // ---------------- TAB 1: ISSUE BOOK (Matching Image 4) ----------------
  Widget _buildIssueBookTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Form Fields
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Borrower USN / Staff ID input with Verify Button
                      const Text("Borrower USN / Staff ID *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _usnController,
                              decoration: InputDecoration(
                                hintText: "e.g. 4GE24CS030 or FAC-001",
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                              onSubmitted: (_) => _verifyBorrower(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13246E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isVerifying ? null : _verifyBorrower,
                            icon: _isVerifying
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.search_rounded, size: 16),
                            label: const Text("Verify", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      if (_verifyError != null) ...[
                        const SizedBox(height: 6),
                        Text(_verifyError!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                      ],

                      // Auto-filled Borrower Detail Fields
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Borrower Full Name *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _borrowerNameController,
                                  readOnly: true,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    hintText: "Auto-filled upon verification",
                                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                                    filled: true,
                                    fillColor: const Color(0xFFF1F5F9),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Borrower Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _borrowerTypeController,
                                  readOnly: true,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    hintText: "Student / Faculty",
                                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                                    filled: true,
                                    fillColor: const Color(0xFFF1F5F9),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Department *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _borrowerDeptController,
                                  readOnly: true,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    hintText: "Auto-filled Department",
                                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                                    filled: true,
                                    fillColor: const Color(0xFFF1F5F9),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_verifiedBorrower == null || (_verifiedBorrower!['borrower_type'] ?? '').toString().toUpperCase() != 'FACULTY') ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Semester *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _borrowerSemController,
                                    readOnly: true,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    decoration: InputDecoration(
                                      hintText: "Auto-filled Semester",
                                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                                      filled: true,
                                      fillColor: const Color(0xFFF1F5F9),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Verified Borrower Card
                      if (_verifiedBorrower != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _verifiedBorrower!['is_eligible'] == true ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _verifiedBorrower!['is_eligible'] == true ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _verifiedBorrower!['is_eligible'] == true ? Icons.verified_rounded : Icons.warning_rounded,
                                    color: _verifiedBorrower!['is_eligible'] == true ? const Color(0xFF059669) : Colors.red,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${_verifiedBorrower!['name']} (${_verifiedBorrower!['usn']})",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                                    child: Text(
                                      "Card: ${_verifiedBorrower!['card_number'] ?? 'Not Active'}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _verifiedBorrower!['has_active_card'] == true ? const Color(0xFF13246E) : Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Dept: ${_verifiedBorrower!['department']} • ${_verifiedBorrower!['semester']} • Active Loans: ${_verifiedBorrower!['active_loans']} / ${_verifiedBorrower!['max_limit']}",
                                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                              ),
                              if (_verifiedBorrower!['is_eligible'] != true) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "Eligibility: ${_verifiedBorrower!['ineligible_reason']}",
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Select Book *
                      const Text("Select Book *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: _selectedBookId,
                        isExpanded: true,
                        hint: const Text("Choose a book title from catalogue...", style: TextStyle(fontSize: 13, color: Colors.black45)),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        items: _filteredCatalogBooks.map((b) {
                          final avail = b['available_copies'] ?? ((b['copies'] as List?)?.where((c) => (c['status'] ?? '').toString().toLowerCase() == 'available').length ?? 0);
                          final total = b['total_copies'] ?? ((b['copies'] as List?)?.length ?? 0);
                          return DropdownMenuItem<int>(
                            value: b['id'],
                            child: Text("${b['title']} ($avail/$total available)", overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (id) => _onBookSelected(id),
                      ),
                      const SizedBox(height: 16),

                      // Select Copy *
                      const Text("Select Copy *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: _selectedCopyId,
                        isExpanded: true,
                        hint: Text(
                          _selectedBook == null
                              ? "Select a book first"
                              : (_availableCopies.isEmpty ? "No available copies for this book" : "Select physical copy barcode..."),
                          style: const TextStyle(fontSize: 13, color: Colors.black45),
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        items: _availableCopies.map((c) {
                          return DropdownMenuItem<int>(
                            value: c['id'],
                            child: Text("Copy #${c['copy_number']} • Barcode: ${c['barcode'] ?? 'ID-${c['id']}'}", style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (id) {
                          setState(() {
                            _selectedCopyId = id;
                            _selectedCopy = _availableCopies.firstWhere((c) => c['id'] == id, orElse: () => {});
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Loan Duration & Automatic Due Date
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Loan Duration *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      child: TextField(
                                        controller: _loanDaysController,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => _calculateDueDate(),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: const Color(0xFFF1F5F9),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text("days", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Automatic Due Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Text(
                                    DateFormat('dd-MMM-yyyy').format(_dueDate),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E40AF)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Issue Notes
                      const Text("Issue Notes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          hintText: "Optional circulation notes or condition of book copy...",
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 28),

                // Right Book Preview matching Image 4
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: const Color(0xFFEFF6FF),
                              child: const Icon(Icons.menu_book_rounded, color: Color(0xFF13246E), size: 40),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedBook != null ? (_selectedBook!['title'] ?? 'Selected Book') : "Select Book",
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                            ),
                            if (_selectedBook != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                "Author: ${_selectedBook!['authors'] ?? 'N/A'}",
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                "ISBN: ${_selectedBook!['isbn'] ?? 'N/A'}",
                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                                child: Text(
                                  "${_availableCopies.length} available copies",
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Submit & Cancel buttons matching Image 4
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF13246E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isSubmittingIssue ? null : _submitIssue,
                          child: _isSubmittingIssue
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text("Submit Issue", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedBookId = null;
                            _selectedBook = null;
                            _selectedCopy = null;
                            _selectedCopyId = null;
                            _availableCopies = [];
                            _notesController.clear();
                          });
                        },
                        child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- TAB 2: RETURN BOOK / ACTIVE LOANS ----------------
  Widget _buildReturnBookTab() {
    final filtered = _activeLoans.where((l) {
      final q = _returnSearchQuery.toLowerCase().trim();
      final title = (l['book_title'] ?? l['copy']?['book'] ?? '').toString().toLowerCase();
      final borrower = (l['borrower_name'] ?? '').toString().toLowerCase();
      final barcode = (l['copy_barcode'] ?? l['copy']?['barcode'] ?? '').toString().toLowerCase();
      final issueId = (l['issue_id'] ?? '').toString().toLowerCase();
      final usn = (l['borrower_usn'] ?? '').toString().toLowerCase();
      final dept = (l['borrower_department'] ?? '').toString();
      final sem = l['borrower_semester']?.toString() ?? '';

      final matchesSearch = q.isEmpty ||
          title.contains(q) ||
          borrower.contains(q) ||
          barcode.contains(q) ||
          issueId.contains(q) ||
          usn.contains(q);

      final matchesDept = _selectedReturnDepartment == 'All Departments' ||
          dept.toLowerCase().trim() == _selectedReturnDepartment.toLowerCase().trim();

      final matchesSem = _selectedReturnSemester == 'All Semesters' ||
          ("Semester $sem" == _selectedReturnSemester);

      return matchesSearch && matchesDept && matchesSem;
    }).toList();

    return Column(
      children: [
        // Search & Filters bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _returnSearchQuery = v),
                      decoration: InputDecoration(
                        hintText: "Search active loans by book title, borrower name, USN, or copy barcode...",
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF13246E)),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: "Refresh Loans",
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF13246E)),
                    onPressed: _fetchActiveLoans,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text("Filter Loans:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(width: 12),
                  // Department Dropdown Filter
                  SizedBox(
                    width: 260,
                    height: 38,
                    child: DropdownButtonFormField<String>(
                      value: _selectedReturnDepartment,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                      items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() => _selectedReturnDepartment = v ?? 'All Departments'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Semester Dropdown Filter
                  SizedBox(
                    width: 150,
                    height: 38,
                    child: DropdownButtonFormField<String>(
                      value: _selectedReturnSemester,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                      items: _semesters.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() => _selectedReturnSemester = v ?? 'All Semesters'),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "Showing ${filtered.length} of ${_activeLoans.length} active loans",
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Loans list
        Expanded(
          child: _isLoadingLoans
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF13246E)))
              : _loanError != null
                  ? Center(child: Text(_loanError!, style: TextStyle(color: Colors.red.shade700)))
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF059669)),
                              SizedBox(height: 10),
                              Text("No active borrowed books right now.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final item = filtered[i];
                            final title = item['book_title'] ?? item['copy']?['book'] ?? 'Book';
                            final borrower = item['borrower_name'] ?? 'Borrower';
                            final dueDateStr = item['due_date']?.toString().substring(0, 10) ?? 'N/A';
                            final barcode = item['copy_barcode'] ?? item['copy']?['barcode'] ?? 'N/A';
                            final isOverdue = item['is_overdue'] == true;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isOverdue ? Colors.red.shade50 : const Color(0xFFEFF6FF),
                                  foregroundColor: isOverdue ? Colors.red.shade700 : const Color(0xFF13246E),
                                  child: Icon(isOverdue ? Icons.warning_rounded : Icons.menu_book_rounded),
                                ),
                                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text("Borrower: $borrower • Copy Barcode: $barcode • Due: $dueDateStr"),
                                trailing: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () => _processReturn(item),
                                  icon: const Icon(Icons.keyboard_return_rounded, size: 16),
                                  label: const Text("Return Book", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
