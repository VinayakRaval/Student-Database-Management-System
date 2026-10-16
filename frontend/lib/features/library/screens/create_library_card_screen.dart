import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/library/widgets/digital_library_card_widget.dart';

class CreateLibraryCardScreen extends StatefulWidget {
  final int? existingCardId;
  final String? initialIdentifier;
  final String? initialBorrowerType;
  const CreateLibraryCardScreen({
    super.key,
    this.existingCardId,
    this.initialIdentifier,
    this.initialBorrowerType,
  });

  @override
  State<CreateLibraryCardScreen> createState() => _CreateLibraryCardScreenState();
}

class _CreateLibraryCardScreenState extends State<CreateLibraryCardScreen> {
  final _formKey = GlobalKey<FormState>();

  // Borrower Type: STUDENT or FACULTY
  String _borrowerType = 'STUDENT';
  final _identifierController = TextEditingController();

  // Auto-fetched borrower details
  bool _isVerifying = false;
  String? _verifyError;
  Map<String, dynamic>? _verifiedBorrower;
  Map<String, dynamic>? _existingCard;

  final _nameController = TextEditingController();
  final _usnController = TextEditingController();
  final _departmentController = TextEditingController();
  final _semesterController = TextEditingController();
  final _sectionController = TextEditingController(text: "A");
  final _rollNoController = TextEditingController();
  final _designationController = TextEditingController();
  final _academicYearController = TextEditingController(text: "2025-2026");

  // Dynamic component inputs for "Name of Book", "Date of Issue", "Date of Return", "Due Date", etc.
  final _bookTitleController = TextEditingController();
  final _bookBarcodeController = TextEditingController();
  final _issueDateController = TextEditingController();
  final _returnDateController = TextEditingController();
  final _dueDateController = TextEditingController();
  final Map<String, TextEditingController> _customComponentControllers = {};
  Map<String, dynamic>? _selectedMissingBook;
  String? _selectedBookKey;

  Map<String, Map<String, dynamic>> _getSelectableBooks() {
    final Map<String, Map<String, dynamic>> map = {};
    for (int i = 0; i < _missingBooks.length; i++) {
      final b = _missingBooks[i];
      final key = "miss_${b['issue_id'] ?? b['book_copy_no'] ?? i}";
      map[key] = b;
    }
    return map;
  }

  void _removeComponentByName(String compName) {
    setState(() {
      _components.removeWhere((c) => c.trim().toLowerCase() == compName.trim().toLowerCase());
      _customComponentControllers.remove(compName);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Removed \"$compName\" component."),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // Dynamic Card Components (matching Fee Structure Components pattern)
  static const List<String> _availableComponentTypes = [
    "Name of Book",
    "Date of Issue",
    "Due Date",
    "Date of Return",
    "Signature Image",
    "Book Barcode / Copy ID",
    "Librarian Remarks",
    "+ Add Custom Component",
  ];

  final List<String> _components = [
    "Name of Book",
    "Date of Issue",
    "Date of Return",
    "Due Date",
    "Signature Image",
  ];

  // Signature Upload
  PlatformFile? _signatureImageFile;

  // Circulation history from IssueRecord & Missing Books
  bool _isLoadingLoans = false;
  List<Map<String, dynamic>> _circulationRows = [];
  List<Map<String, dynamic>> _missingBooks = [];
  int _loanDays = 14;
  int _loanLimit = 3;

  // Configuration check
  bool _isConfigured = true;
  Map<String, dynamic>? _libraryConfig;

  // Submission state
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialBorrowerType != null && widget.initialBorrowerType!.isNotEmpty) {
      _borrowerType = widget.initialBorrowerType!.toUpperCase();
    }
    if (widget.initialIdentifier != null && widget.initialIdentifier!.isNotEmpty) {
      _identifierController.text = widget.initialIdentifier!;
    }
    _fetchLibraryConfig().then((_) {
      if (widget.existingCardId != null) {
        _loadExistingCard(widget.existingCardId!);
      } else if (widget.initialIdentifier != null && widget.initialIdentifier!.isNotEmpty) {
        _verifyBorrower();
      }
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _nameController.dispose();
    _usnController.dispose();
    _departmentController.dispose();
    _semesterController.dispose();
    _sectionController.dispose();
    _rollNoController.dispose();
    _designationController.dispose();
    _academicYearController.dispose();
    _bookTitleController.dispose();
    _bookBarcodeController.dispose();
    _issueDateController.dispose();
    _returnDateController.dispose();
    _dueDateController.dispose();
    for (final c in _customComponentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getCustomController(String comp) {
    if (!_customComponentControllers.containsKey(comp)) {
      _customComponentControllers[comp] = TextEditingController();
    }
    return _customComponentControllers[comp]!;
  }

  Future<void> _fetchLibraryConfig() async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/config/active/');
      if (res.data is Map && mounted) {
        setState(() {
          _libraryConfig = Map<String, dynamic>.from(res.data);
          _isConfigured = _libraryConfig?['is_active'] == true;
          if (_libraryConfig?['academic_year'] != null) {
            _academicYearController.text = _libraryConfig!['academic_year'];
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isConfigured = false);
      }
    }
  }

  Future<void> _loadExistingCard(int cardId) async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/cards/$cardId/');
      if (res.data is Map && mounted) {
        final card = Map<String, dynamic>.from(res.data);
        setState(() {
          _existingCard = card;
          _borrowerType = card['borrower_type'] ?? 'STUDENT';
          _nameController.text = card['borrower_name'] ?? card['student_name'] ?? '';
          _usnController.text = card['borrower_id_number'] ?? card['student_usn'] ?? '';
          _identifierController.text = _usnController.text;
          final rawDept = card['department_name'] ?? card['department'];
          _departmentController.text = (rawDept != null && rawDept.toString().trim().isNotEmpty && rawDept.toString().trim() != 'N/A')
              ? rawDept.toString().trim()
              : 'Computer Science and Engineering';
          _semesterController.text = card['semester'] != null ? "Semester ${card['semester']}" : '';
          _sectionController.text = card['section'] ?? 'A';
          _rollNoController.text = card['roll_no'] ?? '';
          _academicYearController.text = card['academic_year'] ?? '2025-2026';

          if (card['components'] is List && (card['components'] as List).isNotEmpty) {
            _components.clear();
            for (final c in card['components']) {
              if (c is String) {
                _components.add(c);
              } else if (c is Map && c['name'] != null) {
                _components.add(c['name'].toString());
              }
            }
          }

          if (card['circulation_rows'] is List && (card['circulation_rows'] as List).isNotEmpty) {
            _circulationRows = List<Map<String, dynamic>>.from(card['circulation_rows']);
          } else if (card['recorded_books'] is List && (card['recorded_books'] as List).isNotEmpty) {
            _circulationRows = List<Map<String, dynamic>>.from(card['recorded_books']);
          }

          _verifiedBorrower = {
            'user_id': card['student_user'],
            'name': _nameController.text,
            'usn': _usnController.text,
            'department': _departmentController.text,
            'semester': _semesterController.text,
            'is_eligible': true,
            'has_active_card': true,
            'card_number': card['card_number'],
          };
        });
      }
    } catch (_) {}
  }

  Future<void> _verifyBorrower() async {
    final query = _identifierController.text.trim();
    if (query.isEmpty) {
      setState(() => _verifyError = "Please enter a USN or Faculty ID to verify.");
      return;
    }

    setState(() {
      _isVerifying = true;
      _verifyError = null;
      _verifiedBorrower = null;
      _existingCard = null;
      _circulationRows = [];
      _missingBooks = [];
    });

    try {
      final dio = ApiClient().dio;
      // 1. Try unified borrower_books endpoint
      try {
        final res = await dio.get('/library/cards/borrower_books/', queryParameters: {
          'identifier': query,
          'borrower_type': _borrowerType,
        });
        if (res.data is Map && res.data['borrower'] != null && mounted) {
          final b = Map<String, dynamic>.from(res.data['borrower']);
          final isFac = (b['borrower_type'] ?? _borrowerType).toString().toUpperCase() == 'FACULTY';
          final existingCard = res.data['card'] is Map ? Map<String, dynamic>.from(res.data['card']) : null;
          final missing = res.data['missing_books'] is List ? List<Map<String, dynamic>>.from(res.data['missing_books']) : <Map<String, dynamic>>[];
          final allBooks = (res.data['all_books'] is List)
              ? List<Map<String, dynamic>>.from(res.data['all_books'])
              : ((res.data['all_borrower_books'] is List)
                  ? List<Map<String, dynamic>>.from(res.data['all_borrower_books'])
                  : <Map<String, dynamic>>[]);

          setState(() {
            _verifiedBorrower = b;
            _existingCard = existingCard;
            _borrowerType = isFac ? 'FACULTY' : 'STUDENT';
            _nameController.text = b['name'] ?? '';
            _usnController.text = b['identifier'] ?? query;
            final rawDept = b['department'] ?? b['department_name'];
            _departmentController.text = (rawDept != null && rawDept.toString().trim().isNotEmpty && rawDept.toString().trim() != 'N/A')
                ? rawDept.toString().trim()
                : 'Computer Science and Engineering';
            _loanDays = res.data['loan_days'] ?? (isFac ? 30 : 14);
            _loanLimit = res.data['loan_limit'] ?? (isFac ? 5 : 3);
            _missingBooks = missing;

            if (isFac) {
              _designationController.text = b['designation'] ?? 'Faculty Member';
              _semesterController.clear();
              _sectionController.clear();
              _rollNoController.clear();
            } else {
              _semesterController.text = b['semester'] != null ? "Semester ${b['semester']}" : 'Semester 1';
              _sectionController.text = b['section'] ?? 'A';
              _rollNoController.text = b['roll_no'] ?? _usnController.text;
            }

            if (existingCard != null) {
              _existingCard = existingCard;
              if (existingCard['circulation_rows'] is List && (existingCard['circulation_rows'] as List).isNotEmpty) {
                _circulationRows = List<Map<String, dynamic>>.from(existingCard['circulation_rows']);
              } else if (existingCard['recorded_books'] is List && (existingCard['recorded_books'] as List).isNotEmpty) {
                _circulationRows = List<Map<String, dynamic>>.from(existingCard['recorded_books']);
              } else if (allBooks.isNotEmpty) {
                _circulationRows = List<Map<String, dynamic>>.from(allBooks);
              }
              if (existingCard['components'] is List && (existingCard['components'] as List).isNotEmpty) {
                _components.clear();
                for (final c in existingCard['components']) {
                  final str = c is String ? c : (c['name']?.toString() ?? '');
                  if (str.isNotEmpty) _components.add(str);
                }
              }
            } else {
              _circulationRows = List<Map<String, dynamic>>.from(allBooks);
            }

            // Auto-select the first unrecorded/missing book into inputs so the subject is immediately active
            if (missing.isNotEmpty && _bookTitleController.text.trim().isEmpty) {
              final firstBook = missing.first;
              _selectedMissingBook = firstBook;
              _selectedBookKey = "miss_${firstBook['issue_id'] ?? firstBook['book_copy_no'] ?? 0}";
              _bookTitleController.text = firstBook['book_title'] ?? '';
              _bookBarcodeController.text = firstBook['book_copy_no'] ?? firstBook['copy_barcode'] ?? 'CPY-01';
              _issueDateController.text = firstBook['issued_date'] ?? DateTime.now().toString().substring(0, 10);
              _returnDateController.text = firstBook['due_date'] ?? firstBook['return_date'] ?? _calculateReturnDate(_issueDateController.text);
              _dueDateController.text = firstBook['due_date'] ?? _returnDateController.text;
            }

            _isVerifying = false;
          });
          return;
        }
      } catch (_) {}

      // Fallback: search_borrower
      final res = await dio.get('/library/cards/search_borrower/', queryParameters: {'q': query});
      final List results = (res.data is Map && res.data['results'] is List) ? res.data['results'] : [];

      Map<String, dynamic>? match;
      for (final r in results) {
        final bType = (r['type'] ?? '').toString().toUpperCase();
        if (bType == _borrowerType) {
          match = Map<String, dynamic>.from(r);
          break;
        }
      }

      if (match == null && results.isNotEmpty) {
        match = Map<String, dynamic>.from(results.first);
        _borrowerType = match['type'] ?? _borrowerType;
      }

      if (match != null && mounted) {
        final isFac = (_borrowerType == 'FACULTY') || (match['type'] == 'FACULTY');
        setState(() {
          _verifiedBorrower = match;
          _isVerifying = false;
          _nameController.text = match!['name'] ?? match['student_name'] ?? match['faculty_name'] ?? '';
          _usnController.text = match['identifier'] ?? match['usn'] ?? match['student_usn'] ?? match['faculty_id'] ?? query;
          final rawDept = match['department'] ?? match['department_name'];
          _departmentController.text = (rawDept != null && rawDept.toString().trim().isNotEmpty && rawDept.toString().trim() != 'N/A')
              ? rawDept.toString().trim()
              : 'Computer Science and Engineering';

          if (isFac) {
            _designationController.text = match['designation'] ?? 'Faculty Member';
            _semesterController.clear();
            _sectionController.clear();
            _rollNoController.clear();
          } else {
            _semesterController.text = match['semester']?.toString() ?? 'Semester 1';
            _sectionController.text = match['section']?.toString() ?? 'A';
            _rollNoController.text = match['roll_no']?.toString() ?? _usnController.text;
          }
        });

        _fetchBorrowerLoans(match['user_id'] ?? match['id']);
      } else if (mounted) {
        setState(() {
          _isVerifying = false;
          _verifyError = "No $_borrowerType found with ID/USN \"$query\". Please check the identifier and try again.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _verifyError = "Error verifying borrower: $e";
        });
      }
    }
  }

  Future<void> _fetchBorrowerLoans(dynamic userId) async {
    if (userId == null) return;
    setState(() => _isLoadingLoans = true);
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/issues/history/');
      if (res.data is List && mounted) {
        final List allLoans = res.data;
        final borrowerLoans = allLoans.where((iss) {
          final bName = (iss['borrower_name'] ?? '').toString().toLowerCase();
          final bUsn = (iss['borrower_usn'] ?? '').toString().toLowerCase();
          final myName = _nameController.text.toLowerCase();
          final myUsn = _usnController.text.toLowerCase();
          return (myUsn.isNotEmpty && bUsn.contains(myUsn)) || (myName.isNotEmpty && bName.contains(myName));
        }).toList();

        final rows = <Map<String, dynamic>>[];
        for (int i = 0; i < borrowerLoans.length && i < 8; i++) {
          final iss = borrowerLoans[i];
          rows.add({
            'serial_no': i + 1,
            'book_title': iss['book_title'] ?? 'Book Title',
            'book_copy_no': iss['copy_barcode'] ?? 'CPY-01',
            'issued_date': iss['issued_at'] != null ? iss['issued_at'].toString().substring(0, 10) : '',
            'return_date': iss['returned_at'] != null ? iss['returned_at'].toString().substring(0, 10) : (iss['due_date']?.toString().substring(0, 10) ?? ''),
            'status': iss['status'] ?? 'ISSUED',
            'is_signed': true,
          });
        }

        setState(() {
          _circulationRows = rows;
          _isLoadingLoans = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLoans = false);
    }
  }

  Future<void> _addMissingBookToCard(Map<String, dynamic> book) async {
    final ref = book['issue_id'] ?? book['book_copy_no'];
    final alreadyExists = _circulationRows.any((r) =>
        (r['issue_id'] != null && r['issue_id'] == ref) ||
        (r['book_copy_no'] != null && r['book_copy_no'] == ref));

    if (alreadyExists) {
      setState(() {
        _missingBooks.removeWhere((b) => (b['issue_id'] == ref || b['book_copy_no'] == ref));
      });
      return;
    }

    final newRow = {
      'serial_no': _circulationRows.length + 1,
      'book_title': book['book_title'] ?? '',
      'book_copy_no': book['book_copy_no'] ?? '',
      'issued_date': book['issued_date'] ?? DateTime.now().toString().substring(0, 10),
      'return_date': book['return_date'] ?? DateTime.now().add(Duration(days: _loanDays)).toString().substring(0, 10),
      'due_date': book['due_date'] ?? book['return_date'] ?? DateTime.now().add(Duration(days: _loanDays)).toString().substring(0, 10),
      'status': book['status'] ?? 'ISSUED',
      'is_signed': true,
      'issue_id': book['issue_id'],
    };

    setState(() {
      _circulationRows.add(newRow);
      _missingBooks.removeWhere((b) => (b['issue_id'] == ref || b['book_copy_no'] == ref));
    });

    if (_existingCard != null && _existingCard!['id'] != null) {
      try {
        final dio = ApiClient().dio;
        await dio.post('/library/cards/${_existingCard!['id']}/record_missing_books/', data: {
          'books': [newRow],
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Recorded \"${book['book_title']}\" onto Library Card!"),
              backgroundColor: const Color(0xFF059669),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (_) {}
    }
  }

  Future<void> _addAllMissingBooksToCard() async {
    if (_missingBooks.isEmpty) return;
    final toAdd = List<Map<String, dynamic>>.from(_missingBooks);
    final newRows = <Map<String, dynamic>>[];

    for (final book in toAdd) {
      final ref = book['issue_id'] ?? book['book_copy_no'];
      final alreadyExists = _circulationRows.any((r) =>
          (r['issue_id'] != null && r['issue_id'] == ref) ||
          (r['book_copy_no'] != null && r['book_copy_no'] == ref));
      if (!alreadyExists) {
        newRows.add({
          'serial_no': _circulationRows.length + newRows.length + 1,
          'book_title': book['book_title'] ?? '',
          'book_copy_no': book['book_copy_no'] ?? '',
          'issued_date': book['issued_date'] ?? DateTime.now().toString().substring(0, 10),
          'return_date': book['return_date'] ?? DateTime.now().add(Duration(days: _loanDays)).toString().substring(0, 10),
          'due_date': book['due_date'] ?? book['return_date'] ?? DateTime.now().add(Duration(days: _loanDays)).toString().substring(0, 10),
          'status': book['status'] ?? 'ISSUED',
          'is_signed': true,
          'issue_id': book['issue_id'],
        });
      }
    }

    setState(() {
      _circulationRows.addAll(newRows);
      _missingBooks.clear();
    });

    if (_existingCard != null && _existingCard!['id'] != null && newRows.isNotEmpty) {
      try {
        final dio = ApiClient().dio;
        await dio.post('/library/cards/${_existingCard!['id']}/record_missing_books/', data: {
          'books': newRows,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Added ${newRows.length} missing books to Library Card!"),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
      } catch (_) {}
    }
  }

  String _calculateReturnDate(String issueDateStr) {
    try {
      final parsed = DateTime.parse(issueDateStr.trim());
      final returnDate = parsed.add(Duration(days: _loanDays));
      return returnDate.toString().substring(0, 10);
    } catch (_) {
      final returnDate = DateTime.now().add(Duration(days: _loanDays));
      return returnDate.toString().substring(0, 10);
    }
  }

  Future<void> _pickIssueDate() async {
    // If not yet filled and a missing book was selected, auto-fetch from DB record
    if (_issueDateController.text.trim().isEmpty && _selectedMissingBook != null && _selectedMissingBook!['issued_date'] != null) {
      _issueDateController.text = _selectedMissingBook!['issued_date'];
      _returnDateController.text = _selectedMissingBook!['due_date'] ?? _selectedMissingBook!['return_date'] ?? _calculateReturnDate(_issueDateController.text);
    }

    DateTime initialDate = DateTime.now();
    if (_issueDateController.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(_issueDateController.text.trim());
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: "Select Date of Issue",
      confirmText: "Set Issue Date",
    );

    if (picked != null) {
      final issueStr = picked.toString().substring(0, 10);
      setState(() {
        _issueDateController.text = issueStr;
        // Auto-fill Date of Return and Due Date based on library configuration settings (_loanDays)
        final autoCalc = _calculateReturnDate(issueStr);
        _returnDateController.text = autoCalc;
        _dueDateController.text = autoCalc;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Issue Date set to $issueStr. Return/Due Date auto-filled as ${_returnDateController.text} (Rule: $_loanDays days loan duration)."),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _pickReturnDate() async {
    DateTime initialDate = DateTime.now().add(Duration(days: _loanDays));
    if (_returnDateController.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(_returnDateController.text.trim());
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: "Select Date of Return (Configured Rule: $_loanDays days)",
      confirmText: "Set Return Date",
    );

    if (picked != null) {
      setState(() {
        _returnDateController.text = picked.toString().substring(0, 10);
      });
    }
  }

  Future<void> _pickDueDate() async {
    DateTime initialDate = DateTime.now().add(Duration(days: _loanDays));
    if (_dueDateController.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(_dueDateController.text.trim());
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: "Select Due Date (Configured Rule: $_loanDays days)",
      confirmText: "Set Due Date",
    );

    if (picked != null) {
      setState(() {
        _dueDateController.text = picked.toString().substring(0, 10);
      });
    }
  }

  void _onBookSelectedFromComponent(Map<String, dynamic>? book) {
    if (book == null) {
      setState(() {
        _selectedBookKey = null;
        _selectedMissingBook = null;
        _bookTitleController.clear();
        _bookBarcodeController.clear();
        _issueDateController.clear();
        _returnDateController.clear();
        _dueDateController.clear();
      });
      return;
    }

    final title = book['book_title'] ?? book['title'] ?? '';
    final copies = book['copies'] as List?;
    String barcode = book['book_copy_no'] ?? '';
    if (barcode.isEmpty && copies != null && copies.isNotEmpty) {
      final firstCopy = copies.first;
      if (firstCopy is Map) {
        barcode = (firstCopy['barcode'] ?? firstCopy['copy_number'] ?? 'CPY-01').toString();
      }
    }
    if (barcode.isEmpty) {
      barcode = 'CPY-01';
    }

    final autoIssue = book['issued_date'] ?? DateTime.now().toString().substring(0, 10);
    final autoReturn = book['due_date'] ?? book['return_date'] ?? _calculateReturnDate(autoIssue);

    setState(() {
      _selectedMissingBook = book;
      _bookTitleController.text = title;
      _bookBarcodeController.text = barcode;
      _issueDateController.text = autoIssue;
      _returnDateController.text = autoReturn;
      _dueDateController.text = autoReturn;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Selected \"$title\". Issue Date auto-fetched. Return & Due Date auto-filled with $_loanDays days rule."),
        backgroundColor: const Color(0xFF13246E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _recordSelectedBookFromComponents() async {
    final title = _bookTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a book from the component dropdown or enter a title."), backgroundColor: Colors.red),
      );
      return;
    }

    final issueDate = _issueDateController.text.trim().isNotEmpty
        ? _issueDateController.text.trim()
        : DateTime.now().toString().substring(0, 10);
    final returnDate = _returnDateController.text.trim().isNotEmpty
        ? _returnDateController.text.trim()
        : _calculateReturnDate(issueDate);
    final dueDate = _dueDateController.text.trim().isNotEmpty
        ? _dueDateController.text.trim()
        : returnDate;
    final barcode = _bookBarcodeController.text.trim().isNotEmpty
        ? _bookBarcodeController.text.trim()
        : 'CPY-01';

    final ref = _selectedMissingBook?['issue_id'] ?? barcode;

    final newRow = <String, dynamic>{
      'serial_no': _circulationRows.length + 1,
      'book_title': title,
      'book_copy_no': barcode,
      'issued_date': issueDate,
      'return_date': returnDate,
      'due_date': dueDate,
      'status': _selectedMissingBook?['status'] ?? 'ISSUED',
      'is_signed': true,
      'issue_id': _selectedMissingBook?['issue_id'],
    };

    // Attach custom component values
    for (final entry in _customComponentControllers.entries) {
      final key = entry.key.toLowerCase().replaceAll(' ', '_');
      newRow[key] = entry.value.text.trim();
      newRow[entry.key] = entry.value.text.trim();
    }

    setState(() {
      _circulationRows.add(newRow);
      if (_selectedMissingBook != null) {
        _missingBooks.removeWhere((b) => (b['issue_id'] == ref || b['book_copy_no'] == ref));
      }
      _selectedBookKey = null;
      _selectedMissingBook = null;
      _bookTitleController.clear();
      _bookBarcodeController.clear();
      _issueDateController.clear();
      _returnDateController.clear();
      _dueDateController.clear();
      for (final ctrl in _customComponentControllers.values) {
        ctrl.clear();
      }
    });

    if (_existingCard != null && _existingCard!['id'] != null) {
      try {
        final dio = ApiClient().dio;
        await dio.post('/library/cards/${_existingCard!['id']}/record_missing_books/', data: {
          'books': [newRow],
        });
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Recorded \"$title\" onto Library Issue Card!"),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _addComponent(String componentName) {
    if (componentName.trim().isEmpty) return;
    if (_components.contains(componentName.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Component \"$componentName\" is already added.")),
      );
      return;
    }
    setState(() {
      _components.add(componentName.trim());
    });
  }

  void _removeComponent(int index) {
    if (index >= 0 && index < _components.length) {
      final comp = _components[index];
      setState(() {
        _components.removeAt(index);
        _customComponentControllers.remove(comp);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Removed \"$comp\" component."),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _pickSignatureImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _signatureImageFile = result.files.first;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Signature \"${_signatureImageFile!.name}\" selected!"),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking image: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Map<String, dynamic> _buildCardData() {
    final isFaculty = _borrowerType == 'FACULTY';
    final List<Map<String, dynamic>> effectiveRows = List<Map<String, dynamic>>.from(_circulationRows);

    if (effectiveRows.isEmpty && _missingBooks.isNotEmpty) {
      for (int i = 0; i < _missingBooks.length; i++) {
        final b = _missingBooks[i];
        effectiveRows.add({
          'serial_no': i + 1,
          'book_title': b['book_title'] ?? 'Library Book',
          'book_copy_no': b['book_copy_no'] ?? b['copy_barcode'] ?? 'CPY-01',
          'issued_date': b['issued_date'] ?? DateTime.now().toString().substring(0, 10),
          'return_date': b['return_date'] ?? _calculateReturnDate(DateTime.now().toString().substring(0, 10)),
          'due_date': b['due_date'] ?? b['return_date'] ?? _calculateReturnDate(DateTime.now().toString().substring(0, 10)),
          'status': b['status'] ?? 'ISSUED',
          'is_signed': true,
          'issue_id': b['issue_id'],
        });
      }
    }

    final inputTitle = _bookTitleController.text.trim();
    if (inputTitle.isNotEmpty) {
      final already = effectiveRows.any((r) =>
        (r['book_title'] ?? '').toString().trim().toLowerCase() == inputTitle.toLowerCase()
      );
      if (!already) {
        final row = <String, dynamic>{
          'serial_no': effectiveRows.length + 1,
          'book_title': inputTitle,
          'book_copy_no': _bookBarcodeController.text.trim().isNotEmpty ? _bookBarcodeController.text.trim() : 'CPY-01',
          'issued_date': _issueDateController.text.trim().isNotEmpty ? _issueDateController.text.trim() : DateTime.now().toString().substring(0, 10),
          'return_date': _returnDateController.text.trim().isNotEmpty ? _returnDateController.text.trim() : _calculateReturnDate(_issueDateController.text),
          'due_date': _dueDateController.text.trim().isNotEmpty ? _dueDateController.text.trim() : (_returnDateController.text.trim().isNotEmpty ? _returnDateController.text.trim() : _calculateReturnDate(_issueDateController.text)),
          'status': _selectedMissingBook?['status'] ?? 'ISSUED',
          'is_signed': true,
          'issue_id': _selectedMissingBook?['issue_id'],
        };
        for (final entry in _customComponentControllers.entries) {
          final key = entry.key.toLowerCase().replaceAll(' ', '_');
          row[key] = entry.value.text.trim();
          row[entry.key] = entry.value.text.trim();
        }
        effectiveRows.add(row);
      }
    }

    return {
      'card_number': _verifiedBorrower?['card_number'] ?? _existingCard?['card_number'] ?? 'LC-2026-0001',
      'borrower_type': _borrowerType,
      'borrower_name': _nameController.text.isNotEmpty ? _nameController.text : (_verifiedBorrower?['name'] ?? 'Rahul Kumar'),
      'student_name': _nameController.text.isNotEmpty ? _nameController.text : (_verifiedBorrower?['name'] ?? 'Rahul Kumar'),
      'student_usn': _usnController.text.isNotEmpty ? _usnController.text : (_verifiedBorrower?['identifier'] ?? '4GE24CS030'),
      'borrower_id_number': _usnController.text.isNotEmpty ? _usnController.text : (_verifiedBorrower?['identifier'] ?? '4GE24CS030'),
      'department_name': _departmentController.text.isNotEmpty ? _departmentController.text : 'Computer Science and Engineering',
      'academic_year': _academicYearController.text.isNotEmpty ? _academicYearController.text : '2025-2026',
      'section': isFaculty ? '' : (_sectionController.text.isNotEmpty ? _sectionController.text : 'A'),
      'roll_no': isFaculty ? '' : (_rollNoController.text.isNotEmpty ? _rollNoController.text : _usnController.text),
      'hod_name': 'hod001',
      'valid_until': '2027-10-15',
      'issued_at': DateTime.now().toString().substring(0, 10),
      'digital_signature_hash': 'SHA256:214496bc0b109ecb...',
      'circulation_rows': effectiveRows,
      'recorded_books': effectiveRows,
      'components': List<String>.from(_components),
      'signature_image_url': null,
    };
  }

  void _previewCard() {
    if (_verifiedBorrower == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please verify borrower first to preview their card."), backgroundColor: Colors.red),
      );
      return;
    }

    final cardData = _buildCardData();
    final effectiveRows = List<Map<String, dynamic>>.from(cardData['circulation_rows'] ?? []);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DigitalLibraryCardWidget(
                cardData: cardData,
                circulationRows: effectiveRows,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitCard({bool submitForApproval = false}) async {
    if (_verifiedBorrower == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please search and verify a borrower first!"), backgroundColor: Colors.red),
      );
      return;
    }

    if (_components.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one library card component."), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dio = ApiClient().dio;
      final formData = FormData();

      formData.fields.add(MapEntry('borrower_type', _borrowerType));
      formData.fields.add(MapEntry('identifier', _usnController.text.trim()));
      formData.fields.add(MapEntry('academic_year', _academicYearController.text.trim()));
      formData.fields.add(MapEntry('section', _sectionController.text.trim()));
      formData.fields.add(MapEntry('roll_no', _rollNoController.text.trim()));
      if (submitForApproval) {
        formData.fields.add(const MapEntry('submit_for_approval', 'true'));
      }

      final List<Map<String, dynamic>> rowsToSave = List<Map<String, dynamic>>.from(_circulationRows);
      final currentTitle = _bookTitleController.text.trim();
      if (currentTitle.isNotEmpty) {
        final already = rowsToSave.any((r) =>
          (r['book_title'] ?? '').toString().trim().toLowerCase() == currentTitle.toLowerCase()
        );
        if (!already) {
          final newRow = <String, dynamic>{
            'serial_no': rowsToSave.length + 1,
            'book_title': currentTitle,
            'book_copy_no': _bookBarcodeController.text.trim().isNotEmpty ? _bookBarcodeController.text.trim() : 'CPY-01',
            'issued_date': _issueDateController.text.trim().isNotEmpty ? _issueDateController.text.trim() : DateTime.now().toString().substring(0, 10),
            'return_date': _returnDateController.text.trim().isNotEmpty ? _returnDateController.text.trim() : _calculateReturnDate(_issueDateController.text),
            'due_date': _dueDateController.text.trim().isNotEmpty ? _dueDateController.text.trim() : (_returnDateController.text.trim().isNotEmpty ? _returnDateController.text.trim() : _calculateReturnDate(_issueDateController.text)),
            'status': _selectedMissingBook?['status'] ?? 'ISSUED',
            'is_signed': true,
            'issue_id': _selectedMissingBook?['issue_id'],
          };
          for (final entry in _customComponentControllers.entries) {
            final key = entry.key.toLowerCase().replaceAll(' ', '_');
            newRow[key] = entry.value.text.trim();
            newRow[entry.key] = entry.value.text.trim();
          }
          rowsToSave.add(newRow);
        }
      }

      // Add components as JSON list
      formData.fields.add(MapEntry('components', jsonEncode(_components)));

      // Add recorded circulation books
      formData.fields.add(MapEntry('recorded_books', jsonEncode(rowsToSave)));

      // Add signature file if uploaded
      if (_signatureImageFile != null && _signatureImageFile!.bytes != null) {
        formData.files.add(
          MapEntry(
            'signature_image',
            MultipartFile.fromBytes(
              _signatureImageFile!.bytes!,
              filename: _signatureImageFile!.name,
            ),
          ),
        );
      } else if (_signatureImageFile != null && _signatureImageFile!.path != null) {
        formData.files.add(
          MapEntry(
            'signature_image',
            await MultipartFile.fromFile(
              _signatureImageFile!.path!,
              filename: _signatureImageFile!.name,
            ),
          ),
        );
      }

      final res = await dio.post('/library/cards/', data: formData);

      if (mounted) {
        setState(() => _isSubmitting = false);
        final Map<String, dynamic> cardData = res.data is Map ? Map<String, dynamic>.from(res.data) : <String, dynamic>{};
        final cardNum = cardData['card_number'] ?? 'Generated';
        final isFaculty = _borrowerType == 'FACULTY';
        final isPendingHod = submitForApproval && !isFaculty;
        final status = cardData['status'] ?? (isPendingHod ? 'PENDING_HOD' : 'ACTIVE');

        // Success Dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isPendingHod ? Icons.send_rounded : Icons.check_circle_rounded,
                  color: const Color(0xFF059669),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isPendingHod
                        ? "Submitted for HOD Approval!"
                        : (isFaculty ? "Faculty Library Card Activated!" : "Library Issue Card Saved!"),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Card Number: $cardNum", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF13246E))),
                const SizedBox(height: 6),
                Text("Borrower: ${_nameController.text} (${_usnController.text})"),
                Text("Department: ${_departmentController.text}"),
                Text("Recorded Books: ${_circulationRows.length}"),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isPendingHod ? Colors.amber.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPendingHod
                        ? "Status: PENDING_HOD • Card is forwarded to HOD for verification & digital signature."
                        : (isFaculty
                            ? "Status: ACTIVE • Faculty cards do not require HOD approval. Card is immediately active."
                            : "Status: $status • Card verified with College Librarian signature."),
                    style: TextStyle(
                      fontSize: 12,
                      color: isPendingHod ? Colors.amber.shade900 : const Color(0xFF059669),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/library/cards');
                },
                child: const Text("Go to Cards List"),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showGeneratedCardModal(cardData);
                },
                icon: const Icon(Icons.remove_red_eye_rounded, size: 16),
                label: const Text("View Yellow Card"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        String msg = "Failed to save card: $e";
        if (e is DioException && e.response?.data != null) {
          final d = e.response!.data;
          if (d is Map && (d['detail'] != null || d['error'] != null)) {
            msg = (d['detail'] ?? d['error']).toString();
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showGeneratedCardModal(Map<String, dynamic> card) {
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/library/cards');
                },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text("Done"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFaculty = _borrowerType == 'FACULTY';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        title: const Text(
          "Create Library Issue Card",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: "Close",
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.go('/library/cards'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Configuration Warning Banner if incomplete
                  if (!_isConfigured)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "Library configuration is incomplete. Rules, quota, and card formats should be configured in Library Configuration.",
                              style: TextStyle(color: Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                            onPressed: () => context.push('/library/configuration'),
                            child: const Text("Configure Rules"),
                          ),
                        ],
                      ),
                    ),

                  // Existing Card Notification Banner
                  if (_existingCard != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.credit_card_rounded, color: Color(0xFF1D4ED8), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Existing Library Card: ${_existingCard!['card_number'] ?? 'LC'} (${_existingCard!['status']})",
                                  style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 13.5, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Preserving all existing card details. Any added books will be updated onto this card without duplicate card generation.",
                                  style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Card 1: Borrower Verification (Matching Image 2 Fee Structure Input style)
                  Container(
                    padding: const EdgeInsets.all(22),
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
                        const Text(
                          "Basic Details — Auto-Fetched",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Verify the student or faculty member to automatically load their registered college records.",
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 18),

                        // Borrower Type Selector
                        Row(
                          children: [
                            const Text("Borrower Type: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                            const SizedBox(width: 14),
                            if (widget.initialBorrowerType?.toUpperCase() == 'STUDENT' || (_verifiedBorrower != null && _borrowerType == 'STUDENT')) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF13246E),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.school_rounded, size: 16, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text("Student Issue Card", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  ],
                                ),
                              ),
                            ] else if (widget.initialBorrowerType?.toUpperCase() == 'FACULTY' || (_verifiedBorrower != null && _borrowerType == 'FACULTY')) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF13246E),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.badge_rounded, size: 16, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text("Faculty Issue Card", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  ],
                                ),
                              ),
                            ] else ...[
                              ChoiceChip(
                                label: const Text("Student"),
                                selected: _borrowerType == 'STUDENT',
                                selectedColor: const Color(0xFF13246E),
                                labelStyle: TextStyle(
                                  color: _borrowerType == 'STUDENT' ? Colors.white : const Color(0xFF334155),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _borrowerType = 'STUDENT';
                                      _verifiedBorrower = null;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(width: 10),
                              ChoiceChip(
                                label: const Text("Faculty"),
                                selected: _borrowerType == 'FACULTY',
                                selectedColor: const Color(0xFF13246E),
                                labelStyle: TextStyle(
                                  color: _borrowerType == 'FACULTY' ? Colors.white : const Color(0xFF334155),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _borrowerType = 'FACULTY';
                                      _verifiedBorrower = null;
                                    });
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Search & Verify Row
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _identifierController,
                                decoration: InputDecoration(
                                  labelText: isFaculty ? "Search Faculty ID *" : "Search USN / Student ID *",
                                  hintText: isFaculty ? "e.g. FAC-001 or Staff Email" : "e.g. 4GE24CS030",
                                  filled: true,
                                  fillColor: const Color(0xFFF1F5F9),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  prefixIcon: const Icon(Icons.person_search_rounded, size: 20, color: Color(0xFF13246E)),
                                ),
                                onSubmitted: (_) => _verifyBorrower(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF13246E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _isVerifying ? null : _verifyBorrower,
                              icon: _isVerifying
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.search_rounded, size: 18),
                              label: const Text("Verify & Fetch", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        if (_verifyError != null) ...[
                          const SizedBox(height: 8),
                          Text(_verifyError!, style: TextStyle(color: Colors.red.shade700, fontSize: 12.5, fontWeight: FontWeight.w500)),
                        ],

                        // Auto-Fetched Fields
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _buildReadonlyField(
                                label: isFaculty ? "Faculty Name" : "Student Name",
                                controller: _nameController,
                                icon: Icons.badge_rounded,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildReadonlyField(
                                label: isFaculty ? "Faculty ID" : "USN",
                                controller: _usnController,
                                icon: Icons.fingerprint_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: _buildReadonlyField(
                                label: "Department",
                                controller: _departmentController,
                                icon: Icons.school_rounded,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: isFaculty
                                  ? _buildReadonlyField(
                                      label: "Designation",
                                      controller: _designationController,
                                      icon: Icons.work_outline_rounded,
                                    )
                                  : _buildReadonlyField(
                                      label: "Semester",
                                      controller: _semesterController,
                                      icon: Icons.calendar_view_month_rounded,
                                    ),
                            ),
                          ],
                        ),

                        // Section and Roll Number (Students only)
                        if (!isFaculty) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildReadonlyField(
                                  label: "Section",
                                  controller: _sectionController,
                                  icon: Icons.class_rounded,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildReadonlyField(
                                  label: "Roll Number / USN",
                                  controller: _rollNoController,
                                  icon: Icons.pin_rounded,
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildReadonlyField(
                                label: "Academic Year",
                                controller: _academicYearController,
                                icon: Icons.date_range_rounded,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 18),
                                    const SizedBox(width: 8),
                                    Text("Free Membership: ₹0 Borrowing • Max $_loanLimit Books • $_loanDays Days", style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Card 2: Dynamic Library Card Components (Matching Image 2 Fee Components workflow)
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(22),
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
                            const Text(
                              "Library Card Components",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${_components.length} Components Configured",
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Configure the components printed on the borrower's official issue card (Name of Book, Issue Date, Return Date, Signature Image).",
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),

                        // List of Components matching Image 2
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _components.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final comp = _components[index];
                            final isSignature = comp.toLowerCase().contains('signature');

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: const Color(0xFF13246E),
                                    child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      comp,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                  if (isSignature) ...[
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        backgroundColor: const Color(0xFFEEF2FF),
                                      ),
                                      icon: const Icon(Icons.upload_file_rounded, size: 16, color: Color(0xFF13246E)),
                                      label: Text(
                                        _signatureImageFile != null ? "Selected: ${_signatureImageFile!.name}" : "Upload Signature",
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                                      ),
                                      onPressed: _pickSignatureImage,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                    tooltip: "Remove Component",
                                    onPressed: () => _removeComponent(index),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        // Add Component Button & Dropdown matching Image 3
                        Row(
                          children: [
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == "+ Add Custom Component") {
                                  _showCustomComponentDialog();
                                } else {
                                  _addComponent(val);
                                }
                              },
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              itemBuilder: (ctx) => _availableComponentTypes
                                  .where((t) => t == "+ Add Custom Component" || !_components.contains(t))
                                  .map((type) => PopupMenuItem(
                                        value: type,
                                        child: Text(
                                          type,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: type == "+ Add Custom Component" ? FontWeight.bold : FontWeight.normal,
                                            color: type == "+ Add Custom Component" ? const Color(0xFF13246E) : null,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFC7D2FE)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.add_rounded, size: 18, color: Color(0xFF13246E)),
                                    SizedBox(width: 6),
                                    Text("Add Component", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF13246E))),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_drop_down_rounded, size: 20, color: Color(0xFF13246E)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton.icon(
                              onPressed: () => _showCustomComponentDialog(),
                              icon: const Icon(Icons.edit_note_rounded, size: 18),
                              label: const Text("Custom Component", style: TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),

                        // Interactive Component Panel for "Name of Book", "Date of Issue", "Date of Return", "Due Date", etc.
                        if (_components.any((c) => [
                          "Name of Book",
                          "Date of Issue",
                          "Date of Return",
                          "Due Date",
                          "Book Barcode / Copy ID",
                        ].contains(c) || (!_availableComponentTypes.contains(c) && c != "+ Add Custom Component"))) ...[
                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.menu_book_rounded, color: Color(0xFF15803D), size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "Book & Circulation Details — Auto Date & Return Filling",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF166534)),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF86EFAC)),
                                      ),
                                      child: Text(
                                        "Configured Rule: $_loanDays Days Loan",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF15803D)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Select an issued book not yet on the card. Date of Issue auto-fetches & opens calendar; Date of Return auto-calculates from configuration settings.",
                                  style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                                ),
                                const SizedBox(height: 14),

                                // 1. Component Dropdown: "Name of Book"
                                if (_components.contains("Name of Book")) ...[
                                  Builder(
                                    builder: (context) {
                                      final selectableBooks = _getSelectableBooks();
                                      final activeBookKey = (selectableBooks.containsKey(_selectedBookKey)) ? _selectedBookKey : null;

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Text(
                                                "Name of Book Component Dropdown",
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E293B)),
                                              ),
                                              if (_missingBooks.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEF3C7),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                                  ),
                                                  child: Text(
                                                    "${_missingBooks.length} unrecorded books issued",
                                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                                  ),
                                                ),
                                              ],
                                              const Spacer(),
                                              InkWell(
                                                onTap: () => _removeComponentByName("Name of Book"),
                                                child: const Tooltip(
                                                  message: "Remove Name of Book component",
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.close_rounded, size: 16, color: Colors.red),
                                                      SizedBox(width: 2),
                                                      Text("Remove", style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          DropdownButtonFormField<String>(
                                            value: activeBookKey,
                                            isExpanded: true,
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: Colors.white,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF86EFAC))),
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF86EFAC))),
                                              prefixIcon: const Icon(Icons.library_books_rounded, size: 20, color: Color(0xFF15803D)),
                                              hintText: selectableBooks.isNotEmpty
                                                  ? "Select issued book to add to Library Card..."
                                                  : "No unrecorded issued books (enter title below)",
                                            ),
                                            items: [
                                              if (selectableBooks.isEmpty)
                                                const DropdownMenuItem<String>(
                                                  value: null,
                                                  child: Text("No unrecorded issued books found", style: TextStyle(fontSize: 12.5, color: Colors.grey)),
                                                ),
                                              ...selectableBooks.entries.map((entry) {
                                                final b = entry.value;
                                                final label = "${b['book_title']} (Barcode: ${b['book_copy_no']}) • Issued: ${b['issued_date']} [UNRECORDED ISSUE]";
                                                return DropdownMenuItem<String>(
                                                  value: entry.key,
                                                  child: Text(
                                                    label,
                                                    style: const TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                );
                                              }),
                                            ],
                                            onChanged: (newKey) {
                                              setState(() {
                                                _selectedBookKey = newKey;
                                                final book = newKey != null ? selectableBooks[newKey] : null;
                                                _onBookSelectedFromComponent(book);
                                              });
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Text inputs for Book Title and Barcode
                                if (_components.contains("Name of Book") || _components.contains("Book Barcode / Copy ID")) ...[
                                  Row(
                                    children: [
                                      if (_components.contains("Name of Book"))
                                        Expanded(
                                          flex: 3,
                                          child: TextField(
                                            controller: _bookTitleController,
                                            decoration: InputDecoration(
                                              labelText: "Book Title *",
                                              hintText: "Selected book title or enter manually",
                                              filled: true,
                                              fillColor: Colors.white,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                              prefixIcon: const Icon(Icons.book_rounded, size: 18, color: Color(0xFF64748B)),
                                            ),
                                          ),
                                        ),
                                      if (_components.contains("Name of Book") && _components.contains("Book Barcode / Copy ID"))
                                        const SizedBox(width: 10),
                                      if (_components.contains("Book Barcode / Copy ID"))
                                        Expanded(
                                          flex: 2,
                                          child: TextField(
                                            controller: _bookBarcodeController,
                                            decoration: InputDecoration(
                                              labelText: "Barcode / Copy ID",
                                              hintText: "e.g. CS-001 or CPY-01",
                                              filled: true,
                                              fillColor: Colors.white,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                              prefixIcon: const Icon(Icons.qr_code_rounded, size: 18, color: Color(0xFF64748B)),
                                              suffixIcon: IconButton(
                                                icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                                                tooltip: "Remove Barcode component",
                                                onPressed: () => _removeComponentByName("Book Barcode / Copy ID"),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                // Date of Issue, Due Date (if active), and Date of Return
                                if (_components.contains("Date of Issue") || _components.contains("Due Date") || _components.contains("Date of Return")) ...[
                                  Row(
                                    children: [
                                      // Date of Issue
                                      if (_components.contains("Date of Issue"))
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Text(
                                                    "Date of Issue Component *",
                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                                                  ),
                                                  const Spacer(),
                                                  InkWell(
                                                    onTap: () => _removeComponentByName("Date of Issue"),
                                                    child: const Tooltip(
                                                      message: "Remove Date of Issue component",
                                                      child: Icon(Icons.close_rounded, size: 16, color: Colors.red),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              InkWell(
                                                onTap: _pickIssueDate,
                                                borderRadius: BorderRadius.circular(8),
                                                child: IgnorePointer(
                                                  child: TextField(
                                                    controller: _issueDateController,
                                                    readOnly: true,
                                                    decoration: InputDecoration(
                                                      hintText: "Tap to auto-fetch & open calendar",
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF86EFAC))),
                                                      prefixIcon: const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF15803D)),
                                                      suffixIcon: const Icon(Icons.edit_calendar_rounded, size: 18, color: Color(0xFF15803D)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (_components.contains("Due Date")) ...[
                                        if (_components.contains("Date of Issue")) const SizedBox(width: 10),
                                        // Due Date Component
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Text(
                                                    "Due Date Component *",
                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "(Auto: $_loanDays d)",
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF15803D)),
                                                  ),
                                                  const Spacer(),
                                                  InkWell(
                                                    onTap: () => _removeComponentByName("Due Date"),
                                                    child: const Tooltip(
                                                      message: "Remove Due Date component",
                                                      child: Icon(Icons.close_rounded, size: 16, color: Colors.red),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              InkWell(
                                                onTap: _pickDueDate,
                                                borderRadius: BorderRadius.circular(8),
                                                child: IgnorePointer(
                                                  child: TextField(
                                                    controller: _dueDateController,
                                                    readOnly: true,
                                                    decoration: InputDecoration(
                                                      hintText: "Auto-calculated due date",
                                                      filled: true,
                                                      fillColor: const Color(0xFFF8FAFC),
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF86EFAC))),
                                                      prefixIcon: const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF15803D)),
                                                      suffixIcon: const Icon(Icons.edit_calendar_outlined, size: 18, color: Color(0xFF64748B)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (_components.contains("Date of Return")) ...[
                                        if (_components.contains("Date of Issue") || _components.contains("Due Date")) const SizedBox(width: 10),
                                        // Date of Return
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Text(
                                                    "Date of Return Component *",
                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "(Auto: $_loanDays d rule)",
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF15803D)),
                                                  ),
                                                  const Spacer(),
                                                  InkWell(
                                                    onTap: () => _removeComponentByName("Date of Return"),
                                                    child: const Tooltip(
                                                      message: "Remove Date of Return component",
                                                      child: Icon(Icons.close_rounded, size: 16, color: Colors.red),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              InkWell(
                                                onTap: _pickReturnDate,
                                                borderRadius: BorderRadius.circular(8),
                                                child: IgnorePointer(
                                                  child: TextField(
                                                    controller: _returnDateController,
                                                    readOnly: true,
                                                    decoration: InputDecoration(
                                                      hintText: "Auto-calculated using $_loanDays days rule",
                                                      filled: true,
                                                      fillColor: const Color(0xFFF8FAFC),
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                                      prefixIcon: const Icon(Icons.event_available_rounded, size: 18, color: Color(0xFF15803D)),
                                                      suffixIcon: const Icon(Icons.edit_calendar_outlined, size: 18, color: Color(0xFF64748B)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                // Custom component input fields
                                for (final comp in _components) ...[
                                  if (![
                                    "Name of Book",
                                    "Date of Issue",
                                    "Date of Return",
                                    "Due Date",
                                    "Signature Image",
                                    "Book Barcode / Copy ID",
                                    "+ Add Custom Component",
                                  ].contains(comp)) ...[
                                    const SizedBox(height: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              "$comp Component",
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                                            ),
                                            const Spacer(),
                                            InkWell(
                                              onTap: () => _removeComponentByName(comp),
                                              child: const Tooltip(
                                                message: "Remove component",
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.close_rounded, size: 15, color: Colors.red),
                                                    SizedBox(width: 2),
                                                    Text("Remove", style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: _getCustomController(comp),
                                          decoration: InputDecoration(
                                            labelText: "$comp Component",
                                            hintText: "Enter value for $comp (will appear on Library Issue Card)",
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF86EFAC))),
                                            prefixIcon: const Icon(Icons.extension_rounded, size: 18, color: Color(0xFF15803D)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                ],
                                const SizedBox(height: 8),

                                // Record Book Button
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF15803D),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: _recordSelectedBookFromComponents,
                                      icon: const Icon(Icons.add_task_rounded, size: 18),
                                      label: const Text(
                                        "+ Add / Record Book to Library Card",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Missing Books from Library Card Section
                  if (_missingBooks.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.amber.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.bookmark_add_rounded, color: Color(0xFFD97706), size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Missing Books from Issue Card (${_missingBooks.length} unrecorded)",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF92400E)),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD97706),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: _addAllMissingBooksToCard,
                                icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                                label: Text("Add All (${_missingBooks.length}) Books to Card", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "These books have been checked out to this ${_borrowerType.toLowerCase()} in circulation, but are not yet recorded on their library issue card. Issue dates are auto-fetched and return dates are calculated dynamically using the active borrowing rule ($_loanDays days).",
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF78350F)),
                          ),
                          const SizedBox(height: 14),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _missingBooks.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (ctx, idx) {
                              final b = _missingBooks[idx];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: const Color(0xFFD97706),
                                      child: Text("${idx + 1}", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(b['book_title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                          Text("Barcode: ${b['book_copy_no'] ?? 'N/A'}", style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("Issue Date (Auto)", style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                          Text(b['issued_date'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Due Date ($_loanDays d rule)", style: const TextStyle(fontSize: 10.5, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                                          Text(b['due_date'] ?? b['return_date'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF13246E),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      onPressed: () => _addMissingBookToCard(b),
                                      icon: const Icon(Icons.add_rounded, size: 16),
                                      label: const Text("Add to Card", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Card 3: Real Circulation Loans Preview
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(22),
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
                            Text(
                              "Recorded Circulation Loans (${_circulationRows.length})",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            if (_isLoadingLoans)
                              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Books currently recorded on this card. Loan period dynamically calculated using Library Configuration rule: $_loanDays days for ${_borrowerType.toLowerCase()}s.",
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 14),

                        if (_circulationRows.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              "No active or past book loans recorded. Issue card will have blank circulation lines ready for borrow checkout.",
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _circulationRows.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 6),
                            itemBuilder: (ctx, idx) {
                              final row = _circulationRows[idx];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Text("${row['serial_no'] ?? (idx + 1)}.", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 3,
                                      child: Text(row['book_title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text("Barcode: ${row['book_copy_no'] ?? ''}", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text("Issued: ${row['issued_date'] ?? ''}", style: const TextStyle(fontSize: 12)),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text("Due: ${row['due_date'] ?? row['return_date'] ?? ''}", style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text("Digitally Signed", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  // Bottom Action Buttons
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: const BorderSide(color: Color(0xFF13246E), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _previewCard,
                          icon: const Icon(Icons.visibility_rounded, color: Color(0xFF13246E)),
                          label: const Text(
                            "Preview Card",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF13246E)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: const BorderSide(color: Color(0xFF059669), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isSubmitting ? null : () => _submitCard(submitForApproval: false),
                          icon: const Icon(Icons.save_rounded, color: Color(0xFF059669)),
                          label: Text(
                            _borrowerType == 'FACULTY'
                                ? (_existingCard != null ? "Save Faculty Card" : "Generate Faculty Card")
                                : (_existingCard != null ? "Save Card Updates" : "Save as Draft"),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF059669)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_borrowerType != 'FACULTY') ...[
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13246E),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isSubmitting ? null : () => _submitCard(submitForApproval: true),
                            icon: _isSubmitting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.send_rounded, size: 20),
                            label: const Text(
                              "Submit for HOD Approval",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                            ),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isSubmitting ? null : () => _submitCard(submitForApproval: false),
                            icon: _isSubmitting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.verified_rounded, size: 20),
                            label: const Text(
                              "Issue & Activate Card",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadonlyField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: true,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: "Auto-fetched",
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
      ],
    );
  }

  void _showCustomComponentDialog() {
    final customCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Custom Card Component"),
        content: TextField(
          controller: customCtrl,
          decoration: const InputDecoration(
            hintText: "e.g. Borrower Signature, Department Code",
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
            onPressed: () {
              final text = customCtrl.text.trim();
              if (text.isNotEmpty) {
                _addComponent(text);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }
}
