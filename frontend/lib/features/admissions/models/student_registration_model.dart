class StudentRegistrationModel {
  // --- PERSONAL DETAILS ---
  final String name;
  final String? cetNo;
  final String dob;
  final String gender;
  final String fatherName;
  final String motherName;
  final String? parentOccupation;
  final String religion;
  final String nationality;
  final String state;
  final String cityType;
  final String mobileNo;
  final String email;

  // --- ADDRESS DETAILS ---
  final String address;
  final String permanentAddress;

  // --- ADMISSION DETAILS ---
  final String admissionQuota;
  final String seatType;
  final String? rank;
  final String dateOfAdmission;

  // --- RESERVATION ---
  final String? caste;
  final String? otherReservation;

  // --- EDUCATION DETAILS ---
  final String? sslcRegNo;
  final String? sslcYear;
  final int? sslcObtainedMarks;
  final int? sslcTotalMarks;

  final String? pucRegNo;
  final String? pucYear;
  final int? pucObtainedMarks;
  final int? pucTotalMarks;

  final String? diplomaRegNo;
  final String? diplomaYear;
  final int? diplomaObtainedMarks;
  final int? diplomaTotalMarks;

  // --- REQUIRED FK ---
  final int departmentId;
  final int semesterId;
  final int academicYearId;

  StudentRegistrationModel({
    required this.name,
    required this.cetNo,
    required this.dob,
    required this.gender,
    required this.religion,
    required this.nationality,
    required this.state,
    required this.cityType,
    required this.mobileNo,
    required this.email,
    required this.fatherName,
    required this.motherName,
    this.parentOccupation,
    required this.caste,
    required this.otherReservation,

    required this.address,
    required this.permanentAddress,

    required this.admissionQuota,
    required this.seatType,
    this.rank,
    required this.dateOfAdmission,

    this.sslcRegNo,
    this.sslcYear,
    this.sslcObtainedMarks,
    this.sslcTotalMarks,

    this.pucRegNo,
    this.pucYear,
    this.pucObtainedMarks,
    this.pucTotalMarks,

    this.diplomaRegNo,
    this.diplomaYear,
    this.diplomaObtainedMarks,
    this.diplomaTotalMarks,

    required this.departmentId,
    required this.semesterId,
    required this.academicYearId,
  });

  // -------------------------------------------------------------
  // 🔥 REQUIRED → used in fee_payment_upload_screen.dart
  // -------------------------------------------------------------
  factory StudentRegistrationModel.fromJson(Map<String, dynamic> json) {
    return StudentRegistrationModel(
      name: json["name"] ?? "",
      cetNo: json["cet_no"],
      dob: json["dob"] ?? "",
      gender: json["gender"] ?? "male",
      religion: json["religion"] ?? "",
      nationality: json["nationality"] ?? "",
      state: json["state"] ?? "",
      cityType: json["city_type"] ?? "",
      mobileNo: json["mobile_no"] ?? "",
      email: json["email"] ?? "",
      fatherName: json["father_name"] ?? "",
      motherName: json["mother_name"] ?? "",
      parentOccupation: json["parent_occupation"],
      address: json["address"] ?? json["permanent_address"] ?? "",
      permanentAddress: json["permanent_address"] ?? "",
      admissionQuota: json["admission_quota"] ?? "",
      seatType: json["seat_type"] ?? "general_merit",
      rank: json["rank"],
      dateOfAdmission: json["date_of_admission"] ?? "",
      caste: json["caste"],
      otherReservation: json["other_reservation"],
      sslcRegNo: json["sslc_regno"],
      sslcYear: json["sslc_year"],
      sslcObtainedMarks: json["sslc_obtain_marks"],
      sslcTotalMarks: json["sslc_total_marks"],
      pucRegNo: json["puc_regno"],
      pucYear: json["puc_year"],
      pucObtainedMarks: json["puc_obtain_marks"],
      pucTotalMarks: json["puc_total_marks"],
      diplomaRegNo: json["diploma_regno"],
      diplomaYear: json["diploma_year"],
      diplomaObtainedMarks: json["diploma_obtain_marks"],
      diplomaTotalMarks: json["diploma_total_marks"],
      departmentId: json["department_id"] ?? 0,
      semesterId: json["semester_id"] ?? 0,
      academicYearId: json["academic_year_id"] ?? 0,
    );
  }

  // -------------------------------------------------------------
  // 🔥 USED by Admission API (POST /students/create/)
  // -------------------------------------------------------------
  // 📌 FILE: lib/features/admissions/models/student_registration_model.dart

  Map<String, dynamic> toJson() {
    return {
      // Personal
      "name": name,
      "cet_no": cetNo,
      "dob": dob,
      "gender": gender,
      "religion": religion,
      "nationality": nationality,
      "state": state,
      "city_type": cityType,
      "mobile_no": mobileNo,
      "email": email,
      "father_name": fatherName,
      "mother_name": motherName,
      "parent_occupation": parentOccupation,

      // Address (FIXED)
      "address": address,
      "permanent_address": permanentAddress,

      // Admission (FIXED)
      "admission_quota": admissionQuota,
      "seat_type": seatType,
      "rank": rank,
      "date_of_admission": dateOfAdmission,

      // Reservation
      "caste": (caste == null || caste!.trim().isEmpty) ? null : caste!.trim(),
      "other_reservation":
          (otherReservation == null || otherReservation!.trim().isEmpty)
          ? null
          : otherReservation!.trim(),

      // Education
      "sslc_regno": sslcRegNo,
      "sslc_year": sslcYear,
      "sslc_obtain_marks": sslcObtainedMarks,
      "sslc_total_marks": sslcTotalMarks,

      "puc_regno": pucRegNo,
      "puc_year": pucYear,
      "puc_obtain_marks": pucObtainedMarks,
      "puc_total_marks": pucTotalMarks,

      "diploma_regno": diplomaRegNo,
      "diploma_year": diplomaYear,
      "diploma_obtain_marks": diplomaObtainedMarks,
      "diploma_total_marks": diplomaTotalMarks,

      // Foreign Keys
      "department_id": departmentId,
      "semester_id": semesterId,
      "academic_year_id": academicYearId,
    };
  }
}
