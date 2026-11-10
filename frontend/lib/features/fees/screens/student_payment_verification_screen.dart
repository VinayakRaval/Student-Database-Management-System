import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';

class StudentPaymentVerificationScreen extends ConsumerStatefulWidget {
  const StudentPaymentVerificationScreen({super.key});

  @override
  ConsumerState<StudentPaymentVerificationScreen> createState() =>
      _StudentPaymentVerificationScreenState();
}

class _StudentPaymentVerificationScreenState
    extends ConsumerState<StudentPaymentVerificationScreen> {
  List<dynamic>? _payments;
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all'; // 'all', 'pending', 'verified'
  int? _selectedDeptId;
  int? _selectedSemId;
  int? _selectedYearId;

  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _academicYears = [];

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
    _fetchPayments();
  }

  Future<void> _fetchDropdownData() async {
    try {
      final dio = ApiClient().dio;
      final deptRes = await dio.get('/academics/departments/');
      final semRes = await dio.get('/academics/semesters/');
      final yearRes = await dio.get('/academics/academic-years/');
      if (mounted) {
        setState(() {
          final deptList = deptRes.data is List ? deptRes.data : (deptRes.data['results'] ?? []);
          _departments = (deptList as List).map<Map<String, dynamic>>((e) => {
            'id': e['id'],
            'name': e['name']?.toString() ?? '',
          }).toList();

          final semList = semRes.data is List ? semRes.data : (semRes.data['results'] ?? []);
          _semesters = (semList as List).map<Map<String, dynamic>>((e) => {
            'id': e['id'],
            'name': "Semester ${e['sem_number'] ?? e['id']}",
          }).toList();

          final yearList = yearRes.data is List ? yearRes.data : (yearRes.data['results'] ?? []);
          _academicYears = (yearList as List).map<Map<String, dynamic>>((e) => {
            'id': e['id'],
            'name': e['name']?.toString() ?? e['year_name']?.toString() ?? '',
          }).toList();
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
      if (_selectedFilter != 'all') queryParams['status'] = _selectedFilter;

      final response = await dio.get('/fees/payments/', queryParameters: queryParams);
      setState(() {
        _payments = response.data is List
            ? response.data
            : (response.data['results'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getStatus(dynamic p) {
    if (p == null) return 'pending';
    if (p['is_reversed'] == true || p['verification_status'] == 'REVERSED') return 'reversed';
    if (p['verification_status'] == 'REJECTED' ||
        (p['verified'] != true && (p['remark']?.toString().toLowerCase().contains('reject') ?? false))) {
      return 'rejected';
    }
    if (p['verified'] == true || p['verification_status'] == 'VERIFIED') return 'verified';
    return 'pending';
  }

  List<dynamic> get _filteredPayments {
    if (_payments == null) return [];
    var list = _payments!;
    if (_selectedFilter == 'pending') {
      list = list.where((p) => _getStatus(p) == 'pending').toList();
    } else if (_selectedFilter == 'verified') {
      list = list.where((p) => _getStatus(p) == 'verified').toList();
    } else if (_selectedFilter == 'rejected') {
      list = list.where((p) => _getStatus(p) == 'rejected').toList();
    }
    if (_selectedDeptId != null) {
      final selectedDeptMap = _departments.firstWhere((d) => d['id'] == _selectedDeptId, orElse: () => {});
      final selectedDept = selectedDeptMap['name'];
      if (selectedDept != null) {
        list = list.where((p) {
          final dName = (p['department_name'] ?? '').toString().toLowerCase();
          return dName.isNotEmpty && dName == selectedDept.toString().toLowerCase();
        }).toList();
      }
    }
    if (_selectedSemId != null) {
      list = list.where((p) {
        final semStr = (p['semester_name'] ?? '').toString();
        return semStr.contains("$_selectedSemId");
      }).toList();
    }
    if (_selectedYearId != null) {
      final selectedYearMap = _academicYears.firstWhere((y) => y['id'] == _selectedYearId, orElse: () => {});
      final selectedYear = (selectedYearMap['name'] ?? '').toString().toLowerCase();
      if (selectedYear.isNotEmpty) {
        list = list.where((p) {
          final yName = (p['academic_year_name'] ?? '').toString().toLowerCase();
          return yName.isNotEmpty && yName.contains(selectedYear);
        }).toList();
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredPayments;
    final totalCount = _payments?.length ?? 0;
    final pendingCount = _payments?.where((p) => _getStatus(p) == 'pending').length ?? 0;
    final verifiedCount = _payments?.where((p) => _getStatus(p) == 'verified').length ?? 0;
    final rejectedCount = _payments?.where((p) => _getStatus(p) == 'rejected').length ?? 0;

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
              child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Student Payments Verification",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
                Text(
                  "Review student submissions and confirm bank transactions",
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.photo_library_rounded, size: 16),
            label: const Text("Uploaded Proofs", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            onPressed: () => context.push('/fees/uploaded-files'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add_card_rounded, size: 16),
            label: const Text("Record Payment", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            onPressed: () => context.push('/fees/record-payment'),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchPayments,
            tooltip: "Refresh Payments",
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs & Dropdowns
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip("All ($totalCount)", 'all'),
                      const SizedBox(width: 8),
                      _filterChip("Pending ($pendingCount)", 'pending', color: Colors.orange),
                      const SizedBox(width: 8),
                      _filterChip("Verified ($verifiedCount)", 'verified', color: Colors.green),
                      const SizedBox(width: 8),
                      _filterChip("Rejected ($rejectedCount)", 'rejected', color: Colors.red),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
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
                                child: Text("All Depts", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                                child: Text("All Sems", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                                Text("Year", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text("All Years", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              ..._academicYears.map((y) => DropdownMenuItem<int?>(
                                    value: y['id'] as int,
                                    child: Text(y['name'] as String, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
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

                    if (_selectedDeptId != null || _selectedSemId != null || _selectedYearId != null || _selectedFilter != 'all')
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: IconButton(
                          icon: const Icon(Icons.filter_alt_off_rounded, color: Colors.red, size: 20),
                          tooltip: "Reset All Filters",
                          onPressed: () {
                            setState(() {
                              _selectedDeptId = null;
                              _selectedSemId = null;
                              _selectedYearId = null;
                              _selectedFilter = 'all';
                            });
                            _fetchPayments();
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Error: $_error", style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _fetchPayments,
                              icon: const Icon(Icons.refresh),
                              label: const Text("Retry"),
                            ),
                          ],
                        ),
                      )
                    : list.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.payments_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedFilter == 'pending'
                                      ? "No pending payments to verify."
                                      : "No payment records found.",
                                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: list.length,
                            separatorBuilder: (c, i) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final p = list[index];
                              final status = _getStatus(p);
                              final isVerified = status == 'verified';
                              final isRejected = status == 'rejected';
                              final isReversed = status == 'reversed';

                              Color badgeBg;
                              Color badgeColor;
                              String badgeLabel;

                              if (isReversed) {
                                badgeBg = Colors.purple.withValues(alpha: 0.1);
                                badgeColor = Colors.purple;
                                badgeLabel = "REVERSED";
                              } else if (isRejected) {
                                badgeBg = Colors.red.withValues(alpha: 0.1);
                                badgeColor = Colors.red;
                                badgeLabel = "REJECTED";
                              } else if (isVerified) {
                                badgeBg = Colors.green.withValues(alpha: 0.1);
                                badgeColor = Colors.green;
                                badgeLabel = "VERIFIED";
                              } else {
                                badgeBg = Colors.orange.withValues(alpha: 0.1);
                                badgeColor = Colors.orange;
                                badgeLabel = "PENDING";
                              }

                              final studentName = p['student_name'] ?? 'Student #${p['student_fee'] ?? 'N/A'}';
                              final studentUsn = p['student_usn'];
                              final dept = p['department_name'];
                              final sem = p['semester_name'];
                              final remark = p['remark'];

                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _PaymentDetailScreen(payment: p),
                                    ),
                                  ).then((_) => _fetchPayments());
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
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
                                          Expanded(
                                            child: Text(
                                              studentName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Color(0xFF13246E),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: badgeBg,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              badgeLabel,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: badgeColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (studentUsn != null && studentUsn.toString().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          "USN: $studentUsn${dept != null ? ' • $dept' : ''}${sem != null ? ' • $sem' : ''}",
                                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                        ),
                                      ],
                                      if (isRejected && remark != null && remark.toString().isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.error_outline, size: 14, color: Colors.red),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  "Rejection Reason: $remark",
                                                  style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Mode: ${(p['mode'] ?? 'N/A').toString().toUpperCase()}",
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "Txn: ${p['upi_txn_id'] ?? p['bank_reference_no'] ?? 'N/A'}",
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                "₹${p['amount'] ?? '0.00'}",
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF10B981),
                                                ),
                                              ),
                                              Text(
                                                p['paid_on']?.toString().substring(0, 10) ?? '',
                                                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                              ),
                                            ],
                                          ),
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

  Widget _filterChip(String label, String value, {Color? color}) {
    final isSelected = _selectedFilter == value;
    final activeColor = color ?? const Color(0xFF13246E);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: Colors.grey.shade100,
      showCheckmark: false,
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = value);
      },
    );
  }
}

class _PaymentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> payment;
  const _PaymentDetailScreen({required this.payment});

  @override
  State<_PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<_PaymentDetailScreen> {
  bool _isProcessing = false;
  late Map<String, dynamic> _payment;

  @override
  void initState() {
    super.initState();
    _payment = widget.payment;
  }

  String _buildImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = ApiClient().dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
    String cleanPath = path.startsWith('/') ? path : '/$path';
    if (!cleanPath.startsWith('/media/')) {
      cleanPath = '/media$cleanPath';
    }
    return '$base$cleanPath';
  }



  void _showRejectDialog() {
    final remarkCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject Payment Proof"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please specify reason for rejecting this payment (e.g. invalid receipt, incorrect amount):"),
            const SizedBox(height: 12),
            TextField(
              controller: remarkCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Enter rejection reason...",
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final remark = remarkCtrl.text.trim();
              if (remark.isEmpty) return;
              Navigator.pop(ctx);
              await _rejectPayment(remark);
            },
            child: const Text("Confirm Reject"),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectPayment(String remark) async {
    setState(() => _isProcessing = true);
    try {
      final dio = ApiClient().dio;
      final res = await dio.post(
        '/fees/payments/${_payment['id']}/reject/',
        data: {"remark": remark},
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Payment rejected successfully."),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        final err = res.data is Map ? (res.data['detail'] ?? "Rejection failed") : "Error: ${res.statusCode}";
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showFullscreenImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Text(
                    "Image could not be loaded",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  String _getItemStatus(dynamic p) {
    if (p == null) return 'pending';
    if (p['is_reversed'] == true || p['verification_status'] == 'REVERSED') return 'reversed';
    if (p['verification_status'] == 'REJECTED' ||
        (p['verified'] != true && (p['remark']?.toString().toLowerCase().contains('reject') ?? false))) {
      return 'rejected';
    }
    if (p['verified'] == true || p['verification_status'] == 'VERIFIED') return 'verified';
    return 'pending';
  }

  @override
  Widget build(BuildContext context) {
    final itemStatus = _getItemStatus(_payment);
    final verified = itemStatus == 'verified';
    final isRejected = itemStatus == 'rejected';
    final isReversed = itemStatus == 'reversed';
    final receiptFile = _payment['proof_url'] ?? _payment['upi_screenshot'] ?? _payment['bank_statement_file'];
    final remark = _payment['remark'];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          "Payment #${_payment['id']}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Amount Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isReversed
                          ? Colors.purple.withValues(alpha: 0.1)
                          : isRejected
                              ? Colors.red.withValues(alpha: 0.1)
                              : verified
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isReversed
                          ? "REVERSED"
                          : isRejected
                              ? "REJECTED"
                              : verified
                                  ? "VERIFIED"
                                  : "PENDING VERIFICATION",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isReversed
                            ? Colors.purple
                            : isRejected
                                ? Colors.red
                                : verified
                                    ? Colors.green
                                    : Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "₹${_payment['amount'] ?? '0.00'}",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF13246E),
                    ),
                  ),
                  if (_payment['receipt_no'] != null || verified) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Receipt: ${_payment['receipt_no'] ?? 'Generated'}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Rejection remark if any
            if (remark != null && remark.toString().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Notes / Remarks",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "$remark",
                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Student & Payment Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _detailRow("Student Name", "${_payment['student_name'] ?? 'N/A'}"),
                  _detailRow("USN", "${_payment['student_usn'] ?? 'N/A'}"),
                  _detailRow("Department", "${_payment['department_name'] ?? 'N/A'}"),
                  _detailRow("Semester", "${_payment['semester_name'] ?? 'N/A'}"),
                  _detailRow("Payment Method", (_payment['mode'] ?? 'N/A').toString().toUpperCase()),
                  _detailRow(
                    "Transaction / Ref No.",
                    "${_payment['reference_no'] ?? _payment['upi_txn_id'] ?? _payment['bank_reference_no'] ?? 'N/A'}",
                  ),
                  _detailRow(
                    "Submission Date",
                    _payment['paid_on']?.toString().substring(0, 10) ?? 'N/A',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Student Uploaded Fee Payment Proof / Receipt Image
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.image_rounded, color: Color(0xFF13246E), size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Student Uploaded Fee Payment Proof",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                if (receiptFile != null && receiptFile.toString().trim().isNotEmpty)
                  InkWell(
                    onTap: () => _showFullscreenImage(_buildImageUrl(receiptFile.toString())),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13246E).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in_rounded, size: 16, color: Color(0xFF13246E)),
                          SizedBox(width: 4),
                          Text(
                            "Click to Zoom",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                if (receiptFile != null && receiptFile.toString().trim().isNotEmpty) {
                  _showFullscreenImage(_buildImageUrl(receiptFile.toString()));
                }
              },
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 220, maxHeight: 420),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: (receiptFile != null && receiptFile.toString().trim().isNotEmpty)
                      ? Image.network(
                          _buildImageUrl(receiptFile.toString()),
                          fit: BoxFit.contain,
                          loadingBuilder: (c, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                      : null,
                                  color: const Color(0xFF13246E),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, err, _) => Container(
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                                const SizedBox(height: 8),
                                const Text("Uploaded Proof Preview", style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  "File: $receiptFile",
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(24),
                          color: const Color(0xFFF8FAFC),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_outlined, size: 54, color: Color(0xFF13246E)),
                              const SizedBox(height: 12),
                              Text(
                                "Official Payment Slip: ${_payment['mode']?.toString().toUpperCase()} Proof",
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Ref No: ${_payment['reference_no'] ?? _payment['upi_txn_id'] ?? _payment['bank_reference_no'] ?? 'N/A'}",
                                style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Colors.black54),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Amount Paid: ₹${_payment['amount'] ?? '0.00'} • Status: ${verified ? 'VERIFIED' : 'PENDING'}",
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Verification Actions
            if (itemStatus == 'pending') ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _showRejectDialog,
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text(
                    "REJECT PAYMENT PROOF",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
