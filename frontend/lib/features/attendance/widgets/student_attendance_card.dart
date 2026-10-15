import 'package:flutter/material.dart';
import '../models/attendance_model.dart';

class StudentAttendanceCard extends StatelessWidget {
  final StudentAttendanceModel student;
  final VoidCallback onToggle;

  const StudentAttendanceCard({
    super.key,
    required this.student,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: student.isPresent ? Colors.green.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: onToggle,
        leading: CircleAvatar(
          backgroundColor: student.isPresent ? Colors.green[100] : Colors.red[100],
          child: Text(
            student.name[0].toUpperCase(),
            style: TextStyle(
              color: student.isPresent ? Colors.green[800] : Colors.red[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(student.usn, style: const TextStyle(fontSize: 12)),
        trailing: Checkbox(
          value: student.isPresent,
          activeColor: Colors.green,
          onChanged: (_) => onToggle(),
        ),
      ),
    );
  }
}