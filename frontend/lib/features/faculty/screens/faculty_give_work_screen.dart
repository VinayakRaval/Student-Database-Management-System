import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/widgets/app_pagination_bar.dart';

class FacultyGiveWorkScreen extends StatefulWidget {
  const FacultyGiveWorkScreen({super.key});

  @override
  State<FacultyGiveWorkScreen> createState() => _FacultyGiveWorkScreenState();
}

class _FacultyGiveWorkScreenState extends State<FacultyGiveWorkScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _assignedSubjects = [];
  int? _selectedSubjectFilter; // null = all
  String _searchQuery = '';
  int _currentPage = 1;
  static const int _pageSize = 6;

  List<Map<String, dynamic>> _worksList = [];
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;

      // 1. Fetch assigned subjects for faculty
      final subRes = await dio.get('/subjects/professor/subjects/');
      final List rawSubjects = subRes.data is List ? subRes.data : [];
      final subjects = rawSubjects.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // 2. Fetch existing works
      final worksRes = await dio.get('/subjects/works/', queryParameters: {'assigned_only': 'true'});
      final List rawWorks = worksRes.data is List
          ? worksRes.data
          : (worksRes.data is Map && worksRes.data['results'] is List ? worksRes.data['results'] : []);
      final works = rawWorks.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (mounted) {
        setState(() {
          _assignedSubjects = subjects;
          _worksList = works;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load assignments: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchWorks() async {
    try {
      final dio = ApiClient().dio;
      final queryParams = <String, dynamic>{
        'assigned_only': 'true',
      };
      if (_selectedSubjectFilter != null) {
        queryParams['subject_id'] = _selectedSubjectFilter;
      }
      final res = await dio.get('/subjects/works/', queryParameters: queryParams);
      final List rawWorks = res.data is List
          ? res.data
          : (res.data is Map && res.data['results'] is List ? res.data['results'] : []);
      if (mounted) {
        setState(() {
          _worksList = rawWorks.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching works: $e");
    }
  }

  Future<void> _deleteWork(int workId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Delete Assignment?"),
          ],
        ),
        content: Text("Are you sure you want to remove '$title'? Students will no longer see this work."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final dio = ApiClient().dio;
      await dio.delete('/subjects/works/$workId/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Assignment removed successfully!"), backgroundColor: Colors.green),
        );
        _fetchWorks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete assignment: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openCreateWorkDialog() {
    if (_assignedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No assigned subjects available to give work.")),
      );
      return;
    }

    int selectedSubId = (_assignedSubjects.first['id'] ?? _assignedSubjects.first['subject_id']) as int;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final marksCtrl = TextEditingController(text: '10');
    DateTime? dueDate = DateTime.now().add(const Duration(days: 7));
    XFile? pickedImage;
    Uint8List? pickedImageBytes;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: const Color(0xFFEAECEF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: 780,
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF13246E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.assignment_add, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Assign Work to Students",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Two-Column Layout matching Image 3
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Form Fields
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Select Subject
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 130,
                                  child: Text(
                                    "Select Subject *",
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DropdownButtonFormField<int>(
                                      value: selectedSubId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      items: _assignedSubjects.map((s) {
                                        final id = (s['id'] ?? s['subject_id']) as int;
                                        final code = s['subject_code'] ?? '';
                                        final name = s['subject_name'] ?? '';
                                        return DropdownMenuItem(
                                          value: id,
                                          child: Text("$code - $name", overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() => selectedSubId = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 2. Work / Assignment Title
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 130,
                                  child: Text(
                                    "Work Title *",
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: TextField(
                                      controller: titleCtrl,
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: "e.g. Assignment 1 - CPU Scheduling or Lab Sheet",
                                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 3. Instructions / Description
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(
                                  width: 130,
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 10),
                                    child: Text(
                                      "Instructions",
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: TextField(
                                      controller: descCtrl,
                                      maxLines: 3,
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: "Provide problem questions, guidelines, submission details...",
                                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 4. Due Date & Max Marks
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 130,
                                  child: Text(
                                    "Due Date *",
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
                                  ),
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final now = DateTime.now();
                                      final picked = await showDatePicker(
                                        context: ctx,
                                        initialDate: dueDate ?? now.add(const Duration(days: 7)),
                                        firstDate: now,
                                        lastDate: now.add(const Duration(days: 365)),
                                      );
                                      if (picked != null) {
                                        setDialogState(() => dueDate = picked);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF13246E)),
                                          const SizedBox(width: 8),
                                          Text(
                                            dueDate != null ? DateFormat('dd-MMM-yyyy').format(dueDate!) : "Select Date",
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  "Max Marks *",
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 75,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: TextField(
                                      controller: marksCtrl,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      decoration: InputDecoration(
                                        hintText: "10",
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 5. Attach Worksheet / File
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 130,
                                  child: Text(
                                    "Attach File",
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
                                  ),
                                ),
                                Expanded(
                                  child: Row(
                                    children: [
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.folder_open_rounded, size: 18),
                                        label: const Text("Choose Files"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: const Color(0xFF13246E),
                                          elevation: 0,
                                          side: BorderSide(color: Colors.grey.shade300),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: () async {
                                          final picker = ImagePicker();
                                          final XFile? img = await picker.pickImage(source: ImageSource.gallery);
                                          if (img != null) {
                                            final bytes = await img.readAsBytes();
                                            setDialogState(() {
                                              pickedImage = img;
                                              pickedImageBytes = bytes;
                                            });
                                          }
                                        },
                                      ),
                                      if (pickedImage != null) ...[
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            pickedImage!.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF13246E), fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 28),

                      // Right Column: Square Preview Card & Submit / Cancel Button (matching Image 3)
                      SizedBox(
                        width: 200,
                        child: Column(
                          children: [
                            // Square Preview Card
                            Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: pickedImageBytes != null
                                  ? Stack(
                                      alignment: Alignment.topRight,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Image.memory(
                                            pickedImageBytes!,
                                            width: 180,
                                            height: 180,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Colors.red,
                                            child: Icon(Icons.close, size: 14, color: Colors.white),
                                          ),
                                          onPressed: () {
                                            setDialogState(() {
                                              pickedImage = null;
                                              pickedImageBytes = null;
                                            });
                                          },
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.menu_book_rounded, size: 54, color: Colors.grey.shade400),
                                        const SizedBox(height: 10),
                                        Text(
                                          "Select File",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade500,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Worksheet Preview",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Submit Button (Navy Blue, matching Image 3)
                            SizedBox(
                              width: 180,
                              height: 44,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF13246E),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                  elevation: 2,
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        final title = titleCtrl.text.trim();
                                        if (title.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("Please enter a title for the assignment.")),
                                          );
                                          return;
                                        }

                                        setDialogState(() => isSubmitting = true);

                                        try {
                                          final dio = ApiClient().dio;

                                          final Map<String, dynamic> formMap = {
                                            'subject': selectedSubId,
                                            'title': title,
                                            'description': descCtrl.text.trim(),
                                            'due_date': dueDate != null ? DateFormat('yyyy-MM-dd').format(dueDate!) : null,
                                            'max_marks': int.tryParse(marksCtrl.text.trim()) ?? 10,
                                          };

                                          if (pickedImageBytes != null && pickedImage != null) {
                                            formMap['work_image'] = MultipartFile.fromBytes(
                                              pickedImageBytes!,
                                              filename: pickedImage!.name,
                                            );
                                          }

                                          final formData = FormData.fromMap(formMap);

                                          await dio.post('/subjects/works/', data: formData);

                                          if (ctx.mounted) {
                                            Navigator.pop(ctx);
                                          }
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text("Work assigned successfully! Students notified."),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                            _fetchWorks();
                                          }
                                        } catch (e) {
                                          setDialogState(() => isSubmitting = false);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text("Failed to assign work: $e"), backgroundColor: Colors.red),
                                            );
                                          }
                                        }
                                      },
                                child: isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text(
                                        "Submit",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Cancel Button
                            TextButton(
                              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  void _showImagePreviewDialog(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: InteractiveViewer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, prog) {
                            if (prog == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (_, _, _) => const Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text("Could not load image."),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredWorks = _worksList.where((w) {
      if (_selectedSubjectFilter != null) {
        if (w['subject'] != _selectedSubjectFilter) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final title = (w['title'] ?? '').toString().toLowerCase();
        final desc = (w['description'] ?? '').toString().toLowerCase();
        final subName = (w['subject_name'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        return title.contains(q) || desc.contains(q) || subName.contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Student Work & Assignments",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Refresh Works",
            onPressed: _fetchWorks,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF13246E)))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text("Error: $_errorMessage"),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text("Retry"),
                        onPressed: _loadInitialData,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Top Header Banner
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF13246E), Color(0xFF26388A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit_note_rounded, color: Colors.white, size: 16),
                                            SizedBox(width: 6),
                                            Text(
                                              'Assignments & Homework Hub',
                                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Assign Work & Problem Sets',
                                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Create subject assignments, attach question paper worksheets or diagram images, set deadlines, and automatically notify your enrolled students.',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  onPressed: _openCreateWorkDialog,
                                  icon: const Icon(Icons.add_task_rounded, size: 18),
                                  label: const Text('+ Give Work'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF13246E),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 2. Filter & Search Bar
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                // Subject Dropdown Filter
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<int?>(
                                    value: _selectedSubjectFilter,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: "Filter by Subject",
                                      prefixIcon: const Icon(Icons.book_rounded, size: 18, color: Color(0xFF13246E)),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    items: [
                                      const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text("All Assigned Subjects"),
                                      ),
                                      ..._assignedSubjects.map((sub) {
                                        final id = (sub['id'] ?? sub['subject_id']) as int;
                                        final code = sub['subject_code'] ?? '';
                                        final name = sub['subject_name'] ?? '';
                                        return DropdownMenuItem<int?>(
                                          value: id,
                                          child: Text("$code - $name", overflow: TextOverflow.ellipsis),
                                        );
                                      }),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedSubjectFilter = val;
                                        _currentPage = 1;
                                      });
                                      _fetchWorks();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Search TextField
                                Expanded(
                                  flex: 4,
                                  child: TextField(
                                    controller: _searchCtrl,
                                    decoration: InputDecoration(
                                      hintText: "Search works by title or keyword...",
                                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 16),
                                              onPressed: () {
                                                _searchCtrl.clear();
                                                setState(() {
                                                  _searchQuery = '';
                                                  _currentPage = 1;
                                                });
                                              },
                                            )
                                          : null,
                                    ),
                                    onChanged: (val) => setState(() {
                                      _searchQuery = val;
                                      _currentPage = 1;
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 3. Work Cards List
                          if (filteredWorks.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  children: [
                                    Icon(Icons.assignment_turned_in_rounded, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 14),
                                    const Text("No assignments found.", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    const Text("Click '+ Give Work' to create an assignment with optional problem sheet images.", style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            )
                          else
                            Builder(
                              builder: (context) {
                                final totalPages = (filteredWorks.length / _pageSize).ceil();
                                final safePage = _currentPage > totalPages && totalPages > 0 ? totalPages : _currentPage;
                                final paginatedWorks = filteredWorks.skip((safePage - 1) * _pageSize).take(_pageSize).toList();

                              return Column(
                                children: [
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: paginatedWorks.length,
                                    itemBuilder: (context, idx) {
                                      final work = paginatedWorks[idx];
                                      final workId = work['id'] as int;
                                      final title = work['title'] ?? 'Untitled Work';
                                final desc = work['description'] ?? '';
                                final subCode = work['subject_code'] ?? '';
                                final subName = work['subject_name'] ?? '';
                                final dueDate = work['due_date']?.toString();
                                final maxMarks = work['max_marks'] ?? 10;
                                final imageUrl = work['work_image_url'] ?? work['work_image'];
                                final createdAt = work['created_at']?.toString();

                                return Card(
                                  elevation: 0,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Left Image Thumbnail (if attached)
                                        if (imageUrl != null && imageUrl.toString().isNotEmpty) ...[
                                          InkWell(
                                            onTap: () => _showImagePreviewDialog(imageUrl.toString(), title),
                                            borderRadius: BorderRadius.circular(10),
                                            child: Container(
                                              width: 100,
                                              height: 100,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: Colors.grey.shade300),
                                              ),
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(9),
                                                    child: Image.network(
                                                      imageUrl.toString(),
                                                      width: 100,
                                                      height: 100,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withValues(alpha: 0.4),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                        ],

                                        // Main Content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF13246E).withValues(alpha: 0.08),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            "$subCode: $subName",
                                                            style: const TextStyle(
                                                              color: Color(0xFF13246E),
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Text(
                                                          title,
                                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                                    tooltip: "Delete Assignment",
                                                    onPressed: () => _deleteWork(workId, title),
                                                  ),
                                                ],
                                              ),
                                              if (desc.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  desc,
                                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                                ),
                                              ],
                                              const SizedBox(height: 12),
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 6,
                                                children: [
                                                  if (dueDate != null && dueDate.isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.amber.shade50,
                                                        borderRadius: BorderRadius.circular(20),
                                                        border: Border.all(color: Colors.amber.shade400),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.event_rounded, size: 14, color: Colors.amber.shade900),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            "Due: $dueDate",
                                                            style: TextStyle(
                                                              color: Colors.amber.shade900,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.shade50,
                                                      borderRadius: BorderRadius.circular(20),
                                                      border: Border.all(color: Colors.blue.shade300),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.stars_rounded, size: 14, color: Colors.blue),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          "Max: $maxMarks Marks",
                                                          style: TextStyle(
                                                            color: Colors.blue.shade900,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (imageUrl != null && imageUrl.toString().isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.purple.shade50,
                                                        borderRadius: BorderRadius.circular(20),
                                                        border: Border.all(color: Colors.purple.shade200),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.attachment_rounded, size: 14, color: Colors.purple),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            "Worksheet Attached",
                                                            style: TextStyle(
                                                              color: Colors.purple,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  if (createdAt != null)
                                                    Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                                      child: Text(
                                                        "Assigned: ${createdAt.split('T').first}",
                                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            AppPaginationBar(
                              currentPage: safePage,
                              totalPages: totalPages,
                              totalItems: filteredWorks.length,
                              pageSize: _pageSize,
                              onPageChanged: (page) => setState(() => _currentPage = page),
                            ),
                          ],
                        );
                      },
                    ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}
