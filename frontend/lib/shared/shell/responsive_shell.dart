import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/dashboard/widgets/role_sidebar.dart';
import 'package:frontend/features/dashboard/widgets/role_header.dart';

class ResponsiveShell extends StatefulWidget {
  final Widget child;
  const ResponsiveShell({super.key, required this.child});

  @override
  State<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends State<ResponsiveShell> {
  bool _isSidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final role = context.watch<AuthProvider>().role ?? 'STUDENT';

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            RoleSidebar(role: role, collapsed: _isSidebarCollapsed),
            Expanded(
              child: Column(
                children: [
                  RoleHeader(title: "Dashboard", onMenuTap: () {}),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(left: 20),
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
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      );
    } else {
      return Scaffold(
        key: _scaffoldKey,
        appBar: RoleHeader(
          title: "Dashboard",
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        drawer: Drawer(
          width: 260,
          backgroundColor: Colors.transparent,
          child: RoleSidebar(role: role, collapsed: false),
        ),
        body: widget.child,
      );
    }
  }
}
