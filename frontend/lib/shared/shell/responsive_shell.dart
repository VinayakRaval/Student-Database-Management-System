import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/dashboard/widgets/role_sidebar.dart';
import 'package:frontend/features/dashboard/widgets/role_header.dart';
import 'package:frontend/features/dashboard/config/role_menus.dart';

class ResponsiveShell extends StatefulWidget {
  final Widget child;
  final String? currentPath;
  const ResponsiveShell({super.key, required this.child, this.currentPath});

  @override
  State<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends State<ResponsiveShell> {
  bool _isSidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _resolveTitle(String role, String activePath) {
    final path = activePath.isNotEmpty ? activePath : (widget.currentPath ?? '');

    // Specific library & academic sub-path matching first
    if (path.startsWith('/library/catalog') || path.startsWith('/library/books')) return 'Book Inventory';
    if (path.startsWith('/library/configuration')) return 'Library Configuration';
    if (path.startsWith('/library/borrowers')) return 'Borrowers';
    if (path.startsWith('/library/desk') || path.startsWith('/library/issue-book')) return 'Issue & Return Books';
    if (path.startsWith('/library/requests')) return 'Reservations';
    if (path == '/library/cards/create') return 'Create Library Issue Card';
    if (path.startsWith('/library/cards') || path.startsWith('/hod/library-cards')) return 'Library Issue Cards';
    if (path.startsWith('/library/history')) return 'Issue & Return History';
    if (path.startsWith('/library/notifications')) return 'Notifications';
    if (path.startsWith('/library/reports') || path == '/reports') return 'Reports';
    if (path.startsWith('/library/feedback')) return 'Feedback';
    if (path.startsWith('/library/officer')) return 'Dashboard';
    if (path.startsWith('/profile')) return 'Profile';
    if (path.startsWith('/fees/dashboard')) return 'Accounts Dashboard';
    if (path.startsWith('/fees/student-payments')) return 'Verify Payments';
    if (path.startsWith('/fees/students')) return 'Student Fee Directory';
    if (path.startsWith('/fees/record-payment')) return 'Record Payment';
    if (path.startsWith('/fees/uploaded-files')) return 'Uploaded Fee Proofs';
    if (path.startsWith('/fees/reports')) return 'Financial Reports';
    if (path.startsWith('/fees/notifications')) return 'Principal Directives';
    if (path.startsWith('/fees')) return 'Fee Structures';
    if (path.startsWith('/admissions/notifications')) return 'Principal Directives & Notifications';
    if (path.startsWith('/announcements/campus')) return 'Campus Announcements';
    if (path.startsWith('/student/corrections')) return 'Correction Center';
    if (path.startsWith('/corrections/review')) return 'Correction Requests Review';
    if (path.startsWith('/grievances') || path.startsWith('/student/grievances')) return 'Grievances';

    final menu = RoleMenus.getMenu(role);
    for (final item in menu) {
      if (item['route'] == path) {
        return item['title'] ?? 'Dashboard';
      }
      if (item['children'] is List) {
        for (final child in item['children']) {
          if (child['route'] == path) {
            return child['title'] ?? 'Dashboard';
          }
        }
      }
    }

    return 'Dashboard';
  }

  String? _resolveSubtitle(String role, String activePath) {
    final path = activePath.isNotEmpty ? activePath : (widget.currentPath ?? '');
    if (path.startsWith('/fees/reports')) return 'View and manage fee collections and reports';
    if (path.startsWith('/fees/dashboard')) return 'Overview of institutional fee collections & metrics';
    if (path.startsWith('/fees/student-payments')) return 'Audit and verify student fee payment submissions';
    if (path.startsWith('/fees/uploaded-files')) return 'Review student-uploaded screenshots & transaction proofs';
    if (path.startsWith('/fees/record-payment')) return 'Record direct physical counter and DD payments';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final role = context.watch<AuthProvider>().role ?? 'STUDENT';

    String activePath = widget.currentPath ?? '';
    try {
      activePath = GoRouterState.of(context).uri.path;
    } catch (_) {}

    final pageTitle = _resolveTitle(role, activePath);
    final pageSubtitle = _resolveSubtitle(role, activePath);

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            RoleSidebar(
              role: role,
              collapsed: _isSidebarCollapsed,
              currentPath: activePath,
            ),
            Expanded(
              child: Column(
                children: [
                  RoleHeader(
                    title: pageTitle,
                    subtitle: pageSubtitle,
                    onMenuTap: () {},
                  ),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Transform.translate(
            offset: const Offset(0, 8),
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF13246E),
              child: Icon(
                _isSidebarCollapsed
                    ? Icons.arrow_forward_ios
                    : Icons.arrow_back_ios,
                size: 14,
              ),
              onPressed: () =>
                  setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      );
    } else {
      return Scaffold(
        key: _scaffoldKey,
        appBar: RoleHeader(
          title: pageTitle,
          subtitle: pageSubtitle,
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        drawer: Drawer(
          width: screenWidth < 320 ? screenWidth * 0.85 : 260,
          backgroundColor: Colors.transparent,
          child: RoleSidebar(
            role: role,
            collapsed: false,
            currentPath: activePath,
          ),
        ),
        body: widget.child,
      );
    }
  }
}
