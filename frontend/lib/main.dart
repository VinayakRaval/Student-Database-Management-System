import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/screens/landing_page.dart';
import 'package:frontend/features/auth/screens/login_page.dart';
import 'package:frontend/features/auth/screens/forgot_password_page.dart';
import 'package:frontend/features/dashboard/screens/dashboard_screen.dart';
import 'package:frontend/features/profile/screens/profile_screen.dart';
import 'package:frontend/shared/shell/responsive_shell.dart';
import 'package:frontend/shared/screens/placeholder_screen.dart';

// Fee
import 'package:frontend/features/fees/screens/fee_structure_list_screen.dart';
import 'package:frontend/features/fees/screens/fee_structure_detail_screen.dart';
import 'package:frontend/features/fees/screens/fee_structure_create_screen.dart';
import 'package:frontend/features/fees/screens/student_fee_list_screen.dart';
import 'package:frontend/features/fees/screens/student_payment_verification_screen.dart';
import 'package:frontend/features/fees/screens/fee_payment_upload_screen.dart';

// Timetable
import 'package:frontend/features/timetable/screens/timetable_list_screen.dart';
import 'package:frontend/features/timetable/screens/timetable_detail_screen.dart';
import 'package:frontend/features/timetable/screens/timetable_create_screen.dart';
import 'package:frontend/features/timetable/screens/timetable_edit_screen.dart';
import 'package:frontend/features/timetable/screens/faculty_schedule_screen.dart';

// Faculty
import 'package:frontend/features/faculty/screens/faculty_list_screen.dart';
import 'package:frontend/features/faculty/screens/faculty_detail_screen.dart';
import 'package:frontend/features/faculty/screens/faculty_registration_screen.dart';

// Attendance
import 'package:frontend/features/attendance/screens/faculty_attendance_dashboard.dart';
import 'package:frontend/features/attendance/screens/student_attendance_view.dart';

// Admissions
import 'package:frontend/features/admissions/screens/student_registration_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return provider.ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp.router(
        title: 'CampusFlow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: _buildRouter(),
      ),
    );
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final auth = provider.Provider.of<AuthProvider>(context, listen: false);
        final loggedIn = auth.isLoggedIn;
        final location = state.uri.toString();

        // Public routes — no auth needed
        if (location == '/' ||
            location == '/login' ||
            location == '/forgot-password' ||
            location == '/admissions/register' ||
            location == '/fee-upload' ||
            location.startsWith('/fee-upload')) {
          if (loggedIn &&
              (location == '/login' || location == '/forgot-password')) {
            return '/dashboard';
          }
          return null;
        }

        if (!loggedIn) return '/login';
        return null;
      },
      routes: [
        // PUBLIC ROUTES (no auth required)
        GoRoute(path: '/', builder: (c, s) => const LandingPage()),
        GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
        GoRoute(
          path: '/forgot-password',
          builder: (c, s) => const ForgotPasswordPage(),
        ),
        GoRoute(
          path: '/admissions/register',
          builder: (c, s) => const StudentRegistrationScreen(),
        ),
        GoRoute(
          path: '/fee-upload',
          builder: (c, s) => const FeePaymentScreen(feeId: 0),
        ),

        // AUTHENTICATED ROUTES (with sidebar)
        ShellRoute(
          builder: (context, state, child) => ResponsiveShell(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (c, s) => const DashboardScreen(),
            ),
            GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
            GoRoute(
              path: '/fees',
              builder: (c, s) => const FeeStructureListScreen(),
            ),
            GoRoute(
              path: '/fees/create',
              builder: (c, s) => const FeeStructureCreateScreen(),
            ),
            GoRoute(
              path: '/fees/detail/:id',
              builder: (c, s) => FeeStructureDetailScreen(
                id: int.parse(s.pathParameters['id']!),
              ),
            ),
            GoRoute(
              path: '/fees/edit/:id',
              builder: (c, s) => FeeStructureCreateScreen(
                feeId: int.parse(s.pathParameters['id']!),
              ),
            ),
            GoRoute(
              path: '/fees/my-fees',
              builder: (c, s) => const StudentFeeListScreen(),
            ),
            GoRoute(
              path: '/fees/student-payments',
              builder: (c, s) => const StudentPaymentVerificationScreen(),
            ),
            GoRoute(
              path: '/timetable/create',
              builder: (c, s) => const TimetableCreateScreen(),
            ),
            GoRoute(
              path: '/timetable/list',
              builder: (c, s) => const TimetableListScreen(),
            ),
            GoRoute(
              path: '/timetable/approvals',
              builder: (c, s) =>
                  const TimetableListScreen(filterType: 'pending'),
            ),
            GoRoute(
              path: '/timetable/detail/:id',
              builder: (c, s) =>
                  TimetableDetailScreen(id: int.parse(s.pathParameters['id']!)),
            ),
            GoRoute(
              path: '/timetable/edit/:id',
              builder: (c, s) =>
                  TimetableEditScreen(id: int.parse(s.pathParameters['id']!)),
            ),
            GoRoute(
              path: '/timetable/my-schedule',
              builder: (c, s) => const FacultyScheduleScreen(),
            ),
            GoRoute(
              path: '/faculty/register',
              builder: (c, s) => const FacultyRegistrationScreen(),
            ),
            GoRoute(
              path: '/faculty/list',
              builder: (c, s) => const FacultyListScreen(),
            ),
            GoRoute(
              path: '/faculty/approvals',
              builder: (c, s) => const FacultyListScreen(
                filterType: 'pending',
                customTitle: 'Faculty Approvals',
              ),
            ),
            GoRoute(
              path: '/faculty/detail/:id',
              builder: (c, s) =>
                  FacultyDetailScreen(id: int.parse(s.pathParameters['id']!)),
            ),
            GoRoute(
              path: '/attendance/faculty',
              builder: (c, s) => const FacultyAttendanceDashboard(),
            ),
            GoRoute(
              path: '/attendance/student',
              builder: (c, s) => const StudentAttendanceView(),
            ),
            GoRoute(
              path: '/library',
              builder: (c, s) => const PlaceholderScreen(title: 'Library'),
            ),
            GoRoute(
              path: '/exams',
              builder: (c, s) => const PlaceholderScreen(title: 'Exam Cell'),
            ),
            GoRoute(
              path: '/scholarships',
              builder: (c, s) => const PlaceholderScreen(title: 'Scholarships'),
            ),
            GoRoute(
              path: '/reports',
              builder: (c, s) => const PlaceholderScreen(title: 'Reports'),
            ),
            GoRoute(
              path: '/academics',
              builder: (c, s) => const PlaceholderScreen(title: 'Academics'),
            ),
            GoRoute(
              path: '/staff',
              builder: (c, s) =>
                  const PlaceholderScreen(title: 'Staff Directory'),
            ),
            GoRoute(
              path: '/approvals',
              builder: (c, s) => const PlaceholderScreen(title: 'Approvals'),
            ),
            GoRoute(
              path: '/subjects',
              builder: (c, s) => const PlaceholderScreen(title: 'Subjects'),
            ),
            GoRoute(
              path: '/subjects/add',
              builder: (c, s) => const PlaceholderScreen(title: 'Add Subject'),
            ),
            GoRoute(
              path: '/subjects/assign',
              builder: (c, s) =>
                  const PlaceholderScreen(title: 'Assign Subjects'),
            ),
            GoRoute(
              path: '/hod/assign',
              builder: (c, s) => const PlaceholderScreen(title: 'Assign HODs'),
            ),
            GoRoute(
              path: '/admissions/list',
              builder: (c, s) => const PlaceholderScreen(title: 'Student List'),
            ),
          ],
        ),
      ],
    );
  }
}
