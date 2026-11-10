import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend/core/network/api_client.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  State<StudentAssignmentsScreen> createState() => _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _works = [];

  String _selectedSubjectFilter = 'All Subjects';
  String _selectedSort = 'Latest First';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Track submitted works in student session
  final Map<int, Map<String, dynamic>> _submissions = {
    2: {
      'submitted_date': '18 Oct 2026',
      'file_name': 'solution_networks_problemsheet2.pdf',
      'status': 'Submitted',
      'marks': 'Pending Evaluation',
    }
  };

  @override
  void initState() {
    super.initState();
    _fetchAssignedWorks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAssignedWorks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/subjects/works/');
      final List raw = res.data is List
          ? res.data
          : (res.data is Map && res.data['results'] is List ? res.data['results'] : []);

      if (raw.isNotEmpty) {
        if (mounted) {
          setState(() {
            _works = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("Error loading assignments: $e");
    }

    // Fallback sample data matching Image 3
    if (mounted) {
      setState(() {
        _works = _getSampleWorks();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getSampleWorks() {
    return [
      {
        'id': 1,
        'subject_code': 'CS301',
        'subject_name': 'Data Structures & Algorithms',
        'title': 'Assignment 1',
        'description': 'Solve the given problems and submit handwritten or typed solution.',
        'max_marks': 10,
        'faculty_name': 'Prof. Dr. Ramesh Sharma',
        'created_at': '2026-10-17',
        'due_date': '2026-10-24',
        'work_image': 'https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=400&q=80',
        'pill_color': const Color(0xFF2563EB),
        'pill_bg': const Color(0xFFEFF6FF),
      },
      {
        'id': 2,
        'subject_code': 'CS302',
        'subject_name': 'Computer Networks',
        'title': 'Problem Sheet 2',
        'description': 'Answer all the questions. Submit the solution in PDF format.',
        'max_marks': 10,
        'faculty_name': 'Prof. Mrs. Kavitha N',
        'created_at': '2026-10-10',
        'due_date': '2026-10-20',
        'work_image': 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=400&q=80',
        'pill_color': const Color(0xFF059669),
        'pill_bg': const Color(0xFFECFDF5),
      },
      {
        'id': 3,
        'subject_code': 'CS303',
        'subject_name': 'Operating Systems',
        'title': 'Assignment 3',
        'description': 'Draw and explain different CPU scheduling algorithms.',
        'max_marks': 10,
        'faculty_name': 'Prof. Mr. Suresh B',
        'created_at': '2026-10-05',
        'due_date': '2026-10-15',
        'work_image': 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=400&q=80',
        'pill_color': const Color(0xFFEA580C),
        'pill_bg': const Color(0xFFFFF7ED),
      },
    ];
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

  void _showAssignmentDetailsDialog(Map<String, dynamic> w) {
    final int workId = (w['id'] as num?)?.toInt() ?? 0;
    final isSubmitted = _submissions.containsKey(workId);
    final subData = _submissions[workId];

    final title = w['title'] ?? 'Assignment';
    final desc = w['description'] ?? 'No description provided.';
    final subCode = w['subject_code'] ?? 'CS301';
    final subName = w['subject_name'] ?? 'Subject';
    final facultyName = w['faculty_name'] ?? 'Faculty';
    final dueDate = w['due_date']?.toString() ?? '2026-10-24';
    final assignedDate = w['created_at']?.toString().split('T').first ?? '2026-10-17';
    final maxMarks = w['max_marks'] ?? 10;
    final imageUrl = (w['work_image_url'] ?? w['work_image'])?.toString();

    PlatformFile? solutionFile;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Subject Badge + Close Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            "$subCode: $subName",
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Metadata row
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(facultyName, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text("Assigned: $assignedDate", style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.assignment_outlined, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text("Max Marks: $maxMarks", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFFEA580C)),
                            const SizedBox(width: 6),
                            Text("Due: $dueDate", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 28),

                    // Instructions / Description
                    const Text(
                      "Assignment Instructions",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        desc,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Question Paper Attachment Image Preview
                    if (imageUrl != null && imageUrl.isNotEmpty) ...[
                      const Text(
                        "Attachment / Question Sheet",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showImagePreviewDialog(imageUrl, title),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Center(
                                    child: Icon(Icons.broken_image_rounded, color: Colors.grey),
                                  ),
                                ),
                                Container(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  child: const Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          "Click to View Full Image",
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Submission Section
                    const Divider(height: 24),
                    const Text(
                      "Your Submission",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 10),

                    if (isSubmitted) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "Assignment Submitted on ${subData?['submitted_date'] ?? '18 Oct 2026'}",
                                  style: const TextStyle(
                                    color: Color(0xFF059669),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "File: ${subData?['file_name'] ?? 'solution.pdf'}",
                              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Status: ${subData?['marks'] ?? 'Pending Evaluation'}",
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Upload solution file
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        onPressed: () async {
                          final res = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'docx'],
                            withData: true,
                          );
                          if (res != null && res.files.isNotEmpty) {
                            setDlgState(() => solutionFile = res.files.first);
                          }
                        },
                        icon: const Icon(Icons.attach_file_rounded, size: 18, color: Color(0xFF13246E)),
                        label: Text(
                          solutionFile == null ? "Attach Solution File (PDF, PNG, JPG)" : solutionFile!.name,
                          style: const TextStyle(color: Color(0xFF13246E), fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: "Add submission notes or comments (optional)...",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF13246E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            setState(() {
                              _submissions[workId] = {
                                'submitted_date': '18 Oct 2026',
                                'file_name': solutionFile?.name ?? 'solution_submission.pdf',
                                'status': 'Submitted',
                                'marks': 'Pending Evaluation',
                              };
                            });
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Assignment submitted successfully!"),
                                backgroundColor: Color(0xFF059669),
                              ),
                            );
                          },
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text("Submit Assignment", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Unique subject codes for filter
    final uniqueSubjects = <String>{'All Subjects'};
    for (final w in _works) {
      final name = w['subject_name']?.toString() ?? w['subject_code']?.toString();
      if (name != null && name.isNotEmpty) uniqueSubjects.add(name);
    }

    final filteredWorks = _works.where((w) {
      if (_selectedSubjectFilter != 'All Subjects') {
        if (w['subject_name'] != _selectedSubjectFilter && w['subject_code'] != _selectedSubjectFilter) {
          return false;
        }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF13246E)))
          : RefreshIndicator(
              onRefresh: _fetchAssignedWorks,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- HEADER (Title & Subtitle) ---
                    const Text(
                      "My Assignments",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "My Assignments & Coursework",
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- HERO BANNER (Image 3) ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F2B82), Color(0xFF1E3A8A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F2B82).withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Left Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.description_outlined, color: Colors.white, size: 14),
                                          SizedBox(width: 6),
                                          Text(
                                            "Course Assignments",
                                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  "Assigned Works & Problem Sheets",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "View assignments, homework sheets, and question paper images provided by your professors.",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Right Illustration Graphic
                          Container(
                            width: 80,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(Icons.file_copy_rounded, color: Colors.white, size: 36),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- FILTER & SEARCH BAR (Image 3) ---
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Row(
                          children: [
                            // Subject Filter Dropdown
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: uniqueSubjects.contains(_selectedSubjectFilter) ? _selectedSubjectFilter : 'All Subjects',
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                                  items: uniqueSubjects.map((s) {
                                    return DropdownMenuItem(
                                      value: s,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF1E293B)),
                                          const SizedBox(width: 8),
                                          Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedSubjectFilter = val);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Search Field
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                  decoration: const InputDecoration(
                                    hintText: "Search assignments...",
                                    hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Sort Dropdown
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedSort,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                                  items: ['Latest First', 'Due Date (Earliest)', 'Max Marks'].map((s) {
                                    return DropdownMenuItem(
                                      value: s,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF1E293B)),
                                          const SizedBox(width: 8),
                                          Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedSort = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // --- ASSIGNMENT CARDS LIST (Image 3) ---
                    if (filteredWorks.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(50),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.assignment_turned_in_outlined, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text("No assignments found", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text("Assignments published by faculty will appear here.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredWorks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (context, idx) {
                          final w = filteredWorks[idx];
                          final int workId = (w['id'] as num?)?.toInt() ?? 0;
                          final isSubmitted = _submissions.containsKey(workId);
                          final subData = _submissions[workId];

                          final title = w['title'] ?? 'Assignment';
                          final desc = w['description'] ?? '';
                          final subCode = w['subject_code'] ?? 'CS301';
                          final subName = w['subject_name'] ?? 'Subject';
                          final facultyName = w['faculty_name'] ?? 'Professor';
                          final dueDate = w['due_date']?.toString() ?? '2026-10-24';
                          final maxMarks = w['max_marks'] ?? 10;
                          final imageUrl = (w['work_image_url'] ?? w['work_image'])?.toString();

                          // Visual styles
                          final Color pillColor = w['pill_color'] as Color? ?? const Color(0xFF2563EB);
                          final Color pillBg = w['pill_bg'] as Color? ?? const Color(0xFFEFF6FF);

                          // Dynamic Due status calculations based on actual calendar date
                          DateTime? parsedDue;
                          try {
                            parsedDue = DateTime.tryParse(dueDate);
                          } catch (_) {}

                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final dueDay = parsedDue != null ? DateTime(parsedDue.year, parsedDue.month, parsedDue.day) : null;
                          final diffDays = dueDay != null ? dueDay.difference(today).inDays : null;

                          final bool isOverdue = !isSubmitted && diffDays != null && diffDays < 0;
                          final bool isDueToday = !isSubmitted && diffDays == 0;
                          final int overdueDays = diffDays != null && diffDays < 0 ? diffDays.abs() : 0;
                          final int daysLeft = diffDays != null && diffDays > 0 ? diffDays : 0;

                          String statusSubText = "";
                          Color badgeBg = const Color(0xFFFFF7ED);
                          Color badgeBorder = const Color(0xFFFFEDD5);
                          Color badgeFg = const Color(0xFFEA580C);
                          Color subTextFg = const Color(0xFFEA580C);

                          if (isSubmitted) {
                            badgeBg = const Color(0xFFECFDF5);
                            badgeBorder = const Color(0xFFA7F3D0);
                            badgeFg = const Color(0xFF059669);
                            subTextFg = const Color(0xFF059669);
                            statusSubText = "Submitted on ${subData?['submitted_date'] ?? 'Submitted'}";
                          } else if (isOverdue) {
                            badgeBg = const Color(0xFFFEF2F2);
                            badgeBorder = const Color(0xFFFECACA);
                            badgeFg = const Color(0xFFDC2626);
                            subTextFg = const Color(0xFFDC2626);
                            statusSubText = overdueDays == 1 ? "Overdue 1 day late" : "Overdue $overdueDays days late";
                          } else if (isDueToday) {
                            badgeBg = const Color(0xFFFFF7ED);
                            badgeBorder = const Color(0xFFFFEDD5);
                            badgeFg = const Color(0xFFEA580C);
                            subTextFg = const Color(0xFFEA580C);
                            statusSubText = "Due today";
                          } else if (diffDays != null) {
                            final isUrgent = diffDays <= 3;
                            badgeBg = isUrgent ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5);
                            badgeBorder = isUrgent ? const Color(0xFFFFEDD5) : const Color(0xFFA7F3D0);
                            badgeFg = isUrgent ? const Color(0xFFEA580C) : const Color(0xFF059669);
                            subTextFg = isUrgent ? const Color(0xFFEA580C) : const Color(0xFF059669);
                            statusSubText = daysLeft == 1 ? "1 day left" : "$daysLeft days left";
                          } else {
                            statusSubText = "Due: $dueDate";
                          }

                          String assignedDateStr = "17 Oct 2026";
                          if (w['created_at'] != null) {
                            try {
                              final dt = DateTime.parse(w['created_at'].toString());
                              assignedDateStr = DateFormat('dd MMM yyyy').format(dt);
                            } catch (_) {
                              assignedDateStr = w['created_at'].toString().split('T').first;
                            }
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: () => _showAssignmentDetailsDialog(w),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1. Thumbnail Image with Zoom Overlay (Image 3)
                                    if (imageUrl != null && imageUrl.isNotEmpty) ...[
                                      InkWell(
                                        onTap: () => _showImagePreviewDialog(imageUrl, title),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          width: 105,
                                          height: 95,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(9),
                                                child: Image.network(
                                                  imageUrl,
                                                  width: 105,
                                                  height: 95,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.5),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 18),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                    ],

                                    // 2. Middle Details (Image 3)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Subject Pill Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: pillBg,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: pillColor.withValues(alpha: 0.2)),
                                            ),
                                            child: Text(
                                              "$subCode: $subName",
                                              style: TextStyle(
                                                color: pillColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),

                                          // Title
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 4),

                                          // Description
                                          Text(
                                            desc,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF64748B),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 10),

                                          // Meta row: Max marks, Faculty, Assigned date
                                          Wrap(
                                            spacing: 16,
                                            runSpacing: 4,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.assignment_outlined, size: 14, color: Color(0xFF2563EB)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Max Marks: $maxMarks",
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    facultyName,
                                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF64748B)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Assigned: $assignedDateStr",
                                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // 3. Right Status & Action Button (Image 3)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        // Dynamic Due Status Pill & Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: badgeBg,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: badgeBorder),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isSubmitted
                                                    ? Icons.check_circle_rounded
                                                    : (isOverdue ? Icons.error_outline_rounded : Icons.access_time_rounded),
                                                size: 14,
                                                color: badgeFg,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                "Due: $dueDate",
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeFg),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          statusSubText,
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subTextFg),
                                        ),
                                        const SizedBox(height: 14),

                                        // Action Button: View Details >
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            backgroundColor: const Color(0xFFEFF6FF),
                                            foregroundColor: const Color(0xFF2563EB),
                                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _showAssignmentDetailsDialog(w),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                isSubmitted ? "View Submission" : "View Details",
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.chevron_right_rounded, size: 16),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
