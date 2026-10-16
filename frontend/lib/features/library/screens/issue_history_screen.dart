import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';

class IssueHistoryScreen extends StatefulWidget {
  const IssueHistoryScreen({super.key});

  @override
  State<IssueHistoryScreen> createState() => _IssueHistoryScreenState();
}

class _IssueHistoryScreenState extends State<IssueHistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _history = [];
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // ALL, ISSUED, RETURNED, OVERDUE

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/library/issues/history/');
      final List list = res.data is List ? res.data : [];
      if (mounted) {
        setState(() {
          _history = List<Map<String, dynamic>>.from(list);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load circulation history: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _history.where((item) {
      final title = (item['book_title'] ?? '').toString().toLowerCase();
      final borrower = (item['borrower_name'] ?? '').toString().toLowerCase();
      final barcode = (item['copy_barcode'] ?? '').toString().toLowerCase();
      final status = (item['status'] ?? '').toString().toUpperCase();
      final isOverdue = item['is_overdue'] == true;

      final matchesQuery = _searchQuery.isEmpty ||
          title.contains(_searchQuery.toLowerCase()) ||
          borrower.contains(_searchQuery.toLowerCase()) ||
          barcode.contains(_searchQuery.toLowerCase());

      bool matchesStatus = true;
      if (_statusFilter == 'ISSUED') {
        matchesStatus = status == 'ISSUED' && !isOverdue;
      } else if (_statusFilter == 'RETURNED') {
        matchesStatus = status == 'RETURNED';
      } else if (_statusFilter == 'OVERDUE') {
        matchesStatus = isOverdue;
      }

      return matchesQuery && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.history_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              "Issue & Return History Log",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Refresh History",
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchHistory,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF13246E)))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade700),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                        onPressed: _fetchHistory,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Search & Filters
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: InputDecoration(
                              hintText: "Search circulation records by Book Title, Borrower Name, or Barcode...",
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF13246E)),
                              filled: true,
                              fillColor: const Color(0xFFF1F5F9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStatusChip('ALL', 'All Transactions (${_history.length})'),
                              const SizedBox(width: 8),
                              _buildStatusChip('ISSUED', 'Active Loans'),
                              const SizedBox(width: 8),
                              _buildStatusChip('RETURNED', 'Returned Books'),
                              const SizedBox(width: 8),
                              _buildStatusChip('OVERDUE', 'Overdue Loans'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Table / List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.menu_book_outlined, size: 56, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text("No circulation records found.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final row = filtered[i];
                                final isReturned = row['status'] == 'returned';
                                final isOverdue = row['is_overdue'] == true;

                                Color statusBg = Colors.blue.shade50;
                                Color statusFg = Colors.blue.shade800;
                                String statusText = "ACTIVE LOAN";

                                if (isReturned) {
                                  statusBg = const Color(0xFFECFDF5);
                                  statusFg = const Color(0xFF065F46);
                                  statusText = "RETURNED";
                                } else if (isOverdue) {
                                  statusBg = Colors.red.shade50;
                                  statusFg = Colors.red.shade800;
                                  statusText = "OVERDUE (${row['overdue_days']}d)";
                                }

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: statusBg,
                                          child: Icon(
                                            isReturned ? Icons.check_circle_rounded : (isOverdue ? Icons.warning_amber_rounded : Icons.menu_book_rounded),
                                            color: statusFg,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      row['book_title'] ?? 'Book',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(4)),
                                                    child: Text(
                                                      statusText,
                                                      style: TextStyle(color: statusFg, fontWeight: FontWeight.bold, fontSize: 10),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "Borrower: ${row['borrower_name']} • Copy: ${row['copy_barcode']} • Shelf: ${row['shelf_location'] ?? 'Stack A'}",
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Text("Issued: ${row['issued_at']}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                                  const SizedBox(width: 14),
                                                  Text("Due: ${row['due_date']}", style: TextStyle(fontSize: 11, color: isOverdue ? Colors.red.shade700 : Colors.grey.shade600, fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal)),
                                                  if (row['returned_at'] != null) ...[
                                                    const SizedBox(width: 14),
                                                    Text("Returned: ${row['returned_at']}", style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                                                  ],
                                                  const Spacer(),
                                                  Text("Officer: ${row['issued_by_name']}", style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                                                ],
                                              ),
                                            ],
                                          ),
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

  Widget _buildStatusChip(String key, String label) {
    final isSelected = _statusFilter == key;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF13246E),
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF334155),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      checkmarkColor: Colors.white,
      onSelected: (_) => setState(() => _statusFilter = key),
    );
  }
}
