path = r"D:\student-data-management-system\frontend\lib\features\faculty\screens\faculty_list_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. State variable
text = text.replace(
    "String _selectedStatus = 'all';",
    "String _selectedStatus = 'all';\n  String _selectedFacultyType = 'all'; // 'all', 'regular', 'guest'"
)

# 2. _fetchFaculty
old_fetch = """      final response = await dio.get(

        '/faculty/faculties/',

        queryParameters: {'include_all': 'true'},

      );"""

new_fetch = """      final Map<String, dynamic> qParams = {};
      if (_userRole != 'HOD') {
        qParams['include_all'] = 'true';
      }
      final response = await dio.get(
        '/faculty/faculties/',
        queryParameters: qParams.isNotEmpty ? qParams : null,
      );"""

text = text.replace(old_fetch, new_fetch)

# 3. filteredFaculty filter
old_filt = """    // Search query (name, department, employee ID)"""
new_filt = """    // Faculty Type filter (All, Regular, Guest)
    if (_selectedFacultyType == 'guest') {
      list = list.where((f) => f.isGuestFaculty || f.employmentType == 'GUEST' || (f.designation != null && f.designation!.toLowerCase().contains('guest'))).toList();
    } else if (_selectedFacultyType == 'regular') {
      list = list.where((f) => !f.isGuestFaculty && f.employmentType != 'GUEST' && !(f.designation != null && f.designation!.toLowerCase().contains('guest'))).toList();
    }

    // Search query (name, department, employee ID)"""

text = text.replace(old_filt, new_filt)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Updated successfully.")
