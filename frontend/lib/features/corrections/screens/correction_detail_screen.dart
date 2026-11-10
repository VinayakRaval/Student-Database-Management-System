import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/api_client.dart';
import '../models/correction_model.dart';

class CorrectionDetailScreen extends StatefulWidget {
  final int requestId;
  const CorrectionDetailScreen({super.key, required this.requestId});

  @override
  State<CorrectionDetailScreen> createState() => _CorrectionDetailScreenState();
}

class _CorrectionDetailScreenState extends State<CorrectionDetailScreen> {
  CorrectionRequestItem? _request;
  bool _isLoading = true;
  String? _error;

  final _replyCtrl = TextEditingController();
  bool _isReplying = false;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/corrections/requests/${widget.requestId}/');
      if (mounted) {
        setState(() {
          _request = CorrectionRequestItem.fromMap(res.data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load request details.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitResponse() async {
    if (_replyCtrl.text.trim().isEmpty) return;

    setState(() => _isReplying = true);
    try {
      final dio = ApiClient().dio;
      await dio.post(
        '/corrections/requests/${widget.requestId}/respond/',
        data: {'response': _replyCtrl.text.trim()},
      );

      if (mounted) {
        _replyCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Clarification submitted. Status updated to Pending Review."),
            backgroundColor: Color(0xFF15803D),
          ),
        );
        _fetchDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to submit response: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isReplying = false);
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
      appBar: AppBar(
        title: Text(
          _request != null ? "Request ${_request!.requestId}" : "Correction Details",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _request == null
                  ? const Center(child: Text("Request not found"))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 820),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Status Card
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _request!.requestId,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                            color: Color(0xFF13246E),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Submitted on ${_request!.createdAt.isNotEmpty ? _request!.createdAt.substring(0, 10) : ''}",
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getStatusBg(_request!.status),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _request!.statusDisplay,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusText(_request!.status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Details & Comparison Card
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Correction Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    const Divider(height: 24),
                                    _buildInfoRow("Category", _request!.categoryDisplay),
                                    _buildInfoRow("Target Record", _request!.targetRecordRef),
                                    const SizedBox(height: 12),

                                    // Comparison Box
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text("Current Value", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _request!.currentValue.isNotEmpty ? _request!.currentValue : "Not Specified",
                                                  style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.arrow_forward_rounded, color: Color(0xFF94A3B8), size: 20),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text("Requested Correct Value", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _request!.requestedValue,
                                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    _buildInfoRow("Description", _request!.description),
                                    _buildInfoRow("Reason", _request!.reason),

                                    if (_request!.evidenceFile != null && _request!.evidenceFile!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Row(
                                          children: [
                                            const Text("Supporting Evidence: ", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                            const SizedBox(width: 8),
                                            Text(
                                              _request!.evidenceFile!.split('/').last,
                                              style: const TextStyle(fontSize: 13, color: Color(0xFF13246E), fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),

                                    if (_request!.rejectionReason != null && _request!.rejectionReason!.isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                "Rejection Reason: ${_request!.rejectionReason!}",
                                                style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    if (_request!.resolutionNotes != null && _request!.resolutionNotes!.isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF15803D)),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                "Resolution Notes: ${_request!.resolutionNotes!}",
                                                style: const TextStyle(fontSize: 13, color: Color(0xFF15803D), fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Student Reply Card if MORE_INFO_REQUIRED
                              if (_request!.status == 'MORE_INFO_REQUIRED') ...[
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFD8B4FE)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.help_outline, color: Color(0xFF7E22CE), size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            "Staff requested more information:",
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF7E22CE)),
                                          ),
                                        ],
                                      ),
                                      if (_request!.reviewerComments != null && _request!.reviewerComments!.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          _request!.reviewerComments!,
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _replyCtrl,
                                        maxLines: 2,
                                        decoration: const InputDecoration(
                                          hintText: "Enter clarification and explanation for the reviewer...",
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.all(10),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7E22CE), foregroundColor: Colors.white),
                                          onPressed: _isReplying ? null : _submitResponse,
                                          child: Text(_isReplying ? "Submitting..." : "Submit Clarification"),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Audit History Timeline Card
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Audit History & Activity Log", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    const Divider(height: 24),
                                    if (_request!.history.isEmpty)
                                      const Text("No activity recorded yet.", style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)))
                                    else
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _request!.history.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                                        itemBuilder: (context, idx) {
                                          final h = _request!.history[idx];
                                          return Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                                                child: const Icon(Icons.circle, size: 8, color: Color(0xFF13246E)),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(h.action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                                        Text(
                                                          h.timestamp.isNotEmpty ? h.timestamp.substring(0, 16).replaceAll('T', ' ') : '',
                                                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text("By: ${h.actorName}", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                                    if (h.comments.isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(h.comments, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(value.isNotEmpty ? value : "-", style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }
}
