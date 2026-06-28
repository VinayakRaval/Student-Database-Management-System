from django.urls import reverse
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from django.contrib.auth import get_user_model

from academics.models import Department, Semester, AcademicYear
from subjects.models import Subject, SubjectAssignment
from students.models import Student
from faculty.models import Faculty

from .models import IATestSetup, IAMark, IAAggregate

User = get_user_model()


# ----------------------------------------------------
# Helper function to create valid Student objects
# ----------------------------------------------------
def make_student(dept, sem, ay, usn="1GV20CS001", name="Test Student",
                 status="active", user=None, email=None):

    return Student.objects.create(
        user=user,
        name=name,
        cet_no="CET" + usn[-3:],
        dob="2000-01-01",
        religion="Hindu",
        city_type="Urban",
        mobile_no="9999999999",
        email=email or f"{usn}@example.com",
        parent_occupation="Farmer",
        address="Address",
        permanent_address="Address",
        seat_type="general_merit",
        date_of_admission="2024-01-01",
        department=dept,
        semester=sem,
        academic_year=ay,
        status=status,
        usn=usn
    )


# ----------------------------------------------------
# Main Test Class
# ----------------------------------------------------
class IAAssessmentAPITests(TestCase):
    def setUp(self):
        # ---- Academics ----
        self.department = Department.objects.create(name="CSE")
        self.sem1 = Semester.objects.create(sem_number=1)
        self.ay = AcademicYear.objects.create(year_name="2024-2025")

        # ---- Users ----
        self.faculty_user = User.objects.create_user(
            email="fac@test.com", password="pass123", role="FACULTY"
        )
        self.other_faculty_user = User.objects.create_user(
            email="fac2@test.com", password="pass123", role="FACULTY"
        )
        self.student_user = User.objects.create_user(
            email="stu_user@test.com", password="pass123", role="STUDENT"
        )

        # ---- Faculty (REAL MODEL required by SubjectAssignment) ----
        self.faculty = Faculty.objects.create(
            faculty_id="FAC001",
            name="Faculty One",
            department=self.department,
            email="fac@test.com",
            phone="9999999999",
            role="FACULTY",
        )

        self.other_faculty = Faculty.objects.create(
            faculty_id="FAC002",
            name="Faculty Two",
            department=self.department,
            email="fac2@test.com",
            phone="9999998888",
            role="FACULTY",
        )

        # ---- Subject ----
        self.subject = Subject.objects.create(
            department=self.department,
            semester=self.sem1,
            subject_name="Data Structures",
            subject_code="CS101"
        )

        # ---- Faculty Subject Assignment ----
        SubjectAssignment.objects.create(
            subject=self.subject,
            faculty=self.faculty,
            academic_year=self.ay,
            department=self.department,
            semester=self.sem1
        )

        # ---- Students ----
        self.std1 = make_student(self.department, self.sem1, self.ay,
                                 usn="1GV20CS001", name="Std One")
        self.std2 = make_student(self.department, self.sem1, self.ay,
                                 usn="1GV20CS002", name="Std Two")

        # student linked to student_user
        self.std_user_student = make_student(
            self.department, self.sem1, self.ay,
            usn="1GV20CS010", name="User Student",
            user=self.student_user,
            email="stu_user@test.com"
        )

        # ---- Authenticated Clients ----
        self.fac_client = APIClient()
        self.fac_client.force_authenticate(self.faculty_user)

        self.other_fac_client = APIClient()
        self.other_fac_client.force_authenticate(self.other_faculty_user)

        self.student_client = APIClient()
        self.student_client.force_authenticate(self.student_user)

    # ----------------------------------------------------
    # 1. Faculty creates IA Test Setup
    # ----------------------------------------------------
    def test_create_ia_setup(self):
        response = self.fac_client.post("/ia_assessment/ia-tests/create/", {
            "subject": self.subject.id,
            "ia_type": "Test1",
            "ia_name": "Unit Test 1",
            "max_marks": 50
        })

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(IATestSetup.objects.count(), 1)

    # ----------------------------------------------------
    # 2. Faculty fetches active students
    # ----------------------------------------------------
    def test_faculty_active_students_view(self):
        url = f"/ia_assessment/faculty/active-students/?subject_id={self.subject.id}"
        res = self.fac_client.get(url)

        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.data), 3)  # std1, std2, std_user_student

    # ----------------------------------------------------
    # 3. Faculty enters/updates IA marks
    # ----------------------------------------------------
    def test_bulk_mark_update(self):
        ia_test = IATestSetup.objects.create(
            subject=self.subject,
            faculty=self.faculty_user,
            ia_type="Test1",
            ia_name="UT1",
            max_marks=50
        )

        url = f"/ia_assessment/ia-tests/{ia_test.id}/update-marks/"
        res = self.fac_client.put(url, {
            "marks": [
                {"student_id": self.std1.id, "obtained_marks": 40},
                {"student_id": self.std2.id, "obtained_marks": 35},
            ]
        }, format="json")

        self.assertEqual(res.status_code, 200)
        self.assertEqual(IAMark.objects.count(), 2)

    # ----------------------------------------------------
    # 4. Student views own IA marks
    # ----------------------------------------------------
    def test_student_view_own_ia_marks(self):
        ia_test = IATestSetup.objects.create(
            subject=self.subject,
            faculty=self.faculty_user,
            ia_type="Test2",
            ia_name="UT2",
            max_marks=50
        )

        IAMark.objects.create(
            ia_test=ia_test,
            student=self.std_user_student,
            obtained_marks=45
        )

        url = "/ia_assessment/student/ia-marks/"
        res = self.student_client.get(url)

        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.data), 1)
