from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from django.contrib.auth import get_user_model

from academics.models import Department
from faculty.models import Faculty
from hod_assignment.models import HODAssignment

User = get_user_model()


class HODAssignmentTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # --- Create Department ---
        self.dept = Department.objects.create(name="CSE")

        # --- Create Admin User ---
        self.admin = User.objects.create_user(
            email="admin@test.com",
            password="pass123",
            role="SYSTEM",
            is_staff=True,
            is_superuser=True,
        )

        # --- Create Faculty Users ---
        self.user1 = User.objects.create_user(
            email="fac1user@test.com",
            password="pass123",
            role="PROFESSOR"
        )

        self.user2 = User.objects.create_user(
            email="fac2user@test.com",
            password="pass123",
            role="PROFESSOR"
        )

        # --- Create Faculty Profiles ---
        self.fac1 = Faculty.objects.create(
            user=self.user1,
            faculty_id="FAC001",
            name="Faculty One",
            phone="9000000001",
            email="fac1@test.com",
            department=self.dept,
            role="PROFESSOR",
        )

        self.fac2 = Faculty.objects.create(
            user=self.user2,
            faculty_id="FAC002",
            name="Faculty Two",
            phone="9000000002",
            email="fac2@test.com",
            department=self.dept,
            role="PROFESSOR",
        )

    # ---------------------------------------------------------
    # 1. Only Admin can assign a HOD
    # ---------------------------------------------------------
    def test_non_admin_cannot_assign_hod(self):
        self.client.force_authenticate(self.user1)  # not admin
        res = self.client.post("/hod_assignment/assign/", {
            "faculty": self.fac1.id,
            "department": self.dept.id
        })
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    # ---------------------------------------------------------
    # 2. Admin can assign HOD
    # ---------------------------------------------------------
    def test_admin_can_assign_hod(self):
        self.client.force_authenticate(self.admin)

        res = self.client.post("/hod_assignment/assign/", {
            "faculty": self.fac1.id,
            "department": self.dept.id
        })

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(HODAssignment.objects.count(), 1)

        assignment = HODAssignment.objects.first()
        self.assertIsNone(assignment.end_date)  # active HOD

        self.fac1.refresh_from_db()
        self.assertEqual(self.fac1.role, "HOD")

    # ---------------------------------------------------------
    # 3. Reassigning HOD closes previous assignment
    # ---------------------------------------------------------
    def test_assign_new_hod_closes_previous(self):
        self.client.force_authenticate(self.admin)

        # First assignment
        self.client.post("/hod_assignment/assign/", {
            "faculty": self.fac1.id,
            "department": self.dept.id
        })

        # Second assignment
        self.client.post("/hod_assignment/assign/", {
            "faculty": self.fac2.id,
            "department": self.dept.id
        })

        self.assertEqual(HODAssignment.objects.count(), 2)

        old_hod = HODAssignment.objects.get(faculty=self.fac1)
        new_hod = HODAssignment.objects.get(faculty=self.fac2)

        self.assertIsNotNone(old_hod.end_date)
        self.assertIsNone(new_hod.end_date)

        self.fac2.refresh_from_db()
        self.assertEqual(self.fac2.role, "HOD")

    # ---------------------------------------------------------
    # 4. Current HOD List
    # ---------------------------------------------------------
    def test_current_hod(self):
        HODAssignment.objects.create(
            faculty=self.fac1,
            department=self.dept,
            end_date=None
        )

        res = self.client.get("/hod_assignment/current/")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.data), 1)

    # ---------------------------------------------------------
    # 5. Previous HOD List
    # ---------------------------------------------------------
    def test_previous_hod(self):
        HODAssignment.objects.create(
            faculty=self.fac1,
            department=self.dept,
            end_date="2024-01-01"
        )

        res = self.client.get("/hod_assignment/previous/")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.data), 1)
