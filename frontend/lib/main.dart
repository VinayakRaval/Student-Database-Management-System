// Placement
import 'package:frontend/features/placement/screens/principal_placement_officers_screen.dart';
import 'package:frontend/features/placement/screens/placement_officer_dashboard_screen.dart';
import 'package:frontend/features/placement/screens/placement_companies_screen.dart';
import 'package:frontend/features/placement/screens/placement_drives_screen.dart';
import 'package:frontend/features/placement/screens/placement_applications_screen.dart';
import 'package:frontend/features/placement/screens/placement_offers_screen.dart';
import 'package:frontend/features/placement/screens/placement_reports_screen.dart';
import 'package:frontend/features/placement/screens/student_placement_screen.dart';
// Corrections
import 'package:frontend/features/corrections/screens/correction_center_screen.dart';
import 'package:frontend/features/corrections/screens/new_correction_request_screen.dart';
import 'package:frontend/features/corrections/screens/correction_detail_screen.dart';
import 'package:frontend/features/corrections/screens/correction_review_screen.dart';
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
import 'package:frontend/features/auth/screens/sign_up_page.dart';
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
import 'package:frontend/features/fees/screens/accounts_dashboard_screen.dart';
import 'package:frontend/features/fees/screens/student_fee_management_screen.dart';
import 'package:frontend/features/fees/screens/record_payment_screen.dart';
import 'package:frontend/features/fees/screens/fee_reports_screen.dart';
import 'package:frontend/features/fees/screens/accounts_notifications_screen.dart';
import 'package:frontend/features/fees/screens/uploaded_payment_files_screen.dart';

// Timetable
import 'package:frontend/features/timetable/screens/timetable_list_screen.dart';
import 'package:frontend/features/timetable/screens/timetable_detail_screen.dart';
import 'package:frontend/features/timetable/screens/timetable_create_screen.dart';
import 'package:frontend/features/timetable/screens/timetable_edit_screen.dart';
import 'package:frontend/features/timetable/screens/faculty_schedule_screen.dart';
import 'package:frontend/features/timetable/screens/student_schedule_screen.dart';

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
import 'package:frontend/features/admissions/screens/admission_notifications_screen.dart';

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
import 'package:frontend/features/attendance/screens/extra_class_monitoring_screen.dart';

// HOD IA Performance
import 'package:frontend/features/ia_assessment/screens/hod_ia_performance_screen.dart';

// HOD Reports
import 'package:frontend/features/reports/screens/hod_reports_screen.dart';

// Faculty Screens
import 'package:frontend/features/faculty/screens/faculty_students_screen.dart';
import 'package:frontend/features/ia_assessment/screens/faculty_ia_assessment_screen.dart';
import 'package:frontend/features/reports/screens/faculty_reports_screen.dart';
import 'package:frontend/features/faculty/screens/faculty_give_work_screen.dart';
import 'package:frontend/features/faculty/screens/student_assignments_screen.dart';
import 'package:frontend/features/faculty/screens/faculty_lab_batches_screen.dart';
import 'package:frontend/features/faculty/screens/student_academic_history_screen.dart';

// Announcements
import 'package:frontend/features/announcements/screens/department_announcements_screen.dart';
import 'package:frontend/features/announcements/screens/campus_announcements_screen.dart';

// Student Features & Notifications
import 'package:frontend/features/notifications/screens/notifications_screen.dart';
import 'package:frontend/features/ia_assessment/screens/student_ia_marks_screen.dart';
import 'package:frontend/features/students/screens/student_results_screen.dart';
import 'package:frontend/features/grievances/screens/student_grievances_screen.dart';
import 'package:frontend/features/grievances/screens/officer_grievance_dashboard.dart';
import 'package:frontend/features/grievances/providers/grievance_provider.dart';
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
    return provider.MultiProvider(
      providers: [
        provider.ChangeNotifierProvider(create: (_) => AuthProvider()),
        provider.ChangeNotifierProvider(create: (_) => GrievanceProvider()),
      ],
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
            location == '/signup' ||
            location == '/register' ||
            location == '/forgot-password' ||
            location.startsWith('/setup-password') ||
            location == '/admissions/register' ||
            location == '/fee-upload' ||
            location.startsWith('/fee-upload')) {
          if (loggedIn &&
              (location == '/login' || location == '/signup' || location == '/register' || location == '/forgot-password')) {
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
        GoRoute(path: '/signup', builder: (c, s) => const SignUpPage()),
        GoRoute(path: '/register', builder: (c, s) => const SignUpPage()),
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
              redirect: (context, state) {
                final auth = provider.Provider.of<AuthProvider>(context, listen: false);
                final role = (auth.role ?? '').toUpperCase();
                if (role == AppRoles.accounts) {
                  return '/fees/dashboard';
                }
                if (role == AppRoles.placementOfficer) {
                  return '/placement/dashboard';
                }
                return null;
              },
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
              path: '/fees/uploaded-files',
              builder: (c, s) => const UploadedPaymentFilesScreen(),
            ),
            GoRoute(
              path: '/fees/pay/:id',
              builder: (c, s) => FeePaymentScreen(
                feeId: int.parse(s.pathParameters['id']!),
              ),
            ),
            GoRoute(
              path: '/fees/dashboard',
              builder: (c, s) => const AccountsDashboardScreen(),
            ),
            GoRoute(
              path: '/fees/students',
              builder: (c, s) => const StudentFeeManagementScreen(),
            ),
            GoRoute(
              path: '/fees/record-payment',
              builder: (c, s) {
                final feeIdStr = s.uri.queryParameters['feeId'];
                final feeId = feeIdStr != null ? int.tryParse(feeIdStr) : null;
                return RecordPaymentScreen(feeId: feeId);
              },
            ),
            GoRoute(
              path: '/fees/reports',
              builder: (c, s) {
                final tabStr = s.uri.queryParameters['tab'];
                final tabIndex = tabStr != null ? (int.tryParse(tabStr) ?? 0) : 0;
                return FeeReportsScreen(initialTab: tabIndex);
              },
            ),
            GoRoute(
              path: '/fees/notifications',
              builder: (c, s) => const AccountsNotificationsScreen(),
            ),
            GoRoute(
              path: '/timetable',
              redirect: (context, state) {
                final auth = provider.Provider.of<AuthProvider>(context, listen: false);
                final role = (auth.role ?? '').toUpperCase();
                if (role == AppRoles.professor) {
                  return '/timetable/my-schedule';
                }
                if (role == AppRoles.student) {
                  return '/timetable/student-schedule';
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
              path: '/timetable/student-schedule',
              builder: (c, s) => const StudentScheduleScreen(),
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
              path: '/faculty/students',
              builder: (c, s) => const FacultyStudentsScreen(),
            ),
            GoRoute(
              path: '/ia/faculty',
              builder: (c, s) => const FacultyIAAssessmentScreen(),
            ),
            GoRoute(
              path: '/faculty/reports',
              builder: (c, s) => const FacultyReportsScreen(),
            ),
            GoRoute(
              path: '/faculty/assignments',
              builder: (c, s) => const FacultyGiveWorkScreen(),
            ),
            GoRoute(
              path: '/faculty/lab-batches',
              builder: (c, s) => const FacultyLabBatchesScreen(),
            ),
            GoRoute(
              path: '/faculty/academic-history',
              builder: (c, s) {
                final search = s.uri.queryParameters['search'];
                return StudentAcademicHistoryScreen(initialSearch: search);
              },
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
              path: '/attendance/extra-class-monitoring',
              builder: (c, s) => const ExtraClassMonitoringScreen(),
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
              path: '/grievances',
              builder: (c, s) {
                final auth = provider.Provider.of<AuthProvider>(c, listen: false);
                final role = (auth.role ?? '').toUpperCase();
                if (role == AppRoles.student) {
                  return const StudentGrievancesScreen();
                }
                return const OfficerGrievanceDashboard();
              },
            ),
            GoRoute(
              path: '/student/academic-status',
              builder: (c, s) => const StudentAcademicStatusScreen(),
            ),
            GoRoute(
              path: '/student/assignments',
              builder: (c, s) => const StudentAssignmentsScreen(),
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
              builder: (c, s) => const SubjectListScreen(isDepartmentView: false),
            ),
            GoRoute(
              path: '/subjects/department',
              builder: (c, s) => const SubjectListScreen(isDepartmentView: true),
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
            GoRoute(
              path: '/admissions/notifications',
              builder: (c, s) => const AdmissionNotificationsScreen(),
            ),
            GoRoute(
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

            // Placement Routes
            GoRoute(
              path: '/principal/placement-officers',
              builder: (c, s) => const PrincipalPlacementOfficersScreen(),
            ),
            GoRoute(
              path: '/placement/dashboard',
              builder: (c, s) => const PlacementOfficerDashboardScreen(),
            ),
            GoRoute(
              path: '/placement/companies',
              builder: (c, s) => const PlacementCompaniesScreen(),
            ),
            GoRoute(
              path: '/placement/drives',
              builder: (c, s) => const PlacementDrivesScreen(),
            ),
            GoRoute(
              path: '/placement/applications',
              builder: (c, s) => PlacementApplicationsScreen(
                driveId: int.tryParse(s.uri.queryParameters['drive_id'] ?? ''),
              ),
            ),
            GoRoute(
              path: '/placement/offers',
              builder: (c, s) => const PlacementOffersScreen(),
            ),
            GoRoute(
              path: '/placement/reports',
              builder: (c, s) => const PlacementReportsScreen(),
            ),
            GoRoute(
              path: '/placement/students',
              builder: (c, s) => const PlacementApplicationsScreen(),
            ),
            GoRoute(
              path: '/student/placement',
              builder: (c, s) => const StudentPlacementScreen(),
            ),

            
          ],
        ),
      ],
    );
  }
}

