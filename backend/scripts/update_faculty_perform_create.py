path = "faculty/views.py"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

target = """            # Backend enforcement: Reject unauthorized cross-department faculty creation attempts"""

replacement = """            # Backend enforcement: HOD can only register Professor or Guest Faculty
            req_role = (self.request.data.get("role") or "").upper()
            if req_role in ["HOD", "PRINCIPAL", "ADMISSION", "ACCOUNTS", "SYSTEM", "EXAM", "LIBRARY"]:
                raise PermissionDenied("HOD is not authorized to register administrative or other HOD roles.")
            if req_role in ["GUEST", "GUEST_FACULTY"]:
                save_kwargs["role"] = "PROFESSOR"
                save_kwargs["is_guest_faculty"] = True
                save_kwargs["employment_type"] = "GUEST"
                if not self.request.data.get("designation"):
                    save_kwargs["designation"] = "Guest Faculty"

            # Backend enforcement: Reject unauthorized cross-department faculty creation attempts"""

assert target in text, "target not found"
text = text.replace(target, replacement, 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("faculty/views.py perform_create updated.")
