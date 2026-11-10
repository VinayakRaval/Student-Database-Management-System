import re

# 1. Update backend/students/views.py
path_students = "students/views.py"
with open(path_students, "r", encoding="utf-8") as f:
    text = f.read()

target_stu_assign = """            subject_param = self.request.GET.get("subject_id")

            if subject_param and str(subject_param).isdigit():

                assign = assignments.filter(subject_id=int(subject_param)).first()

                if assign:

                    sub_dept = assign.department_id or (assign.subject.department_id if assign.subject else None)

                    sub_sem = assign.semester_id or (assign.subject.semester_id if assign.subject else None)

                    if sub_dept:

                        queryset = queryset.filter(department_id=sub_dept)

                    if sub_sem:

                        queryset = queryset.filter(semester_id=sub_sem)

                else:

                    return Student.objects.none()"""

new_stu_assign = """            subject_param = self.request.GET.get("subject_id")
            if subject_param and str(subject_param).isdigit():
                assign = assignments.filter(subject_id=int(subject_param)).first()
                if assign:
                    # Enforce elective student isolation
                    if getattr(assign.subject, 'is_elective', False):
                        from subjects.models import ElectiveSubjectEnrollment
                        enrolled_qs = ElectiveSubjectEnrollment.objects.filter(
                            subject=assign.subject, is_active=True
                        )
                        if assign.academic_year_id:
                            enrolled_qs = enrolled_qs.filter(academic_year_id=assign.academic_year_id)
                        student_ids = list(enrolled_qs.values_list('student_id', flat=True))
                        if not student_ids:
                            return Student.objects.none()
                        queryset = queryset.filter(id__in=student_ids)
                    else:
                        sub_dept = assign.department_id or (assign.subject.department_id if assign.subject else None)
                        sub_sem = assign.semester_id or (assign.subject.semester_id if assign.subject else None)
                        if sub_dept:
                            queryset = queryset.filter(department_id=sub_dept)
                        if sub_sem:
                            queryset = queryset.filter(semester_id=sub_sem)
                        if assign.academic_year_id:
                            queryset = queryset.filter(academic_year_id=assign.academic_year_id)
                else:
                    return Student.objects.none()"""

if target_stu_assign in text:
    text = text.replace(target_stu_assign, new_stu_assign, 1)
    with open(path_students, "w", encoding="utf-8") as f:
        f.write(text)
    print("students/views.py updated successfully.")
else:
    print("target_stu_assign not found in students/views.py, trying regex...")
    pattern = re.compile(r'subject_param = self\.request\.GET\.get\("subject_id"\).*?return Student\.objects\.none\(\)', re.DOTALL)
    text = pattern.sub(new_stu_assign.strip(), text, count=1)
    with open(path_students, "w", encoding="utf-8") as f:
        f.write(text)
    print("students/views.py updated via regex.")

# 2. Update backend/attendance/views.py
path_att = "attendance/views.py"
with open(path_att, "r", encoding="utf-8") as f:
    text_att = f.read()

target_att_students = """        students_qs = Student.objects.filter(
            department=target_dept,
            semester=target_sem
        ).filter(
            Q(status__iexact='active') | Q(registration_status__iexact='verified')
        )
        if assignment and assignment.academic_year:
            students_qs = students_qs.filter(academic_year=assignment.academic_year)"""

new_att_students = """        if getattr(subject, 'is_elective', False):
            from subjects.models import ElectiveSubjectEnrollment
            enrolled_ids = list(ElectiveSubjectEnrollment.objects.filter(
                subject=subject, is_active=True
            ).values_list('student_id', flat=True))
            students_qs = Student.objects.filter(id__in=enrolled_ids)
        else:
            students_qs = Student.objects.filter(
                department=target_dept,
                semester=target_sem
            ).filter(
                Q(status__iexact='active') | Q(registration_status__iexact='verified')
            )
            if assignment and assignment.academic_year:
                students_qs = students_qs.filter(academic_year=assignment.academic_year)"""

if target_att_students in text_att:
    text_att = text_att.replace(target_att_students, new_att_students, 1)
    with open(path_att, "w", encoding="utf-8") as f:
        f.write(text_att)
    print("attendance/views.py updated successfully.")
else:
    print("target_att_students not found in attendance/views.py")

# 3. Update backend/ia_assessment/views.py
path_ia = "ia_assessment/views.py"
with open(path_ia, "r", encoding="utf-8") as f:
    text_ia = f.read()

target_ia_students = """        students_qs = Student.objects.filter(status__iexact="active")
        if target_dept:
            students_qs = students_qs.filter(department=target_dept)
        if target_sem:
            students_qs = students_qs.filter(semester=target_sem)
        if assignment and assignment.academic_year:
            students_qs = students_qs.filter(academic_year=assignment.academic_year)"""

new_ia_students = """        if getattr(subject, 'is_elective', False):
            from subjects.models import ElectiveSubjectEnrollment
            enrolled_ids = list(ElectiveSubjectEnrollment.objects.filter(
                subject=subject, is_active=True
            ).values_list('student_id', flat=True))
            students_qs = Student.objects.filter(id__in=enrolled_ids)
        else:
            students_qs = Student.objects.filter(status__iexact="active")
            if target_dept:
                students_qs = students_qs.filter(department=target_dept)
            if target_sem:
                students_qs = students_qs.filter(semester=target_sem)
            if assignment and assignment.academic_year:
                students_qs = students_qs.filter(academic_year=assignment.academic_year)"""

if target_ia_students in text_ia:
    text_ia = text_ia.replace(target_ia_students, new_ia_students, 1)
    with open(path_ia, "w", encoding="utf-8") as f:
        f.write(text_ia)
    print("ia_assessment/views.py updated successfully.")
else:
    print("target_ia_students not found in ia_assessment/views.py")
