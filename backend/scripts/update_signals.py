with open("faculty/signals.py", "r", encoding="utf-8") as f:
    text = f.read()

target = """    role_upper = (instance.role or "PROFESSOR").upper()
    if role_upper == "FACULTY":
        role_upper = "PROFESSOR" """

replacement = """    role_upper = (instance.role or "PROFESSOR").upper()
    if role_upper in ["FACULTY", "GUEST", "GUEST_FACULTY", "GUEST FACULTY"]:
        role_upper = "PROFESSOR"
    if instance.is_guest_faculty or instance.employment_type == "GUEST":
        role_upper = "PROFESSOR" """

if target in text:
    text = text.replace(target, replacement, 1)
else:
    # try normalized
    target2 = 'if role_upper == "FACULTY":\n        role_upper = "PROFESSOR"'
    replacement2 = 'if role_upper in ["FACULTY", "GUEST", "GUEST_FACULTY", "GUEST FACULTY"] or instance.is_guest_faculty or instance.employment_type == "GUEST":\n        role_upper = "PROFESSOR"'
    text = text.replace(target2, replacement2, 1)

with open("faculty/signals.py", "w", encoding="utf-8") as f:
    f.write(text)
print("faculty/signals.py updated successfully.")
