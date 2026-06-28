import io
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework.test import APITestCase, APIClient
from rest_framework import status
from django.contrib.auth import get_user_model
from academics.models import Semester
from external_results.models import ExternalResult, ChangeLog

User = get_user_model()


# ============================================================
# Helper: Create a REAL minimal PDF readable by PyMuPDF
# ============================================================
def generate_pdf_with_text(text: str):
    """
    Generates a minimal valid PDF containing the provided text.
    Used for USN validation in tests.
    """
    pdf = f"""
%PDF-1.1
1 0 obj<<>>endobj
2 0 obj<< /Type /Catalog /Pages 3 0 R >>endobj
3 0 obj<< /Type /Pages /Kids [4 0 R] /Count 1 >>endobj
4 0 obj<< /Type /Page /Parent 3 0 R /MediaBox [0 0 600 800] /Contents 5 0 R >>endobj
5 0 obj<< /Length {len(text)+40} >>stream
BT /F1 24 Tf 100 700 Td ({text}) Tj ET
endstream
endobj
xref
0 6
0000000000 65535 f
0000000010 00000 n
0000000050 00000 n
0000000099 00000 n
0000000149 00000 n
0000000249 00000 n
trailer<< /Size 6 /Root 2 0 R >>
startxref
300
%%EOF
"""
    return SimpleUploadedFile(
        "result.pdf",
        pdf.encode("latin-1"),
        content_type="application/pdf"
    )


# ============================================================
# BASE SETUP
# ============================================================
class ExternalResultsBase(APITestCase):
    def setUp(self):
        # Users
        self.student = User.objects.create_user(
            email="stud@test.com",
            password="pass123",
            role="STUDENT"
        )
        self.student.usn = "1GV20CS001"
        self.student.save()

        self.staff = User.objects.create_user(
            email="hod@test.com",
            password="pass123",
            role="HOD",
            is_staff=True
        )

        self.other_student = User.objects.create_user(
            email="other@test.com",
            password="pass123",
            role="STUDENT"
        )
        self.other_student.usn = "1GV20CS002"
        self.other_student.save()

        # Clients
        self.student_client = APIClient()
        self.student_client.force_authenticate(self.student)

        self.staff_client = APIClient()
        self.staff_client.force_authenticate(self.staff)

        # Semester (required by model)
        self.sem1 = Semester.objects.create(sem_number=1)

        # PDFs
        self.valid_pdf = generate_pdf_with_text("USN:1GV20CS001")
        self.invalid_pdf = generate_pdf_with_text("NO_USN_IN_FILE")


# ============================================================
# FULL TEST SUITE  (NO SEMESTER VALIDATION)
# ============================================================
class ExternalResultTests(ExternalResultsBase):

    # 1. Student uploads successfully
    def test_student_can_upload_result(self):
        res = self.student_client.post(
            "/external_results/",
            {
                "semester": self.sem1.id,
                "exam_type": "FRESH",
                "pdf_file": self.valid_pdf,
            },
            format="multipart"
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)

    # 2. Staff cannot upload
    def test_staff_cannot_upload(self):
        res = self.staff_client.post(
            "/external_results/",
            {
                "semester": self.sem1.id,
                "exam_type": "FRESH",
                "pdf_file": self.valid_pdf,
            },
            format="multipart"
        )
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    # 3. Student sees only their results
    def test_student_sees_only_their_results(self):
        ExternalResult.objects.create(
            student=self.student, semester=self.sem1, exam_type="FRESH"
        )
        ExternalResult.objects.create(
            student=self.other_student, semester=self.sem1, exam_type="FRESH"
        )

        res = self.student_client.get("/external_results/")
        self.assertEqual(len(res.data), 1)

    # 4. Staff sees all results
    def test_staff_sees_all_results(self):
        ExternalResult.objects.create(
            student=self.student, semester=self.sem1, exam_type="FRESH"
        )
        ExternalResult.objects.create(
            student=self.staff, semester=self.sem1, exam_type="FRESH"
        )

        res = self.staff_client.get("/external_results/")
        self.assertEqual(len(res.data), 2)

    # 5. Staff update creates changelog
    def test_staff_can_update_and_changelog(self):
        r = ExternalResult.objects.create(
            student=self.student, semester=self.sem1, exam_type="FRESH"
        )

        res = self.staff_client.patch(
            f"/external_results/{r.id}/",
            {"exam_type": "RV"},
            format="json"
        )

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(ChangeLog.objects.count(), 1)

    # 6. Staff delete creates changelog
    def test_staff_delete_creates_changelog(self):
        r = ExternalResult.objects.create(
            student=self.student, semester=self.sem1, exam_type="FRESH"
        )

        res = self.staff_client.delete(f"/external_results/{r.id}/")
        self.assertEqual(res.status_code, status.HTTP_204_NO_CONTENT)
        self.assertEqual(ChangeLog.objects.count(), 1)

    # 7. Student cannot update
    def test_student_cannot_update(self):
        r = ExternalResult.objects.create(
            student=self.student, semester=self.sem1, exam_type="FRESH"
        )

        res = self.student_client.patch(
            f"/external_results/{r.id}/",
            {"exam_type": "RV"},
            format="json"
        )
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    # 8. Duplicate upload forbidden
    def test_duplicate_result_not_allowed(self):
        ExternalResult.objects.create(
            student=self.student, semester=self.sem1, exam_type="FRESH"
        )

        res = self.student_client.post(
            "/external_results/",
            {
                "semester": self.sem1.id,
                "exam_type": "FRESH",
                "pdf_file": self.valid_pdf,
            },
            format="multipart"
        )

        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    # 9. Wrong PDF (USN missing) fails
    def test_pdf_validation_fails_wrong_usn(self):
        res = self.student_client.post(
            "/external_results/",
            {
                "semester": self.sem1.id,
                "exam_type": "FRESH",
                "pdf_file": self.invalid_pdf,
            },
            format="multipart"
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    # 10. Valid PDF containing USN passes
    def test_pdf_validation_passes_with_usn_only(self):
        res = self.student_client.post(
            "/external_results/",
            {
                "semester": self.sem1.id,
                "exam_type": "FRESH",
                "pdf_file": self.valid_pdf,
            },
            format="multipart"
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
