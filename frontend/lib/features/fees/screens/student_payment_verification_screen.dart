import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access');
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:8000',
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status! < 500,
        ),
      );
      final response = await dio.get('/fees/payments/');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Student Payments",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPayments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text("Error: $_error"))
          : _payments == null || _payments!.isEmpty
          ? const Center(child: Text("No payments found."))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _payments!.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final p = _payments![index];
                final verified = p['verified'] == true;
                return InkWell(
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
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Payment #${p['id']}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: verified
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                verified ? "VERIFIED" : "PENDING",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: verified
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text("Amount: ₹${p['amount'] ?? 'N/A'}"),
                        Text("Method: ${p['mode'] ?? 'N/A'}"),
                        Text(
                          "Date: ${p['paid_on']?.toString().substring(0, 10) ?? ''}",
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _PaymentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> payment;
  const _PaymentDetailScreen({required this.payment});

  @override
  Widget build(BuildContext context) {
    final verified = payment['verified'] == true;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          "Payment #${payment['id']}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      color: verified
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      verified ? "VERIFIED" : "PENDING",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: verified ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "₹${payment['amount'] ?? 'N/A'}",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF13246E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _detailRow("Payment ID", "#${payment['id']}"),
                  _detailRow(
                    "Student Fee ID",
                    "${payment['student_fee'] ?? 'N/A'}",
                  ),
                  _detailRow("Amount", "₹${payment['amount'] ?? 'N/A'}"),
                  _detailRow("Method", "${payment['mode'] ?? 'N/A'}"),
                  _detailRow(
                    "Transaction ID",
                    "${payment['upi_txn_id'] ?? payment['bank_reference_no'] ?? 'N/A'}",
                  ),
                  _detailRow(
                    "Date",
                    "${payment['paid_on']?.toString().substring(0, 10) ?? 'N/A'}",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (payment['upi_screenshot'] != null ||
                payment['bank_statement_file'] != null) ...[
              const Text(
                "Payment Receipt",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    'http://127.0.0.1:8000${payment['upi_screenshot'] ?? payment['bank_statement_file'] ?? ''}',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: Text("Receipt not available")),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (!verified)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      const storage = FlutterSecureStorage();
                      final token = await storage.read(key: 'access');
                      final dio = Dio(
                        BaseOptions(
                          baseUrl: 'http://127.0.0.1:8000',
                          headers: {'Authorization': 'Bearer $token'},
                          validateStatus: (s) => s! < 500,
                        ),
                      );
                      final res = await dio.post(
                        '/fees/payments/${payment['id']}/verify/',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Verified! ${res.data}")),
                        );
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Verify Payment",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
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
