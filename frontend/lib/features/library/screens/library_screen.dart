import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/library/widgets/digital_library_card_widget.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data states
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _myIssues = [];
  List<Map<String, dynamic>> _myRequests = [];
  List<Map<String, dynamic>> _myFines = [];
  Map<String, dynamic>? _myCard;
  List<Map<String, dynamic>> _myCirculationRows = [];
  bool _hasCard = false;

  bool _isLoading = true;
  String? _errorMessage;

  // Search & Category Filters
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  // Library Card Application Controllers
  bool _isSubmittingCard = false;
  final TextEditingController _acadYearController = TextEditingController(text: '2025-2026');
  final TextEditingController _sectionController = TextEditingController(text: 'A');
  final TextEditingController _feeRefController = TextEditingController(text: 'CARD-FEE-100');
  int _selectedSemester = 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _acadYearController.dispose();
    _sectionController.dispose();
    _feeRefController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;

      final results = await Future.wait([
        dio.get('/library/books/'),
        dio.get('/library/issues/').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: [])),
        dio.get('/library/requests/').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: [])),
        dio.get('/library/fines/').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: [])),
        dio.get('/library/cards/my_card/').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: {'has_card': false})),
      ]);

      final booksData = results[0].data;
      final issuesData = results[1].data;
      final requestsData = results[2].data;
      final finesData = results[3].data;
      final cardRes = results[4].data;

      final List booksList = booksData is List ? booksData : (booksData is Map && booksData['results'] is List ? booksData['results'] : []);
      final List issuesList = issuesData is List ? issuesData : (issuesData is Map && issuesData['results'] is List ? issuesData['results'] : []);
      final List requestsList = requestsData is List ? requestsData : (requestsData is Map && requestsData['results'] is List ? requestsData['results'] : []);
      final List finesList = finesData is List ? finesData : (finesData is Map && finesData['results'] is List ? finesData['results'] : []);

      Map<String, dynamic>? myCard;
      List<Map<String, dynamic>> circRows = [];
      bool hasCard = false;
      if (cardRes is Map && cardRes['has_card'] == true) {
        hasCard = true;
        if (cardRes['card'] is Map) {
          myCard = Map<String, dynamic>.from(cardRes['card'] as Map);
        }
        if (cardRes['circulation_rows'] is List) {
          circRows = List<Map<String, dynamic>>.from(cardRes['circulation_rows'] as List);
        }
      }

      if (mounted) {
        setState(() {
          _books = List<Map<String, dynamic>>.from(booksList);
          _myIssues = List<Map<String, dynamic>>.from(issuesList);
          _myRequests = List<Map<String, dynamic>>.from(requestsList);
          _myFines = List<Map<String, dynamic>>.from(finesList);
          _hasCard = hasCard;
          _myCard = myCard;
          _myCirculationRows = circRows;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load library resources: $e";
        });
      }
    }
  }

  List<String> get _categories {
    final set = <String>{'All'};
    for (final b in _books) {
      final cat = b['category']?.toString().trim();
      if (cat != null && cat.isNotEmpty) {
        set.add(cat);
      }
    }
    return set.toList();
  }

  List<Map<String, dynamic>> get _filteredBooks {
    return _books.where((b) {
      final title = (b['title'] ?? '').toString().toLowerCase();
      final authors = (b['authors'] ?? '').toString().toLowerCase();
      final isbn = (b['isbn'] ?? '').toString().toLowerCase();
      final cat = (b['category'] ?? '').toString();

      final matchesQuery = _searchQuery.isEmpty ||
          title.contains(_searchQuery.toLowerCase()) ||
          authors.contains(_searchQuery.toLowerCase()) ||
          isbn.contains(_searchQuery.toLowerCase());

      final matchesCat = _selectedCategory == 'All' || cat.toLowerCase() == _selectedCategory.toLowerCase();

      return matchesQuery && matchesCat;
    }).toList();
  }

  Future<void> _borrowBook(Map<String, dynamic> book) async {
    final copies = (book['copies'] as List?) ?? [];
    Map<String, dynamic>? availableCopy;
    for (final c in copies) {
      if (c['status'] == 'available') {
        availableCopy = Map<String, dynamic>.from(c as Map);
        break;
      }
    }

    if (availableCopy == null) {
      _showRequestDialog(prefilledTitle: book['title']?.toString(), prefilledAuthors: book['authors']?.toString());
      return;
    }

    final dueDate = DateTime.now().add(const Duration(days: 14));
    final dueDateStr = "${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}";

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.bookmark_added_rounded, color: Color(0xFF13246E)),
            const SizedBox(width: 10),
            const Text("Borrow Book", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book['title'] ?? 'Selected Book',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF13246E)),
            ),
            const SizedBox(height: 6),
            Text("Authors: ${book['authors'] ?? 'N/A'}", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            Text("Copy #: ${availableCopy?['copy_number']} (Barcode: ${availableCopy?['barcode'] ?? 'N/A'})", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            Text("Shelf Location: ${availableCopy?['shelf_location'] ?? 'General Section'}", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF13246E)),
                const SizedBox(width: 8),
                Text("Standard Loan Period: 14 Days", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Text("Due Date: $dueDateStr", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirm Borrow"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dio = ApiClient().dio;
        await dio.post('/library/issues/', data: {
          'copy_id': availableCopy['id'],
          'due_date': dueDateStr,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Successfully borrowed \"${book['title']}\"!"),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _fetchAllData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error borrowing book: $e"),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showRequestDialog({String? prefilledTitle, String? prefilledAuthors}) {
    final titleCtrl = TextEditingController(text: prefilledTitle ?? '');
    final authorCtrl = TextEditingController(text: prefilledAuthors ?? '');
    final reasonCtrl = TextEditingController();
    String urgency = 'MEDIUM';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF13246E)),
              SizedBox(width: 10),
              Text("Request New Book", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Submit a book purchase or acquisition request to the Library Committee.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: "Book Title *",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: authorCtrl,
                  decoration: const InputDecoration(
                    labelText: "Authors / Publisher",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: "Academic Need / Reason *",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: urgency,
                  decoration: const InputDecoration(
                    labelText: "Urgency Level",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'LOW', child: Text("Low Priority")),
                    DropdownMenuItem(value: 'MEDIUM', child: Text("Medium Priority")),
                    DropdownMenuItem(value: 'HIGH', child: Text("High Priority (Exam Prep / Project)")),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => urgency = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13246E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                try {
                  final dio = ApiClient().dio;
                  await dio.post('/library/requests/', data: {
                    'title': titleCtrl.text.trim(),
                    'authors': authorCtrl.text.trim(),
                    'reason': reasonCtrl.text.trim(),
                    'urgency': urgency,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Book acquisition request submitted successfully!"),
                        backgroundColor: Color(0xFF059669),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    _fetchAllData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to submit request: $e"), backgroundColor: Colors.red.shade700),
                    );
                  }
                }
              },
              child: const Text("Submit Request"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalBooks = _books.length;
    int availableCopies = 0;
    for (final b in _books) {
      availableCopies += (b['available_copies'] as num?)?.toInt() ?? 0;
    }
    int activeIssues = _myIssues.where((i) => i['status'] == 'issued').length;
    int pendingRequests = _myRequests.where((r) => r['status'] == 'pending').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Campus Library & Resource Center",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: "Refresh Catalog",
            onPressed: _fetchAllData,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.auto_stories_rounded, size: 20),
              text: "Catalog (${_books.length})",
            ),
            Tab(
              icon: const Icon(Icons.bookmarks_rounded, size: 20),
              text: "My Borrowed ($activeIssues)",
            ),
            Tab(
              icon: const Icon(Icons.pending_actions_rounded, size: 20),
              text: "Requests ($pendingRequests)",
            ),
            Tab(
              icon: const Icon(Icons.receipt_long_rounded, size: 20),
              text: "Fines (${_myFines.length})",
            ),
            Tab(
              icon: const Icon(Icons.badge_rounded, size: 20),
              text: _hasCard && _myCard?['status'] == 'ACTIVE' ? "My Issue Card" : "Library Card",
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF13246E)),
            )
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
                          onPressed: _fetchAllData,
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Top Metric KPI Cards Bar
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          _buildKpiCard("TOTAL TITLES", "$totalBooks Books", Icons.menu_book_rounded, const Color(0xFF13246E)),
                          const SizedBox(width: 12),
                          _buildKpiCard("AVAILABLE COPIES", "$availableCopies In Stock", Icons.inventory_2_rounded, const Color(0xFF059669)),
                          const SizedBox(width: 12),
                          _buildKpiCard("MY BORROWED", "$activeIssues Active", Icons.account_circle_rounded, const Color(0xFF2563EB)),
                          const SizedBox(width: 12),
                          _buildKpiCard("LIBRARY CARD", _hasCard ? (_myCard?['status'] ?? 'APPLIED') : 'NOT ISSUED', Icons.badge_rounded, _hasCard && _myCard?['status'] == 'ACTIVE' ? const Color(0xFF059669) : const Color(0xFFD97706)),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Tab Views
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCatalogTab(),
                          _buildMyIssuesTab(),
                          _buildMyRequestsTab(),
                          _buildFinesTab(),
                          _buildMyCardTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: Catalog
  Widget _buildCatalogTab() {
    final books = _filteredBooks;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Filter Header
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: "Search books by title, author, or ISBN...",
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF13246E)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showRequestDialog(),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text("Request New Book", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: const Color(0xFF13246E),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isSelected ? const Color(0xFF13246E) : const Color(0xFFCBD5E1)),
                    ),
                    onSelected: (val) {
                      setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Catalog Grid
          if (books.isEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      "No books found matching \"$_searchQuery\"",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    const Text("Can't find what you're looking for? Click \"Request New Book\" above."),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 1100 ? 3 : (constraints.maxWidth > 700 ? 2 : 1);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 260,
                  ),
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final b = books[index];
                    return _buildBookCard(b);
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> b) {
    final avail = (b['available_copies'] as num?)?.toInt() ?? 0;
    final total = (b['total_copies'] as num?)?.toInt() ?? 0;
    final isAvailable = avail > 0;
    final copies = (b['copies'] as List?) ?? [];
    String shelfLoc = 'General Stack';
    if (copies.isNotEmpty && copies.first is Map && copies.first['shelf_location'] != null) {
      shelfLoc = copies.first['shelf_location'].toString();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Category tag & Availability badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  b['category']?.toString() ?? 'General',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3730A3)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAvailable ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isAvailable ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                ),
                child: Text(
                  isAvailable ? "$avail / $total Available" : "Out of Stock",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isAvailable ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title & Authors
          Text(
            b['title']?.toString() ?? 'Untitled Book',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A), height: 1.25),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  b['authors']?.toString() ?? 'Author unknown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Edition & Publisher
          Text(
            "${b['edition'] ?? ''} • ${b['publisher'] ?? ''} (${b['year'] ?? ''})",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),

          const Spacer(),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          // Bottom Shelf location & Borrow action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shelves, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    shelfLoc,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAvailable ? const Color(0xFF13246E) : const Color(0xFF64748B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _borrowBook(b),
                icon: Icon(isAvailable ? Icons.bookmark_add_rounded : Icons.add_shopping_cart_rounded, size: 14),
                label: Text(isAvailable ? "Borrow" : "Request"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 2: My Borrowed Books
  Widget _buildMyIssuesTab() {
    if (_myIssues.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book_rounded, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text("No active book issues.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              const Text("Browse the catalog to borrow textbooks or references."),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                onPressed: () => _tabController.animateTo(0),
                child: const Text("Go to Catalog"),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _myIssues.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final issue = _myIssues[index];
        final title = issue['book_title'] ?? issue['copy']?['book'] ?? 'Issued Book';
        final authors = issue['book_authors'] ?? 'Faculty & Student Reference';
        final issueId = issue['issue_id'] ?? 'ISSUE-${issue['id']}';
        final issuedAt = (issue['issued_at'] ?? '').toString().split('T').first;
        final dueDate = (issue['due_date'] ?? '').toString().split('T').first;
        final status = (issue['status'] ?? 'issued').toString().toUpperCase();
        final isReturned = status == 'RETURNED';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isReturned ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                child: Icon(
                  isReturned ? Icons.check_circle_rounded : Icons.book_rounded,
                  color: isReturned ? const Color(0xFF059669) : const Color(0xFF13246E),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isReturned ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isReturned ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isReturned ? const Color(0xFF065F46) : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("Authors: $authors", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        _buildMetaPill(Icons.fingerprint, "Issue ID: $issueId"),
                        _buildMetaPill(Icons.event, "Issued: $issuedAt"),
                        _buildMetaPill(Icons.event_busy, "Due: $dueDate", isWarning: !isReturned),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetaPill(IconData icon, String text, {bool isWarning = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: isWarning ? Colors.orange.shade800 : const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isWarning ? FontWeight.bold : FontWeight.w500,
            color: isWarning ? Colors.orange.shade900 : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  // TAB 3: My Requests
  Widget _buildMyRequestsTab() {
    if (_myRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pending_actions_rounded, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text("No pending book acquisition requests.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              const Text("Request textbooks or research monographs not available in the library."),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                onPressed: () => _showRequestDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Request New Book"),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _myRequests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final req = _myRequests[index];
        final title = req['title'] ?? 'Requested Title';
        final authors = req['authors'] ?? 'N/A';
        final status = (req['status'] ?? 'pending').toString().toUpperCase();
        final urgency = (req['urgency'] ?? 'MEDIUM').toString().toUpperCase();
        final date = (req['created_at'] ?? '').toString().split('T').first;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text("Authors: $authors", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              if (req['reason'] != null && req['reason'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text("Reason: ${req['reason']}", style: TextStyle(color: Colors.grey.shade800, fontSize: 12, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: urgency == 'HIGH' ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "Urgency: $urgency",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: urgency == 'HIGH' ? Colors.red.shade800 : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text("Submitted on: $date", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // TAB 4: Fines
  Widget _buildFinesTab() {
    if (_myFines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_rounded, size: 54, color: Color(0xFF059669)),
              const SizedBox(height: 14),
              const Text(
                "No Outstanding Library Dues",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                "All borrowed books are in order and your account has zero penalty dues.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _myFines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final f = _myFines[index];
        final amount = f['amount'] ?? 0;
        final reason = f['reason'] ?? 'Late return';
        final isPaid = f['paid'] == true;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Penalty Fine: ₹$amount", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Text("Reason: $reason", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPaid ? "PAID" : "UNPAID",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isPaid ? const Color(0xFF059669) : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // TAB 5: My Digital Library Issue Card
  Widget _buildMyCardTab() {
    if (!_hasCard || _myCard == null) {
      return _buildApplyCardView();
    }

    final status = (_myCard!['status'] ?? 'PENDING_HOD').toString().toUpperCase();

    if (status == 'PENDING_HOD') {
      return _buildCardStatusView(
        title: "Application Pending HOD Verification",
        subtitle: "Your library card application has been submitted and is awaiting verification by your Head of Department.",
        statusColor: const Color(0xFFD97706),
        icon: Icons.hourglass_top_rounded,
        stepIndex: 1,
      );
    } else if (status == 'HOD_APPROVED') {
      return _buildCardStatusView(
        title: "Verified by HOD — Awaiting Card Issuance",
        subtitle: "Your department HOD has approved your application! The Library Staff is now generating your card number and digital cryptographic seal.",
        statusColor: const Color(0xFF2563EB),
        icon: Icons.assignment_turned_in_rounded,
        stepIndex: 2,
      );
    } else if (status == 'REJECTED') {
      final reason = _myCard!['rejection_reason'] ?? 'Information could not be verified by department.';
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.red.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(Icons.cancel_rounded, size: 56, color: Colors.red.shade600),
                    const SizedBox(height: 16),
                    const Text(
                      "Application Returned by HOD",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Reason: $reason",
                        style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w600, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13246E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => setState(() => _hasCard = false),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text("Re-Apply with Corrected Details"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ACTIVE, SUSPENDED, or EXPIRED
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Action / Status Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: status == 'ACTIVE' ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: status == 'ACTIVE' ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            status == 'ACTIVE' ? Icons.check_circle_rounded : Icons.warning_rounded,
                            size: 16,
                            color: status == 'ACTIVE' ? const Color(0xFF059669) : Colors.red.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "STATUS: $status",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: status == 'ACTIVE' ? const Color(0xFF059669) : Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF13246E),
                        side: const BorderSide(color: Color(0xFF13246E)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Digital Library Card is active and ready for circulation verification."),
                            backgroundColor: Color(0xFF13246E),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text("Print / PDF"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Yellow Card matching Image 1
              DigitalLibraryCardWidget(
                cardData: _myCard!,
                circulationRows: _myCirculationRows,
              ),

              const SizedBox(height: 24),

              // Library Privileges & Borrowing Guidelines Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.info_outline_rounded, color: Color(0xFF13246E), size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Library Privileges & Borrowing Guidelines",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildGuidelineRow(Icons.check_circle_outline, "Free Borrowing: All college books and reference material are completely free to borrow."),
                    _buildGuidelineRow(Icons.book_rounded, "Loan Quota: Maximum 3 simultaneous active book loans per student."),
                    _buildGuidelineRow(Icons.calendar_today_rounded, "Loan Duration: Standard loan duration is 14 calendar days per issue."),
                    _buildGuidelineRow(Icons.currency_rupee_rounded, "Charges & Fines: College policy ensures ₹0 borrowing fees and ₹0 late return penalties."),
                    _buildGuidelineRow(Icons.qr_code_rounded, "Verification: Present this digital issue card or QR code token at the circulation checkout desk."),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuidelineRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardStatusView({
    required String title,
    required String subtitle,
    required Color statusColor,
    required IconData icon,
    required int stepIndex,
  }) {
    final card = _myCard ?? {};
    final deptName = card['department_name'] ?? 'Department';
    final appliedAt = card['created_at'] != null ? card['created_at'].toString().substring(0, 10) : 'Recent';
    final feeRef = card['fee_payment_reference'] ?? 'CASH-COUNTER';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: statusColor.withOpacity(0.12),
                        child: Icon(icon, color: statusColor, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                            const SizedBox(height: 4),
                            Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 36),

                  // Progress Step Visualizer
                  Row(
                    children: [
                      _buildStepIndicator("1. Applied & Paid", true, true),
                      Expanded(child: Container(height: 3, color: stepIndex >= 2 ? const Color(0xFF059669) : const Color(0xFFE2E8F0))),
                      _buildStepIndicator("2. HOD Verified", stepIndex >= 2, stepIndex == 1),
                      Expanded(child: Container(height: 3, color: stepIndex >= 3 ? const Color(0xFF059669) : const Color(0xFFE2E8F0))),
                      _buildStepIndicator("3. Card Issued", stepIndex >= 3, stepIndex == 2),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Summary Details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow("Department", deptName),
                        _buildDetailRow("Applied Date", appliedAt),
                        _buildDetailRow("Registration Fee", "₹100.00 (PAID)"),
                        _buildDetailRow("Payment Reference", feeRef),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13246E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _fetchAllData,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text("Refresh Status"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(String label, bool isDone, bool isCurrent) {
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: isDone
              ? const Color(0xFF059669)
              : (isCurrent ? const Color(0xFFD97706) : const Color(0xFFCBD5E1)),
          child: Icon(
            isDone ? Icons.check : (isCurrent ? Icons.circle : Icons.circle_outlined),
            size: 14,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isDone || isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isDone ? const Color(0xFF059669) : (isCurrent ? const Color(0xFFD97706) : const Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  // Application Form View for students without a library card
  Widget _buildApplyCardView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7CA18).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF7CA18)),
                        ),
                        child: const Icon(Icons.badge_rounded, color: Color(0xFFB45309), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Apply for Digital Library Issue Card",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Books are free to borrow! A one-time ₹100 registration fee generates your permanent card with HOD verification.",
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Policy notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Workflow: Application submitted -> HOD verifies USN and enrollment -> Library Staff activates card and generates digital barcode seal.",
                            style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Academic Year
                  const Text("Academic Year", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _acadYearController,
                    decoration: InputDecoration(
                      hintText: "e.g. 2025-2026",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Semester & Section
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Current Semester", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              value: _selectedSemester,
                              items: List.generate(8, (i) => DropdownMenuItem(value: i + 1, child: Text("Semester ${i + 1}"))),
                              onChanged: (v) => setState(() => _selectedSemester = v ?? 1),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Section", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _sectionController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                hintText: "e.g. A, B, C",
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Fee Payment Reference
                  const Text("Card Fee Payment Reference (₹100)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _feeRefController,
                    decoration: InputDecoration(
                      hintText: "e.g. FEE-REC-2026-001 or UPI Transaction ID",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13246E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isSubmittingCard ? null : _submitCardApplication,
                    child: _isSubmittingCard
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Submit Application for HOD Approval (₹100)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitCardApplication() async {
    setState(() => _isSubmittingCard = true);
    try {
      final dio = ApiClient().dio;
      await dio.post('/library/cards/apply/', data: {
        'academic_year': _acadYearController.text.trim(),
        'semester': _selectedSemester,
        'section': _sectionController.text.trim().toUpperCase(),
        'fee_payment_reference': _feeRefController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Library card application submitted successfully! Forwarded to HOD for verification."),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _fetchAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to apply for library card: $e"),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingCard = false);
      }
    }
  }
}
