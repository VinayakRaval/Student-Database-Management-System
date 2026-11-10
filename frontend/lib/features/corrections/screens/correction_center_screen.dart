import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/api_client.dart';
import '../models/correction_model.dart';

class CorrectionCenterScreen extends StatefulWidget {
  const CorrectionCenterScreen({super.key});

  @override
  State<CorrectionCenterScreen> createState() => _CorrectionCenterScreenState();
}

class _CorrectionCenterScreenState extends State<CorrectionCenterScreen> {
  List<CorrectionRequestItem> _requests = [];
  bool _isLoading = true;
  String? _error;
  String _selectedStatus = 'ALL';
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
          _error = "Failed to load correction requests. Please retry.";
          _isLoading = false;
        });
      }
    }
  }

  List<CorrectionRequestItem> get _filteredRequests {
    return _requests.where((r) {
      if (_selectedStatus != 'ALL' && r.status != _selectedStatus) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchId = r.requestId.toLowerCase().contains(q);
        final matchCat = r.categoryDisplay.toLowerCase().contains(q);
        final matchRef = r.targetRecordRef.toLowerCase().contains(q);
        return matchId || matchCat || matchRef;
      }
      return true;
    }).toList();
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
    final total = _requests.length;
    final pending = _requests.where((r) => r.status == 'SUBMITTED' || r.status == 'PENDING_REVIEW' || r.status == 'FORWARDED').length;
    final completed = _requests.where((r) => r.status == 'COMPLETED' || r.status == 'APPROVED').length;
    final rejected = _requests.where((r) => r.status == 'REJECTED').length;

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
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Correction Center",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Report record discrepancies and track staff review status.",
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13246E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text("Report Mistake", style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => context.push('/student/corrections/new').then((_) => _fetchRequests()),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Stat Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  return GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: isWide ? 2.2 : 1.8,
                    children: [
                      _buildStatCard("Total Requests", total.toString(), Icons.layers_outlined, const Color(0xFF13246E)),
                      _buildStatCard("Pending Review", pending.toString(), Icons.pending_actions_rounded, const Color(0xFFD97706)),
                      _buildStatCard("Approved / Completed", completed.toString(), Icons.check_circle_outline_rounded, const Color(0xFF16A34A)),
                      _buildStatCard("Rejected", rejected.toString(), Icons.cancel_outlined, const Color(0xFFDC2626)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Filter & Search Bar
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
                          hintText: "Search by ID, category, or record reference...",
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
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
                            DropdownMenuItem(value: 'MORE_INFO_REQUIRED', child: Text("More Info Required", style: TextStyle(fontSize: 13))),
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

              // Request Cards List
              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
              else if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 10),
                        ElevatedButton(onPressed: _fetchRequests, child: const Text("Retry")),
                      ],
                    ),
                  ),
                )
              else if (_filteredRequests.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.assignment_turned_in_outlined, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          "No correction requests found",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Notice an error in your profile, attendance, IA marks, or fees? Click 'Report Mistake' to request a review.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        ),
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
                  itemBuilder: (context, index) {
                    final item = _filteredRequests[index];
                    return _buildRequestCard(item);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(CorrectionRequestItem item) {
    final statusBg = _getStatusBg(item.status);
    final statusText = _getStatusText(item.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      item.requestId,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF13246E)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.categoryDisplay,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3730A3)),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.statusDisplay,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (item.targetRecordRef.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                "Record: ${item.targetRecordRef}",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
            ),
          Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Submitted: ${item.createdAt.isNotEmpty ? item.createdAt.substring(0, 10) : ''}",
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              TextButton.icon(
                onPressed: () => context.push('/student/corrections/detail/${item.id}').then((_) => _fetchRequests()),
                icon: const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF13246E)),
                label: const Text("View Details", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF13246E))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
