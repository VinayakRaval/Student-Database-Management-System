import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/core/constants/api_constants.dart';
import '../providers/grievance_provider.dart';
import '../models/grievance_model.dart';
import 'student_grievances_screen.dart';

class OfficerGrievanceDashboard extends StatefulWidget {
  const OfficerGrievanceDashboard({super.key});

  @override
  State<OfficerGrievanceDashboard> createState() => _OfficerGrievanceDashboardState();
}

class _OfficerGrievanceDashboardState extends State<OfficerGrievanceDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String? _selectedCategory;
  String? _selectedStatus;
  String? _selectedPriority;
  bool _overdueOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = Provider.of<GrievanceProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final role = (auth.role ?? '').toUpperCase();

      p.fetchCategories();
      p.fetchOfficers();
      p.fetchStats();

      if (role == AppRoles.hod || role == AppRoles.principal) {
        p.setScope('all');
      } else {
        p.setScope('assigned');
      }
    });

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final p = Provider.of<GrievanceProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final role = (auth.role ?? '').toUpperCase();

      if (_tabController.index == 0) {
        // Main view for role
        if (role == AppRoles.hod || role == AppRoles.principal) {
          p.setScope('all');
        } else {
          p.setScope('assigned');
        }
      } else if (_tabController.index == 1) {
        // Assigned to Me or Escalated
        if (role == AppRoles.principal) {
          p.setScope('escalated');
        } else {
          p.setScope('assigned');
        }
      } else if (_tabController.index == 2) {
        // Submitted by Me
        p.setScope('my');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final p = Provider.of<GrievanceProvider>(context, listen: false);
    p.setFilters(
      status: _selectedStatus,
      category: _selectedCategory,
      priority: _selectedPriority,
      search: _searchController.text.trim(),
      overdueOnly: _overdueOnly,
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedStatus = null;
      _selectedPriority = null;
      _searchController.clear();
      _overdueOnly = false;
    });
    Provider.of<GrievanceProvider>(context, listen: false).clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GrievanceProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final role = (auth.role ?? '').toUpperCase();

    String bannerTitle = "Grievance Governance & Resolution Desk";
    String bannerSubtitle = "Track, investigate, assign and resolve institutional grievances.";

    if (role == AppRoles.admission) {
      bannerTitle = "Admission Grievance Desk";
      bannerSubtitle = "Track and manage student admission-related grievances efficiently.";
    } else if (role == AppRoles.hod) {
      bannerTitle = "Department Grievance Desk";
      bannerSubtitle = "Review, investigate, assign and resolve departmental grievances.";
    } else if (role == AppRoles.principal) {
      bannerTitle = "Institutional Grievance Oversight";
      bannerSubtitle = "Oversee escalated complaints and monitor institution-wide grievance resolution.";
    } else if (role == AppRoles.professor) {
      bannerTitle = "Faculty Grievance Portal";
      bannerSubtitle = "Review assigned academic grievances and track submitted concerns.";
    } else if (role == AppRoles.accounts) {
      bannerTitle = "Accounts & Fee Grievances";
      bannerSubtitle = "Review and resolve fee disputes and financial grievance claims.";
    } else if (role == AppRoles.library) {
      bannerTitle = "Library Grievance Desk";
      bannerSubtitle = "Review and address book circulation and library service grievances.";
    }

    List<Tab> tabs = const [
      Tab(text: "Department / Overview"),
      Tab(text: "Assigned To Me"),
      Tab(text: "My Submitted"),
    ];

    if (role == AppRoles.principal) {
      tabs = const [
        Tab(text: "All Grievances"),
        Tab(text: "Escalated Cases"),
        Tab(text: "My Submitted"),
      ];
    } else if (role == AppRoles.professor) {
      tabs = const [
        Tab(text: "Assigned Cases"),
        Tab(text: "Action Required"),
        Tab(text: "My Submitted"),
      ];
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 16,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.assignment_late_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    bannerTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    bannerSubtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: "Refresh Grievances",
            onPressed: () {
              provider.fetchGrievances();
              provider.fetchStats();
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.fetchGrievances();
          await provider.fetchStats();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search and Filters
              _buildFilterBar(provider),
              const SizedBox(height: 16),

              // Scope Underline Tabs
              _buildScopeTabs(tabs),
              const SizedBox(height: 16),

              // KPI Summary Cards
              _buildKpiRow(provider.stats),
              const SizedBox(height: 16),

              // Complaint Cards or Empty State
              if (provider.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (provider.grievances.isEmpty)
                _buildEmptyState()
              else
                _buildGrievanceList(provider.grievances, role),

              // Extra bottom padding so FAB never covers the last card
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF13246E),
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        icon: const Icon(Icons.add, size: 18),
        label: const Text(
          "File Grievance",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const StudentGrievancesScreen()),
          );
        },
      ),
    );
  }



  Widget _buildScopeTabs(List<Tab> tabs) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: const Color(0xFF13246E),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        indicatorColor: const Color(0xFF13246E),
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: tabs,
      ),
    );
  }

  Widget _buildKpiRow(GrievanceStatsModel? s) {
    final total = s?.total ?? 0;
    final inProgress = (s?.underReview ?? 0) + (s?.inProgress ?? 0);
    final awaitingInfo = s?.awaitingInfo ?? 0;
    final escalated = s?.escalated ?? 0;
    final overdue = s?.overdue ?? 0;
    final resolved = (s?.resolved ?? 0) + (s?.closed ?? 0);

    final cards = [
      _buildKpiCard(
        label: "TOTAL CASES",
        count: "$total",
        icon: Icons.description_outlined,
        iconBgColor: const Color(0xFFEBF5FF),
        iconColor: const Color(0xFF3B82F6),
        countColor: const Color(0xFF13246E),
      ),
      _buildKpiCard(
        label: "IN PROGRESS",
        count: "$inProgress",
        icon: Icons.access_time_rounded,
        iconBgColor: const Color(0xFFFFF7ED),
        iconColor: const Color(0xFFF97316),
        countColor: const Color(0xFFEA580C),
      ),
      _buildKpiCard(
        label: "AWAITING INFO",
        count: "$awaitingInfo",
        icon: Icons.help_rounded,
        iconBgColor: const Color(0xFFF5F3FF),
        iconColor: const Color(0xFF8B5CF6),
        countColor: const Color(0xFF7C3AED),
      ),
      _buildKpiCard(
        label: "ESCALATED",
        count: "$escalated",
        icon: Icons.warning_amber_rounded,
        iconBgColor: const Color(0xFFFEF2F2),
        iconColor: const Color(0xFFEF4444),
        countColor: const Color(0xFFDC2626),
      ),
      _buildKpiCard(
        label: "OVERDUE SLA",
        count: "$overdue",
        icon: Icons.access_time_filled_rounded,
        iconBgColor: const Color(0xFFFFF1ED),
        iconColor: const Color(0xFFEA580C),
        countColor: const Color(0xFFEA580C),
      ),
      _buildKpiCard(
        label: "RESOLVED",
        count: "$resolved",
        icon: Icons.check_circle_rounded,
        iconBgColor: const Color(0xFFF0FDF4),
        iconColor: const Color(0xFF22C55E),
        countColor: const Color(0xFF16A34A),
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 960) {
        return Row(
          children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
        );
      } else if (constraints.maxWidth >= 560) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 16) / 3, child: c)).toList(),
        );
      } else {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 8) / 2, child: c)).toList(),
        );
      }
    });
  }

  Widget _buildKpiCard({
    required String label,
    required String count,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required Color countColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: countColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(GrievanceProvider provider) {
    final total = provider.stats?.total ?? provider.grievances.length;
    final inProgress = (provider.stats?.underReview ?? 0) + (provider.stats?.inProgress ?? 0);
    final awaitingInfo = provider.stats?.awaitingInfo ?? 0;
    final escalated = provider.stats?.escalated ?? 0;
    final resolved = (provider.stats?.resolved ?? 0) + (provider.stats?.closed ?? 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips Row matching Image 3
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip("All Records ($total)", _selectedStatus == null && !_overdueOnly, () {
                  setState(() {
                    _selectedStatus = null;
                    _overdueOnly = false;
                  });
                  _applyFilters();
                }),
                const SizedBox(width: 8),
                _filterChip("In Review ($inProgress)", _selectedStatus == 'UNDER_REVIEW' || _selectedStatus == 'IN_PROGRESS', () {
                  setState(() {
                    _selectedStatus = (_selectedStatus == 'UNDER_REVIEW' || _selectedStatus == 'IN_PROGRESS') ? null : 'UNDER_REVIEW';
                    _overdueOnly = false;
                  });
                  _applyFilters();
                }, color: Colors.orange),
                const SizedBox(width: 8),
                _filterChip("Awaiting Info ($awaitingInfo)", _selectedStatus == 'AWAITING_INFO', () {
                  setState(() {
                    _selectedStatus = _selectedStatus == 'AWAITING_INFO' ? null : 'AWAITING_INFO';
                    _overdueOnly = false;
                  });
                  _applyFilters();
                }, color: Colors.purple),
                const SizedBox(width: 8),
                _filterChip("Escalated ($escalated)", _selectedStatus == 'ESCALATED', () {
                  setState(() {
                    _selectedStatus = _selectedStatus == 'ESCALATED' ? null : 'ESCALATED';
                    _overdueOnly = false;
                  });
                  _applyFilters();
                }, color: Colors.red),
                const SizedBox(width: 8),
                _filterChip("Resolved ($resolved)", _selectedStatus == 'RESOLVED' || _selectedStatus == 'CLOSED', () {
                  setState(() {
                    _selectedStatus = (_selectedStatus == 'RESOLVED' || _selectedStatus == 'CLOSED') ? null : 'RESOLVED';
                    _overdueOnly = false;
                  });
                  _applyFilters();
                }, color: Colors.green),
                const SizedBox(width: 12),
                FilterChip(
                  selected: _overdueOnly,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 15,
                        color: _overdueOnly ? Colors.white : const Color(0xFFEA580C),
                      ),
                      const SizedBox(width: 4),
                      Text("Overdue SLA (${provider.stats?.overdue ?? 0})"),
                    ],
                  ),
                  selectedColor: const Color(0xFFEA580C),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _overdueOnly ? Colors.white : const Color(0xFFEA580C),
                  ),
                  onSelected: (val) {
                    setState(() => _overdueOnly = val);
                    _applyFilters();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Dropdowns and Search Row matching Image 3
          LayoutBuilder(builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 720;
            if (isMobile) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownContainer(
                          hint: "Category",
                          icon: Icons.grid_view_rounded,
                          value: _selectedCategory,
                          items: provider.categories
                              .map((c) => DropdownMenuItem(value: c.code, child: Text(c.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (val) {
                            setState(() => _selectedCategory = val);
                            _applyFilters();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDropdownContainer(
                          hint: "Priority",
                          icon: Icons.flag_outlined,
                          value: _selectedPriority,
                          items: ['LOW', 'MEDIUM', 'HIGH', 'URGENT']
                              .map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12))))
                              .toList(),
                          onChanged: (val) {
                            setState(() => _selectedPriority = val);
                            _applyFilters();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: "Search USN / Topic / Name...",
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: _resetFilters,
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      ),
                      onSubmitted: (_) => _applyFilters(),
                    ),
                  ),
                ],
              );
            } else {
              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildDropdownContainer(
                      hint: "All Categories",
                      icon: Icons.grid_view_rounded,
                      value: _selectedCategory,
                      items: provider.categories
                          .map((c) => DropdownMenuItem(value: c.code, child: Text(c.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (val) {
                        setState(() => _selectedCategory = val);
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildDropdownContainer(
                      hint: "All Priorities",
                      icon: Icons.flag_outlined,
                      value: _selectedPriority,
                      items: ['LOW', 'MEDIUM', 'HIGH', 'URGENT']
                          .map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (val) {
                        setState(() => _selectedPriority = val);
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: SizedBox(
                      height: 42,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: "Search USN / Topic / Name...",
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: _resetFilters,
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        ),
                        onSubmitted: (_) => _applyFilters(),
                      ),
                    ),
                  ),
                ],
              );
            }
          }),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? const Color(0xFF13246E))
              : (color?.withValues(alpha: 0.1) ?? Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (color ?? const Color(0xFF13246E))
                : (color?.withValues(alpha: 0.3) ?? Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (color ?? Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownContainer({
    required String hint,
    required IconData icon,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hint,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(hint, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            ...items,
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFFEBF5FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDBEAFE), width: 1.5),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: const [
                Icon(
                  Icons.inbox_rounded,
                  size: 40,
                  color: Color(0xFF3B82F6),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: Color(0xFF60A5FA),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Grievances Found",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Try adjusting search criteria or selecting another scope tab.",
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrievanceList(List<GrievanceModel> list, String role) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (c, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final g = list[index];
        final isResolved = g.status == 'RESOLVED' || g.status == 'CLOSED';
        final isPending = g.status == 'UNDER_REVIEW' || g.status == 'IN_PROGRESS' || g.status == 'SUBMITTED' || g.status == 'PENDING';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: g.isOverdue
                  ? Colors.red.shade300
                  : (g.isEscalated ? Colors.orange.shade300 : const Color(0xFFE2E8F0)),
              width: (g.isOverdue || g.isEscalated) ? 1.5 : 1,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row matching Image 3 (USN/ID pill + Date + Status Pill Badge)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      g.studentUsn?.isNotEmpty == true ? g.studentUsn! : "CASE #${g.id}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF334155)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "📅 ${_formatDate(g.createdAt)}",
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  if (isResolved)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
                          SizedBox(width: 4),
                          Text(
                            "RESOLVED",
                            style: TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  else if (g.isEscalated)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFDC2626)),
                          SizedBox(width: 4),
                          Text(
                            "ESCALATED",
                            style: TextStyle(color: Color(0xFFB91C1C), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  else if (isPending)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pending_actions_rounded, size: 13, color: Color(0xFFD97706)),
                          SizedBox(width: 4),
                          Text(
                            "UNDER REVIEW",
                            style: TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildStatusBadge(g.status),
                ],
              ),
              const SizedBox(height: 10),

              // Complainant Name & Topic
              Text(
                g.complainantName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                g.topic,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 4),
              Text(
                g.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.3),
              ),
              const SizedBox(height: 10),

              // Badges Row (Category, Priority, Overdue, Confidential)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      g.categoryName,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade800),
                    ),
                  ),
                  _buildPriorityBadge(g.priority),
                  if (g.isOverdue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Text("OVERDUE SLA", style: TextStyle(color: Colors.red, fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                  if (g.isConfidential)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text("CONFIDENTIAL", style: TextStyle(color: Colors.purple, fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const Divider(height: 20),

              // Bottom Action Row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Assigned to: ${g.assignedOfficerName}",
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13246E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text("Review & Action", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    onPressed: () => _openReviewDialog(g, role),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openReviewDialog(GrievanceModel g, String role) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _GrievanceActionDialog(grievance: g, role: role),
    );
  }

  String _formatDate(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.blue.shade50;
    Color fg = Colors.blue.shade700;
    switch (status.toUpperCase()) {
      case 'SUBMITTED':
      case 'PENDING':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        break;
      case 'UNDER_REVIEW':
      case 'IN_PROGRESS':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        break;
      case 'AWAITING_INFO':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade700;
        break;
      case 'RESOLVED':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case 'CLOSED':
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        break;
      case 'ESCALATED':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        break;
      case 'REOPENED':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      case 'REJECTED':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color = Colors.blue;
    if (priority == 'URGENT') color = Colors.red;
    if (priority == 'HIGH') color = Colors.orange;
    if (priority == 'LOW') color = Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _GrievanceActionDialog extends StatefulWidget {
  final GrievanceModel grievance;
  final String role;

  const _GrievanceActionDialog({required this.grievance, required this.role});

  @override
  State<_GrievanceActionDialog> createState() => _GrievanceActionDialogState();
}

class _GrievanceActionDialogState extends State<_GrievanceActionDialog> {
  late GrievanceModel g;

  @override
  void initState() {
    super.initState();
    g = widget.grievance;
  }

  @override
  Widget build(BuildContext context) {
    final perms = g.userPermissions;
    final provider = Provider.of<GrievanceProvider>(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF13246E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gavel_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Grievance Review #${g.id}: ${g.topic}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Modal Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Overview Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text("Complainant: ${g.complainantName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 8),
                            Text("(${g.complainantRole}${g.studentUsn != null ? ' - ${g.studentUsn}' : ''})", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                            const Spacer(),
                            Text("Priority: ${g.priority}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text("Category: ${g.categoryName} • Status: ${g.status} • Officer: ${g.assignedOfficerName}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  const Text("Description / Statement:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(g.description, style: const TextStyle(fontSize: 13, height: 1.4)),
                  ),

                  // Reopen Request Notice
                  if (g.reopenRequested) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.replay, color: Colors.orange, size: 18),
                              SizedBox(width: 6),
                              Text("Reopening Request Pending", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text("Reason: ${g.reopenRequestReason ?? 'Issue unresolved.'}", style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],

                  // Activity Timeline
                  const SizedBox(height: 20),
                  const Text("Audit Trail & Timeline:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (g.activities.isEmpty)
                    const Text("No activities recorded yet.", style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    ...g.activities.map((a) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("${a.action.replaceAll('_', ' ')} by ${a.actorName} (${a.actorRole})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF13246E))),
                                  Text("${a.createdAt.day}/${a.createdAt.month}/${a.createdAt.year}", style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                ],
                              ),
                              if (a.notes.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(a.notes, style: const TextStyle(fontSize: 12)),
                              ],
                            ],
                          ),
                        )),
                ],
              ),
            ),

            // Action Buttons Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (perms.canAssign)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text("Assign / Reassign"),
                      onPressed: () => _showAssignDialog(context, provider),
                    ),
                  if (perms.canRequestInfo)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
                      icon: const Icon(Icons.help_outline, size: 16),
                      label: const Text("Request Info"),
                      onPressed: () => _showRequestInfoDialog(context, provider),
                    ),
                  if (perms.canEscalate)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange.shade800, foregroundColor: Colors.white),
                      icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                      label: const Text("Escalate"),
                      onPressed: () => _showEscalateDialog(context, provider),
                    ),
                  if (perms.canResolve)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text("Resolve"),
                      onPressed: () => _showResolveDialog(context, provider),
                    ),
                  if (perms.canReject)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text("Reject"),
                      onPressed: () => _showRejectDialog(context, provider),
                    ),
                  if (g.reopenRequested && perms.canReopen)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
                      icon: const Icon(Icons.replay, size: 16),
                      label: const Text("Review Reopen"),
                      onPressed: () => _showReopenReviewDialog(context, provider),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignDialog(BuildContext context, GrievanceProvider provider) {
    int? selectedOfficerId;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text("Assign / Reassign Officer", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select Officer *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                initialValue: selectedOfficerId,
                items: provider.officers.map((o) {
                  return DropdownMenuItem<int>(
                    value: o.id,
                    child: Text("${o.name} (${o.role}${o.department != null ? ' - ${o.department}' : ''})", style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                onChanged: (val) => setDlgState(() => selectedOfficerId = val),
              ),
              const SizedBox(height: 12),
              const Text("Assignment Notes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "Instructions or rationale...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13246E), foregroundColor: Colors.white),
              onPressed: () async {
                if (selectedOfficerId == null) return;
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                await provider.assignOfficer(g.id, targetUserId: selectedOfficerId!, notes: notesController.text.trim());
              },
              child: const Text("Confirm Assignment"),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestInfoDialog(BuildContext context, GrievanceProvider provider) {
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Request Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Specify what details or proofs the complainant needs to provide:", style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "e.g. Please upload fee receipt or specify the class date...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
            onPressed: () async {
              if (notesCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              await provider.requestInfo(g.id, notes: notesCtrl.text.trim());
            },
            child: const Text("Send Request"),
          ),
        ],
      ),
    );
  }

  void _showEscalateDialog(BuildContext context, GrievanceProvider provider) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Escalate Grievance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Escalate this complaint to the Principal for executive intervention:", style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Reason for escalation...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange.shade800, foregroundColor: Colors.white),
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              await provider.escalate(g.id, reason: reasonCtrl.text.trim(), destinationRole: 'PRINCIPAL');
            },
            child: const Text("Escalate to Principal"),
          ),
        ],
      ),
    );
  }

  void _showResolveDialog(BuildContext context, GrievanceProvider provider) {
    final remarksCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Resolve Grievance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Provide mandatory resolution remarks explaining how the issue was resolved:", style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: remarksCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Investigation notes & resolution outcome...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
            onPressed: () async {
              if (remarksCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              await provider.resolve(g.id, remarks: remarksCtrl.text.trim());
            },
            child: const Text("Mark Resolved"),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, GrievanceProvider provider) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject Grievance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("State the reason for rejecting this complaint:", style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Rejection rationale...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              await provider.reject(g.id, reason: reasonCtrl.text.trim());
            },
            child: const Text("Confirm Rejection"),
          ),
        ],
      ),
    );
  }

  void _showReopenReviewDialog(BuildContext context, GrievanceProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Review Reopen Request", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          "Complainant Reason:\n\"${g.reopenRequestReason ?? 'Issue unresolved'}\"\n\nDo you want to reopen this grievance for further investigation?",
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              await provider.reviewReopen(g.id, decision: 'REJECT', notes: 'Reopen request declined upon review.');
            },
            child: const Text("Decline Reopening", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              await provider.reviewReopen(g.id, decision: 'APPROVE', notes: 'Reopening approved. Investigation resumed.');
            },
            child: const Text("Approve & Reopen"),
          ),
        ],
      ),
    );
  }
}
