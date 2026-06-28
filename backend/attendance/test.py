from rest_framework.test import APITestCase, APIClient
from rest_framework import status
from django.contrib.auth import get_user_model
from django.utils import timezone

from attendance.models import AttendanceSession, AttendanceRecord
from students.models import Student
from faculty.models import Faculty
from subjects.models import Subject, SubjectAssignment
from academics.models import Department, Semester, AcademicYear

User = get_user_model()


class BaseAttendanceTest(APITestCase):
    def setUp(self):
        # --- USERS ---
        self.faculty_user = User.objects.create_user(
            email="faculty@test.com",
            password="pass123",
            role="FACULTY"
        )
        self.client.force_authenticate(self.faculty_user)

        # --- FACULTY PROFILE ---
        self.department = Department.objects.create(name="CSE")
        self.sem1 = Semester.objects.create(sem_number=1)
        self.ay = AcademicYear.objects.create(year_name="2024-2025")

        self.faculty = Faculty.objects.create(
             user=self.faculty_user,
            faculty_id="FAC001",
            name="Test Faculty",
            gender="male",
            dob="1980-01-01",
            phone="9999999999",
            email="facultyprofile@test.com",
            department=self.department,
            qualification="M.Tech",
            role="PROFESSOR",
            status="approved"
        )

        # --- SUBJECT ---
        self.subject = Subject.objects.create(
            subject_code="CS101",
            subject_name="Data Structures",
            department=self.department,
            semester=self.sem1
        )

        # Assign subject to faculty for specific sem & year
        self.assignment = SubjectAssignment.objects.create(
            subject=self.subject,
            faculty=self.faculty,
            department=self.department,
            semester=self.sem1,
            academic_year=self.ay,
        )

        # --- STUDENT ---
        self.student = Student.objects.create(
            name="John Student",
            cet_no="CET001",
            dob="2000-01-01",
            religion="Hindu",
            city_type="Urban",
            mobile_no="9999999999",
            email="student@test.com",
            parent_occupation="Farmer",
            address="Address",
            permanent_address="Address",
            seat_type="general_merit",
            date_of_admission="2024-01-01",
            department=self.department,
            semester=self.sem1,
            academic_year=self.ay,
            status="active"
        )


# -----------------------------------------------------------------------------------
# TESTS
# -----------------------------------------------------------------------------------

class AttendanceTests(BaseAttendanceTest):

    def test_create_attendance_session(self):
        url = "/attendance/session/add/"
        payload = {
            "subject": self.subject.id,
            "faculty": self.faculty.id,
            "date": "2025-01-01",
            "session_count": 1,
        }
        response = self.client.post(url, payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(AttendanceSession.objects.count(), 1)

    def test_create_attendance_record(self):
        # create session
        session = AttendanceSession.objects.create(
            subject=self.subject,
            faculty=self.faculty,
            date="2025-01-01",
            session_count=1
        )

        url = "/attendance/record/add/"
        payload = {
            "session": session.id,
            "student": self.student.id,
            "status": "Present"
        }

        response = self.client.post(url, payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(AttendanceRecord.objects.count(), 1)

    def test_attendance_report(self):
        # create sessions and records
        session = AttendanceSession.objects.create(
            subject=self.subject,
            faculty=self.faculty,
            date="2025-01-01",
            session_count=1
        )

        AttendanceRecord.objects.create(
            session=session,
            student=self.student,
            status="Present"
        )

        url = f"/attendance/report/?subject_id={self.subject.id}"
        response = self.client.get(url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["present"], 1)

    def test_student_attendance_summary(self):
        # create sessions + records
        session1 = AttendanceSession.objects.create(
            subject=self.subject,
            faculty=self.faculty,
            date="2025-01-01",
            session_count=1
        )

        AttendanceRecord.objects.create(
            session=session1,
            student=self.student,
            status="Present"
        )

        url = f"/attendance/student/{self.student.id}/"
        response = self.client.get(url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["present"], 1)
        self.assertEqual(response.data["total_sessions"], 1)

    def test_faculty_active_students(self):
        url = f"/attendance/students/?subject_id={self.subject.id}"
        response = self.client.get(url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["name"], "John Student")
