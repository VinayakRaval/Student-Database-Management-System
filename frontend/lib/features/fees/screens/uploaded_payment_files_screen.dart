import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';

class UploadedPaymentFilesScreen extends ConsumerStatefulWidget {
  const UploadedPaymentFilesScreen({super.key});

  @override
  ConsumerState<UploadedPaymentFilesScreen> createState() =>
      _UploadedPaymentFilesScreenState();
}

class _UploadedPaymentFilesScreenState
    extends ConsumerState<UploadedPaymentFilesScreen> {
  List<dynamic>? _payments;
  bool _isLoading = true;
  String? _error;

  // Filters
  int? _selectedDeptId;
  int? _selectedSemId;
  int? _selectedYearId;
  String _selectedStatus = 'all'; // 'all', 'pending', 'verified'
  bool _proofsOnly = false;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _academicYears = [];

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
    _fetchPayments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdownData() async {
    try {
      final dio = ApiClient().dio;
      final deptRes = await dio.get('/academics/departments/');
      final semRes = await dio.get('/academics/semesters/');
      final yearRes = await dio.get('/academics/academic-years/');

      if (mounted) {
        setState(() {
          final deptList = deptRes.data is List
              ? deptRes.data
              : (deptRes.data['results'] ?? []);
          _departments = (deptList as List)
              .map<Map<String, dynamic>>((e) => {
                    'id': e['id'],
                    'name': e['name']?.toString() ?? '',
                  })
              .toList();

          final semList = semRes.data is List
              ? semRes.data
              : (semRes.data['results'] ?? []);
          _semesters = (semList as List)
              .map<Map<String, dynamic>>((e) => {
                    'id': e['id'],
                    'name': "Semester ${e['sem_number'] ?? e['id']}",
                  })
              .toList();

          final yearList = yearRes.data is List
              ? yearRes.data
              : (yearRes.data['results'] ?? []);
          _academicYears = (yearList as List)
              .map<Map<String, dynamic>>((e) => {
                    'id': e['id'],
                    'name': e['name']?.toString() ??
                        e['year_name']?.toString() ??
                        '',
                  })
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchPayments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ApiClient().dio;
      final queryParams = <String, dynamic>{};

      if (_selectedDeptId != null) queryParams['department'] = _selectedDeptId;
      if (_selectedSemId != null) queryParams['semester'] = _selectedSemId;
      if (_selectedYearId != null) queryParams['academic_year'] = _selectedYearId;
      if (_selectedStatus != 'all') queryParams['status'] = _selectedStatus;
      if (_searchController.text.trim().isNotEmpty) {
        queryParams['search'] = _searchController.text.trim();
      }

      final response =
          await dio.get('/fees/payments/', queryParameters: queryParams);

      if (mounted) {
        setState(() {
          _payments = response.data is List
              ? response.data
              : (response.data['results'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> get _displayedPayments {
    if (_payments == null) return [];
    var list = _payments!;
    if (_proofsOnly) {
      list = list.where((p) {
        final url = p['proof_url'] ?? p['upi_screenshot'] ?? p['bank_statement_file'];
        return url != null && url.toString().trim().isNotEmpty;
      }).toList();
    }
    return list;
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return "N/A";
    try {
      final dt = DateTime.parse(dateStr.toString());
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return dateStr.toString();
    }
  }



  void _showImagePreviewDialog(String imageUrl, String studentName, String refNo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: 760,
          constraints: const BoxConstraints(maxHeight: 700),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 4),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF13246E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Payment Proof — $studentName",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "Reference / UTR: $refNo",
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                      tooltip: "Close",
                    ),
                  ],
                ),
              ),

              // Interactive Image Preview
              Flexible(
                child: Container(
                  color: const Color(0xFF0F172A),
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: InteractiveViewer(
                      panEnabled: true,
                      boundaryMargin: const EdgeInsets.all(20),
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (c, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                  : null,
                              color: Colors.white,
                            ),
                          );
                        },
                        errorBuilder: (c, e, s) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.broken_image_rounded, size: 54, color: Colors.white54),
                            const SizedBox(height: 12),
                            Text("Unable to load image:\n$imageUrl",
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Footer Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Pinch or scroll to zoom in/out",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13246E),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text("Done"),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _displayedPayments;
    final totalCount = _payments?.length ?? 0;
    final proofsCount = _payments?.where((p) {
          final url = p['proof_url'] ?? p['upi_screenshot'] ?? p['bank_statement_file'];
          return url != null && url.toString().trim().isNotEmpty;
        }).length ?? 0;
    final pendingCount = _payments?.where((p) => p['verified'] != true).length ?? 0;
    final verifiedCount = _payments?.where((p) => p['verified'] == true).length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: "Back to Accounts Dashboard",
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/fees/dashboard');
            }
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Uploaded Fee Payment Proofs",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
                Text(
                  "Review student-uploaded screenshots, slips & transaction proofs",
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: "Refresh Proofs",
            onPressed: _fetchPayments,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top status and proof chips
                Row(
                  children: [
                    _filterChip("All Records ($totalCount)", 'all', _selectedStatus == 'all', () {
                      setState(() => _selectedStatus = 'all');
                      _fetchPayments();
                    }),
                    const SizedBox(width: 8),
                    _filterChip("Pending ($pendingCount)", 'pending', _selectedStatus == 'pending', () {
                      setState(() => _selectedStatus = 'pending');
                      _fetchPayments();
                    }, color: Colors.orange),
                    const SizedBox(width: 8),
                    _filterChip("Verified ($verifiedCount)", 'verified', _selectedStatus == 'verified', () {
                      setState(() => _selectedStatus = 'verified');
                      _fetchPayments();
                    }, color: Colors.green),
                    const Spacer(),
                    FilterChip(
                      selected: _proofsOnly,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.attach_file_rounded,
                            size: 15,
                            color: _proofsOnly ? Colors.white : const Color(0xFF13246E),
                          ),
                          const SizedBox(width: 4),
                          Text("With Proofs Only ($proofsCount)"),
                        ],
                      ),
                      selectedColor: const Color(0xFF13246E),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _proofsOnly ? Colors.white : const Color(0xFF13246E),
                      ),
                      onSelected: (val) => setState(() => _proofsOnly = val),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Dropdowns row: Department, Semester, Academic Year, Search
                Row(
                  children: [
                    // Department Dropdown
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            isExpanded: true,
                            value: _selectedDeptId,
                            hint: const Row(
                              children: [
                                Icon(Icons.business_rounded, size: 16, color: Colors.grey),
                                SizedBox(width: 6),
                                Text("Department", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text("All Departments", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              ..._departments.map((d) => DropdownMenuItem<int?>(
                                    value: d['id'] as int,
                                    child: Text(d['name'] as String, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                  )),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedDeptId = val);
                              _fetchPayments();
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Semester Dropdown
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            isExpanded: true,
                            value: _selectedSemId,
                            hint: const Row(
                              children: [
                                Icon(Icons.school_rounded, size: 16, color: Colors.grey),
                                SizedBox(width: 6),
                                Text("Semester", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text("All Semesters", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              ..._semesters.map((s) => DropdownMenuItem<int?>(
                                    value: s['id'] as int,
                                    child: Text(s['name'] as String, style: const TextStyle(fontSize: 12)),
                                  )),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedSemId = val);
                              _fetchPayments();
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Academic Year Dropdown
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            isExpanded: true,
                            value: _selectedYearId,
                            hint: const Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey),
                                SizedBox(width: 6),
                                Text("Academic Year", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text("All Academic Years", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              ..._academicYears.map((y) => DropdownMenuItem<int?>(
                                    value: y['id'] as int,
                                    child: Text(y['name'] as String, style: const TextStyle(fontSize: 12)),
                                  )),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedYearId = val);
                              _fetchPayments();
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Search input
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: "Search USN / Name / UTR...",
                            hintStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      _fetchPayments();
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          ),
                          onSubmitted: (_) => _fetchPayments(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text("Failed to load uploaded files: $_error"),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchPayments,
                              child: const Text("Retry"),
                            ),
                          ],
                        ),
                      )
                    : list.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  "No uploaded fee payment files found.",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Try resetting dropdown filters or toggling 'With Proofs Only'.",
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchPayments,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                final payment = list[index];
                                return _buildPaymentFileCard(payment);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, bool isSelected, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? const Color(0xFF13246E))
              : (color?.withValues(alpha: 0.1) ?? Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (color ?? const Color(0xFF13246E))
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (color ?? Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentFileCard(dynamic payment) {
    final isVerified = payment['verified'] == true;
    final isReversed = payment['is_reversed'] == true;
    final studentName = payment['student_name'] ?? 'Unknown Student';
    final usn = payment['student_usn'] ?? 'N/A';
    final dept = payment['department_name'] ?? 'N/A';
    final sem = payment['semester_name'] ?? 'N/A';
    final year = payment['academic_year_name'] ?? 'N/A';
    final amount = double.tryParse(payment['amount']?.toString() ?? '0') ?? 0.0;
    final mode = payment['mode_display'] ?? payment['mode']?.toString().toUpperCase() ?? 'UPI';
    final refNo = payment['reference_no'] ?? payment['upi_txn_id'] ?? payment['bank_reference_no'] ?? 'N/A';
    final dateStr = _formatDate(payment['paid_on']);
    final proofUrl = payment['proof_url'] ?? payment['upi_screenshot'] ?? payment['bank_statement_file'];
    final bool hasProof = proofUrl != null && proofUrl.toString().trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isVerified
              ? Colors.green.shade200
              : isReversed
                  ? Colors.red.shade200
                  : Colors.amber.shade200,
          width: 1.2,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: USN, Date, Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13246E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    usn,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF13246E),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                if (isReversed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: const Text(
                      "REVERSED",
                      style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 13, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          "VERIFIED",
                          style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pending_actions_rounded, size: 13, color: Colors.amber),
                        SizedBox(width: 4),
                        Text(
                          "PENDING VERIFICATION",
                          style: TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Middle Section: Details (Left) + Proof Preview Thumbnail (Right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left details
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$dept • $sem • $year",
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              mode,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Ref/UTR: ",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            refNo,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            tooltip: "Copy Reference",
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: refNo.toString()));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Reference copied to clipboard!"),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Amount: ₹${amount.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Right: Proof Thumbnail or Placeholder
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasProof
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                proofUrl.toString(),
                                fit: BoxFit.cover,
                                loadingBuilder: (c, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                },
                                errorBuilder: (c, e, s) => Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.insert_drive_file_outlined, color: Colors.grey.shade400, size: 28),
                                      const SizedBox(height: 4),
                                      const Text("File Proof", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _showImagePreviewDialog(
                                      proofUrl.toString(),
                                      studentName,
                                      refNo,
                                    ),
                                    child: Container(
                                      alignment: Alignment.bottomCenter,
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      color: Colors.black38,
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text(
                                            "Click to Enlarge",
                                            style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.no_photography_outlined, color: Colors.grey.shade400, size: 28),
                                const SizedBox(height: 4),
                                Text(
                                  mode.toLowerCase().contains("cash") ? "Direct Cash Entry" : "No File Uploaded",
                                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasProof)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF13246E),
                      side: const BorderSide(color: Color(0xFF13246E)),
                    ),
                    icon: const Icon(Icons.fullscreen_rounded, size: 16),
                    label: const Text("View File Proof"),
                    onPressed: () => _showImagePreviewDialog(
                      proofUrl.toString(),
                      studentName,
                      refNo,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
