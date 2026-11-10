path_main = r"D:\student-data-management-system\frontend\lib\main.dart"
with open(path_main, "r", encoding="utf-8") as f:
    text_main = f.read()

import_code = """// Corrections
import 'package:frontend/features/corrections/screens/correction_center_screen.dart';
import 'package:frontend/features/corrections/screens/new_correction_request_screen.dart';
import 'package:frontend/features/corrections/screens/correction_detail_screen.dart';
import 'package:frontend/features/corrections/screens/correction_review_screen.dart';
"""

if "correction_center_screen.dart" not in text_main:
    text_main = import_code + text_main

routes_code = """            GoRoute(
              path: '/student/corrections',
              builder: (c, s) => const CorrectionCenterScreen(),
            ),
            GoRoute(
              path: '/student/corrections/new',
              builder: (c, s) => const NewCorrectionRequestScreen(),
            ),
            GoRoute(
              path: '/student/corrections/detail/:id',
              builder: (c, s) {
                final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
                return CorrectionDetailScreen(requestId: id);
              },
            ),
            GoRoute(
              path: '/corrections/review',
              builder: (c, s) => const CorrectionReviewScreen(),
            ),
"""

target_routes = """            GoRoute(
              path: '/admissions/notifications',
              builder: (c, s) => const AdmissionNotificationsScreen(),
            ),"""

if "student/corrections" not in text_main:
    text_main = text_main.replace(target_routes, target_routes + "\n" + routes_code, 1)

with open(path_main, "w", encoding="utf-8") as f:
    f.write(text_main)
print("main.dart updated.")

# Update role_menus.dart
path_menus = r"D:\student-data-management-system\frontend\lib\features\dashboard\config\role_menus.dart"
with open(path_menus, "r", encoding="utf-8") as f:
    text_menus = f.read()

# Add to student
target_stu_menu = "{'title': 'Grievances', 'icon': Icons.support_agent_rounded, 'route': '/student/grievances'},"
rep_stu_menu = "{'title': 'Correction Center', 'icon': Icons.rule_rounded, 'route': '/student/corrections'},\n          {'title': 'Grievances', 'icon': Icons.support_agent_rounded, 'route': '/student/grievances'},"

# Try with double/single quotes formatting
if "'route': '/student/grievances'" in text_menus and "student/corrections" not in text_menus:
    idx = text_menus.find("'route': '/student/grievances'")
    # Find start of that map
    map_start = text_menus.rfind("{", 0, idx)
    insertion = """{
            'title': 'Correction Center',
            'icon': Icons.rule_rounded,
            'route': '/student/corrections',
          },
          """
    text_menus = text_menus[:map_start] + insertion + text_menus[map_start:]
    print("student menu updated.")

# Add to HOD hod_access section
if "'route': '/hod/library-cards'" in text_menus and "corrections/review" not in text_menus:
    idx = text_menus.find("'route': '/hod/library-cards'")
    # Find end of that map
    map_end = text_menus.find("},", idx) + 2
    insertion = """
          {
            'title': 'Correction Requests',
            'icon': Icons.rule_rounded,
            'route': '/corrections/review',
            'section': 'hod_access',
          },"""
    text_menus = text_menus[:map_end] + insertion + text_menus[map_end:]
    print("HOD menu updated.")

with open(path_menus, "w", encoding="utf-8") as f:
    f.write(text_menus)

# Update responsive_shell.dart
path_shell = r"D:\student-data-management-system\frontend\lib\shared\shell\responsive_shell.dart"
with open(path_shell, "r", encoding="utf-8") as f:
    text_shell = f.read()

target_shell = "if (path.startsWith('/grievances') || path.startsWith('/student/grievances')) return 'Grievances';"
rep_shell = "if (path.startsWith('/student/corrections')) return 'Correction Center';\n    if (path.startsWith('/corrections/review')) return 'Correction Requests Review';\n    if (path.startsWith('/grievances') || path.startsWith('/student/grievances')) return 'Grievances';"

if target_shell in text_shell and "corrections" not in text_shell:
    text_shell = text_shell.replace(target_shell, rep_shell, 1)
    with open(path_shell, "w", encoding="utf-8") as f:
        f.write(text_shell)
    print("responsive_shell.dart updated.")
