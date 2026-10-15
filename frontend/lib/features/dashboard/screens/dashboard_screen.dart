import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/api/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ApiService();
      final response = await api.dio.get('dashboard/');
      setState(() {
        _dashboardData = response.data;
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
    final auth = context.watch<AuthProvider>();
    final role = auth.role ?? 'Guest';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _fetchDashboard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [const Color(0xFF13246E), const Color(0xFF3B38A0)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Logged in as: ${role.replaceAll('_', ' ')}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Overview',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),

                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Center(child: Text("Error: $_error"))
                else if (_dashboardData != null &&
                    _dashboardData!['cards'] != null &&
                    (_dashboardData!['cards'] as List).isNotEmpty)
                  _buildCards(
                    _dashboardData!['cards'] as List,
                    constraints.maxWidth,
                  )
                else
                  _buildFallbackCards(context, role, constraints.maxWidth),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCards(List cards, double availableWidth) {
    int columns = availableWidth > 1100 ? 3 : (availableWidth > 700 ? 2 : 1);
    double cardWidth = (availableWidth - (24 * (columns - 1))) / columns;

    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: cards.map((card) {
        return SizedBox(
          width: cardWidth,
          child: _StatCard(
            title: card['title'] ?? '',
            value: card['value']?.toString() ?? '',
            icon: _getIcon(card['icon']),
            color: _getColor(card['color']),
            onTap: card['route'] != null
                ? () => context.go(card['route'])
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFallbackCards(
    BuildContext context,
    String role,
    double availableWidth,
  ) {
    List<Map<String, dynamic>> cards = [];
    final upperRole = role.toUpperCase();

    if (upperRole == AppRoles.hod) {
      cards = [
        {
          'title': 'Dept Students',
          'value': 'View',
          'icon': 'people',
          'color': 'navy',
          'route': '/admissions/list',
        },
        {
          'title': 'Department Hub',
          'value': 'Manage',
          'icon': 'checklist',
          'color': 'teal',
          'route': '/academics',
        },
        {
          'title': 'Dept Subjects',
          'value': 'Curriculum',
          'icon': 'book',
          'color': 'blue',
          'route': '/subjects',
        },
        {
          'title': 'Attendance',
          'value': 'Mark',
          'icon': 'check',
          'color': 'green',
          'route': '/attendance/faculty',
        },
      ];
    } else if (upperRole == AppRoles.principal || upperRole == AppRoles.system) {
      cards = [
        {
          'title': 'Students',
          'value': 'Directory',
          'icon': 'people',
          'color': 'navy',
          'route': '/admissions/list',
        },
        {
          'title': 'Faculty',
          'value': 'Directory',
          'icon': 'people',
          'color': 'teal',
          'route': '/faculty/list',
        },
        {
          'title': 'Approvals',
          'value': 'Review',
          'icon': 'checklist',
          'color': 'orange',
          'route': '/approvals',
        },
        {
          'title': 'Reports',
          'value': 'Analytics',
          'icon': 'notifications',
          'color': 'blue',
          'route': '/reports',
        },
      ];
    } else if (upperRole == AppRoles.professor) {
      cards = [
        {
          'title': 'My Schedule',
          'value': 'Timetable',
          'icon': 'checklist',
          'color': 'teal',
          'route': '/timetable/my-schedule',
        },
        {
          'title': 'My Subjects',
          'value': 'Assigned',
          'icon': 'book',
          'color': 'blue',
          'route': '/subjects',
        },
        {
          'title': 'Mark Attendance',
          'value': 'Today',
          'icon': 'check',
          'color': 'green',
          'route': '/attendance/faculty',
        },
      ];
    } else if (upperRole == AppRoles.accounts) {
      cards = [
        {
          'title': 'Fee Structures',
          'value': 'Active',
          'icon': 'monetization',
          'color': 'green',
          'route': '/fees',
        },
        {
          'title': 'Pending Payments',
          'value': 'Review',
          'icon': 'pending',
          'color': 'orange',
          'route': '/fees/student-payments',
        },
        {
          'title': 'Quick Action',
          'value': 'Create Fee',
          'icon': 'add',
          'color': 'blue',
          'route': '/fees/create',
        },
      ];
    } else if (upperRole == AppRoles.admission) {
      cards = [
        {
          'title': 'Students',
          'value': 'Active',
          'icon': 'people',
          'color': 'navy',
          'route': '/admissions/list',
        },
        {
          'title': 'Pending',
          'value': 'Verify',
          'icon': 'checklist',
          'color': 'teal',
          'route': '/admissions/list',
        },
        {
          'title': 'Quick Action',
          'value': 'Register',
          'icon': 'add',
          'color': 'orange',
          'route': '/admissions/register',
        },
      ];
    } else if (upperRole == AppRoles.student) {
      cards = [
        {
          'title': 'Attendance',
          'value': 'View',
          'icon': 'check',
          'color': 'green',
          'route': '/attendance/student',
        },
        {
          'title': 'Fee Details',
          'value': 'Details',
          'icon': 'money',
          'color': 'orange',
          'route': '/fees/my-fees',
        },
        {
          'title': 'Library',
          'value': 'Books',
          'icon': 'book',
          'color': 'blue',
          'route': '/library',
        },
      ];
    } else {
      cards = [
        {
          'title': 'Status',
          'value': 'Active',
          'icon': 'check',
          'color': 'green',
        },
        {
          'title': 'Notifications',
          'value': 'View',
          'icon': 'notifications',
          'color': 'blue',
        },
      ];
    }

    int columns = availableWidth > 1100 ? 3 : (availableWidth > 700 ? 2 : 1);
    double cardWidth = (availableWidth - (24 * (columns - 1))) / columns;

    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: cards.map((c) {
        return SizedBox(
          width: cardWidth,
          child: _StatCard(
            title: c['title'] as String,
            value: c['value'] as String,
            icon: _getIcon(c['icon']),
            color: _getColor(c['color']),
            onTap: c['route'] != null
                ? () => context.go(c['route'] as String)
                : null,
          ),
        );
      }).toList(),
    );
  }

  IconData _getIcon(dynamic iconName) {
    switch (iconName?.toString()) {
      case 'people':
        return Icons.people;
      case 'check':
      case 'checklist':
        return Icons.check_circle;
      case 'money':
      case 'monetization':
        return Icons.monetization_on;
      case 'book':
        return Icons.book;
      case 'notifications':
        return Icons.notifications;
      case 'pending':
        return Icons.pending_actions;
      case 'add':
        return Icons.add_circle_outline;
      default:
        return Icons.dashboard;
    }
  }

  Color _getColor(dynamic colorName) {
    switch (colorName?.toString()) {
      case 'green':
        return const Color(0xFF2E7D32);
      case 'orange':
        return const Color(0xFFE65100);
      case 'blue':
        return const Color(0xFF1565C0);
      case 'navy':
        return const Color(0xFF13246E);
      case 'teal':
        return const Color(0xFF00897B);
      default:
        return const Color(0xFF13246E);
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
