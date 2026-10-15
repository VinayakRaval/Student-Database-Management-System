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
            'title': 'Fee Details',
            'icon': Icons.monetization_on_rounded,
            'route': '/fees/my-fees',
          },
          {
            'title': 'Library',
            'icon': Icons.local_library_rounded,
            'route': '/library',
          },
        ]);
        break;

      case AppRoles.library:
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

