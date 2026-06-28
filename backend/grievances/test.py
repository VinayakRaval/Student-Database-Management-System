from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from django.contrib.auth import get_user_model
from students.models import Student
from academics.models import Department
from grievances.models import Grievance

User = get_user_model()


class GrievanceAPITests(TestCase):

    def setUp(self):
        self.client = APIClient()

        # ---------- Department ----------
        self.dept = Department.objects.create(name="CSE")

        # ---------- Users ----------
        # Student
        self.student_user = User.objects.create_user(
            email="stud@test.com", password="pass123", role="STUDENT"
        )
        self.student = Student.objects.create(
            user=self.student_user,
            name="Student 1",
            cet_no="123",
            dob="2000-01-01",
            religion="Hindu",
            city_type="Urban",
            mobile_no="9999999999",
            email="stud1@test.com",
            parent_occupation="Engineer",
            address="Addr1",
            permanent_address="Paddr1",
            date_of_admission="2020-01-01",
            seat_type="general_merit",
            department=self.dept,
        )

        # Another student
        self.student2_user = User.objects.create_user(
            email="stud2@test.com", password="pass123", role="STUDENT"
        )
        self.student2 = Student.objects.create(
            user=self.student2_user,
            name="Student 2",
            cet_no="999",
            dob="2000-01-01",
            religion="Hindu",
            city_type="Urban",
            mobile_no="9999998888",
            email="stud2@test.com",
            parent_occupation="Teacher",
            address="A",
            permanent_address="B",
            date_of_admission="2020-01-01",
            seat_type="general_merit",
            department=self.dept,
        )

        # HOD
        self.hod = User.objects.create_user(
            email="hod@test.com",
            password="pass123",
            role="HOD",
            department=self.dept
        )

        # Principal
        self.principal = User.objects.create_user(
            email="p@test.com",
            password="pass123",
            role="PRINCIPAL"
        )

        # Superuser(admin)
        self.admin = User.objects.create_superuser(
            email="admin@test.com", password="pass123"
        )

    # ===========================================
    # CREATE
    # ===========================================
    def test_student_can_create_grievance(self):
        self.client.force_authenticate(self.student_user)

        res = self.client.post("/grievances/", {
            "topic": "Issue 1",
            "description": "There is an issue",
            "target_role": "HOD"
        })

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Grievance.objects.count(), 1)

    def test_student_cannot_create_without_target_role(self):
        self.client.force_authenticate(self.student_user)

        res = self.client.post("/grievances/", {
            "topic": "Test",
            "description": "No role"
        })

        self.assertEqual(res.status_code, 400)

    def test_non_student_cannot_create(self):
        self.client.force_authenticate(self.hod)

        res = self.client.post("/grievances/", {
            "topic": "Should Fail",
            "description": "err",
            "target_role": "HOD"
        })

        self.assertEqual(res.status_code, 400)

    # ===========================================
    # VISIBILITY
    # ===========================================
    def test_student_sees_only_own_grievances(self):
        g1 = Grievance.objects.create(
            student=self.student, topic="A", description="D", target_role="HOD", target_user=self.hod
        )
        g2 = Grievance.objects.create(
            student=self.student2, topic="B", description="D", target_role="HOD", target_user=self.hod
        )

        self.client.force_authenticate(self.student_user)
        res = self.client.get("/grievances/")

        self.assertEqual(len(res.data), 1)

    def test_hod_sees_only_their_grievances(self):
        Grievance.objects.create(
            student=self.student,
            topic="A",
            description="AA",
            target_role="HOD",
            target_user=self.hod
        )

        Grievance.objects.create(
            student=self.student2,
            topic="B",
            description="BB",
            target_role="PRINCIPAL",
            target_user=self.principal
        )

        self.client.force_authenticate(self.hod)
        res = self.client.get("/grievances/")
        self.assertEqual(len(res.data), 1)

    def test_admin_sees_all(self):
        Grievance.objects.create(
            student=self.student, topic="A", description="D", target_role="HOD", target_user=self.hod
        )
        Grievance.objects.create(
            student=self.student2, topic="B", description="D", target_role="PRINCIPAL", target_user=self.principal
        )

        self.client.force_authenticate(self.admin)
        res = self.client.get("/grievances/")
        self.assertEqual(len(res.data), 2)

    # ===========================================
    # RESPOND
    # ===========================================
    def test_assigned_user_can_respond(self):
        g = Grievance.objects.create(
            student=self.student,
            topic="A",
            description="AA",
            target_role="HOD",
            target_user=self.hod
        )

        self.client.force_authenticate(self.hod)
        res = self.client.post(f"/grievances/{g.id}/respond/", {"response": "Done"})

        self.assertEqual(res.status_code, 200)

    def test_cannot_respond_not_assigned(self):
        g = Grievance.objects.create(
            student=self.student,
            topic="A",
            description="AA",
            target_role="HOD",
            target_user=self.hod
        )

        self.client.force_authenticate(self.principal)
        res = self.client.post(f"/grievances/{g.id}/respond/", {"response": "Trying"})

        self.assertEqual(res.status_code, 403)
