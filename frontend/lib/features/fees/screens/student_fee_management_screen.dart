import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/network/api_client.dart';
import '../models/student_fee_model.dart';
import '../widgets/dte_fee_receipt_widget.dart';

class StudentFeeManagementScreen extends StatefulWidget {
  const StudentFeeManagementScreen({super.key});

  @override
  State<StudentFeeManagementScreen> createState() => _StudentFeeManagementScreenState();
}

class _StudentFeeManagementScreenState extends State<StudentFeeManagementScreen> {
  List<StudentFee> _fees = [];
  bool _isLoading = true;
  String? _error;

  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedStatus = 'all'; // all, pending, partial, paid
  String _searchQuery = '';
  int? _selectedDeptId;
  int? _selectedSemId;

  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _semesters = [];

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
    _fetchStudentFees();
  }

  Future<void> _fetchDropdownData() async {
    try {
      final dio = ApiClient().dio;
      final deptRes = await dio.get('/academics/departments/');
      final semRes = await dio.get('/academics/semesters/');
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
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchStudentFees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ApiClient().dio;
      final queryParams = <String, dynamic>{};
      if (_searchQuery.isNotEmpty) queryParams['search'] = _searchQuery;
      if (_selectedStatus != 'all') queryParams['status'] = _selectedStatus;
      if (_selectedDeptId != null) queryParams['department'] = _selectedDeptId;
      if (_selectedSemId != null) queryParams['semester'] = _selectedSemId;

      final response = await dio.get('/fees/student-fees/', queryParameters: queryParams);
      final List results = response.data is List ? response.data : (response.data['results'] ?? []);

      if (mounted) {
        setState(() {
          _fees = results.map((e) => StudentFee.fromJson(e)).toList();
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

  Future<void> _showApplyConcessionDialog(StudentFee fee) async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    final success = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.card_giftcard_rounded, color: Color(0xFF13246E)),
            const SizedBox(width: 8),
            Text("Apply Concession: ${fee.studentUsn}"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Student: ${fee.studentName} (${fee.departmentCode})", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("Total Assigned Fee: ₹${fee.totalFee.toStringAsFixed(2)}"),
            if (fee.concessionAmount > 0)
              Text("Current Concession: ₹${fee.concessionAmount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.purple)),
            Text("Current Outstanding: ₹${fee.balanceAmount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Concession / Scholarship Amount (₹)",
                border: OutlineInputBorder(),
                prefixText: "₹ ",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: "Reason / Scholarship Name",
                hintText: "e.g. Merit Scholarship, Sports Quota, EWS Concession",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text.trim()) ?? -1;
              if (amt < 0 || amt > fee.totalFee) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid concession amount."), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text("Apply Concession"),
          ),
        ],
      ),
    );

    if (success == true) {
      final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
      final reason = reasonCtrl.text.trim();
      try {
        final dio = ApiClient().dio;
        await dio.post('/fees/student-fees/${fee.id}/apply-concession/', data: {
          "concession_amount": amt,
          "concession_reason": reason,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Concession applied successfully!"), backgroundColor: Colors.green),
          );
          _fetchStudentFees();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to apply concession: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showStatementDialog(StudentFee fee) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => FutureBuilder(
        future: ApiClient().dio.get('/fees/student-fees/${fee.id}/statement/'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AlertDialog(
              title: const Text("Error"),
              content: Text("${snapshot.error}"),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
            );
          }

          final data = snapshot.data?.data as Map<String, dynamic>? ?? {};
          final stu = data['student'] as Map<String, dynamic>? ?? {};
          final struct = data['fee_structure'] as Map<String, dynamic>? ?? {};
          final comps = (struct['components'] as List?) ?? [];
          final payments = (data['payments'] as List?) ?? [];
          final conc = data['concession'] as Map<String, dynamic>? ?? {};

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 680, maxHeight: 850),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF13246E),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.description_rounded, color: Colors.white, size: 22),
                            SizedBox(width: 8),
                            Text(
                              "Official Student Fee Statement",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.print_rounded, color: Colors.white),
                              tooltip: "Print Statement",
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Sending fee statement to printer / export..."),
                                    backgroundColor: Color(0xFF13246E),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Statement Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Student Details Header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Name: ${stu['name']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text("USN: ${stu['usn']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF13246E))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Department: ${stu['department']}"),
                                    Text("${stu['semester']} • ${stu['academic_year']}"),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Fee Components Breakdown
                          const Text("Fee Structure Breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 8),
                          Table(
                            border: TableBorder.all(color: Colors.grey.shade300),
                            children: [
                              TableRow(
                                decoration: BoxDecoration(color: Colors.grey.shade100),
                                children: const [
                                  Padding(padding: EdgeInsets.all(8), child: Text("Component", style: TextStyle(fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.all(8), child: Text("Amount", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                              ),
                              ...comps.map((c) => TableRow(
                                    children: [
                                      Padding(padding: const EdgeInsets.all(8), child: Text("${c['name']}")),
                                      Padding(padding: const EdgeInsets.all(8), child: Text("₹${c['amount']}", textAlign: TextAlign.right)),
                                    ],
                                  )),
                              TableRow(
                                decoration: BoxDecoration(color: Colors.grey.shade50),
                                children: [
                                  const Padding(padding: EdgeInsets.all(8), child: Text("Total Assigned Fee", style: TextStyle(fontWeight: FontWeight.bold))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text("₹${struct['total_amount']}", textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                                ],
                              ),
                              if ((conc['amount'] as num?)?.toDouble() != null && (conc['amount'] as num).toDouble() > 0)
                                TableRow(
                                  children: [
                                    Padding(padding: const EdgeInsets.all(8), child: Text("Less: Concession (${conc['reason']})", style: const TextStyle(color: Colors.purple))),
                                    Padding(padding: const EdgeInsets.all(8), child: Text("- ₹${conc['amount']}", textAlign: TextAlign.right, style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              TableRow(
                                decoration: BoxDecoration(color: const Color(0xFF13246E).withValues(alpha: 0.05)),
                                children: [
                                  const Padding(padding: EdgeInsets.all(8), child: Text("Net Payable Fee", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF13246E)))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text("₹${data['net_payable']}", textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF13246E)))),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Payments Ledger
                          const Text("Payment History & Receipts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 8),
                          if (payments.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text("No payments recorded yet.", style: TextStyle(color: Colors.grey)),
                            )
                          else
                            Table(
                              border: TableBorder.all(color: Colors.grey.shade300),
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(color: Colors.grey.shade100),
                                  children: const [
                                    Padding(padding: EdgeInsets.all(8), child: Text("Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(8), child: Text("Receipt No", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(8), child: Text("Mode / Ref", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(8), child: Text("Amount", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  ],
                                ),
                                ...payments.map((p) => TableRow(
                                      children: [
                                        Padding(padding: const EdgeInsets.all(8), child: Text("${p['paid_on'] ?? 'N/A'}", style: const TextStyle(fontSize: 12))),
                                        Padding(padding: const EdgeInsets.all(8), child: Text("${p['receipt_no'] ?? '-'}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green))),
                                        Padding(padding: const EdgeInsets.all(8), child: Text("${p['mode']}\n${p['reference_no']}", style: const TextStyle(fontSize: 11))),
                                        Padding(padding: const EdgeInsets.all(8), child: Text("₹${p['amount']}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                      ],
                                    )),
                              ],
                            ),
                          const SizedBox(height: 24),

                          // Summary Box
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text("Total Paid", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text("₹${data['total_paid']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                                  ],
                                ),
                                Container(width: 1, height: 40, color: Colors.grey.shade300),
                                Column(
                                  children: [
                                    const Text("Balance Due", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text("₹${data['balance_amount']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                                  ],
                                ),
                                Container(width: 1, height: 40, color: Colors.grey.shade300),
                                Column(
                                  children: [
                                    const Text("Account Status", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text("${data['status']}".toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF13246E))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReceiptDialog(StudentFee fee) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 820),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(color: Color(0xFF13246E), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text("Official DTE Receipt", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.print_rounded, color: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Sending official receipt to printer / PDF..."), backgroundColor: Color(0xFF13246E)),
                        );
                      },
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: DteFeeReceiptWidget(
                    institutionName: "Government Engineering College Chamarajanagara",
                    bookletNo: fee.bookletNo ?? "10495685",
                    receiptDate: fee.receiptDate ?? "01/01/2045",
                    receiptNo: fee.formattedReceiptNo ?? (fee.receiptNo ?? "0821183"),
                    studentName: fee.studentName.isNotEmpty ? fee.studentName : "Student",
                    branch: fee.departmentCode.isNotEmpty ? fee.departmentCode : "CSE",
                    category: fee.seatType,
                    year: fee.academicYear,
                    components: fee.components.isNotEmpty
                        ? fee.components.map((c) => {'name': c.name, 'amount': c.amount}).toList()
                        : [{'name': 'Tuition Fee', 'amount': fee.paidAmount > 0 ? fee.paidAmount : fee.totalFee}],
                    totalAmount: fee.paidAmount > 0 ? fee.paidAmount : fee.totalFee,
                    status: fee.status,
                    isStudentReceipt: true,
                  ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Student Fee Directory",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh List",
            onPressed: _fetchStudentFees,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Controls Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: "Search by Student Name, USN, or Email...",
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                    _fetchStudentFees();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onSubmitted: (val) {
                          setState(() => _searchQuery = val.trim());
                          _fetchStudentFees();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13246E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        setState(() => _searchQuery = _searchCtrl.text.trim());
                        _fetchStudentFees();
                      },
                      child: const Text("Search"),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Department & Semester Dropdown Filters
                Row(
                  children: [
                    // Department Dropdown
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                Icon(Icons.business_rounded, size: 18, color: Colors.grey),
                                SizedBox(width: 8),
                                Text("All Departments", style: TextStyle(fontSize: 13, color: Colors.grey)),
                              ],
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text("All Departments", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                              ..._departments.map((d) => DropdownMenuItem<int?>(
                                    value: d['id'] as int,
                                    child: Text(d['name'] as String, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                  )),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedDeptId = val);
                              _fetchStudentFees();
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Semester Dropdown
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                Icon(Icons.school_rounded, size: 18, color: Colors.grey),
                                SizedBox(width: 8),
                                Text("All Semesters", style: TextStyle(fontSize: 13, color: Colors.grey)),
                              ],
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text("All Semesters", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                              ..._semesters.map((s) => DropdownMenuItem<int?>(
                                    value: s['id'] as int,
                                    child: Text(s['name'] as String, style: const TextStyle(fontSize: 13)),
                                  )),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedSemId = val);
                              _fetchStudentFees();
                            },
                          ),
                        ),
                      ),
                    ),

                    if (_selectedDeptId != null || _selectedSemId != null || _searchQuery.isNotEmpty || _selectedStatus != 'all')
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: IconButton(
                          icon: const Icon(Icons.filter_alt_off_rounded, color: Colors.red),
                          tooltip: "Reset All Filters",
                          onPressed: () {
                            setState(() {
                              _selectedDeptId = null;
                              _selectedSemId = null;
                              _selectedStatus = 'all';
                              _searchQuery = '';
                              _searchCtrl.clear();
                            });
                            _fetchStudentFees();
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status Chips Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _statusChip("All Students", 'all'),
                      const SizedBox(width: 8),
                      _statusChip("Pending Dues", 'pending', color: Colors.red),
                      const SizedBox(width: 8),
                      _statusChip("Partially Paid", 'partial', color: Colors.orange),
                      const SizedBox(width: 8),
                      _statusChip("Fully Paid", 'paid', color: Colors.green),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Table / List View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text("Error: $_error"))
                    : _fees.isEmpty
                        ? const Center(child: Text("No student fee records found."))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _fees.length,
                            separatorBuilder: (c, i) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final fee = _fees[index];
                              return _buildStudentFeeCard(fee);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, String value, {Color? color}) {
    final isSelected = _selectedStatus == value;
    final activeColor = color ?? const Color(0xFF13246E);
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: Colors.grey.shade100,
      showCheckmark: false,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedStatus = value);
          _fetchStudentFees();
        }
      },
    );
  }

  Widget _buildStudentFeeCard(StudentFee fee) {
    final isPaid = fee.status.toLowerCase() == 'paid';
    final isPartial = fee.status.toLowerCase() == 'partial';
    final statusColor = isPaid ? Colors.green : (isPartial ? Colors.orange : Colors.red);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Student Name, USN, Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fee.studentName.isNotEmpty ? fee.studentName : "Student #${fee.id}",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF13246E)),
                    ),
                    Text(
                      "${fee.studentUsn} • ${fee.departmentCode} • Sem ${fee.semester} • ${fee.seatType}",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fee.status.toUpperCase(),
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Amounts Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricColumn("Total Assigned", "₹${fee.totalFee.toStringAsFixed(2)}"),
              if (fee.concessionAmount > 0)
                _metricColumn("Concession", "₹${fee.concessionAmount.toStringAsFixed(2)}", color: Colors.purple),
              _metricColumn("Paid Amount", "₹${fee.paidAmount.toStringAsFixed(2)}", color: Colors.green),
              _metricColumn("Balance Due", "₹${fee.balanceAmount.toStringAsFixed(2)}", color: Colors.red, isBold: true),
            ],
          ),
          const SizedBox(height: 16),

          // Operations Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showStatementDialog(fee),
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text("Statement"),
              ),
              OutlinedButton.icon(
                onPressed: () => _showApplyConcessionDialog(fee),
                icon: const Icon(Icons.card_giftcard_rounded, size: 16),
                label: const Text("Concession"),
              ),
              if (fee.balanceAmount > 0)
                ElevatedButton.icon(
                  onPressed: () => context.push('/fees/record-payment?feeId=${fee.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13246E),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.payment_rounded, size: 16),
                  label: const Text("Record Payment"),
                ),
              if (fee.paidAmount > 0)
                OutlinedButton.icon(
                  onPressed: () => _showReceiptDialog(fee),
                  icon: const Icon(Icons.description_rounded, size: 16),
                  label: const Text("DTE Receipt"),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricColumn(String label, String value, {Color? color, bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.black87,
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
