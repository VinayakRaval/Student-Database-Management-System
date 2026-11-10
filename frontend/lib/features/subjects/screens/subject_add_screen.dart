import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as p;
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/core/constants/api_constants.dart';
import '../models/subject_model.dart';
import '../providers/subject_provider.dart';
import 'package:frontend/core/utils/validation_utils.dart';

class SubjectAddScreen extends ConsumerStatefulWidget {
  const SubjectAddScreen({super.key});

  @override
  ConsumerState<SubjectAddScreen> createState() => _SubjectAddScreenState();
}

class _SubjectAddScreenState extends ConsumerState<SubjectAddScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _creditsController = TextEditingController(text: "4");
  final _theoryHoursController = TextEditingController(text: "3");
  final _tutorialHoursController = TextEditingController(text: "0");
  final _practicalHoursController = TextEditingController(text: "0");
  final _practicalSessionsController = TextEditingController(text: "0");
  final _practicalDurationController = TextEditingController(text: "0");
  final _totalTeachingHoursController = TextEditingController(text: "3");

  int? _selectedDepartment;
  int? _selectedSemester;
  int? _selectedAcademicYear;
  int? _selectedSchema;
  bool _isElective = false;

  // Subject Type Selection (Theory, Lab, Both, Project)
  String _selectedSubjectType = "THEORY";
  bool _hasTheory = true;
  bool _hasLab = false;
  bool _isAutoDetectedLab = false;
  bool _userManuallyToggledType = false;
  String? _subjectTypeError;

  // Elective Cross-Department Selection
  int? _selectedOfferingDepartment;
  int? _selectedOfferingSemester;
  int? _selectedOfferingSubjectId;
  List<Map<String, dynamic>> _offeringSemesters = [];
  bool _isLoadingOfferingSemesters = false;
  List<Map<String, dynamic>> _offeringSubjects = [];
  bool _isLoadingOfferingSubjects = false;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subjectProvider.notifier).loadDropdowns();
    });
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _nameController.dispose();
    _codeController.dispose();
    _creditsController.dispose();
    _theoryHoursController.dispose();
    _tutorialHoursController.dispose();
    _practicalHoursController.dispose();
    _practicalSessionsController.dispose();
    _practicalDurationController.dispose();
    _totalTeachingHoursController.dispose();
    super.dispose();
  }

  void _recalculateTeachingHours() {
    final th = int.tryParse(_theoryHoursController.text.trim()) ?? 0;
    final tut = int.tryParse(_tutorialHoursController.text.trim()) ?? 0;
    int prac = int.tryParse(_practicalHoursController.text.trim()) ?? 0;
    final sessions = int.tryParse(_practicalSessionsController.text.trim()) ?? 0;
    final dur = int.tryParse(_practicalDurationController.text.trim()) ?? 0;
    if (sessions > 0 && dur > 0 && (prac == 0 || prac == sessions * dur)) {
      prac = sessions * dur;
      _practicalHoursController.text = "$prac";
    }
    final total = (th < 0 ? 0 : th) + (tut < 0 ? 0 : tut) + (prac < 0 ? 0 : prac);
    setState(() {
      _totalTeachingHoursController.text = "$total";
    });
  }

  void _onCodeChanged() {
    final code = _codeController.text.trim();
    // Rule: If 4th character is 'L' (case-insensitive), auto-detect Lab
    final bool detectsLab = code.length >= 4 && code[3].toUpperCase() == 'L';

    setState(() {
      _isAutoDetectedLab = detectsLab;
      if (!_userManuallyToggledType) {
        if (detectsLab) {
          _selectedSubjectType = "LAB";
          _hasLab = true;
          _hasTheory = false;
        } else if (_selectedSubjectType != "PROJECT") {
          _selectedSubjectType = "THEORY";
          _hasTheory = true;
          _hasLab = false;
        }
      }
      _validateSubjectType();
    });
  }

  bool _validateSubjectType() {
    if (_selectedSubjectType == "PROJECT") {
      _subjectTypeError = null;
      return true;
    }
    if (!_hasTheory && !_hasLab) {
      _subjectTypeError = "Please select a valid subject type (Theory, Lab/Practical, Theory + Lab, or Project).";
      return false;
    }
    _subjectTypeError = null;
    return true;
  }

  Future<void> _onOfferingDepartmentChanged(int? deptId) async {
    setState(() {
      _selectedOfferingDepartment = deptId;
      _selectedOfferingSemester = null;
      _selectedOfferingSubjectId = null;
      _offeringSemesters = [];
      _offeringSubjects = [];
      _nameController.clear();
      _codeController.clear();
    });

    if (deptId == null) return;

    setState(() => _isLoadingOfferingSemesters = true);
    try {
      final subjects = await ref
          .read(subjectProvider.notifier)
          .fetchOfferingSubjects(deptId);

      // Extract distinct semesters that actually offer subjects in this department
      final Map<int, String> semMap = {};
      for (final s in subjects) {
        final sId = s['semester'] as int?;
        final sNo = s['semester_no']?.toString() ?? '$sId';
        if (sId != null) {
          semMap[sId] = "Semester $sNo";
        }
      }

      final list = semMap.entries.map((e) => {
        'id': e.key,
        'name': e.value,
        'sem_no': int.tryParse(e.value.replaceAll(RegExp(r'[^0-9]'), '')) ?? e.key,
      }).toList();

      list.sort((a, b) => (a['sem_no'] as int).compareTo(b['sem_no'] as int));

      if (mounted) {
        setState(() {
          _offeringSemesters = list;
          _isLoadingOfferingSemesters = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingOfferingSemesters = false);
      }
    }
  }

  Future<void> _onOfferingSemesterChanged(int? semId) async {
    setState(() {
      _selectedOfferingSemester = semId;
      _selectedOfferingSubjectId = null;
      _offeringSubjects = [];
      _nameController.clear();
      _codeController.clear();
    });

    if (semId == null || _selectedOfferingDepartment == null) return;

    setState(() => _isLoadingOfferingSubjects = true);
    try {
      final subjects = await ref
          .read(subjectProvider.notifier)
          .fetchOfferingSubjects(
            _selectedOfferingDepartment!,
            semester: semId,
          );

      if (mounted) {
        setState(() {
          _offeringSubjects = subjects;
          _isLoadingOfferingSubjects = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingOfferingSubjects = false);
      }
    }
  }

  void _onOfferingSubjectSelected(int? subjectId) {
    setState(() {
      _selectedOfferingSubjectId = subjectId;
      if (subjectId != null) {
        final sub = _offeringSubjects.firstWhere(
          (s) => s['id'] == subjectId,
          orElse: () => <String, dynamic>{},
        );
        if (sub.isNotEmpty) {
          _nameController.text =
              (sub['name'] ?? sub['subject_name'] ?? '').toString();
          _codeController.text =
              (sub['code'] ?? sub['subject_code'] ?? '').toString();
          if (sub['has_theory'] != null || sub['has_lab'] != null) {
            _hasTheory = sub['has_theory'] ?? true;
            _hasLab = sub['has_lab'] ?? false;
            _userManuallyToggledType = true;
          }
        }
      }
    });
  }

  void _submit() {
    final isTypeValid = _isElective ? true : _validateSubjectType();
    if (!_formKey.currentState!.validate() || !isTypeValid) {
      ValidationUtils.showValidationErrorSnackBar(context);
      return;
    }
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter Subject Name.'), backgroundColor: Colors.red),
        );
        return;
      }
      if (_codeController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter Subject Code.'), backgroundColor: Colors.red),
        );
        return;
      }
      if (_selectedDepartment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a Department.'), backgroundColor: Colors.red),
        );
        return;
      }
      if (_selectedSemester == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a Semester.'), backgroundColor: Colors.red),
        );
        return;
      }
      if (_selectedSchema == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a Schema.'), backgroundColor: Colors.red),
        );
        return;
      }
      if (_isElective && _selectedOfferingDepartment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select Offering Department for this elective subject.'), backgroundColor: Colors.red),
        );
        return;
      }
      if (_isElective && _selectedOfferingSemester == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select Offering Semester for this elective subject.'), backgroundColor: Colors.red),
        );
        return;
      }

      final String subjectType = _isElective ? "THEORY" : _selectedSubjectType;
      final bool isProject = subjectType == "PROJECT";
      final cr = int.tryParse(_creditsController.text.trim()) ?? 4;
      final th = (_isElective || isProject) ? 0 : (int.tryParse(_theoryHoursController.text.trim()) ?? 3);
      final tut = (_isElective || isProject) ? 0 : (int.tryParse(_tutorialHoursController.text.trim()) ?? 0);
      final prac = (_isElective || isProject) ? 0 : (int.tryParse(_practicalHoursController.text.trim()) ?? 0);
      final sessions = (_isElective || isProject) ? 0 : (int.tryParse(_practicalSessionsController.text.trim()) ?? 0);
      final dur = (_isElective || isProject) ? 0 : (int.tryParse(_practicalDurationController.text.trim()) ?? 0);
      final total = isProject
          ? (int.tryParse(_totalTeachingHoursController.text.trim()) ?? 0)
          : (_isElective ? th : (int.tryParse(_totalTeachingHoursController.text.trim()) ?? (th + tut + prac)));

      if (cr < 0 || th < 0 || tut < 0 || prac < 0 || sessions < 0 || dur < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teaching hours and credits cannot be negative.')),
        );
        return;
      }

      final subjectData = SubjectAddModel(
        subjectName: _nameController.text.trim(),
        subjectCode: _codeController.text.trim(),
        departmentId: _selectedDepartment!,
        semesterId: _selectedSemester!,
        academicYearId: _selectedAcademicYear,
        offeringDepartmentId: _isElective ? _selectedOfferingDepartment : null,
        schemaId: _selectedSchema!,
        isElective: _isElective,
        hasTheory: isProject ? false : _hasTheory,
        hasLab: isProject ? false : _hasLab,
        subjectType: subjectType,
        credits: cr,
        theoryHours: th,
        tutorialHours: tut,
        practicalHours: prac,
        practicalSessions: sessions,
        practicalDurationPerSession: dur,
        totalTeachingHours: total,
      );

      ref.read(subjectProvider.notifier).addSubject(subjectData);
  }

  // --- NEW: Add Schema Dialog ---
  void _showAddSchemaDialog() {
    if (_selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Department first.')),
      );
      return;
    }

    final schemaNameCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Schema"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter the name for the new syllabus pattern (e.g. '2025 Scheme')."),
            const SizedBox(height: 16),
            TextField(
              controller: schemaNameCtrl,
              decoration: const InputDecoration(
                labelText: "Schema Name",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E)),
            onPressed: () async {
              if (schemaNameCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              
              final success = await ref.read(subjectProvider.notifier)
                  .addSchema(schemaNameCtrl.text, _selectedDepartment!);
              
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Schema Added Successfully!"), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text("Add", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subjectProvider);

    final auth = p.Provider.of<AuthProvider>(context);
    final role = (auth.role ?? '').toUpperCase();
    final isHod = role == AppRoles.hod;
    final int? userDeptId = auth.userData?['department'] is int
        ? auth.userData!['department'] as int
        : int.tryParse(auth.userData?['department']?.toString() ?? '');
    final String? userDeptName = auth.userData?['department_name']?.toString();

    List<SubjectOption> availableDepts = state.departments;
    if (isHod && userDeptId != null) {
      final filtered = state.departments.where((d) => d.id == userDeptId).toList();
      if (filtered.isNotEmpty) {
        availableDepts = filtered;
      } else {
        availableDepts = [SubjectOption(id: userDeptId, name: userDeptName ?? "My Department")];
      }
    }

    ref.listen(subjectProvider, (previous, next) {
      if (next.errorMessage != null) {
        final err = next.errorMessage!;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  err.toLowerCase().contains("already exists") ? Icons.warning_amber_rounded : Icons.error_outline_rounded,
                  color: err.toLowerCase().contains("already exists") ? Colors.orange : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  err.toLowerCase().contains("already exists") ? "Subject Already Exists" : "Subject Creation Issue",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              err,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13246E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
      if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subject Added Successfully!'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    });

    // Auto-select department for HOD or first available
    if (isHod && userDeptId != null && _selectedDepartment != userDeptId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedDepartment = userDeptId;
          });
        }
      });
    } else if (_selectedDepartment == null && availableDepts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedDepartment == null) {
          setState(() {
            _selectedDepartment = availableDepts.first.id;
          });
        }
      });
    }

    // Auto-select semester if available and not selected
    if (_selectedSemester == null && state.semesters.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedSemester == null) {
          setState(() {
            _selectedSemester = state.semesters.first.id;
          });
        }
      });
    }

    // Auto-select schema if available and not selected
    if (_selectedSchema == null && state.schemas.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedSchema == null) {
          setState(() {
            _selectedSchema = state.schemas.first.id;
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Add New Subject", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0), 
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Subject Details",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 30),

                    _buildField(label: "Subject Name *", controller: _nameController, hint: "e.g. Cloud Computing / Data Structures"),
                    _buildField(label: "Subject Code *", controller: _codeController, hint: "e.g. 21CS71 / BCS301 / BCSL301"),

                    _buildDropdown(
                      label: "Department *",
                      value: _selectedDepartment,
                      items: availableDepts,
                      onChanged: isHod ? null : (val) => setState(() => _selectedDepartment = val),
                      isLoading: state.isLoading,
                    ),

                    _buildDropdown(
                      label: "Semester *",
                      value: _selectedSemester,
                      items: state.semesters,
                      onChanged: (val) {
                        setState(() => _selectedSemester = val);
                        if (_isElective && _selectedOfferingDepartment != null) {
                          if (_selectedOfferingSemester != null) { _onOfferingSemesterChanged(_selectedOfferingSemester); }
                        }
                      },
                      isLoading: state.isLoading,
                    ),

                    _buildDropdown(
                      label: "Academic Year (Offering Scope)",
                      value: _selectedAcademicYear,
                      items: state.academicYears,
                      onChanged: (val) => setState(() => _selectedAcademicYear = val),
                      isLoading: state.isLoading,
                    ),

                    _buildSchemaDropdownWithAdd(state),

                    _buildElectiveCheckbox(),

                    if (_isElective) ...[
                      _buildOfferingDepartmentDropdown(state.departments),
                      _buildOfferingSemesterDropdown(state.semesters),
                      if (_selectedOfferingDepartment != null && _selectedOfferingSemester != null)
                        _buildOfferingSubjectDropdown(),
                    ],

                    if (!_isElective) ...[
                      _buildSubjectTypeDropdown(),
                      _buildTeachingHoursSection(),
                    ],

                    const SizedBox(height: 10),

                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 150,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: state.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF13246E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: state.isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Add Subject", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSubjectTypeDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _subjectTypeError != null ? Colors.red.shade400 : const Color(0xFFCBD5E1),
            width: _subjectTypeError != null ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.category_rounded, size: 18, color: Color(0xFF13246E)),
                const SizedBox(width: 8),
                const Text(
                  "Subject Type *",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _selectedSubjectType == "PROJECT"
                        ? Colors.deepPurple.shade50
                        : const Color(0xFF13246E).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _selectedSubjectType == "PROJECT"
                        ? "Project"
                        : (_selectedSubjectType == "BOTH"
                            ? "Theory + Lab"
                            : (_selectedSubjectType == "LAB" ? "Lab/Practical" : "Theory")),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _selectedSubjectType == "PROJECT" ? Colors.deepPurple.shade700 : const Color(0xFF13246E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "Select subject classification: Theory, Lab/Practical, Theory + Lab, or Project (e.g. Major Project Phase II).",
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            if (_isAutoDetectedLab && _selectedSubjectType == "LAB") ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFF059669), size: 16),
                    SizedBox(width: 6),
                    Text(
                      "Lab auto-detected from subject code.",
                      style: TextStyle(color: Color(0xFF047857), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSubjectType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: "THEORY", child: Text("Theory", style: TextStyle(fontWeight: FontWeight.w500))),
                    DropdownMenuItem(value: "LAB", child: Text("Lab/Practical", style: TextStyle(fontWeight: FontWeight.w500))),
                    DropdownMenuItem(value: "BOTH", child: Text("Theory + Lab", style: TextStyle(fontWeight: FontWeight.w500))),
                    DropdownMenuItem(value: "PROJECT", child: Text("Project", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple))),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _selectedSubjectType = val;
                      _userManuallyToggledType = true;
                      if (val == "PROJECT") {
                        _hasTheory = false;
                        _hasLab = false;
                      } else if (val == "LAB") {
                        _hasTheory = false;
                        _hasLab = true;
                      } else if (val == "BOTH") {
                        _hasTheory = true;
                        _hasLab = true;
                      } else {
                        _hasTheory = true;
                        _hasLab = false;
                      }
                      _validateSubjectType();
                    });
                  },
                ),
              ),
            ),
            if (_subjectTypeError != null) ...[
              const SizedBox(height: 8),
              Text(
                _subjectTypeError!,
                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildElectiveCheckbox() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: CheckboxListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          title: const Text(
            "Elective Subject (Optional)",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
          ),
          subtitle: const Text(
            "Check if this subject is an elective or open-elective offering",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          value: _isElective,
          activeColor: const Color(0xFF13246E),
          onChanged: (val) {
            setState(() {
              _isElective = val ?? false;
              if (!_isElective) {
                _selectedOfferingDepartment = null;
                _selectedOfferingSemester = null;
                _selectedOfferingSubjectId = null;
                _offeringSemesters = [];
                _offeringSubjects = [];
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildOfferingDepartmentDropdown(List<SubjectOption> departments) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Offering Department *",
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<int>(
                value: _selectedOfferingDepartment,
                isExpanded: true,
                hint: const Text("Select Offering Department"),
                items: departments
                    .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                    .toList(),
                onChanged: _onOfferingDepartmentChanged,
                decoration: const InputDecoration(border: InputBorder.none),
                validator: (val) => _isElective ? ValidationUtils.mandatorySelect(val) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferingSemesterDropdown(List<SubjectOption> allSemesters) {
    final bool isEnabled = _selectedOfferingDepartment != null;
    final List<Map<String, dynamic>> itemsList = _offeringSemesters.isNotEmpty
        ? _offeringSemesters
        : allSemesters.map((s) => {'id': s.id, 'name': s.name}).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Offering Semester *",
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isEnabled ? Colors.white : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<int>(
                value: _selectedOfferingSemester,
                isExpanded: true,
                hint: Text(
                  !isEnabled
                      ? "Select Offering Department first"
                      : (_isLoadingOfferingSemesters
                          ? "Loading semesters..."
                          : (itemsList.isEmpty
                              ? "No semesters found with elective offerings"
                              : "Select Offering Semester")),
                  style: TextStyle(color: isEnabled ? Colors.grey.shade700 : Colors.grey.shade400),
                ),
                items: !isEnabled
                    ? null
                    : itemsList
                        .map((e) => DropdownMenuItem<int>(
                              value: e['id'] as int,
                              child: Text(e['name']?.toString() ?? ''),
                            ))
                        .toList(),
                onChanged: !isEnabled ? null : _onOfferingSemesterChanged,
                decoration: const InputDecoration(border: InputBorder.none),
                validator: (val) => _isElective ? ValidationUtils.mandatorySelect(val) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferingSubjectDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Department Subject",
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<int>(
                value: _selectedOfferingSubjectId,
                isExpanded: true,
                hint: Text(_isLoadingOfferingSubjects
                    ? "Loading subjects..."
                    : (_offeringSubjects.isEmpty
                        ? "No subjects found for this department & semester"
                        : "Select Subject")),
                items: _offeringSubjects.map((sub) {
                  final id = sub['id'] as int;
                  final name = (sub['name'] ?? sub['subject_name'] ?? '').toString();
                  final code = (sub['code'] ?? sub['subject_code'] ?? '').toString();
                  return DropdownMenuItem<int>(
                    value: id,
                    child: Text("$code - $name", overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: _onOfferingSubjectSelected,
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({required String label, required TextEditingController controller, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            validator: (val) => ValidationUtils.mandatory(val),
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
              errorStyle: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required int? value,
    required List<SubjectOption> items,
    required Function(int?)? onChanged,
    required bool isLoading,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: value,
            isExpanded: true,
            hint: Text(isLoading ? "Loading..." : "Select"),
            items: items.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
              errorStyle: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            validator: (val) => ValidationUtils.mandatorySelect(val),
          ),
        ],
      ),
    );
  }

  // Special Widget for Schema to include the Add Button
  Widget _buildSchemaDropdownWithAdd(SubjectState state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Schema *", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedSchema,
                  isExpanded: true,
                  hint: Text(state.isLoading ? "Loading..." : "Select"),
                  items: state.schemas.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                  onChanged: (val) => setState(() => _selectedSchema = val),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5)),
                    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  validator: (val) => ValidationUtils.mandatorySelect(val),
                ),
              ),
              const SizedBox(width: 10),
              // Add Button
              InkWell(
                onTap: _showAddSchemaDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF13246E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeachingHoursSection() {
    final bool isProject = _selectedSubjectType == "PROJECT";

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: Color(0xFF13246E), size: 20),
              const SizedBox(width: 8),
              Text(
                isProject ? "Academic Credits & Project Details" : "Teaching Hours & Academic Credits",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF13246E)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isProject
                ? "Enter the credits for this project subject (e.g. Major Project Phase II). Theory/practical contact hours are not required."
                : "Configure weekly lecture, tutorial, and practical contact hours. Total teaching hours are automatically calculated.",
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          if (isProject) ...[
            _buildNumericField(
              label: "Credits *",
              controller: _creditsController,
              hint: "e.g. 6 or 10",
              onChanged: (_) => setState(() {}),
            ),
          ] else ...[
            // Credits Field
            _buildNumericField(
              label: "Credits *",
              controller: _creditsController,
              hint: "e.g. 4",
              onChanged: (_) => setState(() {}),
            ),
            const Divider(height: 24),
            // Row 1: Theory Lectures per Week & Tutorials per Week
            Row(
              children: [
                Expanded(
                  child: _buildNumericField(
                    label: "Theory Lectures / Week *",
                    controller: _theoryHoursController,
                    hint: "e.g. 3",
                    onChanged: (_) => _recalculateTeachingHours(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumericField(
                    label: "Tutorials / Week *",
                    controller: _tutorialHoursController,
                    hint: "e.g. 0",
                    onChanged: (_) => _recalculateTeachingHours(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Practical Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildNumericField(
                    label: "Practical Hours / Week *",
                    controller: _practicalHoursController,
                    hint: "e.g. 6 or 0",
                    onChanged: (_) => _recalculateTeachingHours(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Practical Sessions x Duration", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _practicalSessionsController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: "Sess (e.g. 2)",
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) {
                                final s = int.tryParse(val.trim()) ?? 0;
                                final d = int.tryParse(_practicalDurationController.text.trim()) ?? 0;
                                if (s > 0 && d > 0) {
                                  _practicalHoursController.text = "${s * d}";
                                }
                                _recalculateTeachingHours();
                              },
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text("x", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _practicalDurationController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: "Hrs/sess (e.g. 3)",
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) {
                                final d = int.tryParse(val.trim()) ?? 0;
                                final s = int.tryParse(_practicalDurationController.text.trim()) ?? 0;
                                if (s > 0 && d > 0) {
                                  _practicalHoursController.text = "${s * d}";
                                }
                                _recalculateTeachingHours();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Total Teaching Hours (read-only calculation display)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total Teaching Hours / Week",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF)),
                      ),
                      Text(
                        "Formula: Theory + Tutorials + Practical",
                        style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13246E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${_totalTeachingHoursController.text} Hours / Week",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNumericField({
    required String label,
    required TextEditingController controller,
    String? hint,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          validator: (val) => ValidationUtils.mandatoryNumber(val),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF13246E), width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
            errorStyle: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

}
