import 'package:image_picker/image_picker.dart'; // Import this!

class FacultyRegistrationModel {
  final String facultyId;
  final String name;
  final String gender;
  final String dob;
  final String address;
  final String phone;
  final String email;
  final int departmentId;
  final String qualification;
  final String role;
  
  // CHANGED: Use XFile instead of String path
  final XFile? photoFile; 

  FacultyRegistrationModel({
    required this.facultyId,
    required this.name,
    required this.gender,
    required this.dob,
    required this.address,
    required this.phone,
    required this.email,
    required this.departmentId,
    required this.qualification,
    required this.role,
    this.photoFile,
  });

  Map<String, dynamic> toMap() {
    return {
      'faculty_id': facultyId,
      'name': name,
      'gender': gender,
      'dob': dob,
      'address': address,
      'phone': phone,
      'email': email,
      'department': departmentId,
      'qualification': qualification,
      'role': role,
    };
  }
}

class DepartmentOption {
  final int id;
  final String name;

  DepartmentOption({required this.id, required this.name});

  factory DepartmentOption.fromMap(Map<String, dynamic> map) {
    return DepartmentOption(
      id: map['id'] ?? 0,
      name: map['name'] ?? '',
    );
  }
}

// Faculty List Model
class Faculty {
  final int id;
  final String facultyId;
  final String name;
  final String email;
  final String phone;
  final String department;
  final String role;
  final String status;
  final String? photoUrl;
  final String? qualification;
  final String? dob;
  final String? address;
  final int? departmentId;
  final String? gender;

  Faculty({
    required this.id,
    required this.facultyId,
    required this.name,
    required this.email,
    required this.phone,
    required this.department,
    required this.role,
    required this.status,
    this.photoUrl,
    this.qualification,
    this.dob,
    this.address,
    this.departmentId,
    this.gender,
  });

  factory Faculty.fromMap(Map<String, dynamic> map) {
    int? parsedDeptId;
    if (map['department'] is int) {
      parsedDeptId = map['department'] as int;
    } else if (map['department'] is Map) {
      parsedDeptId = map['department']['id'];
    } else {
      parsedDeptId = int.tryParse(map['department']?.toString() ?? '');
    }

    final deptName = map['department_name'] ?? 
        (map['department'] is Map ? map['department']['name'] : null) ?? 
        map['department']?.toString() ?? '';

    return Faculty(
      id: map['id'],
      facultyId: map['faculty_id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      department: deptName,
      role: map['role'] ?? 'N/A',
      status: map['status'] ?? 'pending',
      photoUrl: map['photo'],
      qualification: map['qualification'],
      dob: map['dob'],
      address: map['address'],
      departmentId: parsedDeptId,
      gender: map['gender'],
    );
  }
}