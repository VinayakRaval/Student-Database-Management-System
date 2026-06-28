from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APITestCase, APIClient
from rest_framework import status

from django.contrib.auth import get_user_model

from academics.models import Department, Semester, AcademicYear
from subjects.models import Subject, SubjectAssignment
from faculty.models import Faculty
from timetable.models import TimeTable, TimeTableSlot, TimeTableApprovalHistory
from datetime import time



User = get_user_model()


class TimeTableAPITests(APITestCase):

    def setUp(self):
        # --- Academics ---
        self.department = Department.objects.create(name="CSE")
        self.sem1 = Semester.objects.create(sem_number=1)
        self.ay = AcademicYear.objects.create(year_name="2024-25")

        # --- Users ---
        self.hod_user = User.objects.create_user(
            email="hod@test.com", password="pass123", role="HOD"
        )
        self.principal_user = User.objects.create_user(
            email="pr@test.com", password="pass123", role="PRINCIPAL"
        )
        self.normal_user = User.objects.create_user(
            email="user@test.com", password="pass123", role="STUDENT"
        )

        # --- Faculty ---
        self.faculty = Faculty.objects.create(
            faculty_id="FAC01",
            name="Prof One",
            department=self.department,
            email="fac@test.com",
            phone="9999999999",
            role="FACULTY",
        )

        # --- Subject ---
        self.subject = Subject.objects.create(
            subject_name="DSA", subject_code="CS101",
            department=self.department, semester=self.sem1
        )

        # --- Assignment ---
        self.assignment = SubjectAssignment.objects.create(
            subject=self.subject,
            faculty=self.faculty,
            academic_year=self.ay,
            department=self.department,
            semester=self.sem1
        )

        # Clients
        self.hod_client = APIClient()
        self.hod_client.force_authenticate(self.hod_user)

        self.principal_client = APIClient()
        self.principal_client.force_authenticate(self.principal_user)

        self.user_client = APIClient()
        self.user_client.force_authenticate(self.normal_user)

    # =====================================================
    # 1. CREATE TIMETABLE (HOD only)
    # =====================================================
    def test_create_timetable(self):
        url = reverse("timetable-list")
        payload = {
            "department": self.department.id,
            "semester": self.sem1.id,
            "academic_year": self.ay.id,
            "slots": [
                {
                    "day": "MON",
                    "start_time": "09:00",
                    "end_time": "10:00",
                    "assignment": self.assignment.id
                }
            ]
        }
        res = self.hod_client.post(url, payload, format="json")

        self.assertEqual(res.status_code, 201)
        self.assertEqual(TimeTable.objects.count(), 1)
        self.assertEqual(TimeTableSlot.objects.count(), 1)

    # =====================================================
    # 2. STUDENT cannot create timetable
    # =====================================================
    def test_student_cannot_create_timetable(self):
        url = reverse("timetable-list")
        payload = {
            "department": self.department.id,
            "semester": self.sem1.id,
            "academic_year": self.ay.id,
            "slots": []
        }
        res = self.user_client.post(url, payload, format="json")
        self.assertEqual(res.status_code, 403)

    # =====================================================
    # 3. VALIDATION — Wrong assignment (different dept)
    # =====================================================
    def test_invalid_assignment_wrong_department(self):
        # Create new department
        new_dept = Department.objects.create(name="MECH")

        # Make assignment in wrong dept
        wrong_sub = Subject.objects.create(
            subject_name="Mechanics", subject_code="ME101",
            department=new_dept, semester=self.sem1
        )

        wrong_assignment = SubjectAssignment.objects.create(
            subject=wrong_sub,
            faculty=self.faculty,
            academic_year=self.ay,
            department=new_dept,
            semester=self.sem1
        )

        url = reverse("timetable-list")
        payload = {
            "department": self.department.id,
            "semester": self.sem1.id,
            "academic_year": self.ay.id,
            "slots": [
                {
                    "day": "MON",
                    "start_time": "08:00",
                    "end_time": "09:00",
                    "assignment": wrong_assignment.id
                }
            ]
        }

        res = self.hod_client.post(url, payload, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertIn("department mismatch", str(res.data).lower())

    # =====================================================
    # 4. APPROVE TIMETABLE (Principal only)
    # =====================================================
    def create_sample_timetable(self):
        tt = TimeTable.objects.create(
        department=self.department,
        semester=self.sem1,
        academic_year=self.ay,
        created_by=self.hod_user,
        status="Approved",
        is_active=True
     )
        TimeTableSlot.objects.create(
            timetable=tt,
            day="MON",
            start_time="09:00",
            end_time="10:00",
            assignment=self.assignment
        )
        return tt

    def test_principal_approves_timetable(self):
        tt = self.create_sample_timetable()

        url = reverse("timetable-approve", args=[tt.id])
        payload = {"action": "Approved"}

        res = self.principal_client.post(url, payload, format="json")

        tt.refresh_from_db()

        self.assertEqual(res.status_code, 200)
        self.assertEqual(tt.status, "Approved")
        self.assertTrue(tt.is_active)

    # =====================================================
    # 5. PRINCIPAL Rejects Timetable
    # =====================================================
    def test_principal_rejects_timetable(self):
        tt = self.create_sample_timetable()

        url = reverse("timetable-approve", args=[tt.id])
        payload = {"action": "Rejected", "remarks": "Incorrect data"}

        res = self.principal_client.post(url, payload, format="json")

        tt.refresh_from_db()

        self.assertEqual(res.status_code, 200)
        self.assertEqual(tt.status, "Rejected")

    # =====================================================
    # 6. CONFLICT DETECTION
    # =====================================================
    def test_conflict_detection(self):

    # ensure the assignment belongs to same department + semester for both slots
        self.assignment.semester = self.sem1
        self.assignment.department = self.department
        self.assignment.save()

        # First timetable (active)
        active_tt = TimeTable.objects.create(
            department=self.department,
            semester=self.sem1,
            academic_year=self.ay,
            created_by=self.hod_user,
            status="Approved",
            is_active=True
        )

        TimeTableSlot.objects.create(
            timetable=active_tt,
            day="MON",
            start_time=time(9, 0),
            end_time=time(10, 0),
            assignment=self.assignment
        )

        # New timetable with overlapping slot
        new_tt = TimeTable.objects.create(
            department=self.department,
            semester=self.sem1,
            academic_year=self.ay,
            created_by=self.hod_user,
            status="Pending"
        )

        TimeTableSlot.objects.create(
            timetable=new_tt,
            day="MON",
            start_time=time(9, 30),
            end_time=time(10, 30),
            assignment=self.assignment
        )

        url = reverse("timetable-approve", args=[new_tt.id])
        payload = {"action": "Approved"}

        res = self.principal_client.post(url, payload, format="json")

        print(res.data)

        self.assertEqual(res.status_code, 409)
        self.assertIn("conflicts", str(res.data).lower())


    # =====================================================
    # 7. LIST PENDING TIMETABLES
    # =====================================================
    def test_pending_timetables_list(self):
        TimeTable.objects.create(
            department=self.department,
            semester=self.sem1,
            academic_year=self.ay,
            created_by=self.hod_user,
            status="Pending"
        )

        url = reverse("timetable-pending")
        res = self.principal_client.get(url)

        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.data), 1)

    # =====================================================
    # 8. ASSIGNMENTS API
    # =====================================================
    def test_assignments_api(self):
        url = reverse("timetable-assignments")
        res = self.hod_client.get(url)

        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data[0]["subject_code"], "CS101")
