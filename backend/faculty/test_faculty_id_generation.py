import os
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient
from rest_framework import status
from userlogin.models import CustomUser
from academics.models import Department
from faculty.models import Faculty
from faculty.views import generate_faculty_registration_id

class FacultyRegistrationIdTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.dept = Department.objects.create(name="Computer Science and Engineering")
        self.admin = CustomUser.objects.create_user(
            email="admin@test.com",
            user_id="ADMIN001",
            password="adminpassword123",
            role="SYSTEM"
        )
        self.client.force_authenticate(user=self.admin)

    def test_next_id_guest_faculty(self):
        res = self.client.get("/faculty/next-id/", {"designation": "Guest Faculty"})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data["next_id"].startswith("GUEST"))
        self.assertEqual(res.data["next_id"], "GUEST001")

    def test_next_id_professor(self):
        res = self.client.get("/faculty/next-id/", {"designation": "Professor"})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data["next_id"].startswith("PROF"))

    def test_sequential_guest_generation(self):
        id1 = generate_faculty_registration_id(designation_or_role="Guest Faculty", is_guest=True)
        self.assertEqual(id1, "GUEST001")

        # Create faculty with GUEST001
        f1 = Faculty.objects.create(
            faculty_id="GUEST001",
            name="Guest One",
            email="guest1@example.com",
            phone="9876543210",
            department=self.dept,
            is_guest_faculty=True,
            employment_type="GUEST",
            designation="Guest Faculty"
        )
        id2 = generate_faculty_registration_id(designation_or_role="Guest Faculty", is_guest=True)
        self.assertEqual(id2, "GUEST002")

    def test_sequential_prof_generation(self):
        # Create PROF001
        Faculty.objects.create(
            faculty_id="PROF001",
            name="Prof One",
            email="prof1@example.com",
            phone="9876543211",
            department=self.dept,
            designation="Professor"
        )
        id2 = generate_faculty_registration_id(designation_or_role="Professor")
        self.assertEqual(id2, "PROF002")
