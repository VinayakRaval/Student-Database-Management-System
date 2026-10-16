import 'package:flutter/material.dart';

class DigitalLibraryCardWidget extends StatelessWidget {
  final Map<String, dynamic> cardData;
  final List<Map<String, dynamic>> circulationRows;

  const DigitalLibraryCardWidget({
    super.key,
    required this.cardData,
    this.circulationRows = const [],
  });

  @override
  Widget build(BuildContext context) {
    final borrowerType = (cardData['borrower_type'] ?? 'STUDENT').toString().toUpperCase();
    final isFaculty = borrowerType == 'FACULTY';
    final borrowerName = cardData['borrower_name'] ?? cardData['student_name'] ?? cardData['name'] ?? 'Rahul Kumar';
    final rawDept = cardData['department_name'] ?? cardData['department'];
    final deptName = (rawDept != null && rawDept.toString().trim().isNotEmpty && rawDept.toString().trim() != 'N/A')
        ? rawDept.toString().trim()
        : 'Computer Science and Engineering';
    final section = cardData['section'] ?? 'A';
    final usn = cardData['student_usn'] ?? cardData['borrower_id_number'] ?? cardData['usn'] ?? cardData['faculty_id'] ?? '4GE24CS030';
    final academicYear = cardData['academic_year'] ?? '2025-2026';
    final cardNumber = cardData['card_number'] ?? 'LC-2026-0001';
    final validUntil = cardData['valid_until'] ?? '31-12-2026';
    final issuedAt = cardData['issued_at'] != null ? cardData['issued_at'].toString().substring(0, 10) : '2026-10-15';
    final sigHash = cardData['digital_signature_hash']?.toString() ?? '';
    final shortSig = sigHash.length > 16 ? sigHash.substring(0, 16) : sigHash;
    final photoUrl = (cardData['photo_url'] ?? cardData['student_photo']) as String?;
    final signatureUrl = (cardData['signature_image_url'] ?? cardData['signature_url']) as String?;
    final hodSignatureUrl = (cardData['hod_signature_image_url'] ?? cardData['hod_signature_url']) as String?;
    final cardStatus = (cardData['status'] ?? '').toString().toUpperCase();
    final isApproved = cardStatus == 'HOD_APPROVED' || cardStatus == 'ACTIVE' || cardStatus == 'CARD_GENERATED';
    final hodName = cardData['hod_name'] ?? 'Authorized HOD';
    final hodVerifiedAt = cardData['hod_verified_at'] != null ? cardData['hod_verified_at'].toString().substring(0, 10) : '';

    final List<Map<String, dynamic>> effectiveRows = [];
    final candidateRows = circulationRows.isNotEmpty
        ? circulationRows
        : (cardData['circulation_rows'] as List?) ?? (cardData['recorded_books'] as List?) ?? [];
    for (final r in candidateRows) {
      if (r is Map) {
        effectiveRows.add(Map<String, dynamic>.from(r));
      }
    }
    if (effectiveRows.isEmpty) {
      final fallbackRows = (cardData['missing_books'] as List?) ?? (cardData['all_books'] as List?) ?? (cardData['all_borrower_books'] as List?) ?? [];
      for (final r in fallbackRows) {
        if (r is Map) {
          effectiveRows.add(Map<String, dynamic>.from(r));
        }
      }
    }

    // Dynamic column definitions based on cardData['components']
    final rawComps = cardData['components'] as List?;
    final List<String> compsList = [];
    if (rawComps != null && rawComps.isNotEmpty) {
      for (final c in rawComps) {
        if (c is String) {
          compsList.add(c);
        } else if (c is Map && c['name'] != null) {
          compsList.add(c['name'].toString());
        }
      }
    } else {
      compsList.addAll([
        "Name of Book",
        "Book Barcode / Copy ID",
        "Date of Issue",
        "Due Date",
        "Date of Return",
        "Signature Image",
      ]);
    }

    final hasBookTitle = compsList.any((c) => c.toLowerCase().contains('name') || c.toLowerCase().contains('book'));
    final List<_CardColDef> tableCols = [
      const _CardColDef(key: 'serial_no', header: "Serial\nNo.", width: FixedColumnWidth(40), isCenter: true),
    ];

    if (hasBookTitle) {
      tableCols.add(const _CardColDef(key: 'book_title', header: "Name of Books", width: FlexColumnWidth(3.0), isBold: true));
    }

    if (compsList.any((c) => c.toLowerCase().contains('barcode') || c.toLowerCase().contains('copy'))) {
      tableCols.add(_CardColDef(key: 'book_copy_no', header: "No. of\nthe Book", width: hasBookTitle ? const FixedColumnWidth(75) : const FlexColumnWidth(2.0), isCenter: true));
    }
    if (compsList.any((c) => c.toLowerCase().contains('issue'))) {
      tableCols.add(const _CardColDef(key: 'issued_date', header: "Date of\nIssue", width: FixedColumnWidth(75), isCenter: true));
    }
    if (compsList.any((c) => c.toLowerCase().contains('due'))) {
      tableCols.add(const _CardColDef(key: 'due_date', header: "Due\nDate", width: FixedColumnWidth(75), isCenter: true));
    }
    if (compsList.any((c) => c.toLowerCase().contains('return'))) {
      tableCols.add(const _CardColDef(key: 'return_date', header: "Date of\nReturn", width: FixedColumnWidth(75), isCenter: true));
    }

    // Custom components support
    final standardNames = [
      "name of book",
      "date of issue",
      "date of return",
      "due date",
      "signature image",
      "signature of librarian",
      "book barcode / copy id",
      "librarian remarks",
    ];
    for (final comp in compsList) {
      final lower = comp.toLowerCase();
      if (!standardNames.any((s) => lower == s)) {
        final k = comp.toLowerCase().replaceAll(' ', '_');
        tableCols.add(_CardColDef(key: k, header: comp, width: const FixedColumnWidth(75), isCenter: true));
      }
    }

    if (compsList.any((c) => c.toLowerCase().contains('signature'))) {
      tableCols.add(const _CardColDef(key: 'signature', header: "Signature of\nLibrarian", width: FixedColumnWidth(95), isSignature: true));
    }

    final Map<int, TableColumnWidth> colWidthsMap = {};
    for (int ci = 0; ci < tableCols.length; ci++) {
      colWidthsMap[ci] = tableCols[ci].width;
    }

    const cardBg = Color(0xFFF7CA18); // Authentic Indian Library Card Yellow
    const inkColor = Color(0xFF4A1504); // Deep Indian Maroon/Brown Ink
    const gridColor = Color(0xFF6B2208); // Grid line dark maroon

    return Center(
      child: Container(
        width: 680,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: gridColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Badge / Card No & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "CARD NO: $cardNumber",
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: inkColor,
                    letterSpacing: 1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "DIGITALLY VERIFIED",
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // College Header & Card Header
            const Center(
              child: Text(
                "GOVERNMENT ENGINEERING COLLEGE CHAMARAJANAGARA",
                style: TextStyle(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: inkColor,
                ),
              ),
            ),
            const SizedBox(height: 3),
            const Center(
              child: Text(
                "LIBRARY ISSUE CARD",
                style: TextStyle(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 1.5,
                  color: inkColor,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Main Borrower Profile Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sri/Sm. Name
                      _buildDottedRow("Sri/Sm.", borrowerName, inkColor),
                      const SizedBox(height: 6),
                      if (isFaculty) ...[
                        Row(
                          children: [
                            const Text("Department: ", style: TextStyle(color: inkColor, fontSize: 13, fontWeight: FontWeight.bold)),
                            Expanded(child: _buildDottedField(deptName, inkColor)),
                            const SizedBox(width: 8),
                            const Text("Faculty ID: ", style: TextStyle(color: inkColor, fontSize: 13, fontWeight: FontWeight.bold)),
                            SizedBox(width: 120, child: _buildDottedField(usn, inkColor)),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            const Text("of Class ", style: TextStyle(color: inkColor, fontSize: 13, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: _buildDottedField(deptName, inkColor),
                            ),
                            const SizedBox(width: 8),
                            const Text("Sec. ", style: TextStyle(color: inkColor, fontSize: 13, fontWeight: FontWeight.bold)),
                            SizedBox(width: 40, child: _buildDottedField(section, inkColor)),
                            const SizedBox(width: 8),
                            const Text("Roll No. / USN: ", style: TextStyle(color: inkColor, fontSize: 13, fontWeight: FontWeight.bold)),
                            SizedBox(width: 120, child: _buildDottedField(usn, inkColor)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      // is allowed to borrow books
                      Text(
                        "is allowed to borrow books from the College Library for the academic year $academicYear",
                        style: const TextStyle(color: inkColor, fontSize: 12.5, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      // Date & Authority Stamp
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Date: $issuedAt", style: const TextStyle(color: inkColor, fontSize: 12, fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  border: Border.all(color: (isApproved || isFaculty) ? const Color(0xFF059669) : Colors.orange.shade800, width: 1.2),
                                  borderRadius: BorderRadius.circular(4),
                                  color: (isApproved || isFaculty) ? Colors.green.shade50 : Colors.amber.shade50,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon((isApproved || isFaculty) ? Icons.verified_rounded : Icons.pending_actions_rounded, size: 12, color: (isApproved || isFaculty) ? const Color(0xFF059669) : Colors.orange.shade800),
                                    const SizedBox(width: 4),
                                    Text(
                                      isFaculty
                                          ? "Faculty Card (Direct Issuance)"
                                          : (isApproved ? "HOD Approved: $hodName" : "HOD Status: Pending Approval"),
                                      style: TextStyle(color: (isApproved || isFaculty) ? const Color(0xFF059669) : Colors.orange.shade900, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                "Headmaster / Principal",
                                style: TextStyle(color: inkColor, fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (photoUrl != null && photoUrl.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Container(
                    width: 70,
                    height: 85,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: gridColor, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image.network(_resolveUrl(photoUrl), fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => const Icon(Icons.person, color: inkColor)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // Circulation Table matching Image 4
            Table(
              border: TableBorder.all(color: gridColor, width: 1.2),
              columnWidths: colWidthsMap,
              children: [
                // Table Header
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFE8BD14)),
                  children: tableCols.map((c) => _buildHeaderCell(c.header, inkColor)).toList(),
                ),
                // Data Rows (up to 8 rows, filled with actual loans or blank lines)
                ...List.generate(8, (i) {
                  final row = i < effectiveRows.length ? effectiveRows[i] : null;
                  return TableRow(
                    children: tableCols.map((col) {
                      if (col.isSignature) {
                        return _buildSignatureCell(row, inkColor, signatureUrl);
                      }
                      String val = '';
                      if (row != null) {
                        if (col.key == 'serial_no') {
                          val = "${row['serial_no'] ?? (i + 1)}";
                        } else if (col.key == 'book_title') {
                          val = (row['book_title'] ?? row['title'] ?? row['name'] ?? row['book'] ?? '').toString();
                        } else if (col.key == 'book_copy_no') {
                          val = (row['book_copy_no'] ?? row['copy_barcode'] ?? row['barcode'] ?? row['copy_number'] ?? row['accession_no'] ?? '').toString();
                        } else if (col.key == 'issued_date') {
                          val = (row['issued_date'] ?? row['issued_at'] ?? row['issue_date'] ?? '').toString();
                        } else if (col.key == 'due_date') {
                          val = (row['due_date'] ?? row['return_date'] ?? '').toString();
                        } else if (col.key == 'return_date') {
                          val = (row['return_date'] ?? row['due_date'] ?? row['returned_at'] ?? '').toString();
                        } else {
                          val = (row[col.key] ?? row[col.header] ?? row[col.header.replaceAll('\n', ' ')] ?? '').toString();
                        }
                      } else if (col.key == 'serial_no') {
                        val = "${i + 1}";
                      }
                      return _buildDataCell(val, inkColor, isCenter: col.isCenter, isBold: col.isBold);
                    }).toList(),
                  );
                }),
              ],
            ),
            const SizedBox(height: 14),

            // Card Footer: Security, Librarian Signature & HOD Approval Signature
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Validity & Policy
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Valid Until: $validUntil", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: inkColor)),
                    const SizedBox(height: 2),
                    Text("Policy: ₹0.00 Free Borrowing • Zero Late Fine", style: TextStyle(fontSize: 9.5, color: inkColor.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                    if (shortSig.isNotEmpty)
                      Text("Digital Seal: SHA256:$shortSig...", style: const TextStyle(fontSize: 9, fontFamily: 'Courier', color: inkColor)),
                  ],
                ),

                // Center/Right: Librarian Signature
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (signatureUrl != null && signatureUrl.isNotEmpty)
                      Image.network(
                        _resolveUrl(signatureUrl),
                        height: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Text("✍ Authorized Librarian", style: TextStyle(fontFamily: 'serif', fontStyle: FontStyle.italic, fontSize: 13, color: inkColor, fontWeight: FontWeight.bold)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF059669), width: 1.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("DIGITAL STAMP", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                      ),
                    const SizedBox(height: 4),
                    const Text("Librarian's Signature", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: inkColor)),
                  ],
                ),

                // Right: Head of Department (HOD) Approval Signature (or Direct Issuance for Faculty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isFaculty) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.verified_rounded, size: 14, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text("Direct Issuance (Exempt)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: inkColor)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "No HOD Approval Required",
                        style: TextStyle(fontSize: 8.5, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text("Faculty Library Card", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: inkColor)),
                    ] else if (isApproved && hodSignatureUrl != null && hodSignatureUrl.isNotEmpty) ...[
                      Image.network(
                        _resolveUrl(hodSignatureUrl),
                        height: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF059669)),
                            const SizedBox(width: 4),
                            Text("Approved: $hodName", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: inkColor)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hodVerifiedAt.isNotEmpty ? "Verified: $hodVerifiedAt" : "Approved by HOD",
                        style: const TextStyle(fontSize: 8.5, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text("Head of Department (HOD)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: inkColor)),
                    ] else if (isApproved) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF059669)),
                          const SizedBox(width: 4),
                          Text("Approved: $hodName", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: inkColor)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hodVerifiedAt.isNotEmpty ? "Verified: $hodVerifiedAt" : "Approved by HOD",
                        style: const TextStyle(fontSize: 8.5, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text("Head of Department (HOD)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: inkColor)),
                    ] else ...[
                      Container(
                        width: 140,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: inkColor, width: 1, style: BorderStyle.solid)),
                        ),
                        child: Center(
                          child: Text(
                            cardStatus == 'REJECTED' ? "[Rejected by HOD]" : "[Awaiting HOD Approval]",
                            style: TextStyle(
                              fontSize: 9,
                              fontStyle: FontStyle.italic,
                              color: cardStatus == 'REJECTED' ? Colors.red.shade900 : inkColor.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text("Head of Department (HOD)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: inkColor)),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDottedRow(String label, String value, Color color) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Expanded(child: _buildDottedField(value, color)),
      ],
    );
  }

  Widget _buildDottedField(String text, Color color) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF6B2208), width: 1.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          fontFamily: 'serif',
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildHeaderCell(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: color,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, Color color, {bool isCenter = false, bool isBold = false}) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: isCenter ? Alignment.center : Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSignatureCell(Map<String, dynamic>? row, Color color, String? signatureUrl) {
    if (row == null) {
      return const SizedBox(height: 24);
    }
    if (signatureUrl != null && signatureUrl.isNotEmpty) {
      return Container(
        height: 24,
        alignment: Alignment.center,
        child: Image.network(
          _resolveUrl(signatureUrl),
          height: 18,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_rounded, size: 11, color: Colors.blue.shade900),
              const SizedBox(width: 3),
              Text(
                "Signed",
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      height: 24,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_rounded, size: 11, color: Colors.blue.shade900),
          const SizedBox(width: 3),
          Text(
            "Signed",
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
          ),
        ],
      ),
    );
  }

  static String _resolveUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final clean = url.startsWith('/') ? url : '/$url';
    return 'http://127.0.0.1:8000$clean';
  }
}

class _CardColDef {
  final String key;
  final String header;
  final TableColumnWidth width;
  final bool isCenter;
  final bool isBold;
  final bool isSignature;

  const _CardColDef({
    required this.key,
    required this.header,
    required this.width,
    this.isCenter = false,
    this.isBold = false,
    this.isSignature = false,
  });
}

