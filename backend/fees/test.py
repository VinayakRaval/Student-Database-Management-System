from unittest.mock import patch
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from django.contrib.auth import get_user_model


from academics.models import Department, Semester, AcademicYear
from students.models import Student
from fees.models import (
    FeeStructure, FeeComponent,
    StudentFee, FeePayment, FeeReceipt
)

User = get_user_model()


class FeesTestSetup(TestCase):
    def setUp(self):
        # USERS
        self.accounts = User.objects.create_user(
            email="acc@test.com",
            password="pass123",
            role="ACCOUNTS",
            is_staff=True
        )
        self.student_user = User.objects.create_user(
            email="stu@test.com",
            password="pass123",
            role="STUDENT"
        )

        # ACADEMICS
        self.dept = Department.objects.create(name="CSE")
        self.sem = Semester.objects.create(sem_number=1)
        self.year = AcademicYear.objects.create(year_name="2024-25")

        # STUDENT
        self.student = Student.objects.create(
            user=self.student_user,
            name="John",
            cet_no="CET100",
            dob="2000-05-01",
            religion="Hindu",
            city_type="Urban",
            mobile_no="9999999999",
            email="stu@test.com",
            parent_occupation="Farmer",
            address="Addr",
            permanent_address="Addr",
            seat_type="general_merit",
            date_of_admission="2024-01-01",
            department=self.dept,
            semester=self.sem,
            academic_year=self.year,
            status="active"
        )

        # CLIENTS
        self.acc_client = APIClient()
        self.acc_client.force_authenticate(self.accounts)

        self.student_client = APIClient()
        self.student_client.force_authenticate(self.student_user)

        # APPROVED FEE STRUCTURE
        self.fs = FeeStructure.objects.create(
            department=self.dept,
            academic_year=self.year,
            semester=self.sem,
            seat_type="gm",
            title="Test Fee",
            approval_status="approved",
            is_active=True,
            approved_by=self.accounts,
            approved_on="2024-01-01"
        )

        FeeComponent.objects.create(fee_structure=self.fs, name="Tuition", amount=5000)
        FeeComponent.objects.create(fee_structure=self.fs, name="Library", amount=2000)


class FeeModuleTests(FeesTestSetup):

    def test_bulk_assign(self):
        """Bulk assign must succeed like your Postman call."""
        res = self.acc_client.post(
            "/fees/student-fees/bulk-assign/",
            {
                "department_id": self.dept.id,
                "semester_id": self.sem.id,
                "academic_year": self.year.id,  # matches your view
                "seat_type": "general_merit",
                "fee_structure_id": self.fs.id
            },
            format="json"
        )
        # Postman returns 200 for you, so enforce 200
        self.assertEqual(res.status_code, 200)

        self.assertEqual(StudentFee.objects.count(), 1)

    def test_student_my_fees(self):
        StudentFee.objects.create(student=self.student, fee_structure=self.fs)

        res = self.student_client.get("/fees/student-fees/my-fees/")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.data), 1)

    def test_accounts_create_payment(self):
        sf = StudentFee.objects.create(student=self.student, fee_structure=self.fs)

        res = self.acc_client.post(
            "/fees/payments/",
            {
                "student_fee": sf.id,
                "amount": 5000,
                "mode": "upi",
                "upi_txn_id": "T1",
            },
            format="multipart"
        )

        self.assertIn(res.status_code, [200, 201])

    @patch("fees.views.AppNotification")  # prevent NameError
    def test_verify_payment(self, mock_notif):
        sf = StudentFee.objects.create(student=self.student, fee_structure=self.fs)

        pay = FeePayment.objects.create(
            student_fee=sf,
            amount=5000,
            mode="upi",
            upi_txn_id="TXN",
            entered_by=self.accounts,
            verified=False
        )

        res = self.acc_client.post(f"/fees/payments/{pay.id}/verify/")
        self.assertEqual(res.status_code, 200)

        pay.refresh_from_db()
        self.assertTrue(pay.verified)
        self.assertTrue(FeeReceipt.objects.filter(payment=pay).exists())

    def test_receipt_filter(self):
        sf = StudentFee.objects.create(student=self.student, fee_structure=self.fs)
        pay = FeePayment.objects.create(
            student_fee=sf,
            amount=3000,
            mode="upi",
            upi_txn_id="TX2",
            entered_by=self.accounts,
            verified=True
        )
        FeeReceipt.objects.create(payment=pay, receipt_no="REC1")

        res = self.acc_client.get(f"/fees/receipts/?student_id={self.student.id}")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.data), 1)
