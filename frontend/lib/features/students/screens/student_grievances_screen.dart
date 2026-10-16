import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:dio/dio.dart';

class StudentGrievancesScreen extends StatefulWidget {
  const StudentGrievancesScreen({super.key});

  @override
  State<StudentGrievancesScreen> createState() => _StudentGrievancesScreenState();
}

class _StudentGrievancesScreenState extends State<StudentGrievancesScreen> {
  List<Map<String, dynamic>> _grievances = [];
  bool _isLoading = true;
  String? _errorMessage;

  // View state: true -> Image 4 form UI, false -> Grievances history
  bool _isCreating = false;
  bool _isSubmitting = false;

  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _descController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  String _selectedAuthority = 'HOD';
  String _selectedCategory = 'Academic';
  PlatformFile? _pickedFile;

  final List<String> _authorityOptions = [
    'HOD',
    'PRINCIPAL',
    'EXAM',
    'ACCOUNTS',
    'LIBRARY',
  ];

  final List<String> _categoryOptions = [
    'Academic',
    'Attendance',
    'IA Marks',
    'Fee Structure',
    'Hostel / Facilities',
    'Examination',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _fetchGrievances();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _descController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchGrievances() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/grievances/');
      final dynamic raw = res.data;
      final List list = raw is List ? raw : (raw is Map && raw['results'] is List ? raw['results'] : []);

      if (mounted) {
        setState(() {
          _grievances = List<Map<String, dynamic>>.from(list);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load grievances: $e";
        });
      }
    }
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
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
    final topic = _topicController.text.trim();
    final desc = _descController.text.trim();
    if (topic.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in Topic and Description")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final dio = ApiClient().dio;
      final fullDesc = _contactPhoneController.text.isNotEmpty
          ? "$desc\n[Contact: ${_contactPhoneController.text.trim()}]"
          : desc;

      dynamic payload;
      if (_pickedFile != null && _pickedFile!.bytes != null) {
        payload = FormData.fromMap({
          'topic': topic,
          'target_role': _selectedAuthority,
          'description': fullDesc,
          'category': _selectedCategory,
          'attachment': MultipartFile.fromBytes(_pickedFile!.bytes!, filename: _pickedFile!.name),
        });
      } else {
        payload = {
          'topic': topic,
          'target_role': _selectedAuthority,
          'description': fullDesc,
          'category': _selectedCategory,
        };
      }

      await dio.post('/grievances/', data: payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Grievance submitted successfully!"), backgroundColor: Colors.green),
        );
        _topicController.clear();
        _descController.clear();
        _contactPhoneController.clear();
        _pickedFile = null;
        setState(() {
          _isSubmitting = false;
          _isCreating = false;
        });
        _fetchGrievances();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to submit grievance: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Grievance & Support Desk",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh Grievances",
            onPressed: _fetchGrievances,
          ),
        ],
      ),
      body: _isCreating ? _buildCreateFormView() : _buildHistoryListView(),
    );
  }

  // --- IMAGE 4 FORM VIEW ---
  Widget _buildCreateFormView() {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Form(
          key: _formKey,
          child: Container(
            width: isDesktop ? 1100 : double.infinity,
            padding: EdgeInsets.all(isDesktop ? 40 : 20),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0), // Matching Image 4 gray background
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF13246E)),
                      onPressed: () => setState(() => _isCreating = false),
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      label: const Text("Back to Grievances", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const Text(
                      "Submit Academic Grievance",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 80),
                  ],
                ),
                const SizedBox(height: 36),

                isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildFormLeftColumn(),
                          ),
                          const SizedBox(width: 50),
                          Expanded(
                            flex: 1,
                            child: _buildFormRightColumn(),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildFormRightColumn(),
                          const SizedBox(height: 30),
                          _buildFormLeftColumn(),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormLeftColumn() {
    return Column(
      children: [
        _buildSnippedField(
          label: "Topic",
          controller: _topicController,
          hintText: "Enter grievance topic or subject",
        ),
        _buildDropdownRow(
          label: "Authority",
          value: _selectedAuthority,
          items: _authorityOptions,
          displayMapper: (val) {
            switch (val) {
              case 'HOD':
                return 'Head of Department (HOD)';
              case 'PRINCIPAL':
                return 'Principal Office';
              case 'EXAM':
                return 'Examination Cell';
              case 'ACCOUNTS':
                return 'Accounts / Fee Section';
              case 'LIBRARY':
                return 'Library Administration';
              default:
                return val;
            }
          },
          onChanged: (val) {
            if (val != null) setState(() => _selectedAuthority = val);
          },
        ),
        _buildDropdownRow(
          label: "Category",
          value: _selectedCategory,
          items: _categoryOptions,
          onChanged: (val) {
            if (val != null) setState(() => _selectedCategory = val);
          },
        ),
        _buildSnippedField(
          label: "Phone",
          controller: _contactPhoneController,
          hintText: "Your contact mobile number",
          keyboardType: TextInputType.phone,
        ),
        _buildSnippedField(
          label: "Description",
          controller: _descController,
          hintText: "Describe your issue, subject code, semester, and expected resolution...",
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildFormRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 180,
          width: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: _pickedFile == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_file_rounded, size: 64, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      "Optional Document\nPDF / Image",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 48, color: Colors.green),
                      const SizedBox(height: 8),
                      Text(
                        _pickedFile!.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB",
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 15),

        SizedBox(
          width: 150,
          child: ElevatedButton(
            onPressed: _pickAttachment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              "Upload Document",
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 120),

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _isCreating = false),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
              child: const Text("Cancel", style: TextStyle(color: Colors.black87)),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 130,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitGrievance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        "Submit",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSnippedField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    bool isReadOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextFormField(
                controller: controller,
                readOnly: isReadOnly,
                maxLines: maxLines,
                keyboardType: keyboardType,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String)? displayMapper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonFormField<String>(
                initialValue: value,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                ),
                items: items
                    .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(displayMapper != null ? displayMapper(item) : item, style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- GRIEVANCES HISTORY LIST VIEW ---
  Widget _buildHistoryListView() {
    final pendingCount = _grievances.where((g) => (g['status'] ?? '').toString().toLowerCase().contains('pending')).length;
    final resolvedCount = _grievances.where((g) => (g['status'] ?? '').toString().toLowerCase().contains('resolved')).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Submitted Grievances",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Track real-time resolution status of your academic and administrative concerns",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => setState(() => _isCreating = true),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text("New Grievance", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stat Cards
          Row(
            children: [
              _buildStatCard("TOTAL SUBMITTED", "${_grievances.length}", Icons.assignment_rounded, const Color(0xFF13246E)),
              const SizedBox(width: 14),
              _buildStatCard("PENDING REVIEW", "$pendingCount", Icons.hourglass_top_rounded, Colors.amber.shade800),
              const SizedBox(width: 14),
              _buildStatCard("RESOLVED ISSUES", "$resolvedCount", Icons.check_circle_outline_rounded, const Color(0xFF059669)),
            ],
          ),
          const SizedBox(height: 28),

          // List content
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(60),
                child: CircularProgressIndicator(color: Color(0xFF13246E)),
              ),
            )
          else if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.error_outline_rounded, size: 40, color: Colors.red.shade700),
                  const SizedBox(height: 10),
                  Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800)),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                    onPressed: _fetchGrievances,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
          else if (_grievances.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(60),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 56, color: Colors.green.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    "No Grievances Submitted",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "If you encounter any academic, attendance, or facility issues, click '+ New Grievance' above.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _grievances.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final g = _grievances[index];
                final topic = g['topic'] ?? 'Grievance';
                final desc = g['description'] ?? '';
                final statusStr = (g['status'] ?? 'Pending').toString();
                final targetRole = g['target_role'] ?? 'Authority';
                final response = g['response']?.toString();
                final created = g['created_at'] != null ? DateTime.tryParse(g['created_at'].toString()) : null;

                Color statusColor;
                Color statusBg;
                if (statusStr.toLowerCase().contains('resolved')) {
                  statusColor = Colors.green.shade800;
                  statusBg = Colors.green.shade50;
                } else if (statusStr.toLowerCase().contains('progress')) {
                  statusColor = Colors.blue.shade800;
                  statusBg = Colors.blue.shade50;
                } else {
                  statusColor = Colors.amber.shade900;
                  statusBg = Colors.amber.shade50;
                }

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF13246E).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "To: $targetRole",
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    topic,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusStr.toUpperCase(),
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(desc, style: const TextStyle(color: Color(0xFF334155), fontSize: 13, height: 1.4)),

                      if (response != null && response.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.reply_rounded, size: 16, color: Colors.blue.shade800),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Administrative Response",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade900),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(response, style: TextStyle(color: Colors.blue.shade900, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],

                      if (created != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          "Submitted on ${created.day}/${created.month}/${created.year}",
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
