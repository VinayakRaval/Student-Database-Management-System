from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from userlogin.models import CustomUser
from academics.models import Department, Semester, AcademicYear
from attendance.models import LabBatch, LabBatchStudent
from students.models import Student
from timetable.models import TimeTable

class FirstAttemptLoginAndBugFixesTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.dept = Department.objects.create(name="Civil Engineering")
        self.sem7 = Semester.objects.create(sem_number=7)
        self.ay = AcademicYear.objects.create(year_name="2026-2027")

        self.hod_user = CustomUser.objects.create_user(
            email="hod.civil@sdms.edu",
            user_id="HODCIVIL01",
            password="HodPassword@123",
            role="HOD",
            department=self.dept
        )

    def test_first_attempt_login_with_stale_bearer_token(self):
        # Stale expired or garbage Authorization header sent by client/browser
        self.client.credentials(HTTP_AUTHORIZATION='Bearer invalid_or_expired_jwt_token_12345')

        # Attempt login for the first time
        res = self.client.post("/userlogin/login/", {
            "identifier": "hod.civil@sdms.edu",
            "password": "HodPassword@123"
        }, format="json")

        # Must succeed on first attempt without 401 Unauthorized
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("access", res.data)
        self.assertIn("refresh", res.data)
        self.assertEqual(res.data["role"], "HOD")

    def test_fetch_students_for_lab_batch_without_subject(self):
        self.client.force_authenticate(user=self.hod_user)

        # Create LabBatch with subject=None
        batch = LabBatch.objects.create(
            name="Batch A",
            department=self.dept,
            semester=self.sem7,
            academic_year=self.ay,
            subject=None
        )

        res = self.client.get(f"/attendance/fetch_students_for_lab_batch/?batch_id={batch.id}")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["batch"]["name"], "Batch A")
        self.assertIsNone(res.data["batch"]["subject_id"])
        self.assertEqual(res.data["batch"]["subject_code"], "")

    def test_delete_department_timetable(self):
        self.client.force_authenticate(user=self.hod_user)

        tt = TimeTable.objects.create(
            department=self.dept,
            semester=self.sem7,
            academic_year=self.ay,
            created_by=self.hod_user,
            status="Draft"
        )
        self.assertEqual(TimeTable.objects.filter(id=tt.id).count(), 1)

        # Delete timetable
        res = self.client.delete(f"/timetable/timetables/{tt.id}/")
        self.assertEqual(res.status_code, status.HTTP_204_NO_CONTENT)
        self.assertEqual(TimeTable.objects.filter(id=tt.id).count(), 0)
