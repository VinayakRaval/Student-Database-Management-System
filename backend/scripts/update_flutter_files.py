import os

def update_faculty_model():
    path = r"D:\student-data-management-system\frontend\lib\features\faculty\models\faculty_model.dart"
    with open(path, "rb") as f:
        text = f.read().decode("utf-8").replace("\r\n", "\n")

    target = """  final String? employmentType;
  final bool isGuestFaculty;
  final String? dateOfJoining;
  
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
    this.employmentType = 'PERMANENT',
    this.isGuestFaculty = false,
    this.dateOfJoining,
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
      'employment_type': employmentType ?? (isGuestFaculty ? 'GUEST' : 'PERMANENT'),
      'is_guest_faculty': isGuestFaculty,
      if (dateOfJoining != null && dateOfJoining!.isNotEmpty) 'date_of_joining': dateOfJoining,
    };
  }"""

    replacement = """  final String? designation;
  final String? employmentType;
  final bool isGuestFaculty;
  final String? dateOfJoining;
  
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
    this.designation,
    this.employmentType = 'PERMANENT',
    this.isGuestFaculty = false,
    this.dateOfJoining,
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
      'designation': designation ?? (isGuestFaculty ? 'Guest Faculty' : 'Professor'),
      'employment_type': employmentType ?? (isGuestFaculty ? 'GUEST' : 'PERMANENT'),
      'is_guest_faculty': isGuestFaculty,
      if (dateOfJoining != null && dateOfJoining!.isNotEmpty) 'date_of_joining': dateOfJoining,
    };
  }"""

    assert target in text, "target not found in faculty_model.dart"
    text = text.replace(target, replacement, 1)

    target_fac = """  final String? employmentType;
  final bool isGuestFaculty;
  final String? dateOfJoining;

  Faculty({"""

    rep_fac = """  final String? designation;
  final String? employmentType;
  final bool isGuestFaculty;
  final String? dateOfJoining;

  Faculty({"""

    assert target_fac in text, "target_fac not found in faculty_model.dart"
    text = text.replace(target_fac, rep_fac, 1)

    target_cons = """    this.employmentType = 'PERMANENT',
    this.isGuestFaculty = false,
    this.dateOfJoining,"""

    rep_cons = """    this.designation,
    this.employmentType = 'PERMANENT',
    this.isGuestFaculty = false,
    this.dateOfJoining,"""

    assert target_cons in text, "target_cons not found in faculty_model.dart"
    text = text.replace(target_cons, rep_cons, 1)

    target_from = """      employmentType: map['employment_type'] ?? (isGuest ? 'GUEST' : 'PERMANENT'),
      isGuestFaculty: isGuest,
      dateOfJoining: map['date_of_joining'],"""

    rep_from = """      designation: map['designation']?.toString() ?? (isGuest ? 'Guest Faculty' : 'Professor'),
      employmentType: map['employment_type'] ?? (isGuest ? 'GUEST' : 'PERMANENT'),
      isGuestFaculty: isGuest,
      dateOfJoining: map['date_of_joining'],"""

    assert target_from in text, "target_from not found in faculty_model.dart"
    text = text.replace(target_from, rep_from, 1)

    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    print("faculty_model.dart updated successfully.")

if __name__ == "__main__":
    update_faculty_model()
