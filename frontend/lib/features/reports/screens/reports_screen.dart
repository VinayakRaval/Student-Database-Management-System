import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = [
      (Icons.people_alt_outlined, 'Student Report',
          'View student records and enrollment information.'),
      (Icons.school_outlined, 'Faculty Report',
          'Review faculty and department information.'),
      (Icons.payments_outlined, 'Fee Report',
          'Review fee structures and payment verification.'),
      (Icons.calendar_month_outlined, 'Timetable Report',
          'Review timetable and scheduling information.'),
      (Icons.fact_check_outlined, 'Attendance Report',
          'Open attendance records and summaries.'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Reports Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Campus Reports',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a report area to continue. '
                    'Detailed report data depends on the available modules.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...reports.map((report) => Card(
                child: ListTile(
                  leading: Icon(report.$1, size: 30),
                  title: Text(report.$2),
                  subtitle: Text(report.$3),
                  trailing: const Icon(Icons.info_outline),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${report.$2}: open the corresponding module '
                          'to view its available records.',
                        ),
                      ),
                    );
                  },
                ),
              )),
        ],
      ),
    );
  }
}
