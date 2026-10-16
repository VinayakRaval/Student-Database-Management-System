import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/library/widgets/digital_library_card_widget.dart';

class HodLibraryCardsScreen extends StatefulWidget {
  const HodLibraryCardsScreen({super.key});

  @override
  State<HodLibraryCardsScreen> createState() => _HodLibraryCardsScreenState();
}

class _HodLibraryCardsScreenState extends State<HodLibraryCardsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _applications = [];

  @override
  void initState() {
    super.initState();
    _fetchDepartmentApplications();
  }

  Future<void> _fetchDepartmentApplications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/cards/');
      final List list = res.data is List ? res.data : [];
      if (mounted) {
        setState(() {
          _applications = List<Map<String, dynamic>>.from(list);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load department applications: $e";
        });
      }
    }
  }

  void _previewCard(Map<String, dynamic> card) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DigitalLibraryCardWidget(cardData: card),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text("Close Preview"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approveApplication(int cardId, String borrowerName) async {
    try {
      final dio = ApiClient().dio;
      await dio.post('/library/cards/$cardId/hod_verify/', data: {'action': 'approve'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Application approved with official HOD digital signature for $borrowerName!"),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        _fetchDepartmentApplications();
      }
    } catch (e) {
      if (mounted) {
        if (e is DioException && e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map && data['needs_signature_upload'] == true) {
            _showUploadSignatureDialog(cardId, borrowerName);
            return;
          }
          final detail = (data is Map && data['detail'] != null) ? data['detail'] : e.toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Approval error: $detail"), backgroundColor: Colors.red.shade700),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Approval error: $e"), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _showUploadSignatureDialog(int cardId, String borrowerName) async {
    PlatformFile? chosenFile;
    bool isUploading = false;
    String? uploadErr;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: const [
              Icon(Icons.draw_rounded, color: Color(0xFF13246E), size: 24),
              SizedBox(width: 10),
              Text("Digital Signature Required", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "You have not uploaded an official HOD digital signature yet. To approve and digitally sign this Library Issue Card, please upload your signature image.",
                style: TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
              ),
              const SizedBox(height: 16),
              if (chosenFile != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Selected: ${chosenFile!.name}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF059669)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    side: const BorderSide(color: Color(0xFF13246E)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    try {
                      final result = await FilePicker.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                        withData: true,
                      );
                      if (result != null && result.files.isNotEmpty) {
                        setDialogState(() {
                          chosenFile = result.files.first;
                          uploadErr = null;
                        });
                      }
                    } catch (err) {
                      setDialogState(() => uploadErr = "Error picking file: $err");
                    }
                  },
                  icon: const Icon(Icons.upload_file_rounded, size: 18, color: Color(0xFF13246E)),
                  label: const Text("Select Signature Image (PNG / JPG)", style: TextStyle(color: Color(0xFF13246E), fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              if (uploadErr != null) ...[
                const SizedBox(height: 8),
                Text(uploadErr!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: (chosenFile == null || isUploading)
                  ? null
                  : () async {
                      setDialogState(() => isUploading = true);
                      try {
                        final dio = ApiClient().dio;
                        final formData = FormData();
                        if (chosenFile!.bytes != null) {
                          formData.files.add(MapEntry(
                            'signature',
                            MultipartFile.fromBytes(chosenFile!.bytes!, filename: chosenFile!.name),
                          ));
                        } else if (chosenFile!.path != null) {
                          formData.files.add(MapEntry(
                            'signature',
                            await MultipartFile.fromFile(chosenFile!.path!, filename: chosenFile!.name),
                          ));
                        }

                        // Upload signature to HOD faculty profile
                        await dio.post('/library/cards/upload_hod_signature/', data: formData);

                        // Once saved, proceed with approval
                        await dio.post('/library/cards/$cardId/hod_verify/', data: {'action': 'approve'});

                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Signature saved and Library Card approved for $borrowerName!"),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                          _fetchDepartmentApplications();
                        }
                      } catch (e) {
                        setDialogState(() {
                          isUploading = false;
                          uploadErr = "Upload/Approval failed: $e";
                        });
                      }
                    },
              icon: isUploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text("Save Signature & Approve"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rejectApplication(int cardId) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject Card Application"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Provide the reason for rejecting this student's library card application:"),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: "Rejection Reason", border: OutlineInputBorder(), isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Reject Application"),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonCtrl.text.trim().isNotEmpty) {
      try {
        final dio = ApiClient().dio;
        await dio.post('/library/cards/$cardId/hod_verify/', data: {'action': 'reject', 'reason': reasonCtrl.text.trim()});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Application declined."), backgroundColor: Colors.orange),
          );
          _fetchDepartmentApplications();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red.shade700),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _applications.where((a) => (a['status'] ?? '').toString().toUpperCase() == 'PENDING_HOD').toList();
    final verified = _applications.where((a) => (a['status'] ?? '').toString().toUpperCase() != 'PENDING_HOD').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        elevation: 0,
        title: const Text(
          "Department Library Card Verifications",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh Applications",
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchDepartmentApplications,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF13246E)))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade700),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade800)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                          onPressed: _fetchDepartmentApplications,
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pending Section Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.pending_actions_rounded, color: Colors.orange.shade800, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Pending Verification (${pending.length})",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                              ),
                              const Text(
                                "Verify student identities and approve applications for your department.",
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (pending.isEmpty)
                        Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                          child: const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text("No pending library card applications for your department.", style: TextStyle(fontWeight: FontWeight.w500)),
                            ),
                          ),
                        )
                      else
                        ...pending.map((card) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFF13246E).withValues(alpha: 0.1),
                                    child: const Icon(Icons.badge_rounded, color: Color(0xFF13246E), size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              card['borrower_name'] ?? card['student_name'] ?? card['faculty_name'] ?? 'Borrower',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              "(${card['borrower_id_number'] ?? card['student_usn'] ?? card['faculty_id'] ?? ''})",
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: (card['borrower_type'] == 'FACULTY') ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: (card['borrower_type'] == 'FACULTY') ? const Color(0xFF93C5FD) : const Color(0xFFFDE68A)),
                                              ),
                                              child: Text(
                                                card['borrower_type'] ?? 'STUDENT',
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: (card['borrower_type'] == 'FACULTY') ? const Color(0xFF1D4ED8) : const Color(0xFFB45309)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Dept: ${card['department_name'] ?? 'N/A'} • Sem: ${card['semester'] ?? 'N/A'} • Sec: ${card['section'] ?? 'A'} • Academic Year: ${card['academic_year'] ?? '2025-2026'}",
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                                          child: const Text("Free Membership: ₹0 Borrowing • ₹0 Late Fine", style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFF7CA18),
                                          foregroundColor: const Color(0xFF4A1504),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        onPressed: () => _previewCard(card),
                                        icon: const Icon(Icons.remove_red_eye_rounded, size: 16),
                                        label: const Text("Preview Card", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF059669),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        onPressed: () => _approveApplication(
                                          card['id'],
                                          card['borrower_name'] ?? card['student_name'] ?? card['faculty_name'] ?? 'Borrower',
                                        ),
                                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                        label: const Text("Approve", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red.shade700,
                                          side: BorderSide(color: Colors.red.shade300),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        onPressed: () => _rejectApplication(card['id']),
                                        icon: const Icon(Icons.close_rounded, size: 16),
                                        label: const Text("Reject", style: TextStyle(fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: 32),

                      // Verified History Header
                      Text(
                        "Verified & Issued Department Cards (${verified.length})",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),

                      ...verified.map((card) {
                        final status = (card['status'] ?? '').toString().toUpperCase();
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0))),
                          child: ListTile(
                            leading: Icon(
                              status == 'ACTIVE' || status == 'HOD_APPROVED' ? Icons.check_circle_rounded : Icons.pending_rounded,
                              color: status == 'ACTIVE' || status == 'HOD_APPROVED' ? const Color(0xFF059669) : Colors.blue.shade700,
                            ),
                            title: Text(
                              "${card['borrower_name'] ?? card['student_name'] ?? card['faculty_name'] ?? 'Borrower'} (${card['borrower_id_number'] ?? card['student_usn'] ?? card['faculty_id'] ?? ''})",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text("Card No: ${card['card_number'] ?? 'LC'} • Status: $status", style: const TextStyle(fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (status == 'ACTIVE' || status == 'HOD_APPROVED') ? Colors.green.shade50 : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: (status == 'ACTIVE' || status == 'HOD_APPROVED') ? const Color(0xFF059669) : Colors.blue.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: "View Yellow Issue Card",
                                  icon: const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF13246E), size: 20),
                                  onPressed: () => _previewCard(card),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}
