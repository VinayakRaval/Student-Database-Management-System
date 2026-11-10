import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import '../models/correction_model.dart';

class CorrectionReviewScreen extends StatefulWidget {
  const CorrectionReviewScreen({super.key});

  @override
  State<CorrectionReviewScreen> createState() => _CorrectionReviewScreenState();
}

class _CorrectionReviewScreenState extends State<CorrectionReviewScreen> {
  List<CorrectionRequestItem> _requests = [];
  bool _isLoading = true;
  String? _error;
  String _selectedStatus = 'ALL';
  String _selectedCategory = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/corrections/requests/');
      List data = [];
      if (res.data is List) {
        data = res.data;
      } else if (res.data is Map && res.data['results'] is List) {
        data = res.data['results'];
      }

      if (mounted) {
        setState(() {
          _requests = data.map((e) => CorrectionRequestItem.fromMap(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load requests.";
          _isLoading = false;
        });
      }
    }
  }

  List<CorrectionRequestItem> get _filteredRequests {
    return _requests.where((r) {
      if (_selectedStatus != 'ALL' && r.status != _selectedStatus) return false;
      if (_selectedCategory != 'ALL' && r.category != _selectedCategory) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchId = r.requestId.toLowerCase().contains(q);
        final matchUsn = r.studentUsn.toLowerCase().contains(q);
        final matchName = r.studentName.toLowerCase().contains(q);
        final matchRef = r.targetRecordRef.toLowerCase().contains(q);
        return matchId || matchUsn || matchName || matchRef;
      }
      return true;
    }).toList();
  }

  Future<void> _handleReviewAction(CorrectionRequestItem item, String action, String promptTitle, {bool requireReason = false}) async {
    final textCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(promptTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Request: ${item.requestId} (${item.studentName} - ${item.studentUsn})", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                TextFormField(
                  controller: textCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: requireReason ? "Enter mandatory rejection reason..." : "Enter reviewer comments or remarks...",
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (requireReason && (v == null || v.trim().isEmpty)) {
                      return "Rejection reason is required.";
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: action == 'reject' ? Colors.red.shade700 : const Color(0xFF13246E),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text("Submit Decision"),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final dio = ApiClient().dio;
        await dio.post(
          '/corrections/requests/${item.id}/review/',
          data: {
            'action': action,
            'comments': textCtrl.text.trim(),
            'rejection_reason': textCtrl.text.trim(),
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Decision recorded successfully for ${item.requestId}."),
              backgroundColor: const Color(0xFF15803D),
            ),
          );
          _fetchRequests();
        }
      } catch (e) {
        if (mounted) {
          String msg = "Action failed: $e";
          if (e is DioException && e.response?.data != null) {
            msg = e.response!.data.toString();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleResolve(CorrectionRequestItem item) async {
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Complete & Resolve Correction", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Confirm that the record has been updated and verified for ${item.requestId}:", style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: "Resolution notes (e.g. Attendance record updated in register)...",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text("Mark Completed"),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final dio = ApiClient().dio;
        await dio.post(
          '/corrections/requests/${item.id}/resolve/',
          data: {'resolution_notes': notesCtrl.text.trim()},
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Request ${item.requestId} marked as COMPLETED."),
              backgroundColor: const Color(0xFF0F766E),
            ),
          );
          _fetchRequests();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to resolve: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Color _getStatusBg(String status) {
    switch (status) {
      case 'APPROVED':
        return const Color(0xFFDCFCE7);
      case 'COMPLETED':
        return const Color(0xFFCCFBF1);
      case 'REJECTED':
        return const Color(0xFFFEE2E2);
      case 'MORE_INFO_REQUIRED':
        return const Color(0xFFF3E8FF);
      case 'PENDING_REVIEW':
      case 'FORWARDED':
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFE0E7FF);
    }
  }

  Color _getStatusText(String status) {
    switch (status) {
      case 'APPROVED':
        return const Color(0xFF15803D);
      case 'COMPLETED':
        return const Color(0xFF0F766E);
      case 'REJECTED':
        return const Color(0xFFDC2626);
      case 'MORE_INFO_REQUIRED':
        return const Color(0xFF7E22CE);
      case 'PENDING_REVIEW':
      case 'FORWARDED':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF3730A3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _fetchRequests,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Correction Requests Review",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Review student mistake correction requests and apply authorized updates.",
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF13246E)),
                    onPressed: _fetchRequests,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Filter Controls
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Search by ID, USN, student name...",
                          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          isDense: true,
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text("All Statuses", style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: 'SUBMITTED', child: Text("Submitted", style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: 'PENDING_REVIEW', child: Text("Pending Review", style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: 'APPROVED', child: Text("Approved", style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: 'COMPLETED', child: Text("Completed", style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: 'REJECTED', child: Text("Rejected", style: TextStyle(fontSize: 13))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedStatus = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
              else if (_filteredRequests.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: const [
                        Icon(Icons.check_circle_outline, size: 50, color: Color(0xFF94A3B8)),
                        SizedBox(height: 10),
                        Text("No pending correction requests", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredRequests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final item = _filteredRequests[idx];
                    return _buildReviewCard(item);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(CorrectionRequestItem item) {
    final statusBg = _getStatusBg(item.status);
    final statusText = _getStatusText(item.status);
    final isPending = item.status == 'SUBMITTED' || item.status == 'PENDING_REVIEW' || item.status == 'FORWARDED';
    final isApproved = item.status == 'APPROVED';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(item.requestId, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF13246E), fontSize: 13)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
                    child: Text(item.categoryDisplay, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3730A3))),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(16)),
                child: Text(item.statusDisplay, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusText)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Student Info
          Text(
            "${item.studentName} (${item.studentUsn}) • ${item.studentDepartmentName}",
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),

          // Target Record & Description
          Text("Record: ${item.targetRecordRef}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          const SizedBox(height: 4),
          Text(item.description, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
          const SizedBox(height: 10),

          // Comparison box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Expanded(
                  child: Text("Current: ${item.currentValue.isNotEmpty ? item.currentValue : 'N/A'}", style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                ),
                const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text("Requested: ${item.requestedValue}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isPending) ...[
                OutlinedButton(
                  onPressed: () => _handleReviewAction(item, 'request_info', 'Request Additional Information'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7E22CE),
                    side: const BorderSide(color: Color(0xFF7E22CE)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text("Request Info", style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _handleReviewAction(item, 'reject', 'Reject Correction Request', requireReason: true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade700),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text("Reject", style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () => _handleReviewAction(item, 'approve', 'Approve Correction Request'),
                  child: const Text("Approve", style: TextStyle(fontSize: 12)),
                ),
              ],
              if (isApproved) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text("Mark Completed / Resolved", style: TextStyle(fontSize: 12)),
                  onPressed: () => _handleResolve(item),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
