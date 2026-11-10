path = r"D:\student-data-management-system\frontend\lib\features\faculty\screens\faculty_registration_screen.dart"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Add _customDesignationController
target_ctrl = "  final _dobController = TextEditingController();"
rep_ctrl = "  final _dobController = TextEditingController();\n  final _customDesignationController = TextEditingController();"
assert target_ctrl in text, "target_ctrl not found"
text = text.replace(target_ctrl, rep_ctrl, 1)

# Add dispose
target_disp = "    _dobController.dispose();"
rep_disp = "    _dobController.dispose();\n    _customDesignationController.dispose();"
assert target_disp in text, "target_disp not found"
text = text.replace(target_disp, rep_disp, 1)

# Update _fetchNextFacultyId
target_fetch_id = """    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/faculty/next-id/');"""

rep_fetch_id = """    try {
      final dio = ApiClient().dio;
      final isGuest = _selectedRole == 'GUEST_FACULTY';
      final res = await dio.get('/faculty/next-id/', queryParameters: {'guest': isGuest});"""
assert target_fetch_id in text, "target_fetch_id not found"
text = text.replace(target_fetch_id, rep_fetch_id, 1)

# Update _submitForm
target_submit = """    if (_selectedRole == null || _selectedRole!.isEmpty) {
      _showWarning('Designation is required. Please select designation.');
      return;
    }
    if (_selectedPhoto == null) {
      _showWarning('Faculty Photo is required. Please upload an image.');
      return;
    }

    final facultyData = FacultyRegistrationModel(
      facultyId: regId,
      name: name,
      gender: _selectedGender!,
      dob: dob,
      address: address,
      phone: phone,
      email: email,
      departmentId: _selectedDepartmentId!,
      qualification: qualification,
      role: _selectedRole!,
      photoFile: _selectedPhoto,
      employmentType: 'PERMANENT',
      isGuestFaculty: false,
      dateOfJoining: null,
    );"""

rep_submit = """    if (_selectedRole == null || _selectedRole!.isEmpty) {
      _showWarning('Designation is required. Please select designation.');
      return;
    }
    if (_selectedRole == 'CUSTOM' && _customDesignationController.text.trim().isEmpty) {
      _showWarning('Please enter the custom designation.');
      return;
    }
    if (_selectedPhoto == null) {
      _showWarning('Faculty Photo is required. Please upload an image.');
      return;
    }

    final isGuest = _selectedRole == 'GUEST_FACULTY';
    final isCustom = _selectedRole == 'CUSTOM';
    final effectiveRole = (isGuest || isCustom) ? 'PROFESSOR' : _selectedRole!;
    final effectiveDesignation = isCustom
        ? _customDesignationController.text.trim()
        : (isGuest ? 'Guest Faculty' : (_selectedRole == 'PROFESSOR' ? 'Professor' : _selectedRole!));

    final facultyData = FacultyRegistrationModel(
      facultyId: regId,
      name: name,
      gender: _selectedGender!,
      dob: dob,
      address: address,
      phone: phone,
      email: email,
      departmentId: _selectedDepartmentId!,
      qualification: qualification,
      role: effectiveRole,
      designation: effectiveDesignation,
      employmentType: isGuest ? 'GUEST' : 'PERMANENT',
      isGuestFaculty: isGuest,
      photoFile: _selectedPhoto,
      dateOfJoining: null,
    );"""
assert target_submit in text, "target_submit not found"
text = text.replace(target_submit, rep_submit, 1)

# Update _buildDesignationDropdown
old_dropdown = """  Widget _buildDesignationDropdown() {
    final auth = p.Provider.of<AuthProvider>(context, listen: false);
    final role = (auth.role ?? auth.userData?['role'] ?? '').toString().toUpperCase();
    final bool isHod = role == 'HOD';

    final options = isHod
        ? [
            {'label': 'Professor / Teaching Faculty', 'value': 'PROFESSOR'},
          ]
        : _roleOptions;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          _buildFieldLabel("Designation *"),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRole,
                  hint: const Text("Select Designation", style: TextStyle(fontSize: 13, color: Colors.black45)),
                  isExpanded: true,
                  items: options.map((e) {
                    return DropdownMenuItem(
                      value: e['value'],
                      child: Text(e['label']!),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedRole = val),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }"""

new_dropdown = """  Widget _buildDesignationDropdown() {
    final auth = p.Provider.of<AuthProvider>(context, listen: false);
    final role = (auth.role ?? auth.userData?['role'] ?? '').toString().toUpperCase();
    final bool isHod = role == 'HOD';

    final options = isHod
        ? [
            {'label': 'Professor', 'value': 'PROFESSOR'},
            {'label': 'Guest Faculty', 'value': 'GUEST_FACULTY'},
          ]
        : [
            {'label': 'Professor', 'value': 'PROFESSOR'},
            {'label': 'Guest Faculty', 'value': 'GUEST_FACULTY'},
            {'label': 'Head of Department (HOD)', 'value': 'HOD'},
            {'label': 'Principal', 'value': 'PRINCIPAL'},
            {'label': 'Admission Officer', 'value': 'ADMISSION'},
            {'label': 'Accounts Officer', 'value': 'ACCOUNTS'},
            {'label': 'Custom Designation', 'value': 'CUSTOM'},
          ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildFieldLabel("Designation *"),
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: options.any((e) => e['value'] == _selectedRole) ? _selectedRole : options.first['value'],
                      hint: const Text("Select Designation", style: TextStyle(fontSize: 13, color: Colors.black45)),
                      isExpanded: true,
                      items: options.map((e) {
                        return DropdownMenuItem(
                          value: e['value'],
                          child: Text(e['label']!),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final wasGuest = _selectedRole == 'GUEST_FACULTY';
                          final isNowGuest = val == 'GUEST_FACULTY';
                          setState(() => _selectedRole = val);
                          if (wasGuest != isNowGuest) {
                            _fetchNextFacultyId(force: true);
                          }
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedRole == 'CUSTOM') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildFieldLabel("Custom Designation *"),
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: TextField(
                      controller: _customDesignationController,
                      decoration: const InputDecoration(
                        hintText: "Enter designation (e.g. Visiting Professor)",
                        hintStyle: TextStyle(fontSize: 13, color: Colors.black45),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(bottom: 10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }"""
assert old_dropdown in text, "old_dropdown not found"
text = text.replace(old_dropdown, new_dropdown, 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("faculty_registration_screen.dart updated successfully.")
