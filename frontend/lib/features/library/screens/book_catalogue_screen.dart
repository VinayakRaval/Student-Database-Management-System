import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/api_client.dart';

class BookCatalogueScreen extends StatefulWidget {
  const BookCatalogueScreen({super.key});

  @override
  State<BookCatalogueScreen> createState() => _BookCatalogueScreenState();
}

class _BookCatalogueScreenState extends State<BookCatalogueScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _books = [];

  // Filters matching Image 1 (Shelf/Location omitted as requested)
  String _searchQuery = '';
  String _selectedCategory = 'All Categories';
  String _selectedAuthor = 'All Authors';
  String _selectedAvailability = 'All Status'; // All Status, Available, Partially Available, All Issued
  String _sortBy = 'Recently Added'; // Recently Added, Title (A-Z), Most Copies

  // Pagination matching Image 1
  int _currentPage = 1;
  final int _pageSize = 8;

  @override
  void initState() {
    super.initState();
    _fetchCatalogue();
  }

  Future<void> _fetchCatalogue() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/books/');
      final List list = res.data is List ? res.data : (res.data is Map && res.data['results'] is List ? res.data['results'] : []);
      if (mounted) {
        setState(() {
          _books = List<Map<String, dynamic>>.from(list);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load book inventory: $e";
        });
      }
    }
  }

  List<String> get _categories {
    final set = <String>{'All Categories'};
    for (final b in _books) {
      final c = b['category']?.toString().trim();
      if (c != null && c.isNotEmpty) set.add(c);
    }
    // Also include standard 4 departments
    set.addAll([
      'Computer Science and Engineering',
      'Electronics and Communication Engineering',
      'Civil Engineering',
      'Mechanical Engineering',
    ]);
    return set.toList();
  }

  List<String> get _authors {
    final set = <String>{'All Authors'};
    for (final b in _books) {
      final a = b['authors']?.toString().trim();
      if (a != null && a.isNotEmpty) set.add(a);
    }
    return set.toList();
  }

  int get _totalTitles => _books.length;

  int get _totalCopies {
    int sum = 0;
    for (final b in _books) {
      sum += (b['total_copies'] as int?) ?? ((b['copies'] as List?)?.length ?? 0);
    }
    return sum;
  }

  int get _availableCopies {
    int sum = 0;
    for (final b in _books) {
      if (b['available_copies'] is int) {
        sum += b['available_copies'] as int;
      } else {
        final copies = (b['copies'] as List?) ?? [];
        sum += copies.where((c) => (c['status'] ?? '').toString().toLowerCase() == 'available').length;
      }
    }
    return sum;
  }

  int get _issuedCopies {
    int sum = 0;
    for (final b in _books) {
      final copies = (b['copies'] as List?) ?? [];
      sum += copies.where((c) => (c['status'] ?? '').toString().toLowerCase() == 'issued').length;
    }
    return sum;
  }

  List<Map<String, dynamic>> get _filteredBooks {
    var list = _books.where((b) {
      final title = (b['title'] ?? '').toString().toLowerCase();
      final author = (b['authors'] ?? '').toString().toLowerCase();
      final isbn = (b['isbn'] ?? '').toString().toLowerCase();
      final cat = (b['category'] ?? '').toString();

      // Search match
      final q = _searchQuery.toLowerCase().trim();
      bool matchesSearch = q.isEmpty ||
          title.contains(q) ||
          author.contains(q) ||
          isbn.contains(q);

      if (!matchesSearch && b['copies'] is List) {
        for (final c in b['copies']) {
          final bar = (c['barcode'] ?? c['copy_number'] ?? '').toString().toLowerCase();
          if (bar.contains(q)) {
            matchesSearch = true;
            break;
          }
        }
      }

      // Category match
      final matchesCat = _selectedCategory == 'All Categories' || cat.toLowerCase() == _selectedCategory.toLowerCase();

      // Author match
      final matchesAuth = _selectedAuthor == 'All Authors' || (b['authors'] ?? '').toString() == _selectedAuthor;

      // Availability match
      int avail = b['available_copies'] is int
          ? b['available_copies']
          : ((b['copies'] as List?)?.where((c) => (c['status'] ?? '').toString().toLowerCase() == 'available').length ?? 0);
      int total = (b['total_copies'] as int?) ?? ((b['copies'] as List?)?.length ?? 0);

      bool matchesAvail = true;
      if (_selectedAvailability == 'Available') {
        matchesAvail = avail > 0 && avail == total;
      } else if (_selectedAvailability == 'Partially Available') {
        matchesAvail = avail > 0 && avail < total;
      } else if (_selectedAvailability == 'All Issued') {
        matchesAvail = avail == 0 && total > 0;
      }

      return matchesSearch && matchesCat && matchesAuth && matchesAvail;
    }).toList();

    // Sort
    if (_sortBy == 'Recently Added') {
      list.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
    } else if (_sortBy == 'Title (A-Z)') {
      list.sort((a, b) => (a['title'] ?? '').toString().compareTo((b['title'] ?? '').toString()));
    } else if (_sortBy == 'Title (Z-A)') {
      list.sort((a, b) => (b['title'] ?? '').toString().compareTo((a['title'] ?? '').toString()));
    } else if (_sortBy == 'Most Copies') {
      list.sort((a, b) {
        int ca = (a['total_copies'] as int?) ?? 0;
        int cb = (b['total_copies'] as int?) ?? 0;
        return cb.compareTo(ca);
      });
    }

    return list;
  }

  void _exportCsv() {
    final list = _filteredBooks;
    if (list.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln("#,Book Title,Author,ISBN,Category,Available Copies,Total Copies,Status");
    for (int i = 0; i < list.length; i++) {
      final b = list[i];
      final title = '"${(b['title'] ?? '').replaceAll('"', '""')}"';
      final author = '"${(b['authors'] ?? '').replaceAll('"', '""')}"';
      final isbn = b['isbn'] ?? '';
      final cat = b['category'] ?? '';
      final avail = b['available_copies'] ?? 0;
      final total = b['total_copies'] ?? 0;
      final status = avail == total ? 'Available' : (avail > 0 ? 'Partially Available' : 'All Issued');
      buffer.writeln("${i + 1},$title,$author,$isbn,$cat,$avail,$total,$status");
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Exported ${list.length} inventory records to CSV successfully!"),
        backgroundColor: const Color(0xFF059669),
      ),
    );
  }

  void _showBookDetailDialog(Map<String, dynamic> book) {
    final copies = (book['copies'] as List?) ?? [];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: Color(0xFF13246E)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                book['title'] ?? 'Book Details',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Author: ${book['authors'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 4),
                Text("ISBN: ${book['isbn'] ?? 'N/A'} • Category: ${book['category'] ?? 'General'}", style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
                const SizedBox(height: 4),
                Text("Department: ${book['department_name'] ?? 'General Engineering'}", style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
                const Divider(height: 24),
                const Text("Physical Copies & Barcodes:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                if (copies.isEmpty)
                  const Text("No physical copy records found for this title.", style: TextStyle(color: Colors.grey, fontSize: 12))
                else
                  ...copies.map((c) {
                    final status = (c['status'] ?? 'available').toString().toUpperCase();
                    final isAvail = status == 'AVAILABLE';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.qr_code_2_rounded, size: 18, color: Colors.blueGrey.shade700),
                          const SizedBox(width: 10),
                          Text(
                            "Copy #${c['copy_number'] ?? c['id']} • Barcode: ${c['barcode'] ?? 'N/A'}",
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAvail ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isAvail ? const Color(0xFF059669) : Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
          TextButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text("Edit Book"),
            onPressed: () {
              Navigator.pop(ctx);
              _showEditBookDialog(book);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/library/desk?bookId=${book['id']}');
            },
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: const Text("Issue This Book"),
          ),
        ],
      ),
    );
  }

  void _showEditBookDialog(Map<String, dynamic> book) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: book['title']?.toString() ?? '');
    final authorsCtrl = TextEditingController(text: book['authors']?.toString() ?? '');
    final isbnCtrl = TextEditingController(text: book['isbn']?.toString() ?? '');
    final publisherCtrl = TextEditingController(text: book['publisher']?.toString() ?? '');
    final editionCtrl = TextEditingController(text: book['edition']?.toString() ?? '');
    final yearCtrl = TextEditingController(text: book['year'] != null ? "${book['year']}" : (book['publication_year'] != null ? "${book['publication_year']}" : ''));
    final descCtrl = TextEditingController(text: book['description']?.toString() ?? '');

    String selectedCategory = (book['category']?.toString() ?? '').trim();
    if (selectedCategory.isEmpty || selectedCategory == 'All Categories') {
      selectedCategory = 'Computer Science and Engineering';
    }

    final deptList = [
      'None / General',
      'Computer Science and Engineering',
      'Electronics and Communication Engineering',
      'Civil Engineering',
      'Mechanical Engineering',
    ];
    String selectedDept = book['department_name']?.toString() ?? (book['department'] is Map ? book['department']['name']?.toString() : null) ?? 'None / General';
    if (!deptList.contains(selectedDept)) {
      selectedDept = 'None / General';
    }

    final catOptions = _categories.where((c) => c != 'All Categories').toList();
    if (!catOptions.contains(selectedCategory) && selectedCategory.isNotEmpty) {
      catOptions.insert(0, selectedCategory);
    }
    if (catOptions.isEmpty) {
      catOptions.addAll([
        'Computer Science and Engineering',
        'Electronics and Communication Engineering',
        'Civil Engineering',
        'Mechanical Engineering',
      ]);
    }

    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.edit_note_rounded, color: Color(0xFF13246E), size: 24),
              SizedBox(width: 8),
              Text("Edit Book Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: "Book Title *", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Book title is required" : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: authorsCtrl,
                      decoration: const InputDecoration(labelText: "Author(s) *", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Author(s) required" : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: isbnCtrl,
                            decoration: const InputDecoration(labelText: "ISBN", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: yearCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Publication Year *", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                            validator: (v) => (v == null || v.trim().isEmpty) ? "Year required" : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: catOptions.contains(selectedCategory) ? selectedCategory : catOptions.first,
                      decoration: const InputDecoration(labelText: "Category *", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      items: catOptions.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setDialogState(() => selectedCategory = v ?? selectedCategory),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: publisherCtrl,
                            decoration: const InputDecoration(labelText: "Publisher", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: editionCtrl,
                            decoration: const InputDecoration(labelText: "Edition", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedDept,
                      decoration: const InputDecoration(labelText: "Department (Optional)", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      items: deptList.map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setDialogState(() => selectedDept = v ?? 'None / General'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: "Description / Remarks", border: OutlineInputBorder(), contentPadding: EdgeInsets.all(10)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);
                      try {
                        final dio = ApiClient().dio;
                        final payload = {
                          'title': titleCtrl.text.trim(),
                          'authors': authorsCtrl.text.trim(),
                          'isbn': isbnCtrl.text.trim(),
                          'category': selectedCategory,
                          'publisher': publisherCtrl.text.trim(),
                          'edition': editionCtrl.text.trim(),
                          'year': int.tryParse(yearCtrl.text.trim()) ?? 2025,
                          'description': descCtrl.text.trim(),
                        };
                        await dio.patch('/library/books/${book['id']}/', data: payload);
                        nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text("Book details updated successfully!"), backgroundColor: Color(0xFF059669)),
                        );
                        _fetchCatalogue();
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text("Failed to update book: $e"), backgroundColor: Colors.red),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBooks;
    final totalItems = filtered.length;
    final totalPages = (totalItems / _pageSize).ceil();
    final safeCurrentPage = totalPages == 0 ? 1 : _currentPage.clamp(1, totalPages);
    final startIndex = (safeCurrentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalItems);
    final pageItems = filtered.sublist(startIndex, endIndex);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.inventory_2_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              "Book Inventory",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Export CSV",
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: _exportCsv,
          ),
          IconButton(
            tooltip: "Refresh Catalogue",
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchCatalogue,
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
                        onPressed: _fetchCatalogue,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header matching Image 1
                      const Text(
                        "BOOK INVENTORY",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search bar & Action Buttons Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextField(
                                onChanged: (v) => setState(() {
                                  _searchQuery = v;
                                  _currentPage = 1;
                                }),
                                decoration: const InputDecoration(
                                  hintText: "Search title, author, ISBN or copy ID...",
                                  hintStyle: TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
                                  prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13246E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text("Add New Book", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () => context.push('/library/books/add').then((_) => _fetchCatalogue()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 4 Summary Stat Cards matching Image 1
                      Row(
                        children: [
                          _buildStatCard("Total Titles", "$_totalTitles"),
                          const SizedBox(width: 16),
                          _buildStatCard("Total Copies", "$_totalCopies"),
                          const SizedBox(width: 16),
                          _buildStatCard("Available Copies", "$_availableCopies", color: const Color(0xFF0284C7)),
                          const SizedBox(width: 16),
                          _buildStatCard("Issued Copies", "$_issuedCopies", color: const Color(0xFF1E293B)),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Filter Bar (Category, Author, Availability, Sort By - No Shelf as requested)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            // Category Filter
                            Expanded(
                              child: _buildFilterDropdown(
                                label: "Category",
                                value: _selectedCategory,
                                items: _categories,
                                onChanged: (v) => setState(() {
                                  _selectedCategory = v ?? 'All Categories';
                                  _currentPage = 1;
                                }),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Author Filter
                            Expanded(
                              child: _buildFilterDropdown(
                                label: "Author",
                                value: _selectedAuthor,
                                items: _authors,
                                onChanged: (v) => setState(() {
                                  _selectedAuthor = v ?? 'All Authors';
                                  _currentPage = 1;
                                }),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Availability Filter
                            Expanded(
                              child: _buildFilterDropdown(
                                label: "Availability",
                                value: _selectedAvailability,
                                items: const ['All Status', 'Available', 'Partially Available', 'All Issued'],
                                onChanged: (v) => setState(() {
                                  _selectedAvailability = v ?? 'All Status';
                                  _currentPage = 1;
                                }),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Sort By
                            Expanded(
                              child: _buildFilterDropdown(
                                label: "Sort By",
                                value: _sortBy,
                                items: const ['Recently Added', 'Title (A-Z)', 'Title (Z-A)', 'Most Copies'],
                                onChanged: (v) => setState(() {
                                  _sortBy = v ?? 'Recently Added';
                                  _currentPage = 1;
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Inventory Table matching Image 1
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
                                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                              child: Row(
                                children: const [
                                  SizedBox(width: 36, child: Text("#", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF475569)))),
                                  Expanded(flex: 3, child: Text("BOOK TITLE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF475569)))),
                                  Expanded(flex: 2, child: Text("AUTHOR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF475569)))),
                                  Expanded(flex: 2, child: Text("ISBN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF475569)))),
                                  Expanded(flex: 2, child: Text("CATEGORY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF475569)))),
                                  Expanded(flex: 2, child: Text("COPIES (AVAIL / TOTAL)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF475569)), textAlign: TextAlign.center)),
                                  Expanded(flex: 2, child: Text("STATUS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF475569)), textAlign: TextAlign.center)),
                                  SizedBox(width: 125, child: Text("ACTIONS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF475569)), textAlign: TextAlign.center)),
                                ],
                              ),
                            ),

                            // Rows
                            if (pageItems.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(48),
                                child: Center(
                                  child: Text("No book inventory records match your criteria.", style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: pageItems.length,
                                separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                itemBuilder: (ctx, i) {
                                  final b = pageItems[i];
                                  final globalIndex = startIndex + i + 1;

                                  int avail = b['available_copies'] is int
                                      ? b['available_copies']
                                      : ((b['copies'] as List?)?.where((c) => (c['status'] ?? '').toString().toLowerCase() == 'available').length ?? 0);
                                  int total = (b['total_copies'] as int?) ?? ((b['copies'] as List?)?.length ?? 0);

                                  String statusText = "Available";
                                  Color statusColor = const Color(0xFF059669);
                                  Color statusBg = const Color(0xFFECFDF5);
                                  if (avail == 0 && total > 0) {
                                    statusText = "All Issued";
                                    statusColor = const Color(0xFFDC2626);
                                    statusBg = const Color(0xFFFEF2F2);
                                  } else if (avail > 0 && avail < total) {
                                    statusText = "Partially Available";
                                    statusColor = const Color(0xFFD97706);
                                    statusBg = const Color(0xFFFFFBEB);
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 36,
                                          child: Text("$globalIndex", style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            b['title'] ?? 'Untitled Book',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            b['authors'] ?? 'Unknown',
                                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            b['isbn'] ?? 'N/A',
                                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF475569)),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                b['category'] ?? 'General',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            "$avail / $total",
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Center(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                                              child: Text(
                                                statusText,
                                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 125,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              IconButton(
                                                padding: const EdgeInsets.all(4),
                                                constraints: const BoxConstraints(),
                                                icon: const Icon(Icons.remove_red_eye_outlined, size: 17, color: Color(0xFF13246E)),
                                                tooltip: "View Details & Copies",
                                                onPressed: () => _showBookDetailDialog(b),
                                                splashRadius: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                padding: const EdgeInsets.all(4),
                                                constraints: const BoxConstraints(),
                                                icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF0284C7)),
                                                tooltip: "Edit Book",
                                                onPressed: () => _showEditBookDialog(b),
                                                splashRadius: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                padding: const EdgeInsets.all(4),
                                                constraints: const BoxConstraints(),
                                                icon: const Icon(Icons.swap_horiz_rounded, size: 19, color: Color(0xFF2563EB)),
                                                tooltip: "Issue Book",
                                                onPressed: () => context.push('/library/desk?bookId=${b['id']}'),
                                                splashRadius: 16,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                            // Footer Pagination Bar matching Image 1
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
                                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    totalItems == 0 ? "Showing 0 titles" : "Showing ${startIndex + 1}–$endIndex of $totalItems titles",
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.first_page_rounded, size: 20),
                                        onPressed: safeCurrentPage > 1 ? () => setState(() => _currentPage = 1) : null,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left_rounded, size: 20),
                                        onPressed: safeCurrentPage > 1 ? () => setState(() => _currentPage--) : null,
                                      ),
                                      ...List.generate(totalPages.clamp(1, 5), (idx) {
                                        final pageNo = idx + 1;
                                        final isCur = pageNo == safeCurrentPage;
                                        return InkWell(
                                          onTap: () => setState(() => _currentPage = pageNo),
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 3),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isCur ? const Color(0xFF13246E) : Colors.transparent,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              "$pageNo",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isCur ? Colors.white : const Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                      if (totalPages > 5) ...[
                                        const Text(" ... ", style: TextStyle(color: Color(0xFF94A3B8))),
                                        InkWell(
                                          onTap: () => setState(() => _currentPage = totalPages),
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 3),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            child: Text(
                                              "$totalPages",
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                            ),
                                          ),
                                        ),
                                      ],
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right_rounded, size: 20),
                                        onPressed: safeCurrentPage < totalPages ? () => setState(() => _currentPage++) : null,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.last_page_rounded, size: 20),
                                        onPressed: safeCurrentPage < totalPages ? () => setState(() => _currentPage = totalPages) : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard(String title, String count, {Color color = const Color(0xFF0F172A)}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        const SizedBox(height: 4),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
