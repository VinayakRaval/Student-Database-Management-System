import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../models/student_fee_model.dart';

String buildProofImageUrl(String? path) {
  if (path == null || path.trim().isEmpty) return '';
  final trimmed = path.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  final base = ApiClient().dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
  String cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  if (!cleanPath.startsWith('/media/') && !cleanPath.startsWith('/fees/')) {
    cleanPath = '/media$cleanPath';
  }
  return '$base$cleanPath';
}

void showPaymentProofDialog(BuildContext context, PaymentRecord payment) {
  final status = payment.verificationStatus.toUpperCase();
  final isVerified = status == 'VERIFIED';
  final isRejected = status == 'REJECTED';
  final isReversed = status == 'REVERSED';

  final Color statusBg = isVerified
      ? const Color(0xFFECFDF5)
      : isRejected
          ? const Color(0xFFFEF2F2)
          : isReversed
              ? const Color(0xFFF1F5F9)
              : const Color(0xFFFFFBEB);

  final Color statusColor = isVerified
      ? const Color(0xFF059669)
      : isRejected
          ? const Color(0xFFDC2626)
          : isReversed
              ? const Color(0xFF64748B)
              : const Color(0xFFD97706);

  final Color statusBorder = isVerified
      ? const Color(0xFFA7F3D0)
      : isRejected
          ? const Color(0xFFFECACA)
          : isReversed
              ? const Color(0xFFCBD5E1)
              : const Color(0xFFFDE68A);

  final fullUrl = buildProofImageUrl(payment.proofUrl);
  final isPdf = fullUrl.toLowerCase().endsWith('.pdf');

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 780),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF13246E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Payment Proof Review",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Proof Document / Screenshot Box
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 220, maxHeight: 380),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: fullUrl.isNotEmpty
                            ? (isPdf
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.picture_as_pdf_rounded,
                                              size: 64, color: Color(0xFFDC2626)),
                                          const SizedBox(height: 12),
                                          const Text(
                                            "PDF Payment Proof Uploaded",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            fullUrl.split('/').last,
                                            style: const TextStyle(
                                                fontSize: 12, color: Color(0xFF64748B)),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Image.network(
                                    fullUrl,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (c, child, progress) {
                                      if (progress == null) return child;
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(40),
                                          child: CircularProgressIndicator(
                                            value: progress.expectedTotalBytes != null
                                                ? progress.cumulativeBytesLoaded /
                                                    progress.expectedTotalBytes!
                                                : null,
                                            color: const Color(0xFF13246E),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (c, err, stack) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.image_not_supported_rounded,
                                                  size: 48, color: Color(0xFF94A3B8)),
                                              const SizedBox(height: 8),
                                              const Text(
                                                "Proof Image Preview Unavailable",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: Color(0xFF64748B)),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                payment.referenceNo.isNotEmpty
                                                    ? "Ref: ${payment.referenceNo}"
                                                    : "Uploaded Payment Proof",
                                                style: const TextStyle(
                                                    fontSize: 11, color: Color(0xFF94A3B8)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ))
                            : const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.attachment_rounded,
                                          size: 48, color: Color(0xFF94A3B8)),
                                      SizedBox(height: 8),
                                      Text(
                                        "No receipt document uploaded",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Payment Metadata Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            "Payment Amount",
                            "₹${payment.amount.toStringAsFixed(2)}",
                            isBold: true,
                            valueColor: const Color(0xFF13246E),
                            icon: Icons.currency_rupee_rounded,
                          ),
                          const Divider(height: 18, color: Color(0xFFF1F5F9)),
                          _buildDetailRow(
                            "Payment Date",
                            payment.paidOn != null && payment.paidOn!.isNotEmpty
                                ? payment.paidOn!
                                : "N/A",
                            icon: Icons.calendar_today_rounded,
                          ),
                          const Divider(height: 18, color: Color(0xFFF1F5F9)),
                          _buildDetailRow(
                            "Payment Method",
                            payment.modeDisplay,
                            icon: payment.mode.toLowerCase() == 'upi'
                                ? Icons.qr_code_rounded
                                : Icons.account_balance_rounded,
                          ),
                          const Divider(height: 18, color: Color(0xFFF1F5F9)),
                          _buildDetailRow(
                            "Transaction Reference",
                            payment.referenceNo.isNotEmpty ? payment.referenceNo : "N/A",
                            icon: Icons.tag_rounded,
                          ),
                          const Divider(height: 18, color: Color(0xFFF1F5F9)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified_user_outlined,
                                      size: 16, color: Color(0xFF64748B)),
                                  SizedBox(width: 8),
                                  Text(
                                    "Verification Status",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusBorder),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (payment.remark != null && payment.remark!.trim().isNotEmpty) ...[
                            const Divider(height: 18, color: Color(0xFFF1F5F9)),
                            _buildDetailRow(
                              "Officer Remarks",
                              payment.remark!.trim(),
                              valueColor: isRejected ? Colors.red : const Color(0xFF334155),
                              icon: Icons.comment_outlined,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF13246E),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
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

Widget _buildDetailRow(
  String label,
  String value, {
  bool isBold = false,
  Color? valueColor,
  IconData? icon,
}) {
  return Row(
    children: [
      if (icon != null) ...[
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
      ],
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w500,
        ),
      ),
      const Spacer(),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ),
    ],
  );
}

class PaymentRecordTile extends StatelessWidget {
  final PaymentRecord payment;
  final VoidCallback onViewProof;

  const PaymentRecordTile({
    super.key,
    required this.payment,
    required this.onViewProof,
  });

  @override
  Widget build(BuildContext context) {
    final status = payment.verificationStatus.toUpperCase();
    final isVerified = status == 'VERIFIED';
    final isRejected = status == 'REJECTED';
    final isReversed = status == 'REVERSED';

    final Color statusBg = isVerified
        ? const Color(0xFFECFDF5)
        : isRejected
            ? const Color(0xFFFEF2F2)
            : isReversed
                ? const Color(0xFFF1F5F9)
                : const Color(0xFFFFFBEB);

    final Color statusColor = isVerified
        ? const Color(0xFF059669)
        : isRejected
            ? const Color(0xFFDC2626)
            : isReversed
                ? const Color(0xFF64748B)
                : const Color(0xFFD97706);

    final Color statusBorder = isVerified
        ? const Color(0xFFA7F3D0)
        : isRejected
            ? const Color(0xFFFECACA)
            : isReversed
                ? const Color(0xFFCBD5E1)
                : const Color(0xFFFDE68A);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
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
                  Icon(
                    payment.mode.toLowerCase() == 'upi'
                        ? Icons.qr_code_rounded
                        : Icons.account_balance_rounded,
                    size: 16,
                    color: const Color(0xFF13246E),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    payment.modeDisplay,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusBorder),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Amount: ₹${payment.amount.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF13246E),
                ),
              ),
              Text(
                payment.paidOn != null && payment.paidOn!.isNotEmpty
                    ? payment.paidOn!
                    : "",
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Ref / Txn No: ${payment.referenceNo.isNotEmpty ? payment.referenceNo : 'N/A'}",
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
          ),
          if (payment.remark != null && payment.remark!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              "Remark: ${payment.remark!.trim()}",
              style: TextStyle(
                fontSize: 11,
                color: isRejected ? Colors.red.shade700 : const Color(0xFF64748B),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              onPressed: onViewProof,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF13246E),
                side: const BorderSide(color: Color(0xFF13246E), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                backgroundColor: Colors.white,
              ),
              icon: const Icon(Icons.remove_red_eye_rounded, size: 16),
              label: const Text(
                "View Payment Proof",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
