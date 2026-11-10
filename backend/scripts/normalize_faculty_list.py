import re

path = r"D:\student-data-management-system\frontend\lib\features\faculty\screens\faculty_list_screen.dart"
with open(path, "rb") as f:
    text = f.read().decode("utf-8").replace("\r\n", "\n")

# Normalize multiple consecutive empty lines to a single empty line
text = re.sub(r'\n{3,}', '\n\n', text)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("faculty_list_screen.dart normalized.")
