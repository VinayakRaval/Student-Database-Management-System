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
                    (_dashboardData!['cards'] as List).isNotEmpty) ...[
                  _buildCards(
                    _dashboardData!['cards'] as List,
                    constraints.maxWidth,
                  ),
                  if (role.toUpperCase() == AppRoles.professor || role.toUpperCase() == AppRoles.hod) ...[
                    const SizedBox(height: 32),
                    _buildProfessorExtraSections(context, isDark, constraints.maxWidth),
                  ],
                ]
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
          'route': '/subjects/department',
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
          'title': 'My Students',
          'value': 'Directory',
          'icon': 'people',
          'color': 'navy',
          'route': '/faculty/students',
        },
        {
          'title': 'Mark Attendance',
          'value': 'Today',
          'icon': 'check',
          'color': 'green',
          'route': '/attendance/faculty',
        },
        {
          'title': 'IA Assessment',
          'value': 'Evaluation',
          'icon': 'grade',
          'color': 'purple',
          'route': '/ia/faculty',
        },
        {
          'title': 'Academic Reports',
          'value': 'Analytics',
          'icon': 'analytics',
          'color': 'teal',
          'route': '/faculty/reports',
        },
      ];
    } else if (upperRole == AppRoles.accounts) {
      cards = [
        {
          'title': 'Accounts Hub',
          'value': 'Dashboard',
          'icon': 'monetization',
          'color': 'green',
          'route': '/fees/dashboard',
        },
        {
          'title': 'Student Fees',
          'value': 'Directory',
          'icon': 'people',
          'color': 'navy',
          'route': '/fees/students',
        },
        {
          'title': 'Record Payment',
          'value': 'Collect',
          'icon': 'add',
          'color': 'blue',
          'route': '/fees/record-payment',
        },
        {
          'title': 'Pending Payments',
          'value': 'Verify',
          'icon': 'pending',
          'color': 'orange',
          'route': '/fees/student-payments',
        },
        {
          'title': 'Financial Reports',
          'value': 'Audit & Exports',
          'icon': 'analytics',
          'color': 'teal',
          'route': '/fees/reports',
        },
        {
          'title': 'Principal Directives',
          'value': 'Directives & Orders',
          'icon': 'notifications',
          'color': 'purple',
          'route': '/fees/notifications',
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

  Widget _buildProfessorExtraSections(
    BuildContext context,
    bool isDark,
    double availableWidth,
  ) {
    final todayClasses = (_dashboardData?['today_classes'] as List?) ?? [];
    final announcements = (_dashboardData?['recent_announcements'] as List?) ?? [];
    final unmarkedCount = _dashboardData?['unmarked_classes_today'] ?? 0;
    final pendingCorrections = _dashboardData?['pending_corrections'] ?? 0;
    final activeIaTests = _dashboardData?['active_ia_tests'] ?? 0;

    final isWide = availableWidth > 900;

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTodayTimetableCard(context, todayClasses, isDark),
        const SizedBox(height: 24),
        _buildPendingTasksCard(
          context,
          unmarkedCount,
          pendingCorrections,
          activeIaTests,
          isDark,
        ),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuickActionsCard(context, isDark),
        const SizedBox(height: 24),
        _buildAnnouncementsCard(context, announcements, isDark),
      ],
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: leftColumn),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: rightColumn),
        ],
      );
    } else {
      return Column(
        children: [
          leftColumn,
          const SizedBox(height: 24),
          rightColumn,
        ],
      );
    }
  }

  Widget _buildTodayTimetableCard(
    BuildContext context,
    List todayClasses,
    bool isDark,
  ) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                  color: const Color(0xFF13246E).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.schedule_rounded, color: Color(0xFF13246E), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Teaching Schedule",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${todayClasses.length} assigned session(s) today",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => context.go('/timetable/my-schedule'),
                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                label: const Text("Full Schedule"),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF13246E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          if (todayClasses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    size: 36,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "No classes scheduled for today.",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: todayClasses.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final cls = todayClasses[index];
                final slotId = cls['slot_id'];
                final subName = cls['subject_name'] ?? 'Subject';
                final subCode = cls['subject_code'] ?? '';
                final startTime = cls['start_time'] ?? '';
                final endTime = cls['end_time'] ?? '';
                final sem = cls['semester'] ?? '';
                final dept = cls['department'] ?? '';
                final isMarked = cls['is_attendance_marked'] == true;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isMarked
                          ? const Color(0xFF86EFAC).withOpacity(0.4)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF13246E).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF13246E)),
                            const SizedBox(height: 4),
                            Text(
                              startTime,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF13246E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subCode.isNotEmpty ? "$subCode - $subName" : subName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "$sem ${dept.isNotEmpty ? '• $dept' : ''} ($startTime - $endTime)",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (isMarked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                              SizedBox(width: 4),
                              Text(
                                "Marked",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () {
                            context.go('/attendance/mark/$slotId', extra: subName);
                          },
                          icon: const Icon(Icons.check_rounded, size: 14),
                          label: const Text("Mark Attendance"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF13246E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPendingTasksCard(
    BuildContext context,
    dynamic unmarkedCount,
    dynamic pendingCorrections,
    dynamic activeIaTests,
    bool isDark,
  ) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isHod = (auth.role ?? '').toUpperCase() == AppRoles.hod;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pending_actions_rounded, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                "Pending Academic Tasks",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _buildTaskRow(
            title: "Classes Awaiting Attendance",
            subtitle: "$unmarkedCount class(es) today require attendance submission",
            count: "$unmarkedCount",
            isUrgent: (unmarkedCount as num? ?? 0) > 0,
            btnLabel: "Attendance",
            onTap: () => context.go('/attendance/faculty'),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildTaskRow(
            title: "Active IA Test Evaluations",
            subtitle: "$activeIaTests test assessment(s) open for marks entry",
            count: "$activeIaTests",
            isUrgent: (activeIaTests as num? ?? 0) > 0,
            btnLabel: "Enter Marks",
            onTap: () => context.go('/ia/faculty'),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildTaskRow(
            title: "Attendance Corrections Pending",
            subtitle: "$pendingCorrections request(s) awaiting HOD review",
            count: "$pendingCorrections",
            isUrgent: false,
            btnLabel: "View Status",
            onTap: () => context.go(isHod ? '/attendance/monitoring' : '/attendance/faculty'),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow({
    required String title,
    required String subtitle,
    required String count,
    required bool isUrgent,
    required String btnLabel,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isUrgent ? const Color(0xFFFEE2E2) : const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: Text(
              count,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              side: const BorderSide(color: Color(0xFF13246E)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text(
              btnLabel,
              style: const TextStyle(fontSize: 11, color: Color(0xFF13246E), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final actions = [
      {'title': 'My Subjects', 'icon': Icons.library_books_rounded, 'color': const Color(0xFF13246E), 'route': '/subjects'},
      {'title': 'My Students', 'icon': Icons.people_alt_rounded, 'color': const Color(0xFF0D9488), 'route': '/faculty/students'},
      {'title': 'IA Assessment', 'icon': Icons.grade_rounded, 'color': const Color(0xFF3B38A0), 'route': '/ia/faculty'},
      {'title': 'Reports & Alerts', 'icon': Icons.analytics_rounded, 'color': const Color(0xFF16A34A), 'route': '/faculty/reports'},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick Module Access",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: actions.map((act) {
              final color = act['color'] as Color;
              return InkWell(
                onTap: () => context.go(act['route'] as String),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(act['icon'] as IconData, color: color, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          act['title'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsCard(BuildContext context, List announcements, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B38A0).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.campaign_rounded, color: Color(0xFF3B38A0), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Notices & Upcoming Exams",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/notifications'),
                child: const Text("View All", style: TextStyle(color: Color(0xFF13246E))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (announcements.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  "No announcements posted yet.",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: announcements.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final ann = announcements[index];
                final title = ann['title'] ?? 'Notice';
                final content = ann['content'] ?? '';
                final priority = (ann['priority'] ?? 'NORMAL').toString().toUpperCase();
                final category = (ann['category'] ?? 'GENERAL').toString().toUpperCase();
                final date = ann['created_at'] ?? '';

                Color priorityColor = Colors.grey;
                if (priority == 'URGENT') priorityColor = Colors.red;
                if (priority == 'IMPORTANT') priorityColor = Colors.orange;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (priority != 'NORMAL')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: priorityColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                priority,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: priorityColor,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13246E).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF13246E),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            date,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (content.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          content,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
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
