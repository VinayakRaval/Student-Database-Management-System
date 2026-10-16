import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/api_client.dart';

class IssueBookScreen extends StatefulWidget {
  final int? preselectedBookId;
  const IssueBookScreen({super.key, this.preselectedBookId});

  @override
  State<IssueBookScreen> createState() => _IssueBookScreenState();
}

class _IssueBookScreenState extends State<IssueBookScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _usnController = TextEditingController();
  final _borrowerNameController = TextEditingController();
  final _borrowerDeptController = TextEditingController();
  final _borrowerSemController = TextEditingController();
  final _borrowerTypeController = TextEditingController();
  final _loanDaysController = TextEditingController(text: "14");
  final _notesController = TextEditingController();

  // State variables
  bool _isVerifyingBorrower = false;
  Map<String, dynamic>? _borrowerInfo;
  String? _borrowerError;

  bool _isLoadingBooks = true;
  List<Map<String, dynamic>> _books = [];
  Map<String, dynamic>? _selectedBook;
  int? _selectedBookId;

  List<Map<String, dynamic>> _availableCopies = [];
  int? _selectedCopyId;
  Map<String, dynamic>? _selectedCopy;

  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 14));

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchBooks();
  }

  @override
  void dispose() {
    _usnController.dispose();
    _borrowerNameController.dispose();
    _borrowerDeptController.dispose();
    _borrowerSemController.dispose();
    _borrowerTypeController.dispose();
    _loanDaysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchBooks() async {
    setState(() => _isLoadingBooks = true);
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/books/');
      final List list = res.data is List ? res.data : [];
      if (mounted) {
        setState(() {
          _books = List<Map<String, dynamic>>.from(list);
          _isLoadingBooks = false;

          if (widget.preselectedBookId != null) {
            _onBookSelected(widget.preselectedBookId);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBooks = false);
      }
    }
  }

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

    final bk = _books.firstWhere((b) => b['id'] == bookId, orElse: () => {});
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

  Future<void> _verifyBorrower() async {
    final rawQuery = _usnController.text.trim();
    if (rawQuery.isEmpty) {
      setState(() {
        _borrowerError = "Please enter a USN or Student ID.";
        _borrowerInfo = null;
      });
      return;
    }

    final query = rawQuery.replaceAll(RegExp(r'^[\$#@]+'), '').trim();

    setState(() {
      _isVerifyingBorrower = true;
      _borrowerError = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/issues/lookup_borrower/', queryParameters: {'query': query});
      if (mounted) {
        final data = Map<String, dynamic>.from(res.data as Map);
        final isFaculty = (data['borrower_type'] ?? '').toString().toUpperCase() == 'FACULTY' || (data['is_faculty'] == true);
        setState(() {
          _borrowerInfo = data;
          _isVerifyingBorrower = false;
          _borrowerNameController.text = (data['name'] ?? '').toString();
          _borrowerDeptController.text = (data['department'] ?? '').toString();
          _borrowerSemController.text = isFaculty ? 'N/A (Faculty)' : (data['semester'] ?? '').toString();
          _borrowerTypeController.text = isFaculty ? 'Faculty' : 'Student';
          _loanDaysController.text = isFaculty ? "30" : "14";
          _updateDueDateFromDays(_loanDaysController.text);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _borrowerInfo = null;
          _borrowerError = "Borrower with identifier \"$rawQuery\" not found or not registered.";
          _isVerifyingBorrower = false;
          _borrowerNameController.clear();
          _borrowerDeptController.clear();
          _borrowerSemController.clear();
          _borrowerTypeController.clear();
        });
      }
    }
  }

  void _updateDueDateFromDays(String daysStr) {
    final days = int.tryParse(daysStr.trim());
    if (days != null && days > 0) {
      setState(() {
        _dueDate = _issueDate.add(Duration(days: days));
      });
    }
  }

  Future<void> _submitIssue() async {
    if (_borrowerInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please verify the borrower's USN / ID first."), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_borrowerInfo!['is_eligible'] == false) {
      final reasons = (_borrowerInfo!['ineligibility_reasons'] as List?)?.join(', ') ?? 'Borrowing blocked.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Borrower not eligible: $reasons"), backgroundColor: Colors.red.shade700),
      );
      return;
    }

    if (_selectedCopyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an available book copy to issue."), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dio = ApiClient().dio;
      final loanDays = int.tryParse(_loanDaysController.text.trim()) ?? 14;

      await dio.post('/library/issues/', data: {
        'borrower_id': _borrowerInfo!['id'],
        'copy_id': _selectedCopyId,
        'loan_days': loanDays,
        'due_date': DateFormat('yyyy-MM-dd').format(_dueDate),
        'notes': _notesController.text.trim(),
      });

      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Book successfully issued to student!"),
            backgroundColor: Color(0xFF059669),
          ),
        );
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/library/desk');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Checkout failed: $e"), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        elevation: 0,
        title: const Text(
          "Circulation Desk - Issue Book",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/library/desk');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: Container(
            width: isDesktop ? 1100 : double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Form Fields
                        Expanded(
                          flex: 3,
                          child: _buildFormFields(),
                        ),
                        const SizedBox(width: 48),
                        // Right Column: Book / Borrower Card & Action
                        SizedBox(
                          width: 250,
                          child: _buildRightPreviewColumn(),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRightPreviewColumn(),
                        const SizedBox(height: 24),
                        _buildFormFields(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Borrower USN / ID Verification
        _buildCustomRow(
          label: "Borrower USN *",
          child: Row(
            children: [
              Expanded(
                child: _buildInlineInput(
                  controller: _usnController,
                  hintText: "e.g. 4GE24CS030",
                  onSubmitted: (_) => _verifyBorrower(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13246E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: _isVerifyingBorrower ? null : _verifyBorrower,
                  icon: _isVerifyingBorrower
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.search_rounded, size: 16),
                  label: const Text("Verify", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Auto-filled Borrower Name (Read-Only)
        _buildCustomRow(
          label: "Borrower Name *",
          child: _buildInlineInput(
            controller: _borrowerNameController,
            readOnly: true,
            hintText: "Auto-filled upon verification",
          ),
        ),
        const SizedBox(height: 14),

        // Auto-filled Department (Read-Only)
        _buildCustomRow(
          label: "Department *",
          child: _buildInlineInput(
            controller: _borrowerDeptController,
            readOnly: true,
            hintText: "Auto-filled upon verification",
          ),
        ),
        const SizedBox(height: 14),

        // Auto-filled Semester (Read-Only, Hidden or Disabled for Faculty)
        if (_borrowerInfo == null || (_borrowerInfo!['borrower_type'] ?? '').toString().toUpperCase() != 'FACULTY') ...[
          _buildCustomRow(
            label: "Semester *",
            child: _buildInlineInput(
              controller: _borrowerSemController,
              readOnly: true,
              hintText: "Auto-filled upon verification",
            ),
          ),
          const SizedBox(height: 14),
        ],
          Padding(
            padding: const EdgeInsets.only(left: 140, bottom: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_borrowerError!, style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),

        if (_borrowerInfo != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 140, bottom: 14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _borrowerInfo!['is_eligible'] == true ? Colors.green.shade50 : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _borrowerInfo!['is_eligible'] == true ? Colors.green.shade300 : Colors.amber.shade400,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _borrowerInfo!['is_eligible'] == true ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                        color: _borrowerInfo!['is_eligible'] == true ? const Color(0xFF059669) : Colors.amber.shade900,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${_borrowerInfo!['name']} (${_borrowerInfo!['usn']})",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _borrowerInfo!['is_eligible'] == true ? const Color(0xFF059669) : Colors.red.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _borrowerInfo!['is_eligible'] == true ? "ELIGIBLE" : "BLOCKED",
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text("Dept: ${_borrowerInfo!['department'] ?? 'General'} | Sem ${_borrowerInfo!['semester'] ?? '-'}",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      const SizedBox(width: 14),
                      Text("Active: ${_borrowerInfo!['active_loans_count']}/3",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade900)),
                      const SizedBox(width: 14),
                      Text("Overdue: ${_borrowerInfo!['overdue_count']}",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: (_borrowerInfo!['overdue_count'] ?? 0) > 0 ? Colors.red.shade700 : Colors.grey.shade700)),
                      const SizedBox(width: 14),
                      Text("Fines: ₹${_borrowerInfo!['unpaid_fines_amount']}",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: (_borrowerInfo!['unpaid_fines_amount'] ?? 0) > 0 ? Colors.red.shade700 : Colors.green.shade800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Library Card status pill
                  Row(
                    children: [
                      Icon(Icons.badge_rounded, size: 14, color: _borrowerInfo!['library_card'] != null && _borrowerInfo!['library_card']['status'] == 'ACTIVE' ? const Color(0xFF059669) : Colors.orange.shade800),
                      const SizedBox(width: 6),
                      Text(
                        _borrowerInfo!['library_card'] != null
                            ? "Library Card: ${_borrowerInfo!['library_card']['card_number'] ?? 'Pending'} (${_borrowerInfo!['library_card']['status']})"
                            : "Library Card: NOT APPLIED (Borrowing Blocked)",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _borrowerInfo!['library_card'] != null && _borrowerInfo!['library_card']['status'] == 'ACTIVE' ? const Color(0xFF059669) : Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                  if (_borrowerInfo!['is_eligible'] == false && (_borrowerInfo!['ineligibility_reasons'] as List?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 14, color: Colors.red.shade800),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              (_borrowerInfo!['ineligibility_reasons'] as List).join(' • '),
                              style: TextStyle(color: Colors.red.shade900, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],

        // Book Selection Dropdown
        _buildCustomRow(
          label: "Select Book *",
          child: _isLoadingBooks
              ? Container(
                  height: 40,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                  child: const Text("Loading library catalogue...", style: TextStyle(color: Colors.grey, fontSize: 13)),
                )
              : Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.transparent),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedBookId,
                      hint: const Text("Choose a book title from catalogue...", style: TextStyle(fontSize: 14, color: Colors.black54)),
                      items: _books.map((b) {
                        final avail = (b['available_copies'] as num?)?.toInt() ?? 0;
                        return DropdownMenuItem<int>(
                          value: b['id'],
                          child: Text(
                            "${b['title']} ($avail available)",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: _onBookSelected,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 14),

        // Available Copy Selection
        _buildCustomRow(
          label: "Select Copy *",
          child: _selectedBookId == null
              ? Container(
                  height: 40,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                  child: const Text("Select a book first", style: TextStyle(color: Colors.grey, fontSize: 13)),
                )
              : _availableCopies.isEmpty
                  ? Container(
                      height: 40,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                      child: Text("No available copies in stock for this book", style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.bold)),
                    )
                  : Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _selectedCopyId,
                          items: _availableCopies.map((c) {
                            return DropdownMenuItem<int>(
                              value: c['id'],
                              child: Text(
                                "Copy #${c['copy_number']} | Barcode: ${c['barcode'] ?? 'N/A'} | Shelf: ${c['shelf_location'] ?? 'N/A'}",
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedCopyId = val;
                              _selectedCopy = _availableCopies.firstWhere((c) => c['id'] == val, orElse: () => {});
                            });
                          },
                        ),
                      ),
                    ),
        ),
        const SizedBox(height: 14),

        // Loan Duration & Due Date Row
        _buildCustomRow(
          label: "Loan Duration *",
          child: Row(
            children: [
              Expanded(
                child: _buildInlineInput(
                  controller: _loanDaysController,
                  keyboardType: TextInputType.number,
                  hintText: "14",
                  onChanged: _updateDueDateFromDays,
                ),
              ),
              const SizedBox(width: 12),
              const Text("days", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(width: 24),
              const Text("Due Date: ", style: TextStyle(fontSize: 14, color: Colors.black87)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  DateFormat('dd-MMM-yyyy').format(_dueDate),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF13246E)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Circulation Remarks / Notes
        _buildCustomRow(
          label: "Issue Notes",
          child: _buildInlineInput(
            controller: _notesController,
            hintText: "Optional circulation notes or condition of book copy...",
          ),
        ),
      ],
    );
  }

  Widget _buildRightPreviewColumn() {
    return Column(
      children: [
        // 180x180 Image / Book Preview Container matching Image 1
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: _selectedBook != null && _selectedBook!['cover_image_url'] != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _selectedBook!['cover_image_url'],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildFallbackPreview(),
                  ),
                )
              : _buildFallbackPreview(),
        ),
        const SizedBox(height: 14),

        // Book title & details snippet under preview
        if (_selectedBook != null) ...[
          Text(
            _selectedBook!['title'] ?? '',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedBook!['authors'] ?? '',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          if (_selectedCopy != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF13246E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Barcode: ${_selectedCopy!['barcode'] ?? ''}",
                style: const TextStyle(color: Color(0xFF13246E), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ] else ...[
          const Text(
            "Book Preview",
            style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
          ),
        ],

        const SizedBox(height: 36),

        // Submit Button matching Image 1: #13246E pill button
        SizedBox(
          width: 140,
          height: 40,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: _isSubmitting ? null : _submitIssue,
            child: _isSubmitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("Submit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/library/desk');
            }
          },
          child: const Text("Cancel", style: TextStyle(color: Colors.black54, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildFallbackPreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.menu_book_rounded, size: 56, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        Text(
          _selectedBook != null ? "No Cover Art" : "Select Book",
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildCustomRow({required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildInlineInput({
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: readOnly ? Border.all(color: const Color(0xFFCBD5E1)) : null,
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: TextStyle(
          fontSize: 14,
          color: readOnly ? const Color(0xFF1E293B) : Colors.black87,
          fontWeight: readOnly ? FontWeight.w600 : FontWeight.normal,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }
}
