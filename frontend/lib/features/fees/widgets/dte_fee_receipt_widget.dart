import 'package:flutter/material.dart';

/// Helper to convert numbers to Indian Currency words (e.g. 32932 -> Thirty Two Thousand Nine Hundred and Thirty Two Only)
String numberToIndianWords(num number) {
  if (number == 0) return "Zero Rupees Only";

  final units = [
    "", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine",
    "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen",
    "Seventeen", "Eighteen", "Nineteen"
  ];
  final tens = [
    "", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"
  ];

  String convertChunk(int n) {
    if (n == 0) return "";
    if (n < 20) return units[n];
    if (n < 100) {
      final rem = n % 10;
      return "${tens[n ~/ 10]}${rem > 0 ? ' ${units[rem]}' : ''}";
    }
    final rem = n % 100;
    return "${units[n ~/ 100]} Hundred${rem > 0 ? ' and ${convertChunk(rem)}' : ''}";
  }

  int intPart = number.toInt();
  int paise = ((number - intPart) * 100).round();

  String words = "";
  if (intPart >= 10000000) {
    words += "${convertChunk(intPart ~/ 10000000)} Crore ";
    intPart %= 10000000;
  }
  if (intPart >= 100000) {
    words += "${convertChunk(intPart ~/ 100000)} Lakh ";
    intPart %= 100000;
  }
  if (intPart >= 1000) {
    words += "${convertChunk(intPart ~/ 1000)} Thousand ";
    intPart %= 1000;
  }
  if (intPart > 0) {
    words += convertChunk(intPart);
  }

  words = words.trim();
  if (words.isEmpty && paise > 0) {
    return "${convertChunk(paise)} Paise Only";
  }
  if (paise > 0) {
    return "$words Rupees and ${convertChunk(paise)} Paise Only";
  }
  return "$words Only";
}

/// Official Department of Technical Education Fee Receipt & Structure Component
/// Meticulously modeled from Image 1: DTE Official Receipt Booklet
class DteFeeReceiptWidget extends StatelessWidget {
  final String institutionName;
  final String bookletNo;
  final String receiptDate;
  final String receiptNo;
  final String studentName;
  final String branch;
  final String category;
  final String year;
  final String? semester;
  final List<Map<String, dynamic>> components;
  final double totalAmount;
  final String status;
  final String? approvedByName;
  final String? approvedDate;
  final bool isStudentReceipt;
  final bool isReprint;

  static const List<String> standardFeeItems = [
    "Registration fee",
    "Tuition Fee",
    "Sports Fee",
    "Union Fee",
    "Library Fee",
    "Magazine Fee",
    "Library Tax",
    "Laboratory Fee",
    "ID card Fee",
    "Student Welfare Fee",
    "Teacher's Welfare Fee",
    "Development Fee",
    "NSS Fee",
    "Other Fee",
  ];

  const DteFeeReceiptWidget({
    super.key,
    this.institutionName = "Government Engineering College Chamarajanagara",
    this.bookletNo = "10495685",
    this.receiptDate = "01/01/2045",
    this.receiptNo = "0821183",
    this.studentName = "Vivekanand S Kalgurti",
    this.branch = "CSE",
    this.category = "General",
    this.year = "2025",
    this.semester,
    required this.components,
    required this.totalAmount,
    this.status = "APPROVED",
    this.approvedByName,
    this.approvedDate,
    this.isStudentReceipt = false,
    this.isReprint = false,
  });

  @override
  Widget build(BuildContext context) {
    final isApproved = status.toUpperCase() == 'APPROVED' || status.toUpperCase() == 'PAID';
    final isPending = status.toUpperCase() == 'PENDING';

    String displayAcademicYear = year.trim();
    String displaySemester = (semester ?? "").trim();

    if (displaySemester.isEmpty && displayAcademicYear.contains("•")) {
      final parts = displayAcademicYear.split("•");
      displayAcademicYear = parts[0].trim();
      if (parts.length > 1) {
        displaySemester = parts[1].trim();
      }
    } else if (displaySemester.isEmpty && displayAcademicYear.toLowerCase().contains("sem")) {
      final semIdx = displayAcademicYear.toLowerCase().indexOf("sem");
      displaySemester = displayAcademicYear.substring(semIdx).trim();
      displayAcademicYear = displayAcademicYear.substring(0, semIdx).replaceAll("-", " ").trim();
    }

    if (displayAcademicYear.isEmpty) displayAcademicYear = "2025-2026";
    if (displaySemester.isEmpty) displaySemester = "Semester 3";

    // Calculate total if not provided or 0
    final double calculatedTotal = components.fold<double>(
      0.0,
      (sum, c) => sum + (double.tryParse(c['amount']?.toString() ?? '0') ?? 0.0),
    );
    final double displayTotal = totalAmount > 0 ? totalAmount : calculatedTotal;

    // Helper to normalize strings for flexible matching
    String normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    // Standard slot matching patterns
    final List<List<String>> standardPatterns = [
      ["registration", "admission", "regfee"], // 1. Registration fee
      ["tuition", "tution", "coursefee", "academicfee"], // 2. Tuition Fee
      ["sports", "games", "gymkhana", "physicaleducation"], // 3. Sports Fee
      ["union", "studentunion"], // 4. Union Fee
      ["libraryfee", "library", "books"], // 5. Library Fee
      ["magazine"], // 6. Magazine Fee
      ["librarytax", "libtax"], // 7. Library Tax
      ["laboratory", "labfee", "lab"], // 8. Laboratory Fee
      ["idcard", "identitycard", "idfee"], // 9. ID card Fee
      ["studentwelfare", "swfee", "welfarefee"], // 10. Student Welfare Fee
      ["teacherswelfare", "teacherwelfare", "twfee"], // 11. Teacher's Welfare Fee
      ["development", "collegedevelopment"], // 12. Development Fee
      ["nss", "nssfee"], // 13. NSS Fee
      ["other", "others", "miscellaneous"], // 14. Other Fee
    ];

    // Prepare slots for the 14 rows
    final List<Map<String, dynamic>> slots = List.generate(
      standardFeeItems.length,
      (i) => {
        'index': i + 1,
        'name': standardFeeItems[i],
        'amount': 0.0,
        'isMatched': false,
      },
    );

    final List<Map<String, dynamic>> customComponents = [];

    // 1. Assign matched components to standard slots
    for (final c in components) {
      final rawName = (c['name'] ?? '').toString().trim();
      final amt = double.tryParse(c['amount']?.toString() ?? '0') ?? 0.0;
      if (rawName.isEmpty && amt <= 0) continue;

      final norm = normalize(rawName);
      int matchedSlotIndex = -1;

      for (int i = 0; i < standardPatterns.length; i++) {
        if (slots[i]['isMatched'] == true) continue;
        for (final p in standardPatterns[i]) {
          if (norm == p || norm.contains(p) || p.contains(norm)) {
            matchedSlotIndex = i;
            break;
          }
        }
        if (matchedSlotIndex != -1) break;
      }

      if (matchedSlotIndex != -1) {
        slots[matchedSlotIndex]['amount'] = amt;
        slots[matchedSlotIndex]['isMatched'] = true;
        // If the user specified a custom name variation, use the rawName
        if (rawName.isNotEmpty && rawName.toLowerCase() != slots[matchedSlotIndex]['name'].toString().toLowerCase()) {
          slots[matchedSlotIndex]['name'] = rawName;
        }
      } else {
        customComponents.add({'name': rawName.isNotEmpty ? rawName : 'Component', 'amount': amt});
      }
    }

    // 2. Put custom / unmatched components into available empty slots (starting from slot 14 upwards, or first empty)
    final List<int> emptySlotIndices = [];
    // Prefer filling slot 14 ("Other Fee") first, then any other empty slots
    if (slots[13]['isMatched'] == false) {
      emptySlotIndices.add(13);
    }
    for (int i = 0; i < slots.length; i++) {
      if (i != 13 && slots[i]['isMatched'] == false) {
        emptySlotIndices.add(i);
      }
    }

    final List<Map<String, dynamic>> overflowComponents = [];
    for (final custom in customComponents) {
      if (emptySlotIndices.isNotEmpty) {
        final slotIdx = emptySlotIndices.removeAt(0);
        slots[slotIdx]['name'] = custom['name'];
        slots[slotIdx]['amount'] = custom['amount'];
        slots[slotIdx]['isMatched'] = true;
      } else {
        overflowComponents.add(custom);
      }
    }

    // 3. Assemble tableRows
    final List<Map<String, dynamic>> tableRows = slots.map((s) => {
      'index': s['index'],
      'name': s['name'],
      'amount': s['amount'],
    }).toList();

    for (final over in overflowComponents) {
      tableRows.add({
        'index': tableRows.length + 1,
        'name': over['name'],
        'amount': over['amount'],
      });
    }

    final int totalRs = displayTotal.toInt();
    final int totalPs = ((displayTotal - totalRs) * 100).round();
    final String amountInWords = numberToIndianWords(displayTotal);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 680),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TOP HEADER: Department of Technical Education
          const Center(
            child: Text(
              "Department of Technical Education",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
                letterSpacing: 0.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 1.5, color: const Color(0xFF334155)),
          const SizedBox(height: 14),

          // 2. METADATA: Institution, Booklet No, Receipt Date, Red Receipt Number
          _buildUnderlinedField("Institution :", institutionName),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 5,
                child: _buildUnderlinedField("Booklet no:", bookletNo),
              ),
              const SizedBox(width: 16),
              // Prominent Red Receipt Number with Reprint Badge
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    receiptNo,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C), // Deep Red like Image 1
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (isReprint) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        border: Border.all(color: const Color(0xFFEF4444), width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "DUPLICATE / REPRINT",
                        style: TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          _buildUnderlinedField("Receipt Date:", receiptDate),
          const SizedBox(height: 8),

          _buildUnderlinedField("Student name:", studentName),
          const SizedBox(height: 8),

          // Dedicated Full-Width Row for Branch so long branch names never truncate
          _buildUnderlinedField("Branch:", branch, allowWrap: true),
          const SizedBox(height: 8),

          // Category, Academic Year, and Semester Row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildUnderlinedField("Category:", category),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: _buildUnderlinedField("Academic Year:", displayAcademicYear),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: _buildUnderlinedField("Semester:", displaySemester),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. TABLE GRID: Details | Rs. | Ps.
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1.4),
            ),
            child: Column(
              children: [
                // Table Header Row
                Container(
                  color: const Color(0xFFF8FAFC),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 7,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          child: Text(
                            "Details",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      _vDivider(),
                      const SizedBox(
                        width: 75,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            "Rs.",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      _vDivider(),
                      const SizedBox(
                        width: 48,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            "Ps.",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _hDivider(),

                // Table Data Rows
                ...tableRows.map((row) {
                  final idx = row['index'];
                  final name = row['name'];
                  final double amt = row['amount'] ?? 0.0;
                  final String rsStr = amt > 0 ? amt.toInt().toString() : "";
                  final String psStr = amt > 0 ? ((amt - amt.toInt()) * 100).round().toString().padLeft(2, '0') : "";

                  return Column(
                    children: [
                      SizedBox(
                        height: 25,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 7,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  "$idx. $name",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                    fontWeight: amt > 0 ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            _vDivider(),
                            SizedBox(
                              width: 75,
                              child: Center(
                                child: Text(
                                  rsStr,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                              ),
                            ),
                            _vDivider(),
                            SizedBox(
                              width: 48,
                              child: Center(
                                child: Text(
                                  psStr,
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _hDivider(),
                    ],
                  );
                }),

                // Table Total Row
                Container(
                  color: const Color(0xFFF8FAFC),
                  height: 32,
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 7,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            "Total Fees",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      _vDivider(),
                      SizedBox(
                        width: 75,
                        child: Center(
                          child: Text(
                            "$totalRs",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                          ),
                        ),
                      ),
                      _vDivider(),
                      SizedBox(
                        width: 48,
                        child: Center(
                          child: Text(
                            totalPs.toString().padLeft(2, '0'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. RUPEES IN LETTERS
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Rupees in Letters : ",
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(bottom: 2),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black, width: 1.1)),
                  ),
                  child: Text(
                    amountInWords,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // 5. SIGNATURES: Cashier (Left) & Principal (Right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 1. Cashier Digital Signature Section
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isApproved) ...[
                      // Stylized Cashier Digital Signature
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          "K. R. V. (Accounts)",
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E3A8A).withValues(alpha: 0.9),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified, size: 11, color: Color(0xFF059669)),
                            const SizedBox(width: 3),
                            Text(
                              "Digitally Signed: ${receiptDate.length > 10 ? receiptDate.substring(0, 10) : receiptDate}",
                              style: const TextStyle(fontSize: 8.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        "Cashier / Accounts Officer",
                        style: TextStyle(fontSize: 8, color: Color(0xFF64748B)),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ] else ...[
                      const SizedBox(height: 38),
                    ],
                    Container(height: 1.2, color: Colors.black),
                    const SizedBox(height: 4),
                    const Text(
                      "Cashier",
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // 2. Status Seal in the middle
              if (isApproved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF059669), width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFECFDF5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 14, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text(
                            "APPROVED",
                            style: TextStyle(
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        approvedDate ?? "Verified & Audited",
                        style: const TextStyle(fontSize: 8, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
                      ),
                      const Text(
                        "DTE Official Receipt",
                        style: TextStyle(fontSize: 7.5, color: Color(0xFF047857)),
                      ),
                    ],
                  ),
                )
              else if (isPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD97706), width: 1.2),
                    borderRadius: BorderRadius.circular(6),
                    color: const Color(0xFFFFFBEB),
                  ),
                  child: const Text(
                    "PENDING APPROVAL",
                    style: TextStyle(
                      color: Color(0xFFD97706),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              else
                const Spacer(flex: 2),

              const SizedBox(width: 8),

              // 3. Principal Digital Signature Section
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isApproved) ...[
                      // Stylized Principal Digital Signature - STRICTLY SINGLE LINE
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          approvedByName?.isNotEmpty == true ? approvedByName! : "Dr. Parashivamurthy K.I.",
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 11, color: Color(0xFF059669)),
                            const SizedBox(width: 3),
                            Text(
                              "Digitally Signed: ${approvedDate != null && approvedDate!.length > 10 ? approvedDate!.substring(0, 10) : (approvedDate ?? receiptDate)}",
                              style: const TextStyle(fontSize: 8.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        "Principal, GECC Chamarajanagara",
                        style: TextStyle(fontSize: 8, color: Color(0xFF64748B)),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ] else ...[
                      const SizedBox(height: 38),
                    ],
                    Container(height: 1.2, color: Colors.black),
                    const SizedBox(height: 4),
                    const Text(
                      "Principal",
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnderlinedField(String label, String value, {bool allowWrap = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          "$label ",
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.only(bottom: 2),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 1.1)),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              overflow: allowWrap ? TextOverflow.visible : TextOverflow.ellipsis,
              softWrap: allowWrap,
            ),
          ),
        ),
      ],
    );
  }

  Widget _vDivider() {
    return Container(width: 1.2, color: Colors.black);
  }

  Widget _hDivider() {
    return Container(height: 1.1, color: Colors.black);
  }
}
