import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';
import '../models/announcement_model.dart';

class CampusAnnouncementsScreen extends StatefulWidget {
  const CampusAnnouncementsScreen({super.key});

  @override
  State<CampusAnnouncementsScreen> createState() => _CampusAnnouncementsScreenState();
}

class _CampusAnnouncementsScreenState extends State<CampusAnnouncementsScreen> with SingleTickerProviderStateMixin {
  List<AnnouncementItem> _announcements = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _academicYears = [];

  bool _isLoading = true;
  bool _isSavingAnnouncement = false;
  String? _errorMessage;
  String _selectedCategory = 'ALL';
  String _selectedHistoryTab = 'ALL';
  String _searchQuery = '';

  final List<String> _standardCategories = const [
    'ALL',
    'GENERAL',
    'EXAM',
    'HOLIDAY',
    'EVENT',
    'TIMETABLE',
  ];

  final List<String> _historyTabs = const [
    'ALL',
    'PUBLISHED',
    'SCHEDULED',
    'DRAFT',
    'EXPIRED',
  ];

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  void initState() {
    super.initState();
    _loadMetadata();
    _loadAnnouncements();
  }

  Future<void> _loadMetadata() async {
    try {
      final dio = ApiClient().dio;
      final deptRes = await dio.get('/academics/departments/');
      final semRes = await dio.get('/academics/semesters/');
      final ayRes = await dio.get('/academics/academic-years/');

      if (mounted) {
        setState(() {
          _departments = List<Map<String, dynamic>>.from(deptRes.data is List ? deptRes.data : (deptRes.data['results'] ?? []));
          _semesters = List<Map<String, dynamic>>.from(semRes.data is List ? semRes.data : (semRes.data['results'] ?? []));
          _academicYears = List<Map<String, dynamic>>.from(ayRes.data is List ? ayRes.data : (ayRes.data['results'] ?? []));
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final queryParams = <String, dynamic>{};
      if (_selectedCategory != 'ALL') {
        queryParams['category'] = _selectedCategory;
      }
      if (_selectedHistoryTab != 'ALL') {
        queryParams['status_filter'] = _selectedHistoryTab;
      }

      final res = await dio.get('/announcements/items/', queryParameters: queryParams);
      final List data = res.data is List ? res.data : (res.data['results'] ?? []);
      if (mounted) {
        setState(() {
          _announcements = data.map((e) => AnnouncementItem.fromJson(Map<String, dynamic>.from(e))).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load campus announcements. Please retry.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAnnouncement(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Delete Notice", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to permanently delete this campus announcement?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final dio = ApiClient().dio;
      await dio.delete('/announcements/items/$id/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Campus notice deleted successfully!"), backgroundColor: Colors.green),
        );
        _loadAnnouncements();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCreateEditDialog({AnnouncementItem? item}) {
    final isEdit = item != null;
    final titleController = TextEditingController(text: item?.title ?? '');
    final contentController = TextEditingController(text: item?.content ?? '');
    final customCategoryController = TextEditingController();

    Uint8List? pickedImageBytes;
    String? pickedImageName;
    bool removeImage = false;
    String? existingImageUrl = item?.imageUrl;

    Uint8List? pickedDocBytes;
    String? pickedDocName;
    bool removeDoc = false;
    String? existingAttachmentUrl = item?.attachmentUrl;

    // Check if editing an announcement with an existing custom category
    const standardCategoriesList = ['GENERAL', 'EXAM', 'HOLIDAY', 'EVENT', 'TIMETABLE'];
    String category = 'GENERAL';

    if (item != null) {
      if (standardCategoriesList.contains(item.category.toUpperCase())) {
        category = item.category.toUpperCase();
      } else {
        category = 'CUSTOM';
        customCategoryController.text = item.category;
      }
    }

    String priority = item?.priority ?? 'NORMAL';
    String? selectedDeptId = item?.departmentId?.toString();
    String targetAudience = item?.targetAudience ?? 'ALL';
    int? selectedSemester = item?.semesterId;
    int? selectedAcademicYear = item?.academicYearId;
    DateTime? publishDate = item?.publishDate;
    DateTime? expiryDate = item?.expiryDate;
    bool notifyUsers = item?.notifyUsers ?? false;
    bool isPreviewMode = false;
    _isSavingAnnouncement = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final effectiveCategory = (category == 'CUSTOM')
              ? (customCategoryController.text.trim().isEmpty ? 'CUSTOM' : customCategoryController.text.trim().toUpperCase())
              : category;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Container(
              width: 700,
              constraints: const BoxConstraints(maxHeight: 760),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    decoration: const BoxDecoration(
                      color: Color(0xFF13246E),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? "Edit Campus Announcement" : "Create Campus Announcement",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              style: TextButton.styleFrom(foregroundColor: Colors.white),
                              onPressed: () => setDialogState(() => isPreviewMode = !isPreviewMode),
                              icon: Icon(isPreviewMode ? Icons.edit_note_rounded : Icons.visibility_rounded, size: 18),
                              label: Text(isPreviewMode ? "Edit Form" : "Preview Notice"),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close, color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Content Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: isPreviewMode
                          ? _buildPreviewCard(
                              title: titleController.text.trim().isEmpty ? "Announcement Title" : titleController.text.trim(),
                              content: contentController.text.trim().isEmpty ? "Announcement content goes here..." : contentController.text.trim(),
                              category: effectiveCategory,
                              priority: priority,
                              audience: targetAudience,
                              imageBytes: pickedImageBytes,
                              imageUrl: removeImage ? null : existingImageUrl,
                              docBytes: pickedDocBytes,
                              docName: pickedDocName,
                              attachmentUrl: removeDoc ? null : existingAttachmentUrl,
                              publishDate: publishDate,
                              expiryDate: expiryDate,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Title
                                _buildStyledInputField(
                                  label: "ANNOUNCEMENT TITLE *",
                                  child: TextField(
                                    controller: titleController,
                                    decoration: const InputDecoration(
                                      hintText: "e.g. End Semester Examination Circular",
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // 2. Target Department & Priority
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStyledInputField(
                                        label: "TARGET DEPARTMENT",
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: selectedDeptId,
                                            isExpanded: true,
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                            items: [
                                              const DropdownMenuItem(value: null, child: Text("All Departments (Campus-Wide)")),
                                              ..._departments.map((d) => DropdownMenuItem(
                                                    value: d['id'].toString(),
                                                    child: Text(d['name'] ?? 'Dept'),
                                                  )),
                                            ],
                                            onChanged: (val) => setDialogState(() => selectedDeptId = val),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStyledInputField(
                                        label: "PRIORITY",
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: priority,
                                            isExpanded: true,
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                            items: const [
                                              DropdownMenuItem(value: 'NORMAL', child: Text('Normal Priority')),
                                              DropdownMenuItem(value: 'IMPORTANT', child: Text('Important')),
                                              DropdownMenuItem(value: 'URGENT', child: Text('Urgent Notice')),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) setDialogState(() => priority = val);
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // 3. Category & Custom Category Input
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildStyledInputField(
                                            label: "CATEGORY *",
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: category,
                                                isExpanded: true,
                                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                                items: const [
                                                  DropdownMenuItem(value: 'GENERAL', child: Text('General Notice')),
                                                  DropdownMenuItem(value: 'EXAM', child: Text('Semester Exam')),
                                                  DropdownMenuItem(value: 'HOLIDAY', child: Text('Holiday Announcement')),
                                                  DropdownMenuItem(value: 'EVENT', child: Text('College Event')),
                                                  DropdownMenuItem(value: 'TIMETABLE', child: Text('Timetable / Schedule Change')),
                                                  DropdownMenuItem(
                                                    value: 'CUSTOM',
                                                    child: Text(
                                                      '+ Custom Category...',
                                                      style: TextStyle(color: Color(0xFF13246E), fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setDialogState(() {
                                                      category = val;
                                                    });
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                          if (category == 'CUSTOM') ...[
                                            const SizedBox(height: 10),
                                            _buildStyledInputField(
                                              label: "CUSTOM CATEGORY NAME *",
                                              child: TextField(
                                                controller: customCategoryController,
                                                decoration: const InputDecoration(
                                                  hintText: "e.g. Workshop, Placement, Sports, Symposium",
                                                  prefixIcon: Icon(Icons.label_outline_rounded, size: 18),
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStyledInputField(
                                        label: "TARGET AUDIENCE",
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: targetAudience,
                                            isExpanded: true,
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                            items: const [
                                              DropdownMenuItem(value: 'ALL', child: Text('All (Faculty & Students)')),
                                              DropdownMenuItem(value: 'STUDENTS', child: Text('Students Only')),
                                              DropdownMenuItem(value: 'FACULTY', child: Text('Faculty Only')),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) setDialogState(() => targetAudience = val);
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // 4. Target Semester & Academic Year
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStyledInputField(
                                        label: "TARGET SEMESTER",
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int?>(
                                            value: selectedSemester,
                                            isExpanded: true,
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                            items: [
                                              const DropdownMenuItem(value: null, child: Text('All Semesters')),
                                              ..._semesters.map((s) => DropdownMenuItem<int?>(
                                                    value: s['id'] as int?,
                                                    child: Text("Semester ${s['sem_number']}"),
                                                  )),
                                            ],
                                            onChanged: (val) => setDialogState(() => selectedSemester = val),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStyledInputField(
                                        label: "ACADEMIC YEAR",
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int?>(
                                            value: selectedAcademicYear,
                                            isExpanded: true,
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                            items: [
                                              const DropdownMenuItem(value: null, child: Text('Current Year')),
                                              ..._academicYears.map((ay) => DropdownMenuItem<int?>(
                                                    value: ay['id'] as int?,
                                                    child: Text(ay['year_name'] ?? 'Year'),
                                                  )),
                                            ],
                                            onChanged: (val) => setDialogState(() => selectedAcademicYear = val),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // 5. Publish Schedule Date/Time & Expiry Date
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStyledInputField(
                                        label: "SCHEDULED PUBLICATION DATE (OPTIONAL)",
                                        child: InkWell(
                                          onTap: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: publishDate ?? DateTime.now(),
                                              firstDate: DateTime.now(),
                                              lastDate: DateTime.now().add(const Duration(days: 180)),
                                            );
                                            if (picked != null) setDialogState(() => publishDate = picked);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  publishDate != null ? "${publishDate!.day}/${publishDate!.month}/${publishDate!.year}" : "Immediate",
                                                  style: TextStyle(color: publishDate != null ? const Color(0xFF13246E) : Colors.grey.shade600, fontSize: 13, fontWeight: publishDate != null ? FontWeight.bold : FontWeight.normal),
                                                ),
                                                if (publishDate != null)
                                                  IconButton(
                                                    icon: const Icon(Icons.clear, size: 16),
                                                    onPressed: () => setDialogState(() => publishDate = null),
                                                  )
                                                else
                                                  const Icon(Icons.schedule_rounded, size: 18, color: Colors.grey),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStyledInputField(
                                        label: "EXPIRY DATE",
                                        child: InkWell(
                                          onTap: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: expiryDate ?? DateTime.now().add(const Duration(days: 30)),
                                              firstDate: DateTime.now(),
                                              lastDate: DateTime.now().add(const Duration(days: 365)),
                                            );
                                            if (picked != null) setDialogState(() => expiryDate = picked);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  expiryDate != null ? "${expiryDate!.day}/${expiryDate!.month}/${expiryDate!.year}" : "Never expires",
                                                  style: TextStyle(color: expiryDate != null ? Colors.black87 : Colors.grey.shade600, fontSize: 13),
                                                ),
                                                const Icon(Icons.event_outlined, size: 18, color: Colors.grey),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // 6. Optional Image Upload & Optional File Attachment
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Image / Poster Upload
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "ATTACH IMAGE / POSTER (OPTIONAL)",
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF13246E), letterSpacing: 0.5),
                                          ),
                                          const SizedBox(height: 6),
                                          if (pickedImageBytes != null || (existingImageUrl != null && existingImageUrl.isNotEmpty && !removeImage)) ...[
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Row(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: pickedImageBytes != null
                                                        ? Image.memory(pickedImageBytes!, width: 44, height: 44, fit: BoxFit.cover)
                                                        : Image.network(
                                                            existingImageUrl!,
                                                            width: 44,
                                                            height: 44,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 36, color: Colors.grey),
                                                          ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          pickedImageName ?? existingImageUrl!.split('/').last,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          pickedImageBytes != null ? formatBytes(pickedImageBytes!.length) : "Existing Poster",
                                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () async {
                                                      final result = await FilePicker.pickFiles(
                                                        type: FileType.custom,
                                                        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                                                        withData: true,
                                                      );
                                                      if (result != null && result.files.isNotEmpty) {
                                                        setDialogState(() {
                                                          pickedImageBytes = result.files.first.bytes;
                                                          pickedImageName = result.files.first.name;
                                                          removeImage = false;
                                                        });
                                                      }
                                                    },
                                                    child: const Text("Change", style: TextStyle(fontSize: 12, color: Color(0xFF13246E))),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                                    tooltip: "Remove image",
                                                    onPressed: () {
                                                      setDialogState(() {
                                                        pickedImageBytes = null;
                                                        pickedImageName = null;
                                                        removeImage = true;
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ] else ...[
                                            InkWell(
                                              onTap: () async {
                                                final result = await FilePicker.pickFiles(
                                                  type: FileType.custom,
                                                  allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                                                  withData: true,
                                                );
                                                if (result != null && result.files.isNotEmpty) {
                                                  setDialogState(() {
                                                    pickedImageBytes = result.files.first.bytes;
                                                    pickedImageName = result.files.first.name;
                                                    removeImage = false;
                                                  });
                                                }
                                              },
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                                ),
                                                child: const Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF13246E), size: 18),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      "Upload Image / Poster",
                                                      style: TextStyle(color: Color(0xFF13246E), fontWeight: FontWeight.bold, fontSize: 13),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Text(
                                            "Optional — supports JPG, PNG, WEBP",
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Document / PDF Upload
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "ATTACH DOCUMENT / PDF (OPTIONAL)",
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF13246E), letterSpacing: 0.5),
                                          ),
                                          const SizedBox(height: 6),
                                          if (pickedDocBytes != null || (existingAttachmentUrl != null && existingAttachmentUrl.isNotEmpty && !removeDoc)) ...[
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.shade50,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Icon(Icons.picture_as_pdf_rounded, color: Colors.red.shade700, size: 24),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          pickedDocName ?? existingAttachmentUrl!.split('/').last,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          pickedDocBytes != null ? formatBytes(pickedDocBytes!.length) : "Existing Document",
                                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () async {
                                                      final result = await FilePicker.pickFiles(
                                                        type: FileType.custom,
                                                        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
                                                        withData: true,
                                                      );
                                                      if (result != null && result.files.isNotEmpty) {
                                                        setDialogState(() {
                                                          pickedDocBytes = result.files.first.bytes;
                                                          pickedDocName = result.files.first.name;
                                                          removeDoc = false;
                                                        });
                                                      }
                                                    },
                                                    child: const Text("Change", style: TextStyle(fontSize: 12, color: Color(0xFF13246E))),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                                    tooltip: "Remove document",
                                                    onPressed: () {
                                                      setDialogState(() {
                                                        pickedDocBytes = null;
                                                        pickedDocName = null;
                                                        removeDoc = true;
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ] else ...[
                                            InkWell(
                                              onTap: () async {
                                                final result = await FilePicker.pickFiles(
                                                  type: FileType.custom,
                                                  allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
                                                  withData: true,
                                                );
                                                if (result != null && result.files.isNotEmpty) {
                                                  setDialogState(() {
                                                    pickedDocBytes = result.files.first.bytes;
                                                    pickedDocName = result.files.first.name;
                                                    removeDoc = false;
                                                  });
                                                }
                                              },
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                                ),
                                                child: const Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.upload_file_rounded, color: Color(0xFF13246E), size: 18),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      "Upload Document / PDF",
                                                      style: TextStyle(color: Color(0xFF13246E), fontWeight: FontWeight.bold, fontSize: 13),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Text(
                                            "Optional — supports PDF, DOC, XLS, TXT",
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // 7. Description / Content
                                _buildStyledInputField(
                                  label: "NOTICE DESCRIPTION *",
                                  child: TextField(
                                    controller: contentController,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      hintText: "Enter complete notice description, instructions, circular rules, and guidelines...",
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // 8. Notification Dispatch Checkbox
                                Row(
                                  children: [
                                    Checkbox(
                                      value: notifyUsers,
                                      activeColor: const Color(0xFF13246E),
                                      onChanged: (val) => setDialogState(() => notifyUsers = val ?? false),
                                    ),
                                    const Expanded(
                                      child: Text(
                                        "Dispatch instant notifications to selected audience (in-app & email notification)",
                                        style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),

                  // Actions Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("CANCEL", style: TextStyle(color: Colors.black54)),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF13246E),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isSavingAnnouncement
                              ? null
                              : () => _submitAnnouncement(
                                    ctx: ctx,
                                    item: item,
                                    title: titleController.text.trim(),
                                    content: contentController.text.trim(),
                                    category: category == 'CUSTOM' ? customCategoryController.text.trim() : category,
                                    priority: priority,
                                    selectedDeptId: selectedDeptId,
                                    targetAudience: targetAudience,
                                    selectedSemester: selectedSemester,
                                    selectedAcademicYear: selectedAcademicYear,
                                    publishDate: publishDate,
                                    expiryDate: expiryDate,
                                    pickedImageBytes: pickedImageBytes,
                                    pickedImageName: pickedImageName,
                                    removeImage: removeImage,
                                    pickedDocBytes: pickedDocBytes,
                                    pickedDocName: pickedDocName,
                                    removeDoc: removeDoc,
                                    notifyUsers: notifyUsers,
                                    isPublished: false,
                                    setDialogState: setDialogState,
                                  ),
                          child: const Text("SAVE AS DRAFT"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF13246E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isSavingAnnouncement
                              ? null
                              : () => _submitAnnouncement(
                                    ctx: ctx,
                                    item: item,
                                    title: titleController.text.trim(),
                                    content: contentController.text.trim(),
                                    category: category == 'CUSTOM' ? customCategoryController.text.trim() : category,
                                    priority: priority,
                                    selectedDeptId: selectedDeptId,
                                    targetAudience: targetAudience,
                                    selectedSemester: selectedSemester,
                                    selectedAcademicYear: selectedAcademicYear,
                                    publishDate: publishDate,
                                    expiryDate: expiryDate,
                                    pickedImageBytes: pickedImageBytes,
                                    pickedImageName: pickedImageName,
                                    removeImage: removeImage,
                                    pickedDocBytes: pickedDocBytes,
                                    pickedDocName: pickedDocName,
                                    removeDoc: removeDoc,
                                    notifyUsers: notifyUsers,
                                    isPublished: true,
                                    setDialogState: setDialogState,
                                  ),
                          child: _isSavingAnnouncement
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(isEdit ? "UPDATE NOTICE" : "PUBLISH NOTICE"),
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
    );
  }

  Future<void> _submitAnnouncement({
    required BuildContext ctx,
    required AnnouncementItem? item,
    required String title,
    required String content,
    required String category,
    required String priority,
    required String? selectedDeptId,
    required String targetAudience,
    required int? selectedSemester,
    required int? selectedAcademicYear,
    required DateTime? publishDate,
    required DateTime? expiryDate,
    required Uint8List? pickedImageBytes,
    required String? pickedImageName,
    required bool removeImage,
    required Uint8List? pickedDocBytes,
    required String? pickedDocName,
    required bool removeDoc,
    required bool notifyUsers,
    required bool isPublished,
    required StateSetter setDialogState,
  }) async {
    // Required-field validation
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Announcement title is required."), backgroundColor: Colors.red),
      );
      return;
    }
    if (category.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select or enter a category name."), backgroundColor: Colors.red),
      );
      return;
    }
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notice description is required."), backgroundColor: Colors.red),
      );
      return;
    }

    setDialogState(() => _isSavingAnnouncement = true);
    try {
      final dio = ApiClient().dio;
      final formMap = <String, dynamic>{
        'title': title,
        'content': content,
        'category': category.toUpperCase(),
        'priority': priority,
        'target_audience': targetAudience,
        'notify_users': notifyUsers,
        'is_published': isPublished,
      };

      if (selectedDeptId != null && selectedDeptId.isNotEmpty) {
        formMap['department'] = int.tryParse(selectedDeptId);
      }
      if (selectedSemester != null) {
        formMap['target_semester'] = selectedSemester;
      }
      if (selectedAcademicYear != null) {
        formMap['academic_year'] = selectedAcademicYear;
      }
      if (publishDate != null) {
        formMap['publish_date'] = publishDate.toIso8601String();
      }
      if (expiryDate != null) {
        formMap['expiry_date'] = expiryDate.toIso8601String();
      }

      // Add image file if newly picked, or remove flag if deleted
      if (pickedImageBytes != null && pickedImageName != null) {
        formMap['image'] = MultipartFile.fromBytes(pickedImageBytes, filename: pickedImageName);
      } else if (removeImage) {
        formMap['remove_image'] = 'true';
      }

      // Add attachment document if newly picked, or remove flag if deleted
      if (pickedDocBytes != null && pickedDocName != null) {
        formMap['attachment'] = MultipartFile.fromBytes(pickedDocBytes, filename: pickedDocName);
      } else if (removeDoc) {
        formMap['remove_attachment'] = 'true';
      }

      final formData = FormData.fromMap(formMap);

      if (item != null) {
        await dio.put('/announcements/items/${item.id}/', data: formData);
      } else {
        await dio.post('/announcements/items/', data: formData);
      }

      if (ctx.mounted) {
        Navigator.pop(ctx);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              item != null
                  ? "Campus notice updated successfully!"
                  : (isPublished ? "Campus announcement published and broadcast successfully!" : "Announcement saved as draft."),
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadAnnouncements();
      }
    } catch (e) {
      if (mounted) {
        setDialogState(() => _isSavingAnnouncement = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save notice: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setDialogState(() => _isSavingAnnouncement = false);
      }
    }
  }

  Widget _buildPreviewCard({
    required String title,
    required String content,
    required String category,
    required String priority,
    required String audience,
    required Uint8List? imageBytes,
    required String? imageUrl,
    required Uint8List? docBytes,
    required String? docName,
    required String? attachmentUrl,
    required DateTime? publishDate,
    required DateTime? expiryDate,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF13246E).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(category, style: const TextStyle(color: Color(0xFF13246E), fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(6)),
                    child: Text(priority, style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text("Audience: $audience", style: TextStyle(color: Colors.blue.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 10),
          Text(content, style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.5)),
          if (imageBytes != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(imageBytes, height: 160, width: double.infinity, fit: BoxFit.cover),
            ),
          ] else if (imageUrl != null && imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Text("[Image Attachment Preview]")),
            ),
          ],
          if (docBytes != null || (attachmentUrl != null && attachmentUrl.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    docName ?? (attachmentUrl != null ? attachmentUrl.split('/').last : "Attached Document"),
                    style: const TextStyle(color: Color(0xFF13246E), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Scheduled: ${publishDate != null ? "${publishDate.day}/${publishDate.month}/${publishDate.year}" : "Immediate"}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text("Expiry: ${expiryDate != null ? "${expiryDate.day}/${expiryDate.month}/${expiryDate.year}" : "Never"}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStyledInputField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6B7280),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD1D5DB)),
          ),
          child: child,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Image 2 Statistics
    final totalNotices = _announcements.length;
    final publishedNotices = _announcements.where((a) => a.isPublished).length;
    final scheduledNotices = _announcements.where((a) => a.publishDate != null && a.publishDate!.isAfter(DateTime.now())).length;
    final draftNotices = _announcements.where((a) => !a.isPublished).length;

    // Filter by query
    final filteredAnnouncements = _announcements.where((a) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return a.title.toLowerCase().contains(q) || a.content.toLowerCase().contains(q) || a.category.toLowerCase().contains(q);
    }).toList();

    // Collect all filter categories including any dynamic custom categories present in the announcements list
    final dynamicCategories = _announcements
        .map((a) => a.category.toUpperCase())
        .where((c) => !_standardCategories.contains(c))
        .toSet()
        .toList();
    final allDisplayCategories = [..._standardCategories, ...dynamicCategories];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // 1. Top Navy Header Bar (Image 2 style)
          Container(
            color: const Color(0xFF13246E),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      "Campus Announcements & Circulars",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _loadAnnouncements,
                  tooltip: "Refresh Notices",
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ],
            ),
          ),

          // Main Scrollable Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Administration Banner Card (Image 2 style)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E2B68), Color(0xFF243B80)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF13246E).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_balance_rounded, color: Color(0xFF1E2B68), size: 32),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBBF24).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "CAMPUS ADMINISTRATION",
                                  style: TextStyle(
                                    color: Color(0xFFFBBF24),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Campus-Wide Academic Notices & Official Circulars",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                "Dispatches institutional circulars, academic calendar alerts, and campus notifications",
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 3. Section Title (Image 2 style)
                  const Text(
                    "Campus Statistics",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. 4 KPI Cards (Image 2 style)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 900;
                      final cardWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _buildImage2KPICard(
                              title: "Total Notices",
                              value: "$totalNotices",
                              icon: Icons.campaign_rounded,
                              iconColor: const Color(0xFF13246E),
                              iconBg: const Color(0xFFEEF2FF),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _buildImage2KPICard(
                              title: "Published Notices",
                              value: "$publishedNotices",
                              icon: Icons.check_circle_outline_rounded,
                              iconColor: const Color(0xFF0D9488),
                              iconBg: const Color(0xFFCCFBF1),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _buildImage2KPICard(
                              title: "Scheduled Notices",
                              value: "$scheduledNotices",
                              icon: Icons.schedule_rounded,
                              iconColor: const Color(0xFFEA580C),
                              iconBg: const Color(0xFFFFEDD5),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _buildImage2KPICard(
                              title: "Draft Notices",
                              value: "$draftNotices",
                              icon: Icons.drafts_outlined,
                              iconColor: const Color(0xFF7C3AED),
                              iconBg: const Color(0xFFEDE9FE),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // 5. Container with History Tabs, Category Filters, and Notices
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // History Status Tabs
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Wrap(
                                spacing: 8,
                                children: _historyTabs.map((tab) {
                                  final isSelected = _selectedHistoryTab == tab;
                                  return ChoiceChip(
                                    label: Text(tab == 'ALL' ? 'All Notices' : tab),
                                    selected: isSelected,
                                    selectedColor: const Color(0xFF13246E),
                                    labelStyle: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black87,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                    onSelected: (val) {
                                      if (val) {
                                        setState(() => _selectedHistoryTab = tab);
                                        _loadAnnouncements();
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF13246E),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onPressed: () => _showCreateEditDialog(),
                                icon: const Icon(Icons.add_rounded, size: 20),
                                label: const Text("New Campus Notice"),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE5E7EB)),

                        // Toolbar & Category Filter
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 280,
                                height: 40,
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: "Search notices...",
                                    hintStyle: const TextStyle(fontSize: 13),
                                    prefixIcon: const Icon(Icons.search, size: 20),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                  ),
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: allDisplayCategories.map((cat) {
                                      final isSelected = _selectedCategory == cat;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: FilterChip(
                                          label: Text(cat == 'ALL' ? 'All Categories' : cat),
                                          selected: isSelected,
                                          selectedColor: const Color(0xFF13246E).withOpacity(0.15),
                                          labelStyle: TextStyle(
                                            color: isSelected ? const Color(0xFF13246E) : Colors.black87,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 12,
                                          ),
                                          onSelected: (val) {
                                            setState(() => _selectedCategory = cat);
                                            _loadAnnouncements();
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE5E7EB)),

                        // Announcements list
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _isLoading
                              ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
                              : _errorMessage != null
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                                      ),
                                    )
                                  : filteredAnnouncements.isEmpty
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(40),
                                            child: Column(
                                              children: [
                                                Icon(Icons.campaign_outlined, size: 48, color: Colors.grey.shade400),
                                                const SizedBox(height: 10),
                                                const Text("No campus notices found for this filter.", style: TextStyle(fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        )
                                      : ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: filteredAnnouncements.length,
                                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                                          itemBuilder: (context, index) {
                                            final item = filteredAnnouncements[index];
                                            return _buildNoticeItem(item);
                                          },
                                        ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeItem(AnnouncementItem item) {
    Color statusColor = Colors.green;
    String statusText = item.statusLabel ?? (item.isPublished ? "PUBLISHED" : "DRAFT");
    if (!item.isPublished) {
      statusColor = Colors.purple;
    } else if (item.publishDate != null && item.publishDate!.isAfter(DateTime.now())) {
      statusColor = Colors.orange;
      statusText = "SCHEDULED";
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Category, Priority, Audience, Status, and Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF13246E).withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                    child: Text(item.category, style: const TextStyle(color: Color(0xFF13246E), fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (item.priority == 'URGENT' ? Colors.red : (item.priority == 'IMPORTANT' ? Colors.orange : const Color(0xFF13246E))).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.priority,
                      style: TextStyle(
                        color: item.priority == 'URGENT' ? Colors.red.shade800 : (item.priority == 'IMPORTANT' ? Colors.orange.shade800 : const Color(0xFF13246E)),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  if (item.departmentName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(6)),
                      child: Text(item.departmentName!, style: TextStyle(color: Colors.indigo.shade800, fontWeight: FontWeight.w600, fontSize: 11)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(6)),
                      child: const Text("Campus-Wide", style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  if (item.targetAudience != null && item.targetAudience != 'ALL')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                      child: Text("Audience: ${item.targetAudience}", style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w600, fontSize: 11)),
                    ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.black54),
                    tooltip: "Edit Notice",
                    onPressed: () => _showCreateEditDialog(item: item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    tooltip: "Delete Notice",
                    onPressed: () => _deleteAnnouncement(item.id),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),

          // Content
          Text(item.content, style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.4)),

          // Image if present
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.imageUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          ],

          // PDF attachment if present
          if (item.attachmentUrl != null && item.attachmentUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.attachmentUrl!,
                    style: const TextStyle(color: Color(0xFF13246E), fontSize: 13, decoration: TextDecoration.underline),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Footer
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text("By ${item.authorName ?? 'Administration'}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(width: 16),
              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                item.publishDate != null ? "${item.publishDate!.day}/${item.publishDate!.month}/${item.publishDate!.year}" : "Recent",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              if (item.expiryDate != null) ...[
                const SizedBox(width: 16),
                Icon(Icons.timer_off_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text("Expires: ${item.expiryDate!.day}/${item.expiryDate!.month}/${item.expiryDate!.year}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImage2KPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF), size: 20),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}
