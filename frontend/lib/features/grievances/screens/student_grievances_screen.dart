import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/grievance_provider.dart';
import '../models/grievance_model.dart';
import '../../../core/utils/validation_utils.dart';

class StudentGrievancesScreen extends StatefulWidget {
  const StudentGrievancesScreen({super.key});

  @override
  State<StudentGrievancesScreen> createState() => _StudentGrievancesScreenState();
}

class _StudentGrievancesScreenState extends State<StudentGrievancesScreen> {
  bool _isCreating = false;
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _descController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  int? _selectedCategoryId;
  bool _isCustomCategory = false;
  String _selectedPriority = 'MEDIUM';
  bool _isConfidential = false;
  PlatformFile? _pickedFile;

  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = Provider.of<GrievanceProvider>(context, listen: false);
      p.fetchCategories();
      p.setScope('my');
      p.fetchGrievances();
      p.fetchStats();
    });
  }

  @override
  void dispose() {
    _topicController.dispose();
    _descController.dispose();
    _contactPhoneController.dispose();
    _customCategoryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'docx'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _pickedFile = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error selecting file: $e")),
        );
      }
    }
  }

  Future<void> _submitGrievance() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _contactPhoneController.text.trim();
    if (phone.isNotEmpty) {
      final phoneError = ValidationUtils.validatePhone(phone);
      if (phoneError != null) {
        ValidationUtils.showValidationPopup(
          context,
          title: "Invalid Phone Number",
          message: phoneError,
        );
        return;
      }
    }

    final provider = Provider.of<GrievanceProvider>(context, listen: false);
    final desc = phone.isNotEmpty
        ? "${_descController.text.trim()}\n[Contact: $phone]"
        : _descController.text.trim();

    int? catId = _selectedCategoryId;
    String? catName;
    if (_isCustomCategory && _customCategoryController.text.trim().isNotEmpty) {
      catName = _customCategoryController.text.trim();
      final customCat = await provider.addCustomCategory(catName);
      catId = customCat.id;
    } else if (catId != null) {
      final found = provider.categories.firstWhere((c) => c.id == catId, orElse: () => provider.categories.first);
      catName = found.name;
    }

    final success = await provider.submitGrievance(
      topic: _topicController.text.trim(),
      description: desc,
      categoryId: catId,
      categoryName: catName,
      priority: _selectedPriority,
      isConfidential: _isConfidential,
      fileBytes: _pickedFile?.bytes,
      fileName: _pickedFile?.name,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Grievance submitted successfully! Tracking initiated."),
            backgroundColor: Colors.green,
          ),
        );
        _topicController.clear();
        _descController.clear();
        _contactPhoneController.clear();
        _pickedFile = null;
        setState(() {
          _isCreating = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? "Failed to submit grievance"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showProvideInfoDialog(GrievanceModel g) {
    final infoController = TextEditingController();
    PlatformFile? infoFile;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF13246E)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text("Provide Requested Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (g.infoRequestedNotes != null && g.infoRequestedNotes!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Officer Requested:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.brown)),
                        const SizedBox(height: 4),
                        Text(g.infoRequestedNotes!, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text("Your Response *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: infoController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "Enter the required clarifications or details...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final res = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
                      withData: true,
                    );
                    if (res != null && res.files.isNotEmpty) {
                      setDlgState(() => infoFile = res.files.first);
                    }
                  },
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: Text(infoFile == null ? "Attach Supporting File" : infoFile!.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13246E),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (infoController.text.trim().isEmpty) return;
                Navigator.of(ctx).pop();
                final p = Provider.of<GrievanceProvider>(context, listen: false);
                final messenger = ScaffoldMessenger.of(context);
                final ok = await p.provideInfo(
                  g.id,
                  notes: infoController.text.trim(),
                  fileBytes: infoFile?.bytes,
                  fileName: infoFile?.name,
                );
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(ok ? "Information provided successfully." : "Failed to submit information."),
                      backgroundColor: ok ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              child: const Text("Submit Response"),
            ),
          ],
        ),
      ),
    );
  }

  void _showReopenDialog(GrievanceModel g) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Request Reopening", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "If the resolution provided did not address your grievance, state why this case should be reopened for review.",
              style: TextStyle(fontSize: 13, color: Colors.blueGrey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Explain why issue remains unresolved...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              final p = Provider.of<GrievanceProvider>(context, listen: false);
              final ok = await p.requestReopen(g.id, reason: reasonController.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? "Reopening request submitted for review." : "Failed to submit request."),
                    backgroundColor: ok ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text("Submit Request"),
          ),
        ],
      ),
    );
  }

  void _showDetailModal(GrievanceModel g) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildStatusBadge(g.status),
                                  const SizedBox(width: 8),
                                  _buildPriorityBadge(g.priority),
                                  if (g.isConfidential) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.purple.shade200),
                                      ),
                                      child: const Text("Confidential", style: TextStyle(color: Colors.purple, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(g.topic, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text("Category: ${g.categoryName} • Filed on ${_formatDate(g.createdAt)}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Description
                    const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(g.description, style: const TextStyle(fontSize: 13, height: 1.4)),
                    ),

                    if (g.attachmentUrl != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text("View Supporting Attachment"),
                        onPressed: () {},
                      ),
                    ],

                    // Assigned Officer Info
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD0DDFC)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, color: Color(0xFF13246E)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Assigned Officer", style: TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                                Text(g.assignedOfficerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF13246E))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Resolution Remarks
                    if (g.resolutionRemarks != null && g.resolutionRemarks!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: Colors.green.shade800, size: 18),
                                const SizedBox(width: 6),
                                Text("Resolution Remarks", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade900)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(g.resolutionRemarks!, style: const TextStyle(fontSize: 13, height: 1.4)),
                          ],
                        ),
                      ),
                    ],

                    // Activity Timeline
                    const SizedBox(height: 20),
                    const Text("Timeline & History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),
                    if (g.activities.isEmpty)
                      const Text("No timeline events recorded.", style: TextStyle(fontSize: 12, color: Colors.grey))
                    else
                      ...g.activities.map((act) => _buildTimelineItem(act)),

                    const SizedBox(height: 24),

                    // Actions
                    if (g.status == "AWAITING_INFO") ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.edit_note, size: 20),
                        label: const Text("Provide Requested Information", style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _showProvideInfoDialog(g);
                        },
                      ),
                    ] else if (g.status == "RESOLVED" || g.status == "CLOSED") ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade800,
                          side: BorderSide(color: Colors.orange.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.replay_rounded, size: 20),
                        label: const Text("Issue Still Unresolved? Request Reopen"),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _showReopenDialog(g);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(GrievanceActivityModel act) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF13246E),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      act.action.replaceAll('_', ' '),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF13246E)),
                    ),
                    Text(_formatDate(act.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
                Text("by ${act.actorName} (${act.actorRole})", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                if (act.notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(act.notes, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status.toUpperCase()) {
      case 'SUBMITTED':
      case 'PENDING':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        break;
      case 'UNDER_REVIEW':
      case 'IN_PROGRESS':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        break;
      case 'AWAITING_INFO':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade700;
        break;
      case 'RESOLVED':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case 'CLOSED':
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        break;
      case 'ESCALATED':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        break;
      case 'REOPENED':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      case 'REJECTED':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color = Colors.blue;
    if (priority == 'URGENT') color = Colors.red;
    if (priority == 'HIGH') color = Colors.orange;
    if (priority == 'LOW') color = Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        priority,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GrievanceProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 16,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Student Grievance & Support Desk",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
                Text(
                  "Raise concerns, track review status & view resolution history",
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: "Refresh Grievances",
            onPressed: () {
              provider.fetchGrievances();
              provider.fetchStats();
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isCreating ? _buildCreateForm(provider) : _buildHistoryView(provider),
    );
  }

  Widget _buildHistoryView(GrievanceProvider provider) {
    var list = provider.grievances;
    if (_statusFilter == 'ACTIVE') {
      list = list.where((g) => ['SUBMITTED', 'PENDING', 'UNDER_REVIEW', 'IN_PROGRESS', 'AWAITING_INFO', 'ESCALATED', 'REOPENED'].contains(g.status)).toList();
    } else if (_statusFilter == 'AWAITING_INFO') {
      list = list.where((g) => g.status == 'AWAITING_INFO').toList();
    } else if (_statusFilter == 'RESOLVED') {
      list = list.where((g) => ['RESOLVED', 'CLOSED'].contains(g.status)).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((g) =>
          g.topic.toLowerCase().contains(q) ||
          g.description.toLowerCase().contains(q) ||
          g.categoryName.toLowerCase().contains(q) ||
          g.id.toString().contains(q)).toList();
    }

    final totalCount = provider.grievances.length;
    final activeCount = provider.grievances.where((g) => ['SUBMITTED', 'PENDING', 'UNDER_REVIEW', 'IN_PROGRESS', 'AWAITING_INFO', 'ESCALATED', 'REOPENED'].contains(g.status)).length;
    final awaitingCount = provider.grievances.where((g) => g.status == 'AWAITING_INFO').length;
    final resolvedCount = provider.grievances.where((g) => ['RESOLVED', 'CLOSED'].contains(g.status)).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome / Support Desk Banner matching Image 4
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF0F7FF), Color(0xFFE0F2FE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBAE6FD).withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.headset_mic_rounded,
                    color: Color(0xFF0D2158),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Student Grievance & Support Desk",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        "Raise your concerns, track their status, and get support from the concerned department.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Opacity(
                  opacity: 0.6,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF3B82F6), size: 20),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.article_outlined, color: Color(0xFF3B82F6), size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action button row matching Image 4
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D2158),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text("New Grievance", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => setState(() => _isCreating = true),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Metric Cards matching Image 4
          Row(
            children: [
              Expanded(
                child: _buildGrievanceMetricCard(
                  icon: Icons.description_rounded,
                  iconColor: const Color(0xFF0284C7),
                  iconBg: const Color(0xFFE0F2FE),
                  label: "Total Grievances",
                  value: "$totalCount",
                  valColor: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGrievanceMetricCard(
                  icon: Icons.access_time_filled_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBg: const Color(0xFFFEF3C7),
                  label: "Active",
                  value: "$activeCount",
                  valColor: const Color(0xFFD97706),
                  subtitle: "Currently in progress",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGrievanceMetricCard(
                  icon: Icons.error_rounded,
                  iconColor: const Color(0xFF9333EA),
                  iconBg: const Color(0xFFF3E8FF),
                  label: "Action Required",
                  value: "$awaitingCount",
                  valColor: const Color(0xFF9333EA),
                  subtitle: "Needs your attention",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGrievanceMetricCard(
                  icon: Icons.check_circle_rounded,
                  iconColor: const Color(0xFF16A34A),
                  iconBg: const Color(0xFFDCFCE7),
                  label: "Resolved",
                  value: "$resolvedCount",
                  valColor: const Color(0xFF16A34A),
                  subtitle: "Successfully closed",
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Filter Pills & Search Bar matching Image 4
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildGrievanceFilterPill("ALL", "All ($totalCount)"),
                    _buildGrievanceFilterPill("ACTIVE", "Active ($activeCount)"),
                    _buildGrievanceFilterPill("AWAITING_INFO", "Action Required ($awaitingCount)"),
                    _buildGrievanceFilterPill("RESOLVED", "Resolved ($resolvedCount)"),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 240,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                          hintText: "Search grievances...",
                          hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Empty State Container matching Image 4
          if (provider.isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(60.0), child: CircularProgressIndicator(color: Color(0xFF0D2158))))
          else if (list.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F2FE),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.inbox_rounded,
                        size: 42,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "No Grievances Found",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "You haven't raised any grievances yet.\nClick the button below to submit a new grievance if you need support with academics, fees or facilities.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D2158),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("New Grievance", style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => setState(() => _isCreating = true),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final g = list[index];
                return InkWell(
                  onTap: () => _showDetailModal(g),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: g.status == 'AWAITING_INFO' ? Colors.purple.shade300 : const Color(0xFFE2E8F0),
                        width: g.status == 'AWAITING_INFO' ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildStatusBadge(g.status),
                            const SizedBox(width: 8),
                            _buildPriorityBadge(g.priority),
                            const Spacer(),
                            Text(_formatDate(g.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(g.topic, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          g.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(g.categoryName, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Assigned: ${g.assignedOfficerName}",
                                style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700, fontStyle: FontStyle.italic),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                          ],
                        ),
                        if (g.status == 'AWAITING_INFO') ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.error_outline, size: 14, color: Colors.purple),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text("Action Required: Officer requested further information.", style: TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGrievanceFilterPill(String key, String label) {
    final selected = _statusFilter == key;
    return InkWell(
      onTap: () => setState(() => _statusFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0D2158) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF0D2158) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: selected ? Colors.white : const Color(0xFF64748B),
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildGrievanceMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    required Color valColor,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: valColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm(GrievanceProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _isCreating = false),
                ),
                const SizedBox(width: 8),
                const Text("Submit Grievance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF13246E))),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Dropdown
                  const Text("Grievance Category *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      hintText: "Select category",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    initialValue: _selectedCategoryId,
                    items: [
                      ...provider.categories.map((c) {
                        return DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(c.name, style: const TextStyle(fontSize: 13)),
                        );
                      }),
                      const DropdownMenuItem<int>(
                        value: -999,
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFF13246E)),
                            SizedBox(width: 8),
                            Text("+ Add Custom Category", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF13246E))),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedCategoryId = val;
                        if (val == -999) {
                          _isCustomCategory = true;
                        } else {
                          final cat = provider.categories.firstWhere((c) => c.id == val, orElse: () => provider.categories.first);
                          _isCustomCategory = cat.code == 'OTHER';
                          if (cat.isConfidentialByDefault) {
                            _isConfidential = true;
                          }
                        }
                      });
                    },
                    validator: (val) => val == null ? "Category is required" : null,
                  ),
                  if (_isCustomCategory) ...[
                    const SizedBox(height: 12),
                    const Text("Custom Category Name *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _customCategoryController,
                      decoration: InputDecoration(
                        hintText: "Enter custom category (e.g. Hostel Wi-Fi, Sports, Lab Equipment)",
                        prefixIcon: const Icon(Icons.category_outlined, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (val) {
                        if (_isCustomCategory && (val == null || val.trim().isEmpty)) {
                          return "Please enter custom category name";
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Priority Selector
                  const Text("Priority Level *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: ['LOW', 'MEDIUM', 'HIGH', 'URGENT'].map((p) {
                      final sel = _selectedPriority == p;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => setState(() => _selectedPriority = p),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: sel ? const Color(0xFF13246E) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: sel ? const Color(0xFF13246E) : Colors.grey.shade300),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                p,
                                style: TextStyle(
                                  color: sel ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Topic
                  const Text("Grievance Topic / Subject *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _topicController,
                    decoration: InputDecoration(
                      hintText: "Brief summary of your grievance",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? "Topic is required" : null,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  const Text("Detailed Description *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: "Provide all relevant context, dates, subject codes or specifics...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? "Description is required" : null,
                  ),
                  const SizedBox(height: 16),

                  // Contact Phone
                  const Text("Contact Phone (Optional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _contactPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: "Phone number for faster resolution updates",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confidentiality Checkbox
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Mark as Confidential", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Restricts visibility exclusively to leadership and assigned authorities.", style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                    value: _isConfidential,
                    onChanged: (val) => setState(() => _isConfidential = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 12),

                  // Attachment
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _pickAttachment,
                    icon: const Icon(Icons.attach_file, size: 18),
                    label: Text(_pickedFile == null ? "Attach Supporting Document (PDF, Image)" : _pickedFile!.name),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13246E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: provider.isSubmitting ? null : _submitGrievance,
                      child: provider.isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("SUBMIT GRIEVANCE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
}
