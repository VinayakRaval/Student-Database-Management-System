import 'package:flutter/material.dart';
import 'package:frontend/core/constants/api_constants.dart';

class RoleMenus {
  static List<Map<String, dynamic>> getMenu(String role) {
    List<Map<String, dynamic>> menu = [
      {'title': 'HOME', 'icon': Icons.dashboard_rounded, 'route': '/dashboard'},
    ];

    switch (role) {
      // --- HOD ROLE ---
      case AppRoles.hod:
        menu.addAll([
          {
            'title': 'My Department',
            'icon': Icons.business_rounded,
            'route': '/academics',
          },

          // NEW: HODs also teach, so they need their personal schedule
          {
            'title': 'My Timetable',
            'icon': Icons.schedule_rounded,
            'route': '/timetable/my-schedule',
          },

          {
            'title': 'Subjects',
            'icon': Icons.library_books_rounded,
            'route': '/subjects',
            'children': [
              {
                'title': 'Add Subject',
                'icon': Icons.post_add_rounded,
                'route': '/subjects/add',
              },
              {
                'title': 'Assign Subjects',
                'icon': Icons.assignment_ind_rounded,
                'route': '/subjects/assign',
              },
            ],
          },
          {
            'title': 'Timetable Management',
            'icon': Icons.calendar_month_rounded,
            'route': '/timetable',
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
            'title': 'Mark Attendance',
            'icon': Icons.check_circle_outline_rounded,
            'route': '/attendance/faculty',
          },
          {
            'title': 'Attendance Monitoring',
            'icon': Icons.fact_check_rounded,
            'route': '/attendance/monitoring',
          },
          {
            'title': 'IA Performance',
            'icon': Icons.insights_rounded,
            'route': '/ia/performance',
          },
          {
            'title': 'Reports',
            'icon': Icons.assessment_rounded,
            'route': '/reports/department',
          },
          {
            'title': 'Announcements',
            'icon': Icons.campaign_rounded,
            'route': '/announcements/department',
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
            'title': 'Students',
            'icon': Icons.people_alt_rounded,
            'route': '/admissions/list',
          },
          {
            'title': 'Library Card Approvals',
            'icon': Icons.badge_rounded,
            'route': '/hod/library-cards',
          },
        ]);
        break;

      // --- FACULTY ROLE ---
      case AppRoles.professor:
        menu.addAll([
          {
            'title': 'My Timetable',
            'icon': Icons.calendar_today_rounded,
            'route': '/timetable/my-schedule',
          },
          {
            'title': 'My Subjects',
            'icon': Icons.library_books_rounded,
            'route': '/subjects',
          },
          {
            'title': 'Mark Attendance',
            'icon': Icons.check_circle_outline_rounded,
            'route': '/attendance/faculty',
          },
        ]);
        break;

      // --- PRINCIPAL ROLE ---
      case AppRoles.principal:
        menu.addAll([
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
            ],
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
        ]);
        break;

      // --- ACCOUNTS ROLE ---
      case AppRoles.accounts:
        menu.addAll([
          {
            'title': 'Fee Structure',
            'icon': Icons.monetization_on_rounded,
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
            'title': 'Verify Payments',
            'icon': Icons.payment_rounded,
            'route': '/fees/student-payments',
          },
        ]);
        break;

      // --- STUDENT ROLE ---
      case AppRoles.student:
        menu.addAll([
          {
            'title': 'My Timetable',
            'icon': Icons.calendar_month_rounded,
            'route': '/timetable/list',
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
        ]);
        break;

      case AppRoles.exam:
      case AppRoles.scholarship:
        break;
    }

    menu.add({
      'title': 'Profile',
      'icon': Icons.person_rounded,
      'route': '/profile',
    });
    return menu;
  }
}

