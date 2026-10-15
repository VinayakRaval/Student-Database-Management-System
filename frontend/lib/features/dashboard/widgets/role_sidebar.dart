import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/role_menus.dart';

class RoleSidebar extends StatefulWidget {
  final String role;
  final bool collapsed;

  const RoleSidebar({super.key, required this.role, this.collapsed = false});

  @override
  State<RoleSidebar> createState() => _RoleSidebarState();
}

class _RoleSidebarState extends State<RoleSidebar> {
  final Color brandBlue = const Color(0xFF13246E);
  final Color gradientStart = const Color(0xFF2E3AB5);
  final Color gradientEnd = const Color(0xFF13246E);

  Map<int, bool> expanded = {};

  @override
  Widget build(BuildContext context) {
    final menu = RoleMenus.getMenu(widget.role);
    final double width = widget.collapsed ? 80 : 260;
    final String currentRoute = GoRouterState.of(context).uri.toString();

    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientStart, gradientEnd],
        ),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(40)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 30),
          widget.collapsed
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Icon(Icons.school, size: 36, color: Colors.white),
                )
              : const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "CampusFlow",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                    ],
                  ),
                ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: menu.length,
              itemBuilder: (context, index) {
                final item = menu[index];
                final hasChildren =
                    item.containsKey('children') &&
                    (item['children'] as List).isNotEmpty;
                bool isSelected = currentRoute == item['route'];
                if (hasChildren) {
                  for (var child in item['children']) {
                    if (currentRoute == child['route']) isSelected = true;
                  }
                }

                return Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        item['icon'],
                        size: 22,
                        color: Colors.white70,
                      ),
                      title: widget.collapsed
                          ? null
                          : Text(
                              item['title'],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                      trailing: (!widget.collapsed && hasChildren)
                          ? Icon(
                              (expanded[index] ?? false)
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.white54,
                              size: 18,
                            )
                          : null,
                      selected: isSelected,
                      selectedTileColor: Colors.white.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: widget.collapsed ? 0 : 12,
                      ),
                      onTap: () {
                        if (hasChildren) {
                          setState(
                            () => expanded[index] = !(expanded[index] ?? false),
                          );
                          if (item['route'] != null && item['route'] != currentRoute) {
                            context.go(item['route']);
                          }
                        } else {
                          context.go(item['route']);
                        }
                      },
                    ),
                    if (!widget.collapsed &&
                        hasChildren &&
                        (expanded[index] ?? false))
                      Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: Column(
                          children: (item['children'] as List).map<Widget>((
                            child,
                          ) {
                            final isChildActive =
                                currentRoute == child['route'];
                            return ListTile(
                              leading: Icon(
                                child['icon'],
                                size: 16,
                                color: Colors.white54,
                              ),
                              title: Text(
                                child['title'],
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              selected: isChildActive,
                              selectedTileColor: Colors.white.withValues(
                                alpha: 0.05,
                              ),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              onTap: () => context.go(child['route']),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
