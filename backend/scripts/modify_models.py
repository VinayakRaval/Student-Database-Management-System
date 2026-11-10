with open("faculty/models.py", "r", encoding="utf-8") as f:
    text = f.read()

bad_block = """        if self.is_guest_faculty or self.employment_type == "GUEST" or (self.designation and "guest" in str(self.designation).lower()):
            self.employment_type = "GUEST"
            self.is_guest_faculty = True
            if not self.designation:
                self.designation = "Guest Faculty"
        else:
            if not self.designation:
                self.designation = "Professor" 
        else:
            self.employment_type = "PERMANENT"
            self.is_guest_faculty = False"""

good_block = """        if self.is_guest_faculty or self.employment_type == "GUEST" or (self.designation and "guest" in str(self.designation).lower()):
            self.employment_type = "GUEST"
            self.is_guest_faculty = True
            if not self.designation:
                self.designation = "Guest Faculty"
        else:
            self.employment_type = "PERMANENT"
            self.is_guest_faculty = False
            if not self.designation:
                self.designation = "Professor" """

text = text.replace(bad_block, good_block)
with open("faculty/models.py", "w", encoding="utf-8") as f:
    f.write(text)
print("faculty/models.py fixed.")
