from django.urls import reverse
from rest_framework.test import APITestCase, APIClient
from rest_framework import status
from django.contrib.auth import get_user_model
from academics.models import Department, Semester, AcademicYear
from .models import Student

User = get_user_model()


class BaseStudentAPITest(APITestCase):
    def setUp(self):
        # Create roles
        self.principal = User.objects.create_user(email="principal@test.com", password="pass123", role="PRINCIPAL")
        self.hod = User.objects.create_user(email="hod@test.com", password="pass123", role="HOD")
        self.normal_student_user = User.objects.create_user(email="stud@test.com", password="pass123", role="STUDENT")

        self.principal_client = APIClient()
        self.principal_client.force_authenticate(self.principal)

        self.hod_client = APIClient()
        self.hod_client.force_authenticate(self.hod)

        self.student_client = APIClient()
        self.student_client.force_authenticate(self.normal_student_user)

        # Common DB objects
        self.department = Department.objects.create(name="CSE")
        self.sem1 = Semester.objects.create(sem_number=1)
        self.ay = AcademicYear.objects.create(year_name="2024-2025")


# ----------------------------------------------------------------------------------
# MODEL TESTS
# ----------------------------------------------------------------------------------

class StudentModelTests(APITestCase):

    def test_student_admission_id_auto_generation(self):
        student = Student.objects.create(
            name="Test User",
            cet_no="CET123",
            dob="2000-01-01",
            religion="Hindu",
            city_type="Urban",
            mobile_no="9999999999",
            email="testuser@email.com",
            parent_occupation="Farmer",
            address="Addr",
            permanent_address="Addr",
            seat_type="general_merit",
            date_of_admission="2025-01-01"
        )
        self.assertTrue(student.admission_id.startswith("GECC"))


# ----------------------------------------------------------------------------------
# API TESTS
# ----------------------------------------------------------------------------------

class StudentAPITests(BaseStudentAPITest):

    def test_student_registration_success(self):
        url = "/students/create/"
        payload = {
            "name": "John Wick",
            "cet_no": "CET001",
            "dob": "2000-05-01",
            "religion": "Hindu",
            "city_type": "Urban",
            "mobile_no": "8888888888",
            "email": "john@example.com",
            "parent_occupation": "Teacher",
            "address": "Bangalore",
            "permanent_address": "Bangalore",
            "seat_type": "general_merit",
            "date_of_admission": "2024-12-12",
            "department_id": self.department.id,
            "semester_id": self.sem1.id,
            "academic_year_id": self.ay.id
        }

        response = self.client.post(url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn("admission_id", response.data)

    def test_duplicate_email_registration_fails(self):
              # Create a user first because duplicate detection checks CustomUser, not Student
        user = User.objects.create_user(
        email="dupe@mail.com",
        password="pass123",
        role="STUDENT"
    )
        Student.objects.create(
            user=user,
            name="ABC",
            cet_no="CET100",
            dob="2000-05-01",
            religion="Hindu",
            city_type="Urban",
            mobile_no="1111111111",
            email="dupe@mail.com",
            parent_occupation="Farmer",
            address="Addr",
            permanent_address="Addr",
            seat_type="general_merit",
            date_of_admission="2025-01-01"
        )
        url = "/students/create/"

        payload = {
            "name": "XYZ",
            "cet_no": "CET101",
            "dob": "2000-05-01",
            "religion": "Hindu",
            "city_type": "Urban",
            "mobile_no": "2222222222",
            "email": "dupe@mail.com",
            "parent_occupation": "Farmer",
            "address": "Addr",
            "permanent_address": "Addr",
            "seat_type": "general_merit",
            "date_of_admission": "2025-01-01"
        }

        response = self.client.post(url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_department_verification(self):
        # Create sample student
        student = Student.objects.create(
            name="Test", cet_no="CET001", dob="2000-03-01", religion="Hindu",
            city_type="Urban", mobile_no="1111111111", email="verify@mail.com",
            parent_occupation="Farmer", address="Add", permanent_address="Add",
            seat_type="general_merit", date_of_admission="2025-01-01"
        )

        url = f"/students/{student.id}/verify/"
        response = self.hod_client.put(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        student.refresh_from_db()
        self.assertEqual(student.registration_status, "verified")

    def test_principal_approval(self):
        # Create sample student
        student = Student.objects.create(
            name="Test", cet_no="CET001", dob="2000-03-01", religion="Hindu",
            city_type="Urban", mobile_no="1111111112", email="approve@mail.com",
            parent_occupation="Farmer", address="Add", permanent_address="Add",
            seat_type="general_merit", date_of_admission="2025-01-01",
            registration_status="verified"
        )

        url = f"/students/{student.id}/approve/"
        response = self.principal_client.put(url, {"action": "approve"}, format="json")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        student.refresh_from_db()
        self.assertEqual(student.registration_status, "approved")

    def test_promote_student(self):
        self.sem2 = Semester.objects.create(sem_number=2)

        student = Student.objects.create(
            name="Promotion", cet_no="CET300", dob="2000-05-01",
            religion="Hindu", city_type="Urban", mobile_no="1234567890",
            email="promote@mail.com", parent_occupation="Farmer",
            address="Add", permanent_address="Add", seat_type="general_merit",
            date_of_admission="2025-01-01",
            semester=self.sem1, academic_year=self.ay
        )

        url = f"/students/{student.id}/promote/"
        response = self.hod_client.put(url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
