import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

class NewCorrectionRequestScreen extends StatefulWidget {
  const NewCorrectionRequestScreen({super.key});

  @override
  State<NewCorrectionRequestScreen> createState() => _NewCorrectionRequestScreenState();
}

class _NewCorrectionRequestScreenState extends State<NewCorrectionRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedCategory = 'PERSONAL';
  final _targetRecordCtrl = TextEditingController();
  final _currentValueCtrl = TextEditingController();
  final _requestedValueCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  XFile? _selectedFile;

  bool _isSubmitting = false;

  final List<Map<String, String>> _categories = [
    {'code': 'PERSONAL', 'label': 'Personal Details (Name, Phone, DOB, Address)'},
    {'code': 'ADMISSION_USN', 'label': 'USN & Admission Records (Seat type, Quota, CET)'},
    {'code': 'ATTENDANCE', 'label': 'Attendance Discrepancy (Subject, Session Date)'},
    {'code': 'IA_MARKS', 'label': 'IA Marks Error (Test 1/2, Component)'},
    {'code': 'EXAM_RESULTS', 'label': 'External Exam Results Discrepancy'},
    {'code': 'FEES', 'label': 'Fees & Payment Records (Receipt, Transaction)'},
    {'code': 'DOCUMENTS', 'label': 'Uploaded Documents (Marks card, Certificate)'},
    {'code': 'LIBRARY', 'label': 'Library Records (Borrowed Books, Dues)'},
    {'code': 'ACADEMIC', 'label': 'Subjects & Timetable Allocation'},
    {'code': 'ACCOUNT', 'label': 'Account & Profile Access'},
    {'code': 'OTHER', 'label': 'Other College Record Discrepancy'},
  ];

  @override
  void dispose() {
    _targetRecordCtrl.dispose();
    _currentValueCtrl.dispose();
    _requestedValueCtrl.dispose();
    _descriptionCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file != null) {
        setState(() => _selectedFile = file);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to pick file: $e")),
      );
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final dio = ApiClient().dio;

      final Map<String, dynamic> payload = {
        'category': _selectedCategory,
        'target_record_ref': _targetRecordCtrl.text.trim(),
        'current_value': _currentValueCtrl.text.trim(),
        'requested_value': _requestedValueCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'reason': _reasonCtrl.text.trim(),
      };

      dynamic requestData = payload;

      if (_selectedFile != null) {
        final bytes = await _selectedFile!.readAsBytes();
        final formData = FormData.fromMap({
          ...payload,
          'evidence_file': MultipartFile.fromBytes(
            bytes,
            filename: _selectedFile!.name,
          ),
        });
        requestData = formData;
      }

      final res = await dio.post('/corrections/requests/', data: requestData);

      if (mounted) {
        final reqId = res.data?['request_id'] ?? 'CR-XXXX';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Correction Request ($reqId) submitted successfully!"),
            backgroundColor: const Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        String err = "Failed to submit request. Please verify inputs and try again.";
        if (e is DioException && e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map) {
            err = (data['error'] ?? data['detail'] ?? data.values.first).toString();
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Report Mistake / Correction", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notice Header
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
                        Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF1D4ED8)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Notice: Official records (Attendance, IA Marks, Fees, and USN) cannot be edited directly by students. Submitting this request routes it to the responsible department for formal verification and authorized correction.",
                            style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Category
                  const Text("Correction Category *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        items: _categories.map((c) {
                          return DropdownMenuItem(
                            value: c['code'],
                            child: Text(c['label']!, style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Target Record Reference
                  const Text("Target Record / Field Reference *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _targetRecordCtrl,
                    decoration: InputDecoration(
                      hintText: "e.g. Subject CS501, Session 2026-10-15, Fee Receipt #1042",
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? "Please specify the record requiring correction" : null,
                  ),
                  const SizedBox(height: 16),

                  // Current Value vs Requested Value
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Current Value (if known)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _currentValueCtrl,
                              decoration: InputDecoration(
                                hintText: "e.g. Absent / 15 Marks",
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            const Text("Requested Correct Value *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _requestedValueCtrl,
                              decoration: InputDecoration(
                                hintText: "e.g. Present / 20 Marks",
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? "Please specify the correct value" : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  const Text("Mistake Description *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descriptionCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Explain exactly what mistake occurred in the record...",
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) => (v == null || v.trim().length < 5) ? "Please provide a detailed description (min 5 chars)" : null,
                  ),
                  const SizedBox(height: 16),

                  // Reason
                  const Text("Reason for Correction *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _reasonCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: "e.g. Attended class on medical leave approval, fee challan verified with bank",
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) => (v == null || v.trim().length < 5) ? "Please provide the reason (min 5 chars)" : null,
                  ),
                  const SizedBox(height: 16),

                  // Evidence Upload (Optional)
                  const Text("Supporting Evidence (Optional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickFile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedFile != null ? Icons.check_circle : Icons.upload_file_rounded,
                            color: _selectedFile != null ? const Color(0xFF15803D) : const Color(0xFF64748B),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedFile != null ? _selectedFile!.name : "Upload document or image proof (max 5MB)",
                              style: TextStyle(
                                fontSize: 13,
                                color: _selectedFile != null ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                fontWeight: _selectedFile != null ? FontWeight.bold : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          OutlinedButton(
                            onPressed: _pickFile,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              side: const BorderSide(color: Color(0xFF13246E)),
                            ),
                            child: Text(_selectedFile != null ? "Change" : "Browse", style: const TextStyle(fontSize: 12, color: Color(0xFF13246E))),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isSubmitting ? null : () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Cancel"),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF13246E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting ? null : _submitRequest,
                        icon: _isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 16),
                        label: Text(_isSubmitting ? "Submitting..." : "Submit Correction Request"),
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
}
