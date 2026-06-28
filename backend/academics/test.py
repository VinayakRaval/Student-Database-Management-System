from django.urls import reverse
from rest_framework.test import APITestCase, APIClient
from rest_framework import status
from django.contrib.auth import get_user_model

from .models import Department, Semester, AcademicYear, Schema

User = get_user_model()


class BaseTestSetup(APITestCase):
    def setUp(self):
        # Create admin user
        self.admin_user = User.objects.create_user(
            email="admin@example.com", password="admin123", role="ADMIN", is_staff=True
        )

        # Create normal user
        self.normal_user = User.objects.create_user(
            email="user@example.com", password="user123", role="STUDENT"
        )

        # Authenticated clients
        self.admin_client = APIClient()
        self.admin_client.force_authenticate(self.admin_user)

        self.user_client = APIClient()
        self.user_client.force_authenticate(self.normal_user)


# -------------------- MODEL TESTS -------------------- #

class ModelTests(APITestCase):
    def test_department_creation(self):
        dept = Department.objects.create(name="Computer Science")
        self.assertEqual(str(dept), "Computer Science")

    def test_semester_creation(self):
        sem = Semester.objects.create(sem_number=3)
        self.assertEqual(str(sem), "Semester 3")

    def test_academic_year_creation(self):
        ay = AcademicYear.objects.create(year_name="2025-2026")
        self.assertEqual(str(ay), "2025-2026")

    def test_schema_creation(self):
        dept = Department.objects.create(name="ECE")
        schema = Schema.objects.create(name="ECE-2025", department=dept)
        self.assertIn("ECE", str(schema))


# -------------------- API TESTS -------------------- #

class DepartmentAPITests(BaseTestSetup):

    def test_list_departments(self):
        Department.objects.create(name="IT")
        response = self.client.get("/academics/departments/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_create_department_admin_only(self):
        data = {"name": "Mechanical"}
        response = self.admin_client.post("/academics/departments/", data)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_create_department_permission_denied_for_user(self):
        data = {"name": "Civil"}
        response = self.user_client.post("/academics/departments/", data)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class SemesterAPITests(BaseTestSetup):

    def test_list_semesters(self):
        Semester.objects.create(sem_number=4)
        response = self.client.get("/academics/semesters/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_create_semester_admin_only(self):
        data = {"sem_number": 2}
        response = self.admin_client.post("/academics/semesters/", data)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)


class AcademicYearAPITests(BaseTestSetup):

    def test_create_academic_year_requires_auth(self):
        data = {"year_name": "2026-2027"}
        response = self.client.post("/academics/academic-years/", data)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_create_academic_year_authenticated_success(self):
        data = {"year_name": "2027-2028"}
        response = self.user_client.post("/academics/academic-years/", data)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)


class SchemaAPITests(BaseTestSetup):

    def test_create_schema(self):
        dept = Department.objects.create(name="AI & ML")
        data = {"name": "AIML-2026", "department": dept.id}
        response = self.user_client.post("/academics/schemas/", data)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_list_schema(self):
        dept = Department.objects.create(name="EEE")
        Schema.objects.create(name="EEE-2029", department=dept)
        response = self.client.get("/academics/schemas/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
