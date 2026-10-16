import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/screens/landing_page.dart';
import 'package:frontend/features/reports/screens/reports_screen.dart';
import 'package:frontend/features/auth/screens/login_page.dart';
import 'package:frontend/features/auth/screens/forgot_password_page.dart';
import 'package:frontend/features/auth/screens/setup_password_screen.dart';
import 'package:frontend/features/dashboard/screens/dashboard_screen.dart';
import 'package:frontend/features/profile/screens/profile_screen.dart';
import 'package:frontend/shared/shell/responsive_shell.dart';
import 'package:frontend/shared/screens/placeholder_screen.dart';
import 'package:frontend/features/hod_assignment/screens/assign_hod_screen.dart';

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
import 'package:frontend/features/attendance/screens/mark_attendance_screen.dart';

// Admissions & Students
import 'package:frontend/features/admissions/screens/student_registration_screen.dart';
import 'package:frontend/features/admissions/screens/student_list_screen.dart';

// IA Assessment
import 'package:frontend/features/ia_assessment/screens/ia_marks_screen.dart';

// Subjects
import 'package:frontend/features/subjects/screens/subject_list_screen.dart';
import 'package:frontend/features/subjects/screens/subject_add_screen.dart';
import 'package:frontend/features/subjects/screens/assign_subject_screen.dart';

// Academics & Department
import 'package:frontend/features/academics/screens/department_screen.dart';

// Attendance Monitoring
import 'package:frontend/features/attendance/screens/attendance_monitoring_screen.dart';

// HOD IA Performance
import 'package:frontend/features/ia_assessment/screens/hod_ia_performance_screen.dart';

// HOD Reports
import 'package:frontend/features/reports/screens/hod_reports_screen.dart';

// Announcements
import 'package:frontend/features/announcements/screens/department_announcements_screen.dart';
import 'package:frontend/features/announcements/screens/campus_announcements_screen.dart';

// Student Features & Notifications
import 'package:frontend/features/notifications/screens/notifications_screen.dart';
import 'package:frontend/features/ia_assessment/screens/student_ia_marks_screen.dart';
import 'package:frontend/features/students/screens/student_results_screen.dart';
import 'package:frontend/features/students/screens/student_grievances_screen.dart';
import 'package:frontend/features/students/screens/student_academic_status_screen.dart';
import 'package:frontend/features/library/screens/library_screen.dart';
import 'package:frontend/features/library/screens/library_officer_dashboard.dart';
import 'package:frontend/features/library/screens/add_book_screen.dart';
import 'package:frontend/features/library/screens/issue_book_screen.dart';
import 'package:frontend/features/library/screens/book_catalogue_screen.dart';
import 'package:frontend/features/library/screens/issue_return_desk_screen.dart';
import 'package:frontend/features/library/screens/book_requests_screen.dart';
import 'package:frontend/features/library/screens/fines_dues_screen.dart';
import 'package:frontend/features/library/screens/library_notifications_screen.dart';
import 'package:frontend/features/library/screens/library_cards_desk_screen.dart';
import 'package:frontend/features/library/screens/create_library_card_screen.dart';
import 'package:frontend/features/library/screens/hod_library_cards_screen.dart';
import 'package:frontend/features/library/screens/library_configuration_screen.dart';
import 'package:frontend/features/library/screens/borrowers_screen.dart';
import 'package:frontend/features/library/screens/issue_history_screen.dart';
import 'package:frontend/features/library/screens/library_feedback_screen.dart';
import 'package:frontend/features/library/screens/library_reports_screen.dart';

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
            location.startsWith('/setup-password') ||
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
          path: '/setup-password',
          builder: (c, s) => SetupPasswordScreen(
            token: s.uri.queryParameters['token'],
          ),
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
          builder: (context, state, child) => ResponsiveShell(
            currentPath: state.uri.path,
            child: child,
          ),
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
              path: '/fees/pay/:id',
              builder: (c, s) => FeePaymentScreen(
                feeId: int.parse(s.pathParameters['id']!),
              ),
            ),
            GoRoute(
              path: '/timetable',
              redirect: (context, state) {
                final auth = provider.Provider.of<AuthProvider>(context, listen: false);
                final role = (auth.role ?? '').toUpperCase();
                if (role == AppRoles.professor) {
                  return '/timetable/my-schedule';
                }
                return '/timetable/list';
              },
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
              path: '/faculty',
              redirect: (context, state) => '/faculty/list',
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
              path: '/attendance',
              redirect: (c, s) => '/attendance/faculty',
            ),
            GoRoute(
              path: '/attendance/faculty',
              builder: (c, s) => const FacultyAttendanceDashboard(),
            ),
            GoRoute(
              path: '/attendance/monitoring',
              builder: (c, s) => const AttendanceMonitoringScreen(),
            ),
            GoRoute(
              path: '/attendance/department',
              builder: (c, s) => const AttendanceMonitoringScreen(),
            ),
            GoRoute(
              path: '/attendance/mark/:slotId',
              builder: (c, s) {
                final slotId = int.tryParse(s.pathParameters['slotId'] ?? '') ?? 0;
                final subjectName = s.extra as String?;
                return MarkAttendanceScreen(
                  timetableSlotId: slotId,
                  subjectName: subjectName,
                );
              },
            ),
            GoRoute(
              path: '/attendance/student',
              builder: (c, s) => const StudentAttendanceView(),
            ),
            GoRoute(
              path: '/ia/performance',
              builder: (c, s) => const HODIAPerformanceScreen(),
            ),
            GoRoute(
              path: '/reports/department',
              builder: (c, s) => const HODReportsScreen(),
            ),
            GoRoute(
              path: '/announcements/department',
              builder: (c, s) => const DepartmentAnnouncementsScreen(),
            ),
            GoRoute(
              path: '/announcements/campus',
              builder: (c, s) => const CampusAnnouncementsScreen(),
            ),
            GoRoute(
              path: '/announcements/student',
              builder: (c, s) => const NotificationsScreen(),
            ),
            GoRoute(
              path: '/notifications',
              builder: (c, s) => const NotificationsScreen(),
            ),
            GoRoute(
              path: '/ia/student',
              builder: (c, s) => const StudentIAMarksScreen(),
            ),
            GoRoute(
              path: '/student/results',
              builder: (c, s) => const StudentResultsScreen(),
            ),
            GoRoute(
              path: '/student/grievances',
              builder: (c, s) => const StudentGrievancesScreen(),
            ),
            GoRoute(
              path: '/student/academic-status',
              builder: (c, s) => const StudentAcademicStatusScreen(),
            ),
            GoRoute(
              path: '/ia/create/:subjectId',
              builder: (c, s) {
                final subjectId = int.tryParse(s.pathParameters['subjectId'] ?? '') ?? 0;
                final subjectName = s.extra as String?;
                return IAMarksScreen(
                  subjectId: subjectId,
                  subjectName: subjectName,
                );
              },
            ),
            GoRoute(
              path: '/library',
              builder: (c, s) {
                final auth = provider.Provider.of<AuthProvider>(c, listen: false);
                final role = auth.role?.toUpperCase() ?? '';
                if (role == 'LIBRARY') {
                  return const LibraryOfficerDashboard();
                }
                return const LibraryScreen();
              },
            ),
            GoRoute(
              path: '/library/officer',
              builder: (c, s) => const LibraryOfficerDashboard(),
            ),
            GoRoute(
              path: '/library/catalog',
              builder: (c, s) => const BookCatalogueScreen(),
            ),
            GoRoute(
              path: '/library/desk',
              builder: (c, s) => const IssueReturnDeskScreen(),
            ),
            GoRoute(
              path: '/library/requests',
              builder: (c, s) => const BookRequestsScreen(),
            ),
            GoRoute(
              path: '/library/fines',
              builder: (c, s) => const FinesDuesScreen(),
            ),
            GoRoute(
              path: '/library/books/add',
              builder: (c, s) => const AddBookScreen(),
            ),
            GoRoute(
              path: '/library/issue-book',
              builder: (c, s) {
                final bookIdStr = s.uri.queryParameters['bookId'];
                final bookId = bookIdStr != null ? int.tryParse(bookIdStr) : null;
                return IssueBookScreen(preselectedBookId: bookId);
              },
            ),
            GoRoute(
              path: '/library/cards',
              builder: (c, s) => const LibraryCardsDeskScreen(),
            ),
            GoRoute(
              path: '/library/cards/create',
              builder: (c, s) {
                final cardIdStr = s.uri.queryParameters['cardId'];
                final cardId = cardIdStr != null ? int.tryParse(cardIdStr) : null;
                final identifier = s.uri.queryParameters['identifier'];
                final borrowerType = s.uri.queryParameters['borrowerType'];
                return CreateLibraryCardScreen(
                  existingCardId: cardId,
                  initialIdentifier: identifier,
                  initialBorrowerType: borrowerType,
                );
              },
            ),
            GoRoute(
              path: '/library/notifications',
              builder: (c, s) => const LibraryNotificationsScreen(),
            ),
            GoRoute(
              path: '/library/configuration',
              builder: (c, s) => const LibraryConfigurationScreen(),
            ),
            GoRoute(
              path: '/library/borrowers',
              builder: (c, s) => const BorrowersScreen(),
            ),
            GoRoute(
              path: '/library/history',
              builder: (c, s) => const IssueHistoryScreen(),
            ),
            GoRoute(
              path: '/library/feedback',
              builder: (c, s) => const LibraryFeedbackScreen(),
            ),
            GoRoute(
              path: '/library/reports',
              builder: (c, s) => const LibraryReportsScreen(),
            ),
            GoRoute(
              path: '/hod/library-cards',
              builder: (c, s) => const HodLibraryCardsScreen(),
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
              builder: (c, s) => const ReportsScreen(),
            ),
            GoRoute(
              path: '/academics',
              builder: (c, s) => const DepartmentScreen(),
            ),
            GoRoute(
              path: '/staff',
              builder: (c, s) =>
                  const PlaceholderScreen(title: 'Staff Directory'),
            ),
            GoRoute(
              path: '/approvals',
              builder: (c, s) => const StudentListScreen(),
            ),
            GoRoute(
              path: '/subjects',
              builder: (c, s) => const SubjectListScreen(),
            ),
            GoRoute(
              path: '/subjects/add',
              builder: (c, s) => const SubjectAddScreen(),
            ),
            GoRoute(
              path: '/subjects/assign',
              builder: (c, s) => const AssignSubjectScreen(),
            ),
            GoRoute(
              path: '/hod/assign',
              builder: (c, s) => const AssignHodScreen(),
            ),
            GoRoute(
              path: '/admissions/list',
              builder: (c, s) => const StudentListScreen(),
            ),
            
          ],
        ),
      ],
    );
  }
}

