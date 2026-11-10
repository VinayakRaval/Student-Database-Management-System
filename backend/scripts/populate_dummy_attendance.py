import os
import sys
import django
import random
from datetime import date, timedelta

# Setup django
sys.path.insert(0, 'D:/student-data-management-system/backend')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'SDMS.settings')
django.setup()

from django.contrib.auth import get_user_model
from academics.models import Department, Semester, AcademicYear
from subjects.models import Subject, SubjectAssignment
from faculty.models import Faculty
from students.models import Student
from attendance.models import AttendanceSession, AttendanceRecord, LabBatch, LabBatchStudent
from ia_assessment.models import IATestSetup

User = get_user_model()

print("Populating dummy data for Attendance and IA Assessment...")

dept = Department.objects.filter(name__icontains='Computer').first() or Department.objects.first()
sem = Semester.objects.filter(sem_number=3).first() or Semester.objects.first()
ay = AcademicYear.objects.first()

# 2. Resolve Professor Dr. Ramesh Sharma
prof_user = User.objects.filter(user_id='prof001').first()
if not prof_user:
    prof_user = User.objects.filter(email='professor@sdms.edu').first()

faculty = Faculty.objects.filter(user=prof_user).first()
if not faculty:
    faculty = Faculty.objects.first()

print(f"Target Faculty: {faculty.name} ({faculty.id}) | Dept: {dept.name} | Sem: {sem.sem_number}")

# 3. Create or Update 6 standard CSE subjects
subjects_def = [
    {"code": "CS301", "name": "Data Structures & Algorithms", "theory": True, "lab": True},
    {"code": "CS302", "name": "Computer Networks", "theory": True, "lab": True},
    {"code": "CS303", "name": "Operating Systems", "theory": True, "lab": True},
    {"code": "CS304", "name": "Database Management Systems", "theory": True, "lab": True},
    {"code": "CS305", "name": "Software Engineering", "theory": True, "lab": False},
    {"code": "CS306", "name": "Artificial Intelligence", "theory": True, "lab": False},
]

first_sub = Subject.objects.first()
schema = first_sub.schema if first_sub else None

created_subjects = []
for sdef in subjects_def:
    sub, created = Subject.objects.get_or_create(
        subject_code=sdef["code"],
        defaults={
            "subject_name": sdef["name"],
            "department": dept,
            "semester": sem,
            "schema": schema,
            "subject_type": "THEORY" if not sdef["lab"] else "BOTH",
            "has_theory": sdef["theory"],
            "has_lab": sdef["lab"],
        }
    )
    if not created:
        sub.subject_name = sdef["name"]
        sub.department = dept
        sub.semester = sem
        sub.schema = schema
        sub.has_theory = sdef["theory"]
        sub.has_lab = sdef["lab"]
        sub.save()
        sub.semester = sem
        sub.has_theory = sdef["theory"]
        sub.has_lab = sdef["lab"]
        sub.save()

    # Assign to faculty
    SubjectAssignment.objects.get_or_create(
        subject=sub,
        faculty=faculty,
        defaults={
            "department": dept,
            "semester": sem,
            "academic_year": ay,
        }
    )
    created_subjects.append(sub)
    print(f"Assigned subject: {sub.subject_code} - {sub.subject_name}")

# 4. Ensure students exist with names matching Image 3
student_profiles = [
    {"usn": "4GE23CS001", "name": "Rahul Sharma", "target_pct": 0.45},
    {"usn": "4GE23CS002", "name": "Sneha Patil", "target_pct": 0.59},
    {"usn": "4GE23CS003", "name": "Amit Kulkarni", "target_pct": 0.63},
    {"usn": "4GE23CS004", "name": "Kavya N", "target_pct": 0.70},
    {"usn": "4GE23CS005", "name": "Vikram Singh", "target_pct": 0.56},
    {"usn": "4GE23CS006", "name": "Ananya Rao", "target_pct": 0.48},
    {"usn": "4GE24CS030", "name": "Karthik Gowda", "target_pct": 0.82},
]

active_students = []
for sp in student_profiles:
    st = Student.objects.filter(usn=sp["usn"]).first()
    if st:
        st.name = sp["name"]
        st.department = dept
        st.semester = sem
        st.academic_year = ay
        st.status = 'active'
        st.save()
    else:
        st = Student.objects.create(
            usn=sp["usn"],
            name=sp["name"],
            department=dept,
            semester=sem,
            academic_year=ay,
            status='active'
        )
    active_students.append((st, sp["target_pct"]))
    print(f"Enrolled student: {st.usn} - {st.name}")

# 5. Create Lab Batches for Dr. Ramesh Sharma
lab_batches = []
for sub in created_subjects:
    if sub.has_lab:
        b1, _ = LabBatch.objects.get_or_create(
            subject=sub,
            academic_year=ay,
            name="Batch A",
            defaults={"department": dept, "semester": sem, "faculty": faculty}
        )
        b1.faculty = faculty
        b1.save()

        b2, _ = LabBatch.objects.get_or_create(
            subject=sub,
            academic_year=ay,
            name="Batch B",
            defaults={"department": dept, "semester": sem, "faculty": faculty}
        )
        b2.faculty = faculty
        b2.save()

        # Assign students
        for st, _ in active_students[:4]:
            LabBatchStudent.objects.get_or_create(batch=b1, student=st)
        for st, _ in active_students[4:]:
            LabBatchStudent.objects.get_or_create(batch=b2, student=st)

        lab_batches.extend([b1, b2])

print(f"Created/Verified {len(lab_batches)} lab batches.")

# 6. Create Attendance Sessions and Records for the past 40 days
today = date.today()
session_dates = []
for d in range(1, 55):
    dt = today - timedelta(days=d)
    if dt.weekday() != 6:  # Skip Sundays
        session_dates.append(dt)
    if len(session_dates) >= 38:
        break

session_dates.reverse()  # Chronological order

sessions_created = 0
records_created = 0

for sub in created_subjects:
    # 35 theory sessions per subject
    for s_date in session_dates[:35]:
        sess, created = AttendanceSession.objects.get_or_create(
            subject=sub,
            faculty=faculty,
            date=s_date,
            session_type="THEORY",
            extra_class=None,
            defaults={"session_count": 1}
        )
        if created:
            sessions_created += 1

        for st, target_pct in active_students:
            # Deterministic pseudo-random based on student and date to match target_pct
            seed = (hash(st.usn) + s_date.day * 7 + s_date.month * 31 + sub.id * 13) % 100
            is_present = (seed / 100.0) < target_pct
            status = "Present" if is_present else "Absent"

            rec, r_created = AttendanceRecord.objects.get_or_create(
                session=sess,
                student=st,
                defaults={"status": status}
            )
            if r_created:
                records_created += 1

    # Lab sessions
    if sub.has_lab:
        sub_batches = [b for b in lab_batches if b.subject_id == sub.id]
        for b in sub_batches:
            batch_students = [lbs.student for lbs in b.batch_students.all()]
            for s_date in session_dates[-12:]:  # 12 lab sessions
                lab_sess, created = AttendanceSession.objects.get_or_create(
                    subject=sub,
                    faculty=faculty,
                    date=s_date,
                    session_type="LAB",
                    batch=b,
                    extra_class=None,
                    defaults={"session_count": 1}
                )
                if created:
                    sessions_created += 1

                for st in batch_students:
                    # Look up student target_pct
                    pct = next((p for s, p in active_students if s.id == st.id), 0.7)
                    seed = (hash(st.usn) + s_date.day * 11 + b.id * 17) % 100
                    status = "Present" if (seed / 100.0) < pct else "Absent"

                    rec, r_created = AttendanceRecord.objects.get_or_create(
                        session=lab_sess,
                        student=st,
                        defaults={"status": status}
                    )
                    if r_created:
                        records_created += 1

print(f"Created {sessions_created} new sessions and {records_created} new attendance records.")

# 7. Create IA Tests for each of the 6 subjects
for sub in created_subjects:
    if not IATestSetup.objects.filter(subject=sub, ia_type="Test1").exists():
        IATestSetup.objects.create(
            subject=sub,
            faculty=prof_user,
            ia_type="Test1",
            ia_name="Internal Assessment 1",
            max_marks=25,
            status="DRAFT",
        )
    if not IATestSetup.objects.filter(subject=sub, ia_type="Test2").exists():
        IATestSetup.objects.create(
            subject=sub,
            faculty=prof_user,
            ia_type="Test2",
            ia_name="Internal Assessment 2",
            max_marks=25,
            status="DRAFT",
        )

print("IA Tests configured for all subjects.")
print("ALL DUMMY DATA CREATED SUCCESSFULLY!")
