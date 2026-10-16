# library/test.py
import json
from django.contrib.auth.models import Group
from django.urls import reverse
from rest_framework.test import APITestCase, APIClient
from rest_framework import status
from django.utils import timezone
from datetime import date, timedelta

from academics.models import Department, Semester, AcademicYear
from .models import Book, BookCopy, BookRequest, IssueRecord, Fine, AuditLog, EBook
from django.contrib.auth import get_user_model

User = get_user_model()


def make_user(email="u@example.com", password="pass123", role=None,
              is_library_officer=False, is_principal=False, groups=None):
    u = User.objects.create_user(email=email, password=password, role=role)
    # set boolean flags if present on model
    if hasattr(u, "is_library_officer"):
        setattr(u, "is_library_officer", is_library_officer)
        u.save()
    if hasattr(u, "is_principal"):
        setattr(u, "is_principal", is_principal)
        u.save()

    # create / add to groups if requested
    if groups:
        for gname in groups:
            g, _ = Group.objects.get_or_create(name=gname)
            u.groups.add(g)
    return u


class LibraryAPITests(APITestCase):
    def setUp(self):
        # Academics
        self.dept = Department.objects.create(name="CSE")
        self.sem = Semester.objects.create(sem_number=1)
        self.ay = AcademicYear.objects.create(year_name="2024-2025")

        # Users:
        self.student = make_user(email="student@test.com", role="STUDENT")
        # library officer: set boolean and group to satisfy both checks
        self.lib_officer = make_user(
            email="lib@test.com", role="LIBRARY",
            is_library_officer=True, groups=["LibraryOfficer"]
        )
        # principal: set boolean and group
        self.principal = make_user(
            email="principal@test.com", role="PRINCIPAL",
            is_principal=True, groups=["Principal"]
        )
        # another normal user
        self.staff = make_user(email="staff@test.com", role="STAFF")

        # Clients
        self.student_client = APIClient(); self.student_client.force_authenticate(self.student)
        self.lib_client = APIClient(); self.lib_client.force_authenticate(self.lib_officer)
        self.principal_client = APIClient(); self.principal_client.force_authenticate(self.principal)
        self.staff_client = APIClient(); self.staff_client.force_authenticate(self.staff)

        # Create a book via model for tests (we'll also test create via API)
        self.book = Book.objects.create(
            title="Intro to Testing",
            authors="Tester",
            department=self.dept,
            year=2024,
            isbn="ISBN-TEST-001"
        )

    # ---------- Books / Copies ----------
    def test_create_book_and_add_copies(self):
        # Create a book via API (department_id used by serializer)
        payload = {
            "title": "Algorithms",
            "authors": "Algo Author",
            "department_id": self.dept.id,
            "year": 2020,
            "isbn": "ISBN-ALG-001"
        }
        res = self.lib_client.post("/library/books/", data=payload, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        book_id = res.data["id"]

        # add copies via endpoint (count=3)
        res2 = self.lib_client.post(f"/library/books/{book_id}/add_copies/", data={"count": 3}, format="json")
        self.assertEqual(res2.status_code, status.HTTP_201_CREATED)
        created_ids = res2.data.get("created_copy_ids")
        self.assertEqual(len(created_ids), 3)

        # verify copies exist and barcodes auto-generated
        copies = BookCopy.objects.filter(book_id=book_id).order_by("copy_number")
        self.assertTrue(copies.exists())
        for c in copies:
            self.assertIsNotNone(c.barcode)
            self.assertTrue(c.shelf_location)

    def test_student_cannot_create_or_delete_book(self):
        # Student cannot create book
        payload = {"title": "Hacking 101", "department_id": self.dept.id}
        res = self.student_client.post("/library/books/", data=payload, format="json")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        # Student cannot delete book
        res_del = self.student_client.delete(f"/library/books/{self.book.id}/")
        self.assertEqual(res_del.status_code, status.HTTP_403_FORBIDDEN)

    def test_add_copies_validates_count(self):
        # Negative count rejected
        res_neg = self.lib_client.post(f"/library/books/{self.book.id}/add_copies/", data={"count": -1}, format="json")
        self.assertEqual(res_neg.status_code, status.HTTP_400_BAD_REQUEST)

        # Zero count rejected
        res_zero = self.lib_client.post(f"/library/books/{self.book.id}/add_copies/", data={"count": 0}, format="json")
        self.assertEqual(res_zero.status_code, status.HTTP_400_BAD_REQUEST)

        # Excessive count (> 100) rejected
        res_huge = self.lib_client.post(f"/library/books/{self.book.id}/add_copies/", data={"count": 500}, format="json")
        self.assertEqual(res_huge.status_code, status.HTTP_400_BAD_REQUEST)

    def test_bookcopy_save_auto_barcode_and_shelf(self):
        # Create a book and a copy without barcode/shelf -> save() should fill them
        b = Book.objects.create(title="Book X", department=self.dept)
        copy = BookCopy.objects.create(book=b, copy_number=1)
        self.assertIsNotNone(copy.barcode)
        self.assertTrue(copy.shelf_location)

    # ---------- EBook ----------
    def test_upload_ebook(self):
        # upload ebook file via API
        payload = {
            "book_id": self.book.id
        }
        res = self.lib_client.post("/library/ebooks/", data=payload, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertIn("id", res.data)

        # Student cannot upload ebook
        res_stu = self.student_client.post("/library/ebooks/", data=payload, format="json")
        self.assertEqual(res_stu.status_code, status.HTTP_403_FORBIDDEN)

    # ---------- Book Request flow ----------
    def test_student_create_request_and_verify_and_final_approve(self):
        # Student creates request
        req_payload = {"title": "Advanced Topics", "authors": "Author A", "reason": "Needed", "urgency": "high"}
        res = self.student_client.post("/library/requests/", req_payload, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        req_id = res.data["id"]

        # Non-library officer cannot verify -> staff should get 403 when calling verify
        res_non = self.staff_client.post(f"/library/requests/{req_id}/verify/")
        self.assertEqual(res_non.status_code, status.HTTP_403_FORBIDDEN)

        # Library officer verifies
        res_ver = self.lib_client.post(f"/library/requests/{req_id}/verify/")
        self.assertEqual(res_ver.status_code, status.HTTP_200_OK)
        pr = BookRequest.objects.get(id=req_id)
        self.assertEqual(pr.status, BookRequest.REQUEST_STATUS_VERIFIED)

        # Principal can final_approve only if verified -> sets status to approved
        res_final = self.principal_client.post(f"/library/requests/{req_id}/final_approve/")
        self.assertEqual(res_final.status_code, status.HTTP_200_OK)
        pr.refresh_from_db()
        self.assertEqual(pr.status, BookRequest.REQUEST_STATUS_APPROVED)
        self.assertEqual(pr.forwarded_to.email, self.principal.email)

        # Library officer marks purchased
        res_purchased = self.lib_client.post(f"/library/requests/{req_id}/mark_purchased/")
        self.assertEqual(res_purchased.status_code, status.HTTP_200_OK)
        pr.refresh_from_db()
        self.assertEqual(pr.status, BookRequest.REQUEST_STATUS_PURCHASED)

    def test_final_approve_without_verify_fails(self):
        # create a fresh request
        res = self.student_client.post("/library/requests/", {"title": "T2"}, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        req_id = res.data["id"]

        # principal tries to approve before verification -> should get 400
        res_final = self.principal_client.post(f"/library/requests/{req_id}/final_approve/")
        self.assertEqual(res_final.status_code, status.HTTP_400_BAD_REQUEST)

    # ---------- Issue / Return / Mark Lost ----------
    def test_issue_and_return_and_mark_lost_and_fine(self):
        # create a book copy to issue (book from setUp)
        copy = BookCopy.objects.create(book=self.book, copy_number=1)
        self.assertEqual(copy.status, BookCopy.STATUS_AVAILABLE)

        # Student issues the copy (server calculates 14-day due date)
        res_issue = self.student_client.post("/library/issues/", {"copy_id": copy.id}, format="json")
        self.assertEqual(res_issue.status_code, status.HTTP_201_CREATED)
        issue_id = res_issue.data["id"]
        issue = IssueRecord.objects.get(id=issue_id)
        self.assertEqual(issue.status, IssueRecord.STATUS_ISSUED)

        # Return: non-library-officer cannot return -> expect 403
        res_not = self.staff_client.post(f"/library/issues/{issue_id}/return_book/")
        self.assertEqual(res_not.status_code, status.HTTP_403_FORBIDDEN)

        # Library officer returns the book
        res_ret = self.lib_client.post(f"/library/issues/{issue_id}/return_book/")
        self.assertEqual(res_ret.status_code, status.HTTP_200_OK)
        issue.refresh_from_db()
        self.assertEqual(issue.status, IssueRecord.STATUS_RETURNED)
        copy.refresh_from_db()
        self.assertEqual(copy.status, BookCopy.STATUS_AVAILABLE)

        # Now create another issue and mark lost
        copy2 = BookCopy.objects.create(book=self.book, copy_number=2)
        res_issue2 = self.student_client.post("/library/issues/", {"copy_id": copy2.id}, format="json")
        self.assertEqual(res_issue2.status_code, status.HTTP_201_CREATED)
        issue2 = IssueRecord.objects.get(id=res_issue2.data["id"])

        # non-officer cannot mark lost
        res_not2 = self.staff_client.post(f"/library/issues/{issue2.id}/mark_lost/")
        self.assertEqual(res_not2.status_code, status.HTTP_403_FORBIDDEN)

        # library officer marks lost -> creates Fine
        res_lost = self.lib_client.post(f"/library/issues/{issue2.id}/mark_lost/")
        self.assertEqual(res_lost.status_code, status.HTTP_200_OK)
        data = res_lost.data
        self.assertIn("fine_id", data)
        fine = Fine.objects.get(id=data["fine_id"])
        self.assertTrue(fine.amount >= 0)

    # ---------- Fine assign and verified mark paid ----------
    def test_assign_fine_and_mark_paid(self):
        # create issue and fine
        copy = BookCopy.objects.create(book=self.book, copy_number=3)
        issue_resp = self.student_client.post("/library/issues/", {"copy_id": copy.id}, format="json")
        issue = IssueRecord.objects.get(id=issue_resp.data["id"])

        # create manual fine record
        fine = Fine.objects.create(issue=issue, amount=50.00)

        # non-officer cannot assign (should be 403)
        res_non = self.staff_client.post(f"/library/fines/{fine.id}/assign/", {"amount": 100}, format="json")
        self.assertEqual(res_non.status_code, status.HTTP_403_FORBIDDEN)

        # library officer assigns fine
        res_assign = self.lib_client.post(f"/library/fines/{fine.id}/assign/", {"amount": 100, "reason": "Damaged cover"}, format="json")
        self.assertEqual(res_assign.status_code, status.HTTP_200_OK)
        fine.refresh_from_db()
        self.assertEqual(str(fine.amount), "100.00")

        # Security check: Student CANNOT mark their own fine as paid directly!
        res_stu_paid = self.student_client.post(f"/library/fines/{fine.id}/mark_paid/", {"payment_reference": "FAKE123"}, format="json")
        self.assertEqual(res_stu_paid.status_code, status.HTTP_403_FORBIDDEN)
        fine.refresh_from_db()
        self.assertFalse(fine.paid)

        # Library Officer marks fine as paid with verified receipt reference
        res_paid = self.lib_client.post(f"/library/fines/{fine.id}/mark_paid/", {"payment_reference": "REC-LIB-2026-09"}, format="json")
        self.assertEqual(res_paid.status_code, status.HTTP_200_OK)
        fine.refresh_from_db()
        self.assertTrue(fine.paid)
        self.assertEqual(fine.payment_reference, "REC-LIB-2026-09")
        self.assertIsNotNone(fine.paid_at)

    # ---------- Audit logs created ----------
    def test_audit_logs_created_for_actions(self):
        initial_count = AuditLog.objects.count()
        # add a book via API
        res = self.lib_client.post("/library/books/", {"title": "Log Book", "department_id": self.dept.id}, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        # create copy
        book_id = res.data["id"]
        self.lib_client.post(f"/library/books/{book_id}/add_copies/", {"count": 1}, format="json")

        # create request
        req = self.student_client.post("/library/requests/", {"title": "ReqLog"}, format="json")
        self.assertEqual(req.status_code, status.HTTP_201_CREATED)

        # some audits should be created
        self.assertTrue(AuditLog.objects.count() >= initial_count + 2)

