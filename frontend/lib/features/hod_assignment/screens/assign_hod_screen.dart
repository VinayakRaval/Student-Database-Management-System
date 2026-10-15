
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AssignHodScreen extends StatefulWidget {
  const AssignHodScreen({super.key});

  @override
  State<AssignHodScreen> createState() => _AssignHodScreenState();
}

class _AssignHodScreenState extends State<AssignHodScreen> {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://127.0.0.1:8000',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  final FlutterSecureStorage _storage =
      const FlutterSecureStorage();

  List<Map<String, dynamic>> _faculty = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _currentHods = [];

  int? _selectedFaculty;
  int? _selectedDepartment;

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<Response<dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    final token = await _storage.read(key: 'access');

    if (token == null || token.isEmpty) {
      throw Exception('Please log in again. Access token not found.');
    }

    return _dio.request(
      path,
      data: data,
      options: Options(
        method: method,
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
  }

  List<Map<String, dynamic>> _asList(dynamic response) {
    dynamic value = response;

    if (value is Map && value.containsKey('results')) {
      value = value['results'];
    }

    if (value is! List) {
      throw Exception('Unexpected API response format.');
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _request('/academics/departments/'),
        _request('/faculty/faculties/'),
        _request('/hod_assignment/current/'),
      ]);

      if (!mounted) return;

      setState(() {
        _departments = _asList(results[0].data);
        _faculty = _asList(results[1].data);
        _currentHods = _asList(results[2].data);
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _errorMessage(e);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _errorMessage(DioException e) {
    if (e.response?.statusCode == 401) {
      return 'Session expired. Please log in again.';
    }

    if (e.response?.statusCode == 403) {
      return 'Your account does not have permission to assign HODs.';
    }

    final data = e.response?.data;

    if (data is Map) {
      return data.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n');
    }

    return e.message ?? 'Unable to connect to the server.';
  }

  Future<void> _assignHod() async {
    if (_selectedFaculty == null ||
        _selectedDepartment == null) {
      _showMessage('Select both a faculty member and a department.');
      return;
    }

    final alreadyAssigned = _currentHods.any(
      (hod) =>
          hod['department'].toString() ==
          _selectedDepartment.toString(),
    );

    final selectedAlreadyHod = _currentHods.any(
      (hod) =>
          hod['faculty'].toString() ==
          _selectedFaculty.toString(),
    );

    if (selectedAlreadyHod) {
      _showMessage(
        'This faculty member already has a current HOD assignment.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm HOD assignment'),
        content: Text(
          alreadyAssigned
              ? 'An HOD is already assigned to this department. '
                  'The backend will end the previous assignment. Continue?'
              : 'Assign the selected faculty member as HOD?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);

    try {
      await _request(
        '/hod_assignment/assign/',
        method: 'POST',
        data: {
          'faculty': _selectedFaculty,
          'department': _selectedDepartment,
        },
      );

      if (!mounted) return;

      _showMessage('HOD assigned successfully.');
      setState(() {
        _selectedFaculty = null;
        _selectedDepartment = null;
      });

      await _loadData();
    } on DioException catch (e) {
      if (mounted) _showMessage(_errorMessage(e));
    } catch (e) {
      if (mounted) {
        _showMessage(
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _label(Map<String, dynamic> item) {
    final name = item['name'] ??
        item['faculty_name'] ??
        item['faculty_id'] ??
        'Unknown';

    final id = item['faculty_id'];

    return id != null && item['name'] != null
        ? '$name ($id)'
        : name.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text(
                        'Assign Head of Department',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1D2D6C),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Assign faculty members to lead academic departments.',
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'New HOD Assignment',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              DropdownButtonFormField<int>(
                                value: _selectedDepartment,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Department',
                                  prefixIcon:
                                      Icon(Icons.business_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                items: _departments.map((department) {
                                  return DropdownMenuItem<int>(
                                    value: int.tryParse(
                                      department['id'].toString(),
                                    ),
                                    child: Text(
                                      department['name'].toString(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(
                                    () => _selectedDepartment = value,
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<int>(
                                value: _selectedFaculty,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Faculty Member',
                                  prefixIcon:
                                      Icon(Icons.person_outline),
                                  border: OutlineInputBorder(),
                                ),
                                items: _faculty.map((faculty) {
                                  return DropdownMenuItem<int>(
                                    value: int.tryParse(
                                      faculty['id'].toString(),
                                    ),
                                    child: Text(
                                      '${_label(faculty)}'
                                      '${faculty['role'] != null ? ' • ${faculty['role']}' : ''}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(
                                    () => _selectedFaculty = value,
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _submitting
                                      ? null
                                      : _assignHod,
                                  icon: _submitting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.assignment_ind),
                                  label: Text(
                                    _submitting
                                        ? 'Assigning...'
                                        : 'Assign HOD',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Current HOD Assignments',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh',
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_currentHods.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'No current HOD assignments found.',
                              ),
                            ),
                          ),
                        )
                      else
                        ..._currentHods.map((hod) {
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(
                                (hod['faculty_name'] ?? 'Unknown faculty')
                                    .toString(),
                              ),
                              subtitle: Text(
                                (hod['department_name'] ??
                                        'Unknown department')
                                    .toString(),
                              ),
                              trailing: const Chip(
                                label: Text('Current'),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
