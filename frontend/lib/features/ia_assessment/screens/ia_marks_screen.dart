import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

class IAMarksScreen extends ConsumerStatefulWidget {
  final int subjectId;
  final String? subjectName;

  const IAMarksScreen({
    super.key,
    required this.subjectId,
    this.subjectName,
  });

  @override
  ConsumerState<IAMarksScreen> createState() => _IAMarksScreenState();
}

class _IAMarksScreenState extends ConsumerState<IAMarksScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _students = [];
  final Map<int, TextEditingController> _controllers = {};

  String _iaType = 'Test1';
  final TextEditingController _iaNameController = TextEditingController(text: 'Internal Assessment 1');
  final TextEditingController _maxMarksController = TextEditingController(text: '25');

  final List<String> _iaTypes = ['Test1', 'Test2', 'Assignment', 'Quiz'];

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  @override
  void dispose() {
    _iaNameController.dispose();
    _maxMarksController.dispose();
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final response = await dio.get(
        '/ia/faculty/active-students/',
        queryParameters: {'subject_id': widget.subjectId},
      );

      final List data = response.data is List ? response.data : [];
      final List<Map<String, dynamic>> students = data
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      for (var s in students) {
        final id = s['id'] as int;
        _controllers.putIfAbsent(id, () => TextEditingController(text: '0'));
      }

      if (mounted) {
        setState(() {
          _students = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        String msg = "Could not load students for this subject.";
        if (e is DioException) {
          final data = e.response?.data;
          if (e.response?.statusCode == 403) {
            msg = data is Map && data['error'] != null
                ? data['error'].toString()
                : "Permission Denied: Only the faculty member assigned to teach this subject can enter or update IA marks.";
          } else if (data is Map && data['error'] != null) {
            msg = data['error'].toString();
          } else if (e.response?.statusCode == 404) {
            msg = "No enrolled students found for this subject.";
          }
        }
        setState(() {
          _errorMessage = msg;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitMarks() async {
    final maxMarks = int.tryParse(_maxMarksController.text.trim()) ?? 0;
    if (maxMarks <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Max marks must be greater than 0."), backgroundColor: Colors.red),
      );
      return;
    }

    final iaName = _iaNameController.text.trim();
    if (iaName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Assessment Name is required."), backgroundColor: Colors.red),
      );
      return;
    }

    final List<Map<String, dynamic>> marksPayload = [];
    for (var s in _students) {
      final id = s['id'] as int;
      final text = _controllers[id]?.text.trim() ?? '0';
      final val = double.tryParse(text);
      if (val == null || val < 0 || val > maxMarks) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Invalid mark '$text' for student ${s['usn'] ?? s['name']}. Must be 0 to $maxMarks."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      marksPayload.add({
        "student_id": id,
        "obtained_marks": val,
      });
    }

    setState(() => _isSubmitting = true);

    try {
      final dio = ApiClient().dio;

      // 1. Create or get IA Test Setup
      final testRes = await dio.post('/ia/ia-tests/create/', data: {
        'subject': widget.subjectId,
        'ia_type': _iaType,
        'ia_name': iaName,
        'max_marks': maxMarks,
      });

      final testId = testRes.data['id'];

      // 2. Submit Bulk Marks
      await dio.put('/ia/ia-tests/$testId/update-marks/', data: {
        'marks': marksPayload,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("IA Marks submitted successfully!"), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        String msg = "Submission failed. Please check inputs and try again.";
        if (e is DioException && e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map) {
            if (data['error'] != null) {
              msg = data['error'].toString();
            } else if (data['detail'] != null) {
              msg = data['detail'].toString();
            } else if (data['non_field_errors'] != null) {
              msg = (data['non_field_errors'] is List)
                  ? (data['non_field_errors'] as List).join(", ")
                  : data['non_field_errors'].toString();
            } else {
              msg = data.values.map((v) => v is List ? v.join(", ") : v.toString()).join("; ");
            }
          } else if (data is String && data.isNotEmpty) {
            msg = data;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("IA Marks Entry", style: TextStyle(fontSize: 16)),
            Text(widget.subjectName ?? "Subject Assessment", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text("Error: $_errorMessage", textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchStudents,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Test Configuration Card ---
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Assessment Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _iaType,
                                      decoration: const InputDecoration(labelText: "Assessment Type", border: OutlineInputBorder()),
                                      items: _iaTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _iaType = val);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _maxMarksController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: "Max Marks", border: OutlineInputBorder()),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _iaNameController,
                                decoration: const InputDecoration(labelText: "Assessment Name", border: OutlineInputBorder()),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- Student Roster ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Student Marks Roster", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Chip(label: Text("${_students.length} Students")),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_students.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: Text("No enrolled students found for this subject.")),
                          ),
                        )
                      else
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _students.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final student = _students[index];
                              final id = student['id'] as int;
                              final controller = _controllers[id]!;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF13246E).withOpacity(0.1),
                                  foregroundColor: const Color(0xFF13246E),
                                  child: Text("${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                title: Text(student['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text("USN: ${student['usn'] ?? 'N/A'}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                trailing: SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    controller: controller,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(),
                                      hintText: "0",
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
      bottomNavigationBar: _students.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isSubmitting ? null : _submitMarks,
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("SUBMIT IA MARKS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
    );
  }
}
