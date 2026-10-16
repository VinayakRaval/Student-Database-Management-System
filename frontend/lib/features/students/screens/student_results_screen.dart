import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

class StudentResultsScreen extends StatefulWidget {
  const StudentResultsScreen({super.key});

  @override
  State<StudentResultsScreen> createState() => _StudentResultsScreenState();
}

class _StudentResultsScreenState extends State<StudentResultsScreen> {
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _studentProfile;
  bool _isLoading = true;
  String? _errorMessage;

  // Toggle for Image 2 Upload Form View
  bool _isUploadingMode = false;

  // Form State
  int _selectedSem = 1;
  String _examType = 'FRESH'; // FRESH, RV, MAKEUP
  String _academicYear = '2025-2026';
  final TextEditingController _sgpaController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  PlatformFile? _pickedFile;
  bool _isSubmitting = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _fetchResults();
    _fetchStudentProfile();
  }

  @override
  void dispose() {
    _sgpaController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _fetchResults() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/external_results/');
      final dynamic raw = res.data;
      final List list = raw is List ? raw : (raw is Map && raw['results'] is List ? raw['results'] : []);

      if (mounted) {
        setState(() {
          _results = List<Map<String, dynamic>>.from(list);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load examination results: $e";
        });
      }
    }
  }

  Future<void> _fetchStudentProfile() async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/students/me/');
      if (mounted && res.data is Map) {
        setState(() {
          _studentProfile = Map<String, dynamic>.from(res.data as Map);
          if (_studentProfile?['semester'] != null) {
            final semVal = int.tryParse(_studentProfile!['semester'].toString());
            if (semVal != null && semVal >= 1 && semVal <= 8) {
              _selectedSem = semVal;
            }
          }
          if (_studentProfile?['academic_year_name'] != null) {
            _academicYear = _studentProfile!['academic_year_name'].toString();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pickResultFile() async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() {
          _pickedFile = res.files.first;
          _uploadError = null;
        });
      }
    } catch (e) {
      setState(() => _uploadError = "Could not select file: $e");
    }
  }

  Future<void> _submitSemesterResult() async {
    if (_pickedFile == null || _pickedFile!.bytes == null) {
      setState(() => _uploadError = "Please upload a semester result PDF marksheet.");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadError = null;
    });

    try {
      final dio = ApiClient().dio;
      final mapData = <String, dynamic>{
        'semester': _selectedSem,
        'exam_type': _examType,
        'pdf_file': MultipartFile.fromBytes(_pickedFile!.bytes!, filename: _pickedFile!.name),
      };
      if (_sgpaController.text.trim().isNotEmpty) {
        final parsed = double.tryParse(_sgpaController.text.trim());
        if (parsed != null) mapData['sgpa'] = parsed;
      }
      if (_remarksController.text.trim().isNotEmpty) {
        mapData['remarks'] = _remarksController.text.trim();
      }
      final formData = FormData.fromMap(mapData);

      await dio.post('/external_results/', data: formData);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isUploadingMode = false;
          _pickedFile = null;
          _sgpaController.clear();
          _remarksController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Semester $_selectedSem result uploaded successfully!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        _fetchResults();
      }
    } catch (e) {
      String cleanError = "Failed to upload result.";
      if (e is DioException && e.response?.data != null) {
        final d = e.response!.data;
        if (d is Map) {
          if (d['detail'] != null) {
            cleanError = d['detail'].toString();
          } else if (d['pdf_file'] != null) {
            final pf = d['pdf_file'];
            cleanError = pf is List ? pf.join(', ') : pf.toString();
          } else if (d['exam_type'] != null) {
            final et = d['exam_type'];
            cleanError = et is List ? et.join(', ') : et.toString();
          } else if (d['non_field_errors'] != null) {
            final nfe = d['non_field_errors'];
            cleanError = nfe is List ? nfe.join(', ') : nfe.toString();
          } else {
            cleanError = d.values.map((v) => v is List ? v.join(', ') : v.toString()).join('\n');
          }
        } else {
          cleanError = d.toString();
        }
      } else {
        cleanError = e.toString();
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _uploadError = cleanError;
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
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F9),
      // Signature Image 2 Dark Blue Navbar
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Semester Examination Results",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh Results",
            onPressed: () {
              _fetchResults();
              _fetchStudentProfile();
            },
          ),
        ],
      ),
      body: _isUploadingMode ? _buildUploadFormView() : _buildResultsListView(),
    );
  }

  // =====================================================================
  // VIEW 1: RESULTS LIST VIEW
  // =====================================================================
  Widget _buildResultsListView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.workspace_premium_rounded, color: Color(0xFF13246E), size: 28),
                      SizedBox(width: 10),
                      Text(
                        "External Examination Results",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF13246E),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "University semester results, SGPA, grades, and official marksheets",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  setState(() {
                    _isUploadingMode = true;
                    _uploadError = null;
                  });
                },
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text("Upload Marksheet", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Content Area
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
                    onPressed: _fetchResults,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
          else if (_results.isEmpty)
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
                  Icon(Icons.school_outlined, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    "No Examination Results Uploaded",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "You can upload your semester result marksheets or check back after the exam office updates records.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13246E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () {
                      setState(() {
                        _isUploadingMode = true;
                        _uploadError = null;
                      });
                    },
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text("Upload Semester Result", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _results.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = _results[index];
                final sem = item['semester_number'] ?? item['semester'] ?? '-';
                final examTypeDisplay = item['exam_type_display'] ?? item['exam_type'] ?? 'Regular';
                final pdfUrl = item['download_url'] ?? item['pdf_file']?.toString();
                final uploadDate = item['uploaded_at'] != null ? DateTime.tryParse(item['uploaded_at'].toString()) : null;

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
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF13246E).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            "S$sem",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF13246E)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "Semester $sem Examination Result",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Text(
                                    examTypeDisplay.toString().toUpperCase(),
                                    style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, size: 12, color: Colors.green.shade700),
                                      const SizedBox(width: 4),
                                      Text("Submitted for Verification", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (uploadDate != null)
                                  Text(
                                    "Uploaded: ${uploadDate.day}/${uploadDate.month}/${uploadDate.year}",
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (pdfUrl != null && pdfUrl.isNotEmpty)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF13246E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            final uri = Uri.tryParse(pdfUrl);
                            if (uri != null) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.white),
                          label: const Text("View Marksheet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // =====================================================================
  // VIEW 2: IMAGE 2 UPLOAD SEMESTER RESULT FORM VIEW
  // =====================================================================
  Widget _buildUploadFormView() {
    final studentName = _studentProfile?['name'] ?? _studentProfile?['student_name'] ?? 'Rahul Kumar';
    final studentUsn = _studentProfile?['usn'] ?? '4GE24CS030';
    final deptName = _studentProfile?['department_name'] ?? 'Computer Science & Engineering';

    return SingleChildScrollView(
      child: Column(
        children: [
          // Image 2 Center Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: const Center(
              child: Text(
                "Upload Semester Result",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),

          // Main Image 2 Form Body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error Notification Banner
                if (_uploadError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Validation Error",
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _uploadError!,
                                style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _uploadError = null),
                        ),
                      ],
                    ),
                  ),
                ],

                // Two-Column Layout (Matching Image 2)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 820;

                    final leftFields = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormRow("Name", _buildReadOnlyField(studentName)),
                        _buildFormRow("Registration ID", _buildReadOnlyField(studentUsn)),
                        _buildFormRow("Department", _buildReadOnlyField(deptName)),
                        _buildFormRow(
                          "Semester",
                          _buildDropdownField<int>(
                            value: _selectedSem,
                            items: List.generate(8, (i) => i + 1).map((s) {
                              return DropdownMenuItem<int>(
                                value: s,
                                child: Text("Semester $s"),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedSem = val);
                            },
                          ),
                        ),
                        _buildFormRow(
                          "Exam Type",
                          _buildDropdownField<String>(
                            value: _examType,
                            items: const [
                              DropdownMenuItem(value: 'FRESH', child: Text("Regular Examination")),
                              DropdownMenuItem(value: 'RV', child: Text("Revaluation")),
                              DropdownMenuItem(value: 'MAKEUP', child: Text("Makeup / Supplementary")),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _examType = val);
                            },
                          ),
                        ),
                        _buildFormRow(
                          "Academic Year",
                          _buildReadOnlyField(_academicYear),
                        ),
                        _buildFormRow(
                          "SGPA (Optional)",
                          _buildInputField(
                            controller: _sgpaController,
                            hintText: "e.g. 8.75",
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        _buildFormRow(
                          "Remarks",
                          _buildInputField(
                            controller: _remarksController,
                            hintText: "Optional notes or university exam session",
                          ),
                        ),
                      ],
                    );

                    final rightUploadBox = Column(
                      children: [
                        // White rounded card matching Image 2's right preview box
                        Container(
                          width: 220,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _pickedFile != null
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.picture_as_pdf_rounded, size: 64, color: Colors.red.shade700),
                                        const SizedBox(height: 10),
                                        Text(
                                          _pickedFile!.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF13246E)),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB",
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.account_box_rounded, size: 76, color: Colors.grey.shade400),
                                      const SizedBox(height: 8),
                                      Text("PDF Marksheet", style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Image 2 Dark Blue Pill Button "Upload Image" -> "Upload Image" / "Upload Result PDF"
                        SizedBox(
                          width: 160,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13246E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                              elevation: 1,
                            ),
                            onPressed: _pickResultFile,
                            child: Text(
                              _pickedFile != null ? "Change PDF" : "Upload Image",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "PDF format only (Max 10MB)",
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: leftFields),
                          const SizedBox(width: 48),
                          Expanded(flex: 2, child: Align(alignment: Alignment.topCenter, child: rightUploadBox)),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          rightUploadBox,
                          const SizedBox(height: 28),
                          leftFields,
                        ],
                      );
                    }
                  },
                ),

                const SizedBox(height: 36),

                // Bottom Right Actions (Submit Button matching Image 2)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                      onPressed: () {
                        setState(() {
                          _isUploadingMode = false;
                          _uploadError = null;
                        });
                      },
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13246E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        elevation: 2,
                      ),
                      onPressed: _isSubmitting ? null : _submitSemesterResult,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              "Submit",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // IMAGE 2 HELPER WIDGETS
  // =====================================================================
  Widget _buildFormRow(String label, Widget input) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 540) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: input),
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                input,
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildReadOnlyField(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF13246E))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          isDense: true,
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF13246E))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }
}
