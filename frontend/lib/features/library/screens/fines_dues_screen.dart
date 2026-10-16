import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';

class FinesDuesScreen extends StatefulWidget {
  const FinesDuesScreen({super.key});

  @override
  State<FinesDuesScreen> createState() => _FinesDuesScreenState();
}

class _FinesDuesScreenState extends State<FinesDuesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _fines = [];
  String _searchQuery = '';
  String _statusFilter = 'UNPAID'; // UNPAID, PAID, ALL

  @override
  void initState() {
    super.initState();
    _fetchFines();
  }

  Future<void> _fetchFines() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/fines/');
      final List list = res.data is List ? res.data : [];
      if (mounted) {
        setState(() {
          _fines = List<Map<String, dynamic>>.from(list);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load fines: $e";
        });
      }
    }
  }

  void _showRecordPaymentDialog(Map<String, dynamic> fine) {
    final refCtrl = TextEditingController(text: "REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text("Record Fine Clearance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Fine Amount:", style: TextStyle(fontSize: 14, color: Colors.black54)),
                      Text("₹${fine['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF13246E))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text("Student: ${fine['student_name'] ?? fine['borrower_name'] ?? 'Student'}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text("Reason: ${fine['reason'] ?? 'Late overdue fine'}", style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: refCtrl,
              decoration: const InputDecoration(
                labelText: "Cash Receipt No. / Transaction Ref *",
                hintText: "e.g. REC-9872 or UPI/Bank ref",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            onPressed: () async {
              if (refCtrl.text.trim().isEmpty) return;
              try {
                final dio = ApiClient().dio;
                await dio.post('/library/fines/${fine['id']}/mark_paid/', data: {
                  'payment_reference': refCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Fine payment recorded and cleared!"), backgroundColor: Color(0xFF059669)),
                  );
                  _fetchFines();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red.shade700),
                  );
                }
              }
            },
            child: const Text("Clear Fine"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalOutstanding = 0;
    double totalCleared = 0;
    for (final f in _fines) {
      final amt = (f['amount'] as num?)?.toDouble() ?? 0.0;
      if (f['paid'] == true) {
        totalCleared += amt;
      } else {
        totalOutstanding += amt;
      }
    }

    final filtered = _fines.where((f) {
      final isPaid = f['paid'] == true;
      final student = (f['student_name'] ?? f['borrower_name'] ?? '').toString().toLowerCase();
      final usn = (f['student_usn'] ?? f['borrower_usn'] ?? '').toString().toLowerCase();
      final reason = (f['reason'] ?? '').toString().toLowerCase();

      final matchesQuery = _searchQuery.isEmpty ||
          student.contains(_searchQuery.toLowerCase()) ||
          usn.contains(_searchQuery.toLowerCase()) ||
          reason.contains(_searchQuery.toLowerCase());

      bool matchesStatus = true;
      if (_statusFilter == 'UNPAID') {
        matchesStatus = !isPaid;
      } else if (_statusFilter == 'PAID') {
        matchesStatus = isPaid;
      }

      return matchesQuery && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        elevation: 0,
        title: const Text(
          "Library Fines & Dues",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh Fines",
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchFines,
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
                          onPressed: _fetchFines,
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // KPI Summary Strip
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard("TOTAL OUTSTANDING", "₹$totalOutstanding", Icons.money_off_rounded, Colors.red.shade700),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard("TOTAL COLLECTED", "₹$totalCleared", Icons.check_circle_rounded, const Color(0xFF059669)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard("TOTAL FINES FILED", "${_fines.length} Records", Icons.receipt_long_rounded, const Color(0xFF13246E)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Search & Filter Strip
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (v) => setState(() => _searchQuery = v),
                              decoration: InputDecoration(
                                hintText: "Search fines by student USN, name, or reason...",
                                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF13246E)),
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          FilterChip(
                            label: Text("Unpaid Dues (${_fines.where((f) => f['paid'] != true).length})"),
                            selected: _statusFilter == 'UNPAID',
                            selectedColor: Colors.red.shade700,
                            backgroundColor: const Color(0xFFF1F5F9),
                            labelStyle: TextStyle(
                              color: _statusFilter == 'UNPAID' ? Colors.white : Colors.black87,
                              fontWeight: _statusFilter == 'UNPAID' ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            checkmarkColor: Colors.white,
                            onSelected: (_) => setState(() => _statusFilter = 'UNPAID'),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text("Cleared (${_fines.where((f) => f['paid'] == true).length})"),
                            selected: _statusFilter == 'PAID',
                            selectedColor: const Color(0xFF059669),
                            backgroundColor: const Color(0xFFF1F5F9),
                            labelStyle: TextStyle(
                              color: _statusFilter == 'PAID' ? Colors.white : Colors.black87,
                              fontWeight: _statusFilter == 'PAID' ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            checkmarkColor: Colors.white,
                            onSelected: (_) => setState(() => _statusFilter = 'PAID'),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text("All Records"),
                            selected: _statusFilter == 'ALL',
                            selectedColor: const Color(0xFF13246E),
                            backgroundColor: const Color(0xFFF1F5F9),
                            labelStyle: TextStyle(
                              color: _statusFilter == 'ALL' ? Colors.white : Colors.black87,
                              fontWeight: _statusFilter == 'ALL' ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            checkmarkColor: Colors.white,
                            onSelected: (_) => setState(() => _statusFilter = 'ALL'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Fines List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, size: 56, color: Colors.green.shade400),
                                  const SizedBox(height: 12),
                                  const Text("No fine records found.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 6),
                                  const Text("All students are in good standing with zero pending dues."),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(24),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final f = filtered[i];
                                final isPaid = f['paid'] == true;
                                final amt = f['amount'] ?? 0;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isPaid ? const Color(0xFFE2E8F0) : Colors.red.shade200,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: isPaid ? Colors.green.shade50 : Colors.red.shade50,
                                          child: Icon(
                                            isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                                            color: isPaid ? const Color(0xFF059669) : Colors.red.shade700,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    f['student_name'] ?? f['borrower_name'] ?? 'Student',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                                  ),
                                                  if (f['student_usn'] != null || f['borrower_usn'] != null)
                                                    Text(
                                                      " (${f['student_usn'] ?? f['borrower_usn']})",
                                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                                    ),
                                                  const Spacer(),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: isPaid ? Colors.green.shade50 : Colors.red.shade50,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      isPaid ? "CLEARED" : "UNPAID",
                                                      style: TextStyle(
                                                        color: isPaid ? const Color(0xFF059669) : Colors.red.shade700,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "Reason: ${f['reason'] ?? 'Overdue loan'}",
                                                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                              ),
                                              if (isPaid && f['payment_reference'] != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    "Receipt Ref: ${f['payment_reference']}",
                                                    style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w500),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              "₹$amt",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: isPaid ? const Color(0xFF059669) : Colors.red.shade700,
                                              ),
                                            ),
                                            if (!isPaid) ...[
                                              const SizedBox(height: 6),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF059669),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                ),
                                                onPressed: () => _showRecordPaymentDialog(f),
                                                child: const Text("Record Payment", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
