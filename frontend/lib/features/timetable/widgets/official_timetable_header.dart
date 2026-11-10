import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/timetable_model.dart';

class OfficialTimetableHeader extends StatelessWidget {
  final String? institutionName;
  final String departmentName;
  final int? semesterNo;
  final String academicYear;
  final String? classTeacherName;
  final DateTime? effectiveDate;
  final ValueChanged<DateTime>? onEffectiveDateChanged;
  final bool isEditable;
  final bool isReadOnly;
  final bool isPrintMode;

  const OfficialTimetableHeader({
    super.key,
    this.institutionName,
    required this.departmentName,
    this.semesterNo = 1,
    required this.academicYear,
    this.classTeacherName,
    this.effectiveDate,
    this.onEffectiveDateChanged,
    this.isEditable = false,
    this.isReadOnly = false,
    this.isPrintMode = false,
  });

  String _formatWefDate(DateTime? dt) {
    if (dt == null) {
      return isReadOnly ? "Not configured" : "Not configured (Tap to set)";
    }
    return DateFormat("dd.MM.yyyy").format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final college = (institutionName != null && institutionName!.trim().isNotEmpty)
        ? institutionName!
        : CollegeConfig.institutionName;
    final sem = semesterNo ?? 1;
    final title = TimeTable.buildTitle(sem, academicYear);
    final bool canEditDate = !isReadOnly && (isEditable || onEffectiveDateChanged != null);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isPrintMode ? 0 : 8),
        border: Border.all(
          color: const Color(0xFF13246E),
          width: isPrintMode ? 1.0 : 1.5,
        ),
        boxShadow: isPrintMode
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF13246E).withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Professional Header Banner with Navy Background
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF13246E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // 2. Body Details (Institution, Program/Branch, and W.E.F)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isPrintMode ? 12 : 16,
              vertical: isPrintMode ? 10 : 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Column: Institution & Branch Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance, size: 16, color: Color(0xFF13246E)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                                children: [
                                  const TextSpan(
                                    text: "Name of Institution: ",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text: college,
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.school, size: 16, color: Color(0xFF13246E)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                                children: [
                                  const TextSpan(
                                    text: "Name of Program/Branch: ",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text: departmentName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF13246E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_pin_rounded, size: 16, color: Color(0xFF13246E)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                                children: [
                                  const TextSpan(
                                    text: "Class Teacher: ",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text: (classTeacherName != null && classTeacherName!.trim().isNotEmpty)
                                        ? classTeacherName!
                                        : "Not Assigned",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: (classTeacherName != null && classTeacherName!.trim().isNotEmpty)
                                          ? const Color(0xFF0F2577)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Right Column: W.E.F Date Pill
                InkWell(
                  onTap: canEditDate
                      ? () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: effectiveDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFF13246E),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null && onEffectiveDateChanged != null) {
                            onEffectiveDateChanged!(picked);
                          }
                        }
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFC7D2FE),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF13246E)),
                        const SizedBox(width: 6),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12, color: Color(0xFF13246E)),
                            children: [
                              const TextSpan(
                                text: "W.E.F: ",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: _formatWefDate(effectiveDate),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: effectiveDate == null && canEditDate
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF13246E),
                                  decoration: effectiveDate == null && canEditDate
                                      ? TextDecoration.underline
                                      : TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canEditDate) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 14, color: Color(0xFF13246E)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OfficialSubjectSummaryTable extends StatelessWidget {
  final List<Map<String, dynamic>> subjectDetails;
  final Map<String, dynamic>? teachingHoursSummary;
  final bool isPrintMode;

  const OfficialSubjectSummaryTable({
    super.key,
    required this.subjectDetails,
    this.teachingHoursSummary,
    this.isPrintMode = false,
  });

  Widget _vDivider() {
    return Container(width: 1, color: isPrintMode ? Colors.black87 : const Color(0xFFCBD5E1));
  }

  Widget _hDivider() {
    return Divider(height: 1, thickness: 1, color: isPrintMode ? Colors.black87 : const Color(0xFFCBD5E1));
  }

  Widget _cell(
    String text, {
    TextAlign align = TextAlign.left,
    bool isBold = false,
    bool isHeader = false,
    bool isSubHeader = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isHeader || isSubHeader ? 4 : 6,
        vertical: isHeader ? 8 : (isSubHeader ? 6 : 7),
      ),
      alignment: align == TextAlign.center
          ? Alignment.center
          : (align == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isHeader ? 11 : (isSubHeader ? 10 : 11),
          fontWeight: isHeader || isSubHeader || isBold ? FontWeight.bold : FontWeight.normal,
          color: Colors.black87,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (subjectDetails.isEmpty) {
      return const SizedBox.shrink();
    }

    int calcTheory = 0;
    int calcTut = 0;
    int calcPrac = 0;
    int calcTotal = 0;
    int calcCredits = 0;

    for (final item in subjectDetails) {
      final th = int.tryParse(item['theory_hours']?.toString() ?? '0') ?? 0;
      final tut = int.tryParse(item['tutorial_hours']?.toString() ?? '0') ?? 0;
      final prac = int.tryParse(item['practical_hours']?.toString() ?? '0') ?? 0;
      final tot = int.tryParse(item['total_hours']?.toString() ?? '0') ?? (th + tut + prac);
      final cr = int.tryParse(item['credits']?.toString() ?? '0') ?? 0;

      calcTheory += th;
      calcTut += tut;
      calcPrac += prac;
      calcTotal += tot;
      calcCredits += cr;
    }

    final totalTheory = teachingHoursSummary?['total_theory_hours'] ?? calcTheory;
    final totalTutorial = teachingHoursSummary?['total_tutorial_hours'] ?? calcTut;
    final totalPractical = teachingHoursSummary?['total_practical_hours'] ?? calcPrac;
    final totalHours = teachingHoursSummary?['total_teaching_hours'] ?? calcTotal;
    final totalCredits = teachingHoursSummary?['total_credits'] ?? calcCredits;

    final borderColor = isPrintMode ? Colors.black87 : const Color(0xFFCBD5E1);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isPrintMode ? 0 : 6),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Container(
            color: const Color(0xFFF1F5F9),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 7, child: _cell("Sl.\nNo.", align: TextAlign.center, isHeader: true)),
                  _vDivider(),
                  Expanded(flex: 14, child: _cell("Subject Code", align: TextAlign.center, isHeader: true)),
                  _vDivider(),
                  Expanded(flex: 28, child: _cell("Subject", isHeader: true)),
                  _vDivider(),
                  Expanded(
                    flex: 38,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          alignment: Alignment.center,
                          child: const Text(
                            "Teaching Hours / Week",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        _hDivider(),
                        IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(flex: 10, child: _cell("Theory\nLectures", align: TextAlign.center, isSubHeader: true)),
                              _vDivider(),
                              Expanded(flex: 8, child: _cell("Tutorial", align: TextAlign.center, isSubHeader: true)),
                              _vDivider(),
                              Expanded(flex: 10, child: _cell("Practical", align: TextAlign.center, isSubHeader: true)),
                              _vDivider(),
                              Expanded(flex: 10, child: _cell("Total", align: TextAlign.center, isSubHeader: true)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _vDivider(),
                  Expanded(flex: 8, child: _cell("Credits", align: TextAlign.center, isHeader: true)),
                  _vDivider(),
                  Expanded(flex: 24, child: _cell("Faculty Name", isHeader: true)),
                ],
              ),
            ),
          ),
          _hDivider(),

          // Data Rows
          ...subjectDetails.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;

            String pracText = "0";
            final pDisp = item['practical_display']?.toString();
            final pHours = item['practical_hours'];
            if (pDisp != null && pDisp.isNotEmpty && pDisp != '0' && pDisp != 'null') {
              pracText = pDisp;
            } else if (pHours != null && pHours != 0) {
              pracText = pHours.toString();
            }

            return Column(
              children: [
                if (idx > 0) _hDivider(),
                Container(
                  color: idx % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 7, child: _cell("${item['sl_no'] ?? (idx + 1)}", align: TextAlign.center)),
                        _vDivider(),
                        Expanded(flex: 14, child: _cell("${item['subject_code'] ?? ''}", isBold: true, align: TextAlign.center)),
                        _vDivider(),
                        Expanded(flex: 28, child: _cell("${item['subject_name'] ?? ''}")),
                        _vDivider(),
                        Expanded(flex: 10, child: _cell("${item['theory_hours'] ?? 0}", align: TextAlign.center)),
                        _vDivider(),
                        Expanded(flex: 8, child: _cell("${item['tutorial_hours'] ?? 0}", align: TextAlign.center)),
                        _vDivider(),
                        Expanded(flex: 10, child: _cell(pracText, align: TextAlign.center)),
                        _vDivider(),
                        Expanded(flex: 10, child: _cell("${item['total_hours'] ?? 0}", align: TextAlign.center, isBold: true)),
                        _vDivider(),
                        Expanded(flex: 8, child: _cell("${item['credits'] ?? 0}", align: TextAlign.center, isBold: true)),
                        _vDivider(),
                        Expanded(flex: 24, child: _cell("${item['faculty_name'] ?? 'Not Assigned'}")),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),

          // Total Row
          _hDivider(),
          Container(
            color: const Color(0xFFF1F5F9),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 49, // 7 + 14 + 28
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      alignment: Alignment.centerRight,
                      child: const Text(
                        "Total",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black),
                      ),
                    ),
                  ),
                  _vDivider(),
                  Expanded(flex: 10, child: _cell("$totalTheory", align: TextAlign.center, isBold: true)),
                  _vDivider(),
                  Expanded(flex: 8, child: _cell("$totalTutorial", align: TextAlign.center, isBold: true)),
                  _vDivider(),
                  Expanded(flex: 10, child: _cell("$totalPractical", align: TextAlign.center, isBold: true)),
                  _vDivider(),
                  Expanded(flex: 10, child: _cell("$totalHours", align: TextAlign.center, isBold: true)),
                  _vDivider(),
                  Expanded(flex: 8, child: _cell("$totalCredits", align: TextAlign.center, isBold: true)),
                  _vDivider(),
                  Expanded(flex: 24, child: _cell("—", align: TextAlign.center)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OfficialSignatureArea extends StatelessWidget {
  final bool isPrintMode;
  const OfficialSignatureArea({super.key, this.isPrintMode = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isPrintMode ? 24 : 32,
        vertical: isPrintMode ? 24 : 32,
      ),
      child: Column(
        children: [
          const SizedBox(height: 36),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildSignColumn("Timetable Coordinator"),
              _buildSignColumn("HOD"),
              _buildSignColumn("Principal"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignColumn(String title) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 140,
          height: 1,
          color: Colors.black54,
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
