from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status

from academics.models import Department, Semester, Schema, AcademicYear
from faculty.models import Faculty
from subjects.models import Subject, SubjectAssignment
from timetable.models import TimeTable
from userlogin.models import PasswordAuditLog
from userlogin.password_service import set_temporary_password_for_user

User = get_user_model()


class SubjectProjectAndElectiveTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.dept_cse = Department.objects.create(name="Computer Science")
        self.dept_me = Department.objects.create(name="Mechanical Engineering")
        self.dept_cv = Department.objects.create(name="Civil Engineering")

        self.sem5 = Semester.objects.create(sem_number=5)
        self.sem7 = Semester.objects.create(sem_number=7)

        self.schema = Schema.objects.create(name="2022 Scheme")
        self.ay = AcademicYear.objects.create(year_name="2026-2027")

        # HOD CSE user
        self.hod_user = User.objects.create_user(
            email="hod_cse@example.com",
            password="Password@123",
            role="HOD",
            department=self.dept_cse
        )
        self.hod_faculty = Faculty.objects.create(
            user=self.hod_user,
            faculty_id="HODCS01",
            name="Dr. CSE HOD",
            email="hod_cse@example.com",
            phone="9876543210",
            department=self.dept_cse,
            role="HOD",
            status="approved"
        )

        # Faculty CSE
        self.cse_fac_user = User.objects.create_user(
            email="prof_cs@example.com",
            password="Password@123",
            role="PROFESSOR",
            department=self.dept_cse
        )
        self.cse_faculty = Faculty.objects.create(
            user=self.cse_fac_user,
            faculty_id="PROFCS01",
            name="Prof CS One",
            email="prof_cs@example.com",
            phone="9876543211",
            department=self.dept_cse,
            role="PROFESSOR",
            status="approved"
        )

        # Faculty Mechanical
        self.me_fac_user = User.objects.create_user(
            email="prof_me@example.com",
            password="Password@123",
            role="PROFESSOR",
            department=self.dept_me
        )
        self.me_faculty = Faculty.objects.create(
            user=self.me_fac_user,
            faculty_id="PROFME01",
            name="Prof ME One",
            email="prof_me@example.com",
            phone="9876543212",
            department=self.dept_me,
            role="PROFESSOR",
            status="approved"
        )

    def test_add_project_subject_type(self):
        """Test adding a Project subject (e.g. Major Project Phase II) without requiring theory or practical hours."""
        self.client.force_authenticate(user=self.hod_user)
        payload = {
            "department": self.dept_cse.id,
            "semester": self.sem7.id,
            "subject_name": "Major Project Phase II",
            "subject_code": "22CSP75",
            "subject_type": "PROJECT",
            "credits": 10,
            "theory_hours": 0,
            "tutorial_hours": 0,
            "practical_hours": 0,
            "total_teaching_hours": 6,
            "schema": self.schema.id,
            "academic_year": self.ay.id,
        }
        res = self.client.post("/subjects/addSubject/", data=payload, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        subject = Subject.objects.get(subject_code="22CSP75")
        self.assertEqual(subject.subject_type, "PROJECT")
        self.assertEqual(subject.credits, 10)
        self.assertFalse(subject.has_theory)
        self.assertFalse(subject.has_lab)

    def test_timetable_auto_approved_for_hod(self):
        """Test department timetable created by HOD is automatically approved and not sent to Principal."""
        self.client.force_authenticate(user=self.hod_user)
        payload = {
            "department": self.dept_cse.id,
            "semester": self.sem5.id,
            "academic_year": self.ay.id,
            "effective_date": "2026-11-01",
            "slots": [],
        }
        res = self.client.post("/timetable/timetables/", data=payload, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        tt_id = res.data["id"]
        tt = TimeTable.objects.get(id=tt_id)
        self.assertEqual(tt.status, "Approved")
        self.assertTrue(tt.is_active)

    def test_elective_faculty_assignment_offering_department_enforcement(self):
        """Test that elective subjects can only be assigned to faculty from the offering department."""
        # Open elective offered by CSE
        elective = Subject.objects.create(
            department=self.dept_cse,
            semester=self.sem7,
            subject_name="Cloud Computing",
            subject_code="22CS751",
            is_elective=True,
            subject_type="THEORY",
            credits=3,
            theory_hours=3,
        )

        self.client.force_authenticate(user=self.hod_user)

        # 1. Attempt assigning ME faculty to CSE elective -> should fail
        fail_payload = {
            "department_id": self.dept_cse.id,
            "assignments": [
                {
                    "subject_id": elective.id,
                    "subject_code": elective.subject_code,
                    "faculty_id": self.me_faculty.id,
                    "semester": self.sem7.id,
                    "academic_year": self.ay.id,
                }
            ]
        }
        res_fail = self.client.post("/subjects/assign_subjects/", data=fail_payload, format="json")
        self.assertEqual(res_fail.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("only faculty members belonging to offering department", res_fail.data.get("error", ""))

        # 2. Assign CSE faculty to CSE elective -> should succeed
        success_payload = {
            "department_id": self.dept_cse.id,
            "assignments": [
                {
                    "subject_id": elective.id,
                    "subject_code": elective.subject_code,
                    "faculty_id": self.cse_faculty.id,
                    "semester": self.sem7.id,
                    "academic_year": self.ay.id,
                }
            ]
        }
        res_success = self.client.post("/subjects/assign_subjects/", data=success_payload, format="json")
        self.assertEqual(res_success.status_code, status.HTTP_200_OK, res_success.data)
        assignment = SubjectAssignment.objects.filter(subject=elective, faculty=self.cse_faculty).first()
        self.assertIsNotNone(assignment)

    def test_temporary_password_generation_and_auto_erase_on_change(self):
        """Test temporary password is generated on creation and erased automatically on password change."""
        # Create faculty with temporary password
        fac_user = User.objects.create_user(
            email="temp_fac@example.com",
            user_id="PROFTEMP01",
            role="PROFESSOR",
            department=self.dept_cse,
            force_password_change=True,
        )
        temp_pwd = set_temporary_password_for_user(
            user=fac_user,
            actor=self.hod_user,
            action=PasswordAuditLog.ACTION_INITIAL_CREATION
        )
        faculty = Faculty.objects.create(
            user=fac_user,
            faculty_id="PROFTEMP01",
            name="Prof Temp",
            email="temp_fac@example.com",
            phone="9876543299",
            department=self.dept_cse,
            role="PROFESSOR",
            status="approved",
            temp_password=temp_pwd
        )

        # HOD can view temporary password
        self.client.force_authenticate(user=self.hod_user)
        res = self.client.get(f"/faculty/faculties/{faculty.id}/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data.get("temp_password"), temp_pwd)

        # Faculty logs in and changes password
        self.client.force_authenticate(user=fac_user)
        pwd_res = self.client.post("/userlogin/password/change/", data={
            "old_password": temp_pwd,
            "new_password": "NewPermanentPassword@2026"
        }, format="json")
        self.assertEqual(pwd_res.status_code, status.HTTP_200_OK, pwd_res.data)

        # Verify temp_password is automatically erased in database
        faculty.refresh_from_db()
        self.assertIsNone(faculty.temp_password)

        # Verify serializer returns None for temp_password
        self.client.force_authenticate(user=self.hod_user)
        res_after = self.client.get(f"/faculty/faculties/{faculty.id}/")
        self.assertIsNone(res_after.data.get("temp_password"))
