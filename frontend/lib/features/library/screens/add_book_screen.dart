import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/api_client.dart';

class AddBookScreen extends StatefulWidget {
  const AddBookScreen({super.key});

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  final _formKey = GlobalKey<FormState>();

  // 10 Exact Fields:
  // 1. Book Title (Required)
  // 2. Author(s) (Required)
  // 3. ISBN (Optional)
  // 4. Category (Required, dynamic + "+ Add Custom Category")
  // 5. Publisher (Optional)
  // 6. Edition (Optional)
  // 7. Publication Year (Required, <= current year)
  // 8. Department (Optional, 4 depts or shared)
  // 9. Initial Copies (Required, positive integer)
  // 10. Book Cover Image (Required, preview)

  final _titleController = TextEditingController();
  final _authorsController = TextEditingController();
  final _isbnController = TextEditingController();
  final _publisherController = TextEditingController();
  final _editionController = TextEditingController(text: "1st Edition");
  final _yearController = TextEditingController(text: DateTime.now().year.toString());
  final _copiesController = TextEditingController(text: "3");

  String? _selectedCategory;
  List<String> _categories = [];
  bool _isLoadingCategories = true;

  int? _selectedDepartmentId;
  List<Map<String, dynamic>> _departments = [];

  PlatformFile? _coverImageFile;
  bool _isLoading = false;
  String? _errorMessage;

  static const List<String> _allowedDepartmentNames = [
    'Computer Science and Engineering',
    'Electronics and Communication Engineering',
    'Civil Engineering',
    'Mechanical Engineering',
  ];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchDepartments();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorsController.dispose();
    _isbnController.dispose();
    _publisherController.dispose();
    _editionController.dispose();
    _yearController.dispose();
    _copiesController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/categories/');
      final data = res.data;
      final List list = data is List ? data : (data is Map && data['results'] is List ? data['results'] : []);
      final names = list.map((c) => (c['name'] ?? '').toString()).where((s) => s.isNotEmpty).toList();

      if (mounted) {
        setState(() {
          if (names.isNotEmpty) {
            _categories = names;
          } else {
            _categories = [
              "Computer Science and Engineering",
              "Electronics and Communication Engineering",
              "Civil Engineering",
              "Mechanical Engineering",
              "Basic Sciences & Humanities",
              "General Reference",
            ];
          }
          if (_selectedCategory == null || !_categories.contains(_selectedCategory)) {
            _selectedCategory = _categories.first;
          }
          _isLoadingCategories = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _categories = [
            "Computer Science and Engineering",
            "Electronics and Communication Engineering",
            "Civil Engineering",
            "Mechanical Engineering",
            "Basic Sciences & Humanities",
            "General Reference",
          ];
          _selectedCategory ??= _categories.first;
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _fetchDepartments() async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/academics/departments/');
      final data = res.data;
      final List list = data is List ? data : (data is Map && data['results'] is List ? data['results'] : []);

      if (mounted) {
        final filteredDepts = list
            .where((d) => _allowedDepartmentNames.contains(d['name']))
            .map((d) => Map<String, dynamic>.from(d))
            .toList();

        setState(() {
          _departments = filteredDepts;
          // Department is optional (can be null / shared)
          _selectedDepartmentId = null;
        });
      }
    } catch (_) {}
  }

  void _showAddCategoryDialog() {
    final textCtrl = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.category_rounded, color: Color(0xFF13246E), size: 22),
              SizedBox(width: 8),
              Text(
                "Add Custom Category",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter new category name to persist to library database:",
                style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "e.g. Artificial Intelligence, Data Science...",
                  errorText: errorText,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13246E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final catName = textCtrl.text.trim();
                if (catName.isEmpty) {
                  setDialogState(() => errorText = "Category name cannot be empty.");
                  return;
                }
                if (_categories.any((c) => c.toLowerCase() == catName.toLowerCase())) {
                  setDialogState(() => errorText = "Category \"$catName\" already exists.");
                  return;
                }

                try {
                  final dio = ApiClient().dio;
                  final res = await dio.post('/library/categories/', data: {'name': catName});
                  final newName = res.data['name'] ?? catName;

                  if (mounted) {
                    setState(() {
                      if (!_categories.contains(newName)) {
                        _categories.add(newName);
                        _categories.sort();
                      }
                      _selectedCategory = newName;
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Category \"$newName\" added and selected successfully!"),
                        backgroundColor: const Color(0xFF059669),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  String errMsg = "Failed to save category.";
                  if (e is DioException && e.response?.data != null) {
                    final d = e.response!.data;
                    if (d is Map && d['name'] != null) {
                      final n = d['name'];
                      errMsg = n is List ? n.first.toString() : n.toString();
                    } else if (d is Map && d['detail'] != null) {
                      errMsg = d['detail'].toString();
                    }
                  }
                  setDialogState(() => errorText = errMsg);
                }
              },
              child: const Text("Save Category"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCoverImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _coverImageFile = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking image: $e")),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final authors = _authorsController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Book Title is required.")),
      );
      return;
    }

    if (authors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Author(s) is required.")),
      );
      return;
    }

    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Category is required.")),
      );
      return;
    }

    final year = int.tryParse(_yearController.text.trim());
    final currentYear = DateTime.now().year;
    if (year == null || year < 1000 || year > currentYear) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Publication Year must be between 1000 and $currentYear.")),
      );
      return;
    }

    final copiesCount = int.tryParse(_copiesController.text.trim());
    if (copiesCount == null || copiesCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Initial Copies must be a positive number of at least 1.")),
      );
      return;
    }

    if (_coverImageFile == null || _coverImageFile!.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Book Cover Image is required. Please upload a book cover."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;

      final mapData = <String, dynamic>{
        'title': title,
        'authors': authors,
        'isbn': _isbnController.text.trim(),
        'category': _selectedCategory,
        'publisher': _publisherController.text.trim(),
        'edition': _editionController.text.trim(),
        'year': year,
        'initial_copies': copiesCount,
      };

      if (_selectedDepartmentId != null) {
        mapData['department_id'] = _selectedDepartmentId;
      }

      if (_coverImageFile != null && _coverImageFile!.bytes != null) {
        mapData['cover_image'] = MultipartFile.fromBytes(
          _coverImageFile!.bytes!,
          filename: _coverImageFile!.name,
        );
      }

      final formData = FormData.fromMap(mapData);
      final res = await dio.post('/library/books/', data: formData);

      final bookId = res.data['id'];
      if (bookId != null && copiesCount > 0) {
        // Also ensure physical copies exist via add_copies if not created by perform_create
        try {
          final existingCopies = res.data['copies'] as List?;
          if (existingCopies == null || existingCopies.isEmpty) {
            await dio.post('/library/books/$bookId/add_copies/', data: {
              'count': copiesCount.clamp(1, 100),
              'shelf_location': 'Stack A-1',
            });
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Book title and copies successfully registered!"),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/library/catalog');
        }
      }
    } catch (e) {
      String cleanError = "Failed to add book: $e";
      if (e is DioException && e.response?.data != null) {
        final d = e.response!.data;
        if (d is Map && d['detail'] != null) {
          cleanError = d['detail'].toString();
        } else {
          cleanError = d.toString();
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = cleanError;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cleanError),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Add New Book",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/library/catalog');
            }
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Container(
              width: isDesktop ? 1050 : double.infinity,
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), // Clean card container matching Image 1
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Add New Book Title",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                    ),
                  ],

                  // Two-Column Form Layout
                  isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildLeftColumn(),
                            ),
                            const SizedBox(width: 44),
                            Expanded(
                              flex: 2,
                              child: _buildRightColumn(),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildRightColumn(),
                            const SizedBox(height: 24),
                            _buildLeftColumn(),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      children: [
        // 1. Book Title (Required)
        _buildSnippedField(
          label: "Book Title *",
          controller: _titleController,
          hint: "e.g. Introduction to Algorithms",
          validator: (v) => (v == null || v.trim().isEmpty) ? "Book Title is required" : null,
        ),

        // 2. Author(s) (Required)
        _buildSnippedField(
          label: "Author(s) *",
          controller: _authorsController,
          hint: "e.g. Thomas H. Cormen, Charles E. Leiserson",
          validator: (v) => (v == null || v.trim().isEmpty) ? "Author(s) is required" : null,
        ),

        // 3. ISBN (Optional)
        _buildSnippedField(
          label: "ISBN",
          controller: _isbnController,
          hint: "e.g. 978-0262033848 (Optional)",
        ),

        // 4. Category (Required, Dynamic + "+ Add Custom Category")
        _buildCategoryDropdownRow(),

        // 5. Publisher (Optional)
        _buildSnippedField(
          label: "Publisher",
          controller: _publisherController,
          hint: "e.g. MIT Press (Optional)",
        ),

        // 6. Edition (Optional)
        _buildSnippedField(
          label: "Edition",
          controller: _editionController,
          hint: "e.g. 3rd Edition (Optional)",
        ),

        // 7. Publication Year (Required, <= current year)
        _buildSnippedField(
          label: "Publication Year *",
          controller: _yearController,
          hint: "e.g. ${DateTime.now().year}",
          keyboardType: TextInputType.number,
          validator: (v) {
            final y = int.tryParse(v?.trim() ?? '');
            if (y == null || y < 1000 || y > DateTime.now().year) {
              return "Enter a valid year up to ${DateTime.now().year}";
            }
            return null;
          },
        ),

        // 8. Department (Optional, CSE, ECE, Civil, Mechanical, or Shared)
        _buildDepartmentDropdown(),

        // 9. Initial Copies (Required, positive int >= 1)
        _buildSnippedField(
          label: "Initial Copies *",
          controller: _copiesController,
          hint: "e.g. 3",
          keyboardType: TextInputType.number,
          validator: (v) {
            final c = int.tryParse(v?.trim() ?? '');
            if (c == null || c < 1) return "Copies must be at least 1";
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 10. Book Cover Upload Box (Required, 180x180 Matching Image 1)
        Container(
          height: 190,
          width: 190,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _coverImageFile != null ? const Color(0xFF13246E) : const Color(0xFFCBD5E1),
              width: _coverImageFile != null ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _coverImageFile != null && _coverImageFile!.bytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    _coverImageFile!.bytes!,
                    fit: BoxFit.cover,
                  ),
                )
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_stories_rounded, size: 68, color: Color(0xFF94A3B8)),
                    SizedBox(height: 8),
                    Text(
                      "Book Cover *",
                      style: TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "(Required)",
                      style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),

        // Upload Button (Exact Image 1 Style)
        SizedBox(
          width: 160,
          child: ElevatedButton.icon(
            onPressed: _pickCoverImage,
            icon: const Icon(Icons.cloud_upload_outlined, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            label: Text(
              _coverImageFile != null ? "Change Cover" : "Upload Image *",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 48),

        // Submit Button (Neatly aligned and visible)
        SizedBox(
          width: 160,
          height: 46,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 18),
                      SizedBox(width: 8),
                      Text("Submit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSnippedField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool isReadOnly = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: TextFormField(
                controller: controller,
                readOnly: isReadOnly,
                keyboardType: keyboardType,
                validator: validator,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  isDense: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdownRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 150,
            child: Text(
              "Category *",
              style: TextStyle(fontSize: 13.5, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: _isLoadingCategories
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Loading categories...", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                        items: [
                          ..._categories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat,
                              child: Text(cat, overflow: TextOverflow.ellipsis),
                            );
                          }),
                          const DropdownMenuItem<String>(
                            value: '__ADD_NEW__',
                            child: Row(
                              children: [
                                Icon(Icons.add_circle_outline_rounded, color: Color(0xFF13246E), size: 16),
                                SizedBox(width: 8),
                                Text(
                                  "+ Add Custom Category",
                                  style: TextStyle(color: Color(0xFF13246E), fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val == '__ADD_NEW__') {
                            _showAddCategoryDialog();
                          } else if (val != null) {
                            setState(() => _selectedCategory = val);
                          }
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 150,
            child: Text(
              "Department",
              style: TextStyle(fontSize: 13.5, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedDepartmentId,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text("None / Shared Across All Departments", style: TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                    ),
                    ..._departments.map((d) {
                      return DropdownMenuItem<int?>(
                        value: d['id'] as int?,
                        child: Text(d['name'] ?? 'Department', overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedDepartmentId = val);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
