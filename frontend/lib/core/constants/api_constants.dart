class AppRoles {
  static const String student = 'STUDENT';
  static const String professor = 'PROFESSOR';
  static const String hod = 'HOD';
  static const String principal = 'PRINCIPAL';
  static const String admission = 'ADMISSION';
  static const String accounts = 'ACCOUNTS';
  static const String exam = 'EXAM';
  static const String scholarship = 'SCHOLARSHIP';
  static const String library = 'LIBRARY';
  static const String system = 'SYSTEM';
}

class ApiConstants {
  static const String login = '/userlogin/login/';
  static const String refresh = '/userlogin/token/refresh/';
  static const String passwordChange = '/userlogin/password/change/';
  static const String forgotPassword = '/userlogin/password/forgot/';
  static const String verifyOtp = '/userlogin/password/verify/';
}
