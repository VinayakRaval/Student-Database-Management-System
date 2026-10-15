import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:provider/provider.dart' as p;

class SubjectSimple {
  final int id;
  final String name;
  final String code;
  final String semester;
  final String? department;

  SubjectSimple({
    required this.id,
    required this.name,
    required this.code,
    required this.semester,
    this.department,
  });

  factory SubjectSimple.fromJson(Map<String, dynamic> json) {
    return SubjectSimple(
      id: json['subject_id'] ?? json['id'] ?? 0,
      name: json['subject_name'] ?? json['name'] ?? 'Unknown Subject',
      code: json['subject_code'] ?? json['code'] ?? '',
      semester: (json['semester'] ?? json['semester_id'] ?? '').toString(),
      department: json['department_name']?.toString() ?? json['department']?.toString(),
    );
  }
}

class SubjectListScreen extends ConsumerStatefulWidget {
  const SubjectListScreen({super.key});

  @override
  ConsumerState<SubjectListScreen> createState() => _SubjectListScreenState();
}

class _SubjectListScreenState extends ConsumerState<SubjectListScreen> {
  List<SubjectSimple> _subjects = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSubjects();
    });
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = p.Provider.of<AuthProvider>(context, listen: false);
      final role = (auth.role ?? '').toUpperCase();
      final dio = ApiClient().dio;

      dynamic response;
      if (role == AppRoles.professor) {
        response = await dio.get('/subjects/professor/subjects/');
      } else {
        response = await dio.get('/subjects/getSubjects/');
      }

      List rawList = [];
      if (response.data is List) {
        rawList = response.data;
      } else if (response.data is Map && response.data['results'] is List) {
        rawList = response.data['results'];
      }

      final items = rawList.map((e) => SubjectSimple.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _subjects = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = (auth.role ?? '').toUpperCase();
    final isHodOrAdmin = role == AppRoles.hod || role == AppRoles.principal || role == AppRoles.system;

    return Scaffold(
      appBar: AppBar(
        title: Text(role == AppRoles.professor ? "My Assigned Subjects" : "Subjects"),
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
            onPressed: _loadSubjects,
          ),
          if (isHodOrAdmin) ...[
            IconButton(
              icon: const Icon(Icons.assignment_ind),
              tooltip: "Assign Faculty",
              onPressed: () => context.push('/subjects/assign').then((_) => _loadSubjects()),
            ),
          ],
        ],
      ),
      floatingActionButton: isHodOrAdmin
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text("Add Subject"),
              onPressed: () => context.push('/subjects/add').then((_) => _loadSubjects()),
            )
          : null,
      body: _buildBody(role),
    );
  }

  Widget _buildBody(String role) {
    final isHodOrAdmin = role == AppRoles.hod || role == AppRoles.principal || role == AppRoles.system;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text("Error loading subjects: $_errorMessage", textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
                onPressed: _loadSubjects,
              ),
            ],
          ),
        ),
      );
    }

    if (_subjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              role == AppRoles.professor
                  ? "No subjects assigned to you yet."
                  : "No subjects found.",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subjects.length,
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF13246E),
              foregroundColor: Colors.white,
              child: Text(
                subject.semester.isNotEmpty ? "S${subject.semester}" : "S",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            title: Text(
              subject.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                "Code: ${subject.code}${subject.department != null ? ' • Dept: ${subject.department}' : ''}",
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
            ),
            trailing: role == AppRoles.professor
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF13246E),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          context.push(
                            '/ia/create/${subject.id}',
                            extra: subject.name,
                          );
                        },
                        child: const Text("IA Marks"),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Color(0xFF13246E)),
                        onPressed: () => _showSubjectDetailsModal(context, subject),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isHodOrAdmin)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: "Delete Subject",
                          onPressed: () => _confirmDeleteSubject(subject),
                        ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Color(0xFF13246E)),
                        onPressed: () => _showSubjectDetailsModal(context, subject),
                      ),
                    ],
                  ),
            onTap: () => _showSubjectDetailsModal(context, subject),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteSubject(SubjectSimple subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text("Delete Subject", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Are you sure you want to delete '${subject.code} - ${subject.name}'?\n\nThis will permanently delete this subject and its faculty assignments.",
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final dio = ApiClient().dio;
        final response = await dio.delete('/subjects/delete/${subject.id}/');
        if (!mounted) return;
        final msg = (response.data is Map && (response.data as Map).containsKey('message'))
            ? response.data['message'].toString()
            : "Subject deleted successfully.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
        _loadSubjects();
      } on DioException catch (e) {
        if (!mounted) return;
        String err = "Failed to delete subject";
        if (e.response?.data != null) {
          if (e.response!.data is Map && (e.response!.data as Map).containsKey('error')) {
            err = (e.response!.data as Map)['error'].toString();
          } else {
            err = e.response?.data.toString() ?? err;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSubjectDetailsModal(BuildContext context, SubjectSimple subject) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SubjectDetailsSheet(
        subject: subject,
        onRefreshNeeded: _loadSubjects,
        onDelete: (s) => _confirmDeleteSubject(s),
      ),
    );
  }
}

class _SubjectDetailsSheet extends StatefulWidget {
  final SubjectSimple subject;
  final VoidCallback onRefreshNeeded;
  final Function(SubjectSimple) onDelete;

  const _SubjectDetailsSheet({
    required this.subject,
    required this.onRefreshNeeded,
    required this.onDelete,
  });

  @override
  State<_SubjectDetailsSheet> createState() => _SubjectDetailsSheetState();
}

class _SubjectDetailsSheetState extends State<_SubjectDetailsSheet> {
  bool _loadingFaculty = true;
  List<Map<String, dynamic>> _assignedFaculty = [];

  @override
  void initState() {
    super.initState();
    _loadAssignedFaculty();
  }

  Future<void> _loadAssignedFaculty() async {
    try {
      final dio = ApiClient().dio;
      final response = await dio.get(
        '/subjects/getAssignedProfessors/',
        queryParameters: {'subject_id': widget.subject.id},
      );

      List raw = [];
      if (response.data is List) {
        raw = response.data;
      } else if (response.data is Map && response.data['results'] is List) {
        raw = response.data['results'];
      }

      if (mounted) {
        setState(() {
          _assignedFaculty = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loadingFaculty = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingFaculty = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = p.Provider.of<AuthProvider>(context, listen: false);
    final role = (auth.role ?? '').toUpperCase();
    final isHodOrAdmin = role == AppRoles.hod || role == AppRoles.principal || role == AppRoles.system;

    return Container(
      padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF13246E),
                foregroundColor: Colors.white,
                child: Text(
                  widget.subject.semester.isNotEmpty ? "S${widget.subject.semester}" : "S",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.subject.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Code: ${widget.subject.code}",
                      style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    if (widget.subject.department != null)
                      Text(
                        "Dept: ${widget.subject.department}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 24),
          const Text(
            "Assigned Faculty",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF13246E)),
          ),
          const SizedBox(height: 8),
          if (_loadingFaculty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_assignedFaculty.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 6),
                  const Text("No faculty assigned to this subject yet.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            )
          else
            ..._assignedFaculty.map((fac) {
              final name = fac['professor_name'] ?? fac['faculty_name'] ?? fac['name'] ?? 'Assigned Faculty';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Color(0xFF13246E)),
                    const SizedBox(width: 8),
                    Text(name.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            }),
          const SizedBox(height: 20),
          // Action Buttons
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (isHodOrAdmin) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13246E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.assignment_ind, size: 18),
                  label: const Text("Assign Faculty"),
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/subjects/assign').then((_) => widget.onRefreshNeeded());
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text("Delete Subject"),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDelete(widget.subject);
                  },
                ),
              ],
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.grade, size: 18),
                label: const Text("IA Marks"),
                onPressed: () {
                  Navigator.pop(context);
                  context.push(
                    '/ia/create/${widget.subject.id}',
                    extra: widget.subject.name,
                  );
                },
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.calendar_month, size: 18),
                label: const Text("Timetable"),
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/timetable/list');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}