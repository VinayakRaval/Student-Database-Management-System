import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';

class StudentIAMarksScreen extends StatefulWidget {
  const StudentIAMarksScreen({super.key});

  @override
  State<StudentIAMarksScreen> createState() => _StudentIAMarksScreenState();
}

class _StudentIAMarksScreenState extends State<StudentIAMarksScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedSemester = 'All Semesters';
  String _selectedSubjectFilter = 'All Subjects';
  String? _selectedSubjectCode;

  List<_SubjectIAModel> _subjects = [];
  Map<String, dynamic>? _studentInfo;

  @override
  void initState() {
    super.initState();
    _fetchStudentIAMarks();
  }

  Future<void> _fetchStudentIAMarks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/ia/student/portal-summary/');
      final data = res.data;

      final List rawSubjects = (data is Map && data['subjects'] is List) ? data['subjects'] : [];
      final studentMap = (data is Map && data['student'] is Map)
          ? Map<String, dynamic>.from(data['student'])
          : null;

      final parsedSubjects = <_SubjectIAModel>[];
      for (final sub in rawSubjects) {
        final code = sub['code']?.toString() ?? '';
        final name = sub['name']?.toString() ?? '';
        final sem = sub['semester']?.toString() ?? 'Semester';
        final finalIa = (sub['final_ia_marks'] as num?)?.toDouble() ?? 0.0;
        final maxM = (sub['max_marks'] as num?)?.toDouble() ?? 25.0;
        final avgScore = (sub['average_score'] as num?)?.toDouble() ?? 0.0;
        final methodCode = sub['calculation_method']?.toString() ?? 'BEST_OF_N';

        String methodLabel;
        switch (methodCode) {
          case 'BEST_OF_N':
            methodLabel = "VTU Best 2 of 3";
            break;
          case 'AVERAGE_ALL':
            methodLabel = "Average of All";
            break;
          case 'WEIGHTED':
            methodLabel = "Weighted IA Scheme";
            break;
          case 'TOTAL':
            methodLabel = "Sum Total";
            break;
          default:
            methodLabel = methodCode;
        }

        final List rawTests = sub['tests'] is List ? sub['tests'] : [];
        final testItems = <_IATestItem>[];

        for (int i = 0; i < rawTests.length; i++) {
          final t = rawTests[i];
          final obt = (t['obtained_marks'] as num?)?.toDouble() ?? 0.0;
          final tMax = (t['max_marks'] as num?)?.toDouble() ?? 25.0;
          final pct = (t['percentage'] as num?)?.toDouble() ?? (tMax > 0 ? (obt / tMax * 100) : 0.0);
          final isAb = t['is_absent'] == true;
          final isEx = t['is_exempted'] == true;

          testItems.add(_IATestItem(
            id: i + 1,
            testName: t['test_name']?.toString() ?? 'Assessment ${i + 1}',
            type: t['type']?.toString() ?? 'Test1',
            componentType: t['component_type']?.toString() ?? 'THEORY',
            dateConducted: t['date_conducted']?.toString() ?? '-',
            maxMarks: tMax,
            obtainedMarks: obt,
            percentage: pct,
            status: t['status']?.toString() ??
                (isEx ? 'Exempted' : (isAb ? 'Absent' : (pct >= 40.0 ? 'Satisfactory' : 'Needs Improvement'))),
            remarks: t['remarks']?.toString() ?? '-',
            isAbsent: isAb,
            isExempted: isEx,
          ));
        }

        parsedSubjects.add(_SubjectIAModel(
          code: code,
          name: name,
          semester: sem,
          finalIAMarks: finalIa,
          maxMarks: maxM,
          averageScore: avgScore,
          calculationMethod: methodLabel,
          tests: testItems,
        ));
      }

      if (mounted) {
        setState(() {
          _studentInfo = studentMap;
          _subjects = parsedSubjects;
          if (parsedSubjects.isNotEmpty) {
            _selectedSubjectCode = parsedSubjects.first.code;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching IA portal marks: $e");
      if (mounted) {
        setState(() {
          _subjects = [];
          _isLoading = false;
          _errorMessage = "Could not connect to IA portal.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF13246E)),
        ),
      );
    }

    if (_subjects.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.assignment_outlined, size: 52, color: Color(0xFF1D4ED8)),
                ),
                const SizedBox(height: 20),
                const Text(
                  "No Published IA Marks",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ??
                      "IA marks are not yet published for this semester.\nOfficial marks will appear here once verified and approved by the department.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F2577),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: _fetchStudentIAMarks,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text("Refresh Status"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filteredSubjects = _subjects.where((s) {
      if (_selectedSemester != 'All Semesters' && s.semester != _selectedSemester) {
        return false;
      }
      if (_selectedSubjectFilter != 'All Subjects' && s.name != _selectedSubjectFilter) {
        return false;
      }
      return true;
    }).toList();

    final activeSubject = _subjects.firstWhere(
      (s) => s.code == _selectedSubjectCode,
      orElse: () => filteredSubjects.isNotEmpty ? filteredSubjects.first : _subjects.first,
    );

    final distinctSemesters = {'All Semesters', ..._subjects.map((s) => s.semester)}.toList();
    final distinctSubjectNames = {'All Subjects', ..._subjects.map((s) => s.name)}.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER (Title & Subtitle) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Internal Assessment (IA) Marks",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _studentInfo != null
                          ? "Official Published Results • ${_studentInfo!['name']} (${_studentInfo!['usn']})"
                          : "Official Published Student Results Portal",
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _fetchStudentIAMarks,
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F2577)),
                  tooltip: "Refresh Marks",
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- FILTER DROPDOWNS BAR ---
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildLabeledDropdown(
                  label: "Semester Filter",
                  icon: Icons.layers_rounded,
                  value: _selectedSemester,
                  items: distinctSemesters,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSemester = val);
                  },
                ),
                _buildLabeledDropdown(
                  label: "Subject Filter",
                  icon: Icons.menu_book_rounded,
                  value: _selectedSubjectFilter,
                  items: distinctSubjectNames,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSubjectFilter = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- SUBJECTS SECTION TITLE ---
            const Text(
              "Enrolled Subjects",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Select a subject below to view verified test scores and calculation details.",
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),

            // --- SUBJECT CARDS ROW / GRID ---
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                int crossAxisCount = 4;
                if (width < 700) {
                  crossAxisCount = 1;
                } else if (width < 1050) {
                  crossAxisCount = 2;
                } else if (width < 1300) {
                  crossAxisCount = 3;
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredSubjects.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 168,
                  ),
                  itemBuilder: (context, idx) {
                    final sub = filteredSubjects[idx];
                    final isSelected = sub.code == activeSubject.code;
                    return _SubjectIACard(
                      subject: sub,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedSubjectCode = sub.code;
                        });
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 28),

            // --- DETAILED TEST TABLE CONTAINER ---
            _buildDetailedTestTableContainer(activeSubject),
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1E293B)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.3,
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: items.contains(value) ? value : items.first,
                  isDense: true,
                  icon: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                  ),
                  items: items.map((it) {
                    return DropdownMenuItem(
                      value: it,
                      child: Text(
                        it,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedTestTableContainer(_SubjectIAModel subject) {
    final visuals = _getSubjectVisuals(subject.code, subject.name);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: visuals.bgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(visuals.icon, color: visuals.iconColor, size: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${subject.code} - ${subject.name}",
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subject.semester,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Calculation Scheme & Final IA Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Final IA: ",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF047857),
                            ),
                          ),
                          Text(
                            "${subject.finalIAMarks.toStringAsFixed(1)} / ${subject.maxMarks.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          subject.calculationMethod,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Table Content
          if (subject.tests.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  "No assessments have been published yet for ${subject.code} ${subject.name}.",
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 900),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  headingTextStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                  dataTextStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                  ),
                  columns: const [
                    DataColumn(label: Text("#")),
                    DataColumn(label: Text("Assessment Name")),
                    DataColumn(label: Text("Type")),
                    DataColumn(label: Text("Date Conducted")),
                    DataColumn(label: Text("Max Marks")),
                    DataColumn(label: Text("Obtained Marks")),
                    DataColumn(label: Text("Percentage")),
                    DataColumn(label: Text("Status")),
                    DataColumn(label: Text("Remarks")),
                  ],
                  rows: subject.tests.map((t) {
                    final isSat = t.status.toLowerCase().contains("satisfactory");
                    final isAb = t.isAbsent;
                    final isEx = t.isExempted;

                    Color badgeBg = isSat
                        ? const Color(0xFFECFDF5)
                        : (isEx
                            ? const Color(0xFFF5F3FF)
                            : (isAb ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB)));
                    Color badgeColor = isSat
                        ? const Color(0xFF059669)
                        : (isEx
                            ? const Color(0xFF7C3AED)
                            : (isAb ? const Color(0xFFDC2626) : const Color(0xFFD97706)));

                    return DataRow(
                      cells: [
                        DataCell(Text(t.id.toString())),
                        DataCell(Text(t.testName, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(t.type, style: const TextStyle(color: Color(0xFF64748B))),
                              if (t.componentType == 'LAB') ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text("LAB",
                                      style: TextStyle(
                                          fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                                ),
                              ],
                            ],
                          ),
                        ),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 6),
                            Text(t.dateConducted),
                          ],
                        )),
                        DataCell(Text(t.maxMarks.toStringAsFixed(0))),
                        DataCell(Text(
                          isAb ? "AB" : (isEx ? "EX" : t.obtainedMarks.toStringAsFixed(1)),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isAb
                                ? const Color(0xFFDC2626)
                                : (isEx ? const Color(0xFF7C3AED) : const Color(0xFF2563EB)),
                          ),
                        )),
                        DataCell(Text(isAb || isEx ? "-" : "${t.percentage.toStringAsFixed(1)}%")),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              t.status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(t.remarks, style: const TextStyle(color: Color(0xFF94A3B8)))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  static _SubjectVisuals _getSubjectVisuals(String code, String name) {
    final lower = "$code $name".toLowerCase();
    if (lower.contains("data structure") || lower.contains("algorithm")) {
      return _SubjectVisuals(
        icon: Icons.account_tree_rounded,
        bgColor: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
      );
    } else if (lower.contains("network") || lower.contains("web")) {
      return _SubjectVisuals(
        icon: Icons.hub_rounded,
        bgColor: const Color(0xFFECFDF5),
        iconColor: const Color(0xFF059669),
      );
    } else if (lower.contains("operating") || lower.contains("system")) {
      return _SubjectVisuals(
        icon: Icons.developer_board_rounded,
        bgColor: const Color(0xFFFFF7ED),
        iconColor: const Color(0xFFEA580C),
      );
    } else if (lower.contains("database") || lower.contains("sql")) {
      return _SubjectVisuals(
        icon: Icons.storage_rounded,
        bgColor: const Color(0xFFF0FDF4),
        iconColor: const Color(0xFF16A34A),
      );
    }
    return _SubjectVisuals(
      icon: Icons.menu_book_rounded,
      bgColor: const Color(0xFFF1F5F9),
      iconColor: const Color(0xFF334155),
    );
  }
}

class _SubjectIACard extends StatelessWidget {
  final _SubjectIAModel subject;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubjectIACard({
    required this.subject,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = _StudentIAMarksScreenState._getSubjectVisuals(subject.code, subject.name);
    final isGood = subject.averageScore >= 60.0;
    final color = isGood ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F7FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.04 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top: Icon + Code + Name + Sem
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: visuals.bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(visuals.icon, color: visuals.iconColor, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.code,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        subject.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subject.semester,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Middle: Final IA + Calculation Scheme Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Final IA",
                      style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                    Text(
                      "${subject.finalIAMarks.toStringAsFixed(1)} / ${subject.maxMarks.toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    subject.calculationMethod,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),

            // Bottom: Test count + Chevron
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      "${subject.tests.length} ${subject.tests.length == 1 ? 'Test' : 'Tests'} Published",
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
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

class _SubjectVisuals {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  _SubjectVisuals({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });
}

class _SubjectIAModel {
  final String code;
  final String name;
  final String semester;
  final double finalIAMarks;
  final double maxMarks;
  final double averageScore;
  final String calculationMethod;
  final List<_IATestItem> tests;

  _SubjectIAModel({
    required this.code,
    required this.name,
    required this.semester,
    required this.finalIAMarks,
    required this.maxMarks,
    required this.averageScore,
    required this.calculationMethod,
    required this.tests,
  });
}

class _IATestItem {
  final int id;
  final String testName;
  final String type;
  final String componentType;
  final String dateConducted;
  final double maxMarks;
  final double obtainedMarks;
  final double percentage;
  final String status;
  final String remarks;
  final bool isAbsent;
  final bool isExempted;

  _IATestItem({
    required this.id,
    required this.testName,
    required this.type,
    required this.componentType,
    required this.dateConducted,
    required this.maxMarks,
    required this.obtainedMarks,
    required this.percentage,
    required this.status,
    required this.remarks,
    required this.isAbsent,
    required this.isExempted,
  });
}
