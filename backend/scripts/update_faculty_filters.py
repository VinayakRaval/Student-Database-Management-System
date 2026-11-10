path = r"D:\student-data-management-system\frontend\lib\features\faculty\screens\faculty_list_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Define facultyTypeDropdown right after departmentDropdown
target_after_dept = """        // Department Dropdown (Fix for HOD: ALWAYS visible and enabled)"""

faculty_type_widget = """        final bool isHodUser = _userRole == 'HOD';

        // Faculty Type Dropdown
        final facultyTypeDropdown = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFacultyType,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.badge_outlined, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Text("All Faculty Types", style: TextStyle(fontSize: 13, color: Color(0xFF334155))),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'regular',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_rounded, size: 16, color: Color(0xFF13246E)),
                      SizedBox(width: 8),
                      Text("Regular Faculty", style: TextStyle(fontSize: 13, color: Color(0xFF13246E))),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'guest',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_rounded, size: 16, color: Color(0xFF7C3AED)),
                      SizedBox(width: 8),
                      Text("Guest Faculty", style: TextStyle(fontSize: 13, color: Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedFacultyType = val;
                    _currentPage = 1;
                  });
                }
              },
            ),
          ),
        );

        // Department Dropdown"""

text = text.replace(target_after_dept, faculty_type_widget)

# Now update the mobile and desktop filter children:
old_mobile_children = """                children: [

                  departmentDropdown,

                  statusDropdown,

                  sortDropdown,

                  if (canRegister) registerButton,

                ],"""

new_mobile_children = """                children: [
                  if (!isHodUser) departmentDropdown,
                  facultyTypeDropdown,
                  statusDropdown,
                  sortDropdown,
                  if (canRegister) registerButton,
                ],"""

text = text.replace(old_mobile_children, new_mobile_children)

old_desktop_children = """            children: [

              Expanded(child: searchWidget),

              const SizedBox(width: 10),

              departmentDropdown,

              const SizedBox(width: 10),

              statusDropdown,

              const SizedBox(width: 10),

              sortDropdown,

              if (canRegister) ...[

                const SizedBox(width: 10),

                registerButton,

              ],

            ],"""

new_desktop_children = """            children: [
              Expanded(child: searchWidget),
              if (!isHodUser) ...[
                const SizedBox(width: 10),
                departmentDropdown,
              ],
              const SizedBox(width: 10),
              facultyTypeDropdown,
              const SizedBox(width: 10),
              statusDropdown,
              const SizedBox(width: 10),
              sortDropdown,
              if (canRegister) ...[
                const SizedBox(width: 10),
                registerButton,
              ],
            ],"""

text = text.replace(old_desktop_children, new_desktop_children)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("faculty_list_screen.dart filters updated successfully.")
