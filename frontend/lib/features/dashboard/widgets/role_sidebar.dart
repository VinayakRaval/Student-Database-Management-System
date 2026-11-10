import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/notification_count_manager.dart';
import '../config/role_menus.dart';

class RoleSidebar extends StatefulWidget {
  final String role;
  final bool collapsed;
  final String? currentPath;

  const RoleSidebar({
    super.key,
    required this.role,
    this.collapsed = false,
    this.currentPath,
  });

  @override
  State<RoleSidebar> createState() => _RoleSidebarState();
}

class _RoleSidebarState extends State<RoleSidebar> {
  // Theme: Deep Royal Navy Blue Sidebar with Stadium Capsule Pills
  static const Color sidebarNavy = Color(0xFF0F2577);
  static const Color pillUnselectedBg = Color(0xFFE8EEF5);
  static const Color pillUnselectedText = Color(0xFF1E293B);
  static const Color pillSelectedBg = Colors.white;
  static const Color pillSelectedText = Color(0xFF0F2577);

  static final Map<String, bool> _staticExpanded = {};
  static final Set<String> _staticUserCollapsed = {};
  static final Map<String, bool> _staticSectionExpanded = {
    'faculty_access': true,
    'hod_access': true,
  };
  String? _lastRoute;

  @override
  void initState() {
    super.initState();
    NotificationCountManager.instance.addListener(_onNotificationCountChanged);
    NotificationCountManager.instance.refresh();
  }

  @override
  void dispose() {
    NotificationCountManager.instance.removeListener(_onNotificationCountChanged);
    super.dispose();
  }

  void _onNotificationCountChanged() {
    if (mounted) setState(() {});
  }

  /// Finds the best (most specific/exact) matching menu route for the current URL path
  String? _findBestMatchingRoute(List<Map<String, dynamic>> menu, String currentPath) {
    if (currentPath.isEmpty) return null;
    String cleanCurrent = currentPath.split('?').first.split('#').first;
    if (cleanCurrent.endsWith('/') && cleanCurrent.length > 1) {
      cleanCurrent = cleanCurrent.substring(0, cleanCurrent.length - 1);
    }

    String? bestRoute;
    int bestScore = -1;

    void evaluateRoute(String? route) {
      if (route == null || route.isEmpty) return;
      String cleanTarget = route.split('?').first.split('#').first;
      if (cleanTarget.endsWith('/') && cleanTarget.length > 1) {
        cleanTarget = cleanTarget.substring(0, cleanTarget.length - 1);
      }

      // Exact match gets highest priority
      if (cleanCurrent == cleanTarget) {
        final score = 10000 + cleanTarget.length;
        if (score > bestScore) {
          bestScore = score;
          bestRoute = route;
        }
        return;
      }

      // Root or Dashboard exact match
      if (cleanTarget == '/dashboard' || cleanTarget == '/') {
        if (cleanCurrent == '/dashboard' || cleanCurrent == '/' || cleanCurrent.isEmpty) {
          final score = 1000 + cleanTarget.length;
          if (score > bestScore) {
            bestScore = score;
            bestRoute = route;
          }
        }
        return;
      }

      // Nested subpage matching (e.g. /fees/detail/1 under /fees)
      // Only match if cleanCurrent starts with cleanTarget + '/'
      if (cleanCurrent.startsWith('$cleanTarget/')) {
        final score = cleanTarget.length;
        if (score > bestScore) {
          bestScore = score;
          bestRoute = route;
        }
      }
    }

    for (final item in menu) {
      if (item['isSectionHeader'] == true) continue;
      evaluateRoute(item['route']);
      if (item['children'] is List) {
        for (final child in item['children']) {
          evaluateRoute(child['route']);
        }
      }
    }

    return bestRoute;
  }

  @override
  Widget build(BuildContext context) {
    final menu = RoleMenus.getMenu(widget.role);
    final double width = widget.collapsed ? 80 : 270;

    String currentPath = widget.currentPath ?? '';
    if (currentPath.isEmpty) {
      try {
        currentPath = GoRouterState.of(context).uri.path;
      } catch (_) {
        try {
          currentPath = GoRouterState.of(context).uri.toString();
        } catch (_) {}
      }
    }

    final String? bestRoute = _findBestMatchingRoute(menu, currentPath);
    if (_lastRoute != bestRoute) {
      _lastRoute = bestRoute;

      // Auto-expand section and parent menu that contains the active route ONLY on route change
      // Automatically close any expanded dropdown menu when user navigates outside that dropdown.
      // Keep dropdown expanded ONLY when the currently active page belongs to that dropdown.
      for (final item in menu) {
        if (item['children'] is List) {
          final String mKey = (item['title'] ?? item['route'] ?? '').toString();
          bool activeChildFound = false;
          for (final child in item['children']) {
            if (child['route'] != null && child['route'] == bestRoute) {
              activeChildFound = true;
              break;
            }
          }

          if (activeChildFound) {
            _staticExpanded[mKey] = true;
            _staticUserCollapsed.remove(mKey);
            final sec = item['section']?.toString();
            if (sec != null && _staticSectionExpanded[sec] != true) {
              _staticSectionExpanded[sec] = true;
            }
          } else {
            // Automatically close dropdown because active page is outside this dropdown!
            _staticExpanded[mKey] = false;
            _staticUserCollapsed.add(mKey);
          }
        }
      }
    }

    final int unreadCount = NotificationCountManager.instance.unreadCount;

    return Container(
      width: width,
      color: Colors.white, // White top area matching Image 1
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Branding Header: "CampusFlow" bold navy on white background
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.collapsed ? 14 : 22,
              22,
              widget.collapsed ? 14 : 22,
              18,
            ),
            child: widget.collapsed
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: sidebarNavy.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "CF",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: sidebarNavy,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  )
                : const Row(
                    children: [
                      Text(
                        "CampusFlow",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: sidebarNavy,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
          ),

          // Deep Blue Sidebar Container starting below "CampusFlow" with rounded top-right corner
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: sidebarNavy,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(28),
                ),
              ),
              child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 80),
              itemCount: menu.length,
              itemBuilder: (context, index) {
                final item = menu[index];

                // Render Expandable Section Headers (e.g. Faculty Access, HOD Access)
                if (item['isSectionHeader'] == true) {
                  final String secKey = item['sectionKey']?.toString() ?? '';
                  final bool isSecExpanded = _staticSectionExpanded[secKey] ?? true;

                  if (widget.collapsed) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _staticSectionExpanded[secKey] = !isSecExpanded;
                          });
                        },
                        child: Tooltip(
                          message: "${item['title']} (${isSecExpanded ? 'Expanded' : 'Collapsed'})",
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            alignment: Alignment.center,
                            child: Icon(
                              item['icon'] as IconData? ?? Icons.folder_rounded,
                              size: 18,
                              color: isSecExpanded ? const Color(0xFF93C5FD) : Colors.white38,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            _staticSectionExpanded[secKey] = !isSecExpanded;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSecExpanded
                                ? const Color(0x24FFFFFF)
                                : const Color(0x12FFFFFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSecExpanded ? const Color(0x3D93C5FD) : Colors.white12,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item['icon'] as IconData? ?? Icons.folder_rounded,
                                size: 17,
                                color: isSecExpanded ? const Color(0xFF93C5FD) : Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  (item['title'] ?? '').toString().toUpperCase(),
                                  style: TextStyle(
                                    color: isSecExpanded ? Colors.white : Colors.white70,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    letterSpacing: 0.9,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              AnimatedRotation(
                                turns: isSecExpanded ? 0.0 : -0.25,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: isSecExpanded ? Colors.white : Colors.white60,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                // If this item belongs to a collapsed section, hide it smoothly
                final String? itemSec = item['section']?.toString();
                if (itemSec != null) {
                  final bool isSecExpanded = _staticSectionExpanded[itemSec] ?? true;
                  if (!isSecExpanded) {
                    return const SizedBox.shrink();
                  }
                }

                final hasChildren =
                    item.containsKey('children') &&
                    (item['children'] as List).isNotEmpty;

                final String menuKey = (item['title'] ?? item['route'] ?? '$index').toString();

                final bool isParentActive = item['route'] != null && item['route'] == bestRoute;
                bool isAnyChildActive = false;
                if (hasChildren) {
                  for (var child in item['children']) {
                    if (child['route'] != null && child['route'] == bestRoute) {
                      isAnyChildActive = true;
                      break;
                    }
                  }
                }

                final bool isSelected = isParentActive || isAnyChildActive;

                // Keep dropdown expanded ONLY when currently active page belongs to that dropdown
                if (isAnyChildActive) {
                  _staticExpanded[menuKey] = true;
                  _staticUserCollapsed.remove(menuKey);
                }

                final bool isCurrentlyExpanded = isAnyChildActive
                    ? true
                    : (_staticExpanded[menuKey] ?? false);

                final String itemRoute = (item['route'] ?? '').toString();
                final String itemTitle =
                    (item['title'] ?? '').toString().toLowerCase();
                final bool isNotifItem = itemRoute == '/fees/notifications' ||
                    itemRoute == '/notifications' ||
                    itemRoute == '/library/notifications' ||
                    itemTitle.contains('directive') ||
                    itemTitle.contains('notification');
                final bool showBadge = isNotifItem && unreadCount > 0;

                return Column(
                  children: [
                    // Main Capsule Pill Item with 8px Active Forward Slide Animation
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5.5),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () {
                            if (hasChildren) {
                              setState(() {
                                if (isCurrentlyExpanded) {
                                  _staticExpanded[menuKey] = false;
                                  _staticUserCollapsed.add(menuKey);
                                } else {
                                  _staticExpanded[menuKey] = true;
                                  _staticUserCollapsed.remove(menuKey);
                                }
                              });
                            } else {
                              if (item['route'] != null) {
                                context.go(item['route']);
                              }
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            margin: EdgeInsets.only(
                              left: widget.collapsed
                                  ? (isSelected ? 6.0 : 0.0)
                                  : (isSelected ? 8.0 : 0.0), // Moves 8px forward to the right
                              right: widget.collapsed
                                  ? (isSelected ? 0.0 : 6.0)
                                  : (isSelected ? 0.0 : 8.0), // Preserves exact pill width
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.collapsed ? 0 : 14,
                              vertical: 10.5,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? pillSelectedBg : pillUnselectedBg,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.22),
                                        blurRadius: 10,
                                        offset: const Offset(3, 4),
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFF0F2577)
                                            .withValues(alpha: 0.15),
                                        blurRadius: 4,
                                        offset: const Offset(1, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: widget.collapsed
                                ? Center(
                                    child: (showBadge)
                                        ? Badge(
                                            label: Text("$unreadCount"),
                                            backgroundColor:
                                                const Color(0xFFDC2626),
                                            child: Icon(
                                              item['icon'],
                                              size: 21,
                                              color: isSelected
                                                  ? pillSelectedText
                                                  : pillUnselectedText,
                                            ),
                                          )
                                        : Icon(
                                            item['icon'],
                                            size: 21,
                                            color: isSelected
                                                  ? pillSelectedText
                                                  : pillUnselectedText,
                                          ),
                                  )
                                : Row(
                                    children: [
                                      Icon(
                                        item['icon'],
                                        size: 20,
                                        color: isSelected
                                            ? pillSelectedText
                                            : pillUnselectedText,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          item['title'],
                                          style: TextStyle(
                                            color: isSelected
                                                ? pillSelectedText
                                                : pillUnselectedText,
                                            fontWeight: isSelected
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            fontSize: 13.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (showBadge) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDC2626),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            "$unreadCount",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (hasChildren) ...[
                                        const SizedBox(width: 4),
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              setState(() {
                                                if (isCurrentlyExpanded) {
                                                  _staticExpanded[menuKey] = false;
                                                  _staticUserCollapsed.add(menuKey);
                                                } else {
                                                  _staticExpanded[menuKey] = true;
                                                  _staticUserCollapsed.remove(menuKey);
                                                }
                                              });
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                              child: Icon(
                                                isCurrentlyExpanded
                                                    ? Icons.expand_less_rounded
                                                    : Icons.expand_more_rounded,
                                                color: isSelected
                                                    ? pillSelectedText
                                                    : pillUnselectedText.withValues(alpha: 0.6),
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),

                    // Sub-items for menus with children (also slides 8px forward when active)
                    if (!widget.collapsed &&
                        hasChildren &&
                        isCurrentlyExpanded)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                        child: Column(
                          children: (item['children'] as List).map<Widget>((child) {
                            final isChildActive = child['route'] != null && child['route'] == bestRoute;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3.5),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(22),
                                  onTap: () => context.go(child['route']),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOutCubic,
                                    margin: EdgeInsets.only(
                                      left: isChildActive ? 28.0 : 20.0,
                                      right: isChildActive ? 2.0 : 10.0,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isChildActive
                                          ? Colors.white
                                          : const Color(0x22FFFFFF),
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: isChildActive
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.18),
                                                blurRadius: 6,
                                                offset: const Offset(2, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          child['icon'],
                                          size: 15,
                                          color: isChildActive
                                              ? pillSelectedText
                                              : Colors.white70,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            child['title'],
                                            style: TextStyle(
                                              color: isChildActive
                                                  ? pillSelectedText
                                                  : Colors.white,
                                              fontWeight: isChildActive
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              fontSize: 12.5,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    ),
  );
}
}
