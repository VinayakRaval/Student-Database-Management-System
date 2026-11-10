import 'package:flutter/material.dart';
import 'package:frontend/core/constants/api_constants.dart';

class RoleMenus {
  static List<Map<String, dynamic>> getMenu(String role) {
    List<Map<String, dynamic>> menu = [
      {'title': 'HOME', 'icon': Icons.dashboard_rounded, 'route': '/dashboard'},
    ];

    switch (role) {
      // --- HOD ROLE (Refactored into 2 distinct expandable sections: Faculty Access & HOD Access) ---
      case AppRoles.hod:
        menu = [
          // ==================== 1. FACULTY ACCESS ====================
          // Personal teaching responsibilities (Subjects, classes, attendance, IA, timetable)
          {
            'isSectionHeader': true,
            'sectionKey': 'faculty_access',
            'title': 'Faculty Access',
            'icon': Icons.co_present_rounded,
          },
          {
            'title': 'Dashboard',
            'icon': Icons.dashboard_rounded,
            'route': '/dashboard',
            'section': 'faculty_access',
          },
          {
            'title': 'My Subjects',
            'icon': Icons.library_books_rounded,
            'route': '/subjects',
            'section': 'faculty_access',
          },
          {
            'title': 'My Students',
            'icon': Icons.people_alt_rounded,
            'route': '/faculty/students',
            'section': 'faculty_access',
          },
          {
            'title': 'Attendance',
            'icon': Icons.fact_check_rounded,
            'route': '/attendance/faculty',
            'section': 'faculty_access',
          },
          {
            'title': 'IA Assessment',
            'icon': Icons.assessment_rounded,
            'route': '/ia/faculty',
            'section': 'faculty_access',
          },
          {
            'title': 'Give Work',
            'icon': Icons.assignment_add,
            'route': '/faculty/assignments',
            'section': 'faculty_access',
          },
          {
            'title': 'My Timetable',
            'icon': Icons.schedule_rounded,
            'route': '/timetable/my-schedule',
            'section': 'faculty_access',
          },
          {
            'title': 'Academic Reports',
            'icon': Icons.analytics_rounded,
            'route': '/faculty/reports',
            'section': 'faculty_access',
          },

          // ==================== 2. HOD ACCESS ====================
          // Departmental management and administrative operations
          {
            'isSectionHeader': true,
            'sectionKey': 'hod_access',
            'title': 'HOD Access',
            'icon': Icons.admin_panel_settings_rounded,
          },
          {
            'title': 'My Department',
            'icon': Icons.business_rounded,
            'route': '/academics',
            'section': 'hod_access',
          },
          {
            'title': 'Department Subjects',
            'icon': Icons.menu_book_rounded,
            'route': '/subjects/department',
            'section': 'hod_access',
            'children': [
              {
                'title': 'All Department Subjects',
                'icon': Icons.list_alt_rounded,
                'route': '/subjects/department',
              },
              {
                'title': 'Add Subject',
                'icon': Icons.post_add_rounded,
                'route': '/subjects/add',
              },
              {
                'title': 'Assign Faculty',
                'icon': Icons.assignment_ind_rounded,
                'route': '/subjects/assign',
              },
            ],
          },
          {
            'title': 'Timetable Management',
            'icon': Icons.calendar_month_rounded,
            'route': '/timetable',
            'section': 'hod_access',
            'children': [
              {
                'title': 'Create New',
                'icon': Icons.add_alarm_rounded,
                'route': '/timetable/create',
              },
              {
                'title': 'Department Timetables',
                'icon': Icons.table_chart_rounded,
                'route': '/timetable/list',
              },
            ],
          },
          {
            'title': 'Attendance Monitoring',
            'icon': Icons.fact_check_outlined,
            'route': '/attendance/monitoring',
            'section': 'hod_access',
          },
          {
            'title': 'Lab Batches',
            'icon': Icons.biotech_rounded,
            'route': '/faculty/lab-batches',
            'section': 'hod_access',
          },
          {
            'title': 'Extra Class Monitoring',
            'icon': Icons.more_time_rounded,
            'route': '/attendance/extra-class-monitoring',
            'section': 'hod_access',
          },
          {
            'title': 'IA Performance',
            'icon': Icons.insights_rounded,
            'route': '/ia/performance',
            'section': 'hod_access',
          },
          {
            'title': 'Department Reports',
            'icon': Icons.assessment_rounded,
            'route': '/reports/department',
            'section': 'hod_access',
          },
          {
            'title': 'Faculty Management',
            'icon': Icons.school_rounded,
            'route': '/faculty',
            'section': 'hod_access',
            'children': [
              {
                'title': 'Register Faculty',
                'icon': Icons.person_add_rounded,
                'route': '/faculty/register',
              },
              {
                'title': 'Faculty List',
                'icon': Icons.list_alt_rounded,
                'route': '/faculty/list',
              },
            ],
          },
          {
            'title': 'Students List',
            'icon': Icons.people_alt_rounded,
            'route': '/admissions/list',
            'section': 'hod_access',
          },
          {
            'title': 'Student History',
            'icon': Icons.history_edu_rounded,
            'route': '/faculty/academic-history',
            'section': 'hod_access',
          },
          {
            'title': 'Library Card Approvals',
            'icon': Icons.badge_rounded,
            'route': '/hod/library-cards',
            'section': 'hod_access',
          },
          {
            'title': 'Correction Requests',
            'icon': Icons.rule_rounded,
            'route': '/corrections/review',
            'section': 'hod_access',
          },
          {
            'title': 'Announcements',
            'icon': Icons.campaign_rounded,
            'route': '/announcements/department',
            'section': 'hod_access',
          },
          {
            'title': 'Grievances',
            'icon': Icons.report_problem_rounded,
            'route': '/grievances',
            'section': 'hod_access',
          },
          {
            'title': 'Profile',
            'icon': Icons.person_rounded,
            'route': '/profile',
            'section': 'hod_access',
          },
        ];
        break;

      // --- FACULTY / PROFESSOR ROLE ---
      case AppRoles.professor:
        menu[0]['title'] = 'Dashboard';
        menu.addAll([
          {
            'title': 'My Subjects',
            'icon': Icons.library_books_rounded,
            'route': '/subjects',
          },
          {
            'title': 'My Students',
            'icon': Icons.people_alt_rounded,
            'route': '/faculty/students',
          },
          {
            'title': 'Student History',
            'icon': Icons.history_edu_rounded,
            'route': '/faculty/academic-history',
          },
          {
            'title': 'Timetable',
            'icon': Icons.calendar_month_rounded,
            'route': '/timetable/my-schedule',
          },
          {
            'title': 'Attendance',
            'icon': Icons.fact_check_rounded,
            'route': '/attendance/faculty',
          },
          {
            'title': 'Lab Batches',
            'icon': Icons.biotech_rounded,
            'route': '/faculty/lab-batches',
          },
          {
            'title': 'IA Assessment',
            'icon': Icons.assessment_rounded,
            'route': '/ia/faculty',
          },
          {
            'title': 'Give Work',
            'icon': Icons.assignment_add,
            'route': '/faculty/assignments',
          },
          {
            'title': 'Academic Reports',
            'icon': Icons.analytics_rounded,
            'route': '/faculty/reports',
          },
          {
            'title': 'Announcements & Notifications',
            'icon': Icons.campaign_rounded,
            'route': '/notifications',
          },
          {
            'title': 'Grievances',
            'icon': Icons.report_problem_rounded,
            'route': '/grievances',
          },
        ]);
        break;

      // --- PRINCIPAL ROLE ---
      case AppRoles.principal:
        menu.addAll([
          {
            'title': 'Grievance Governance',
            'icon': Icons.gavel_rounded,
            'route': '/grievances',
          },
          {
            'title': 'Approvals',
            'icon': Icons.approval_rounded,
            'route': '/approvals',
            'children': [
              {
                'title': 'Student Registrations',
                'icon': Icons.person_add_alt_1_rounded,
                'route': '/admissions/list',
              },
              {
                'title': 'Faculty Approvals',
                'icon': Icons.how_to_reg_rounded,
                'route': '/faculty/approvals',
              },
              {
                'title': 'Fee Approvals',
                'icon': Icons.monetization_on_rounded,
                'route': '/fees',
              },
              {
                'title': 'Timetable Approval',
                'icon': Icons.table_chart_rounded,
                'route': '/timetable/approvals',
              },
              {
                'title': 'IA Approvals & Publication',
                'icon': Icons.fact_check_rounded,
                'route': '/ia/performance',
              },
            ],
          },
          {
            'title': 'IA Monitoring Desk',
            'icon': Icons.insights_rounded,
            'route': '/ia/performance',
          },
          {
            'title': 'Student Directory',
            'icon': Icons.people_alt_rounded,
            'route': '/admissions/list',
          },
          {
            'title': 'Faculty Directory',
            'icon': Icons.list_alt_rounded,
            'route': '/faculty/list',
          },
          {
            'title': 'Placement Officers',
            'icon': Icons.badge_rounded,
            'route': '/principal/placement-officers',
          },
          {
            'title': 'Assign HODs',
            'icon': Icons.manage_accounts_rounded,
            'route': '/hod/assign',
          },
          {
            'title': 'Register Staff',
            'icon': Icons.person_add,
            'route': '/faculty/register',
          },
          {
            'title': 'Announcements',
            'icon': Icons.campaign_rounded,
            'route': '/announcements/campus',
          },
          {
            'title': 'Reports',
            'icon': Icons.analytics_rounded,
            'route': '/reports',
          },
        ]);
        break;

      // --- ADMISSION OFFICER ---
      case AppRoles.admission:
        menu.addAll([
          {
            'title': 'Register Student',
            'icon': Icons.person_add_alt_1_rounded,
            'route': '/admissions/register',
          },
          {
            'title': 'Student List',
            'icon': Icons.people_alt_rounded,
            'route': '/admissions/list',
          },
          {
            'title': 'Faculty',
            'icon': Icons.school_rounded,
            'route': '/faculty',
            'children': [
              {
                'title': 'Register',
                'icon': Icons.person_add_rounded,
                'route': '/faculty/register',
              },
              {
                'title': 'Faculty List',
                'icon': Icons.list_alt_rounded,
                'route': '/faculty/list',
              },
            ],
          },
          {
            'title': 'Grievances',
            'icon': Icons.report_problem_rounded,
            'route': '/grievances',
          },
          {
            'title': 'Announcements',
            'icon': Icons.campaign_rounded,
            'route': '/announcements/campus',
          },
          {
            'title': 'Principal Directives',
            'icon': Icons.mark_email_unread_rounded,
            'route': '/admissions/notifications',
          },
        ]);
        break;

      // --- ACCOUNTS ROLE ---
      case AppRoles.accounts:
        menu[0] = {
          'title': 'Accounts Dashboard',
          'icon': Icons.dashboard_rounded,
          'route': '/fees/dashboard',
        };
        menu.addAll([
          {
            'title': 'Student Fees',
            'icon': Icons.people_alt_rounded,
            'route': '/fees/students',
          },
          {
            'title': 'Record Payment',
            'icon': Icons.add_card_rounded,
            'route': '/fees/record-payment',
          },
          {
            'title': 'Verify Payments',
            'icon': Icons.verified_user_rounded,
            'route': '/fees/student-payments',
          },
          {
            'title': 'Uploaded Fee Proofs',
            'icon': Icons.photo_library_rounded,
            'route': '/fees/uploaded-files',
          },
          {
            'title': 'Fee Structure',
            'icon': Icons.account_tree_rounded,
            'route': '/fees',
            'children': [
              {
                'title': 'Create Structure',
                'icon': Icons.post_add_rounded,
                'route': '/fees/create',
              },
              {
                'title': 'View Structures',
                'icon': Icons.list_alt_rounded,
                'route': '/fees',
              },
            ],
          },
          {
            'title': 'Financial Reports',
            'icon': Icons.analytics_rounded,
            'route': '/fees/reports',
          },
          {
            'title': 'Principal Directives',
            'icon': Icons.mark_email_unread_rounded,
            'route': '/fees/notifications',
          },
          {
            'title': 'Grievances',
            'icon': Icons.report_problem_rounded,
            'route': '/grievances',
          },
        ]);
        break;

      // --- STUDENT ROLE ---
      case AppRoles.student:
        menu.addAll([
          {
            'title': 'My Timetable',
            'icon': Icons.calendar_month_rounded,
            'route': '/timetable/student-schedule',
          },
          {
            'title': 'My Attendance',
            'icon': Icons.pie_chart_outline_rounded,
            'route': '/attendance/student',
          },
          {
            'title': 'IA Marks',
            'icon': Icons.assessment_rounded,
            'route': '/ia/student',
          },
          {
            'title': 'My Assignments',
            'icon': Icons.assignment_rounded,
            'route': '/student/assignments',
          },
          {
            'title': 'Exam Results',
            'icon': Icons.workspace_premium_rounded,
            'route': '/student/results',
          },
          {
            'title': 'Academic Status',
            'icon': Icons.timeline_rounded,
            'route': '/student/academic-status',
          },
          {
            'title': 'Fee Details',
            'icon': Icons.monetization_on_rounded,
            'route': '/fees/my-fees',
          },
          {
            'title': 'Library',
            'icon': Icons.local_library_rounded,
            'route': '/library',
          },
          {
            'title': 'Correction Center',
            'icon': Icons.rule_rounded,
            'route': '/student/corrections',
          },
          {
            'title': 'Placement Cell',
            'icon': Icons.work_outline_rounded,
            'route': '/student/placement',
          },
          {
            'title': 'Grievances',
            'icon': Icons.support_agent_rounded,
            'route': '/student/grievances',
          },
          {
            'title': 'Notifications',
            'icon': Icons.notifications_rounded,
            'route': '/notifications',
          },
        ]);
        break;

      // --- LIBRARY OFFICER ROLE ---
      case AppRoles.library:
        menu.addAll([
          {
            'title': 'Dashboard',
            'icon': Icons.dashboard_customize_rounded,
            'route': '/library/officer',
          },
          {
            'title': 'Book Inventory',
            'icon': Icons.inventory_2_rounded,
            'route': '/library/catalog',
          },
          {
            'title': 'Library Configuration',
            'icon': Icons.tune_rounded,
            'route': '/library/configuration',
          },
          {
            'title': 'Borrowers',
            'icon': Icons.people_alt_rounded,
            'route': '/library/borrowers',
          },
          {
            'title': 'Issue & Return Books',
            'icon': Icons.swap_horiz_rounded,
            'route': '/library/desk',
          },
          {
            'title': 'Reservations',
            'icon': Icons.bookmark_added_rounded,
            'route': '/library/requests',
          },
          {
            'title': 'Library Issue Cards',
            'icon': Icons.badge_rounded,
            'route': '/library/cards',
          },
          {
            'title': 'Issue & Return History',
            'icon': Icons.history_rounded,
            'route': '/library/history',
          },
          {
            'title': 'Notifications',
            'icon': Icons.notifications_active_rounded,
            'route': '/library/notifications',
          },
          {
            'title': 'Reports',
            'icon': Icons.assessment_rounded,
            'route': '/library/reports',
          },
          {
            'title': 'Feedback',
            'icon': Icons.rate_review_rounded,
            'route': '/library/feedback',
          },
          {
            'title': 'Grievances',
            'icon': Icons.report_problem_rounded,
            'route': '/grievances',
          },
        ]);
        break;

      case AppRoles.system:
        menu.addAll([
          {
            'title': 'Grievances',
            'icon': Icons.report_problem_rounded,
            'route': '/grievances',
          },
        ]);
        break;

      case AppRoles.placementOfficer:
        menu = [
          {'title': 'Dashboard', 'icon': Icons.dashboard_rounded, 'route': '/placement/dashboard'},
          {'title': 'Companies', 'icon': Icons.business_rounded, 'route': '/placement/companies'},
          {'title': 'Placement Drives', 'icon': Icons.event_note_rounded, 'route': '/placement/drives'},
          {'title': 'Applications', 'icon': Icons.assignment_turned_in_rounded, 'route': '/placement/applications'},
          {'title': 'Job Offers', 'icon': Icons.workspace_premium_rounded, 'route': '/placement/offers'},
          {'title': 'Reports & Analytics', 'icon': Icons.analytics_rounded, 'route': '/placement/reports'},
        ];
        break;

      case AppRoles.exam:
      case AppRoles.scholarship:
        break;
    }

    if (!menu.any((item) => item['route'] == '/profile')) {
      menu.add({
        'title': 'Profile',
        'icon': Icons.person_rounded,
        'route': '/profile',
      });
    }
    return menu;
  }
}

