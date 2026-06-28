from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model

from rest_framework.test import APIClient
from rest_framework import status

from academics.models import Department, Semester, AcademicYear, Schema
from faculty.models import Faculty
from subjects.models import Subject, SubjectAssignment


User = get_user_model()


class SubjectAPITests(TestCase):

    def setUp(self):
        # ----------- Academics -----------
        self.schema = Schema.objects.create()     # IMPORTANT FIX
        self.department = Department.objects.create(name="CSE")
        self.sem1 = Semester.objects.create(sem_number=1)
        self.ay = AcademicYear.objects.create(year_name="2024-2025")

        # ----------- Users -----------
        self.user = User.objects.create_user(
            email="test@test.com", password="pass", role="ADMIN"
        )
        self.client = APIClient()
        self.client.force_authenticate(self.user)

        # Faculty
        self.faculty = Faculty.objects.create(
            faculty_id="F001",
            name="Prof One",
            department=self.department,
            email="f1@test.com",
            phone="9999999999",
            role="FACULTY"
        )

        self.faculty2 = Faculty.objects.create(
            faculty_id="F002",
            name="Prof Two",
            department=self.department,
            email="f2@test.com",
            phone="9999998888",
            role="FACULTY"
        )

        # ----------- Subjects -----------
        self.subject1 = Subject.objects.create(
            schema=self.schema,
            department=self.department,
            semester=self.sem1,
            subject_name="Data Structures",
            subject_code="CS101"
        )

        self.subject2 = Subject.objects.create(
            schema=self.schema,
            department=self.department,
            semester=self.sem1,
            subject_name="Algorithms",
            subject_code="CS102"
        )

    # ------------------------------------------------------
    # 1. Add Subject
    # ------------------------------------------------------
    def test_add_subject(self):
        url = "/subjects/addSubject/"
        payload = {
            "schema": self.schema.id,
            "department": self.department.id,
            "semester": self.sem1.id,
            "subject_name": "DBMS",
            "subject_code": "CS103"
        }
        res = self.client.post(url, payload, format="json")
        self.assertEqual(res.status_code, 201)
        self.assertTrue(Subject.objects.filter(subject_code="CS103").exists())

    # ------------------------------------------------------
    # 2. Get Subjects with filtering
    # ------------------------------------------------------
    def test_get_subjects_filtering(self):
        url = f"/subjects/getSubjects/?department_id={self.department.id}&semester={self.sem1.id}"
        res = self.client.get(url)
        self.assertEqual(res.status_code, 200)
        self.assertGreaterEqual(len(res.data), 2)

    # ------------------------------------------------------
    # 3. No subjects found
    # ------------------------------------------------------
    def test_get_subjects_not_found(self):
        url = "/subjects/getSubjects/?department_id=999"
        res = self.client.get(url)
        self.assertEqual(res.status_code, 404)

    # ------------------------------------------------------
    # 4. Assign Subjects to Professors
    # ------------------------------------------------------
    def test_assign_subjects(self):
        url = "/subjects/assign_subjects/"
        payload = {
            "department_id": self.department.id,
            "assignments": [
                {
                    "subject_code": "CS101",
                    "faculty_id": self.faculty.id,
                    "semester": self.sem1.id,
                    "academic_year": self.ay.id
                }
            ]
        }
        res = self.client.post(url, payload, format="json")
        self.assertEqual(res.status_code, 200)

        self.assertTrue(
            SubjectAssignment.objects.filter(
                subject=self.subject1,
                faculty=self.faculty,
                academic_year=self.ay
            ).exists()
        )

    # ------------------------------------------------------
    # 5. Assign Subjects with invalid subject
    # ------------------------------------------------------
    def test_assign_subject_invalid(self):
        url = "/subjects/assign_subjects/"
        payload = {
            "department_id": self.department.id,
            "assignments": [
                {
                    "subject_code": "INVALID",
                    "faculty_id": self.faculty.id,
                    "semester": self.sem1.id,
                    "academic_year": self.ay.id
                }
            ]
        }
        res = self.client.post(url, payload, format="json")
        self.assertEqual(res.status_code, 400)

    # ------------------------------------------------------
    # 6. Get assigned professors
    # ------------------------------------------------------
    def test_get_assigned_professors(self):
        SubjectAssignment.objects.create(
            subject=self.subject1,
            faculty=self.faculty,
            academic_year=self.ay,
            department=self.department,
            semester=self.sem1
        )

        url = f"/subjects/getAssignedProfessors/?department_id={self.department.id}"
        res = self.client.get(url)
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data[0]["faculty_id"], self.faculty.id)

    # ------------------------------------------------------
    # 7. View assigned by department
    # ------------------------------------------------------
    def test_view_assigned_by_department(self):
        SubjectAssignment.objects.create(
            subject=self.subject2,
            faculty=self.faculty2,
            academic_year=self.ay,
            department=self.department,
            semester=self.sem1
        )

        url = f"/subjects/view-assigned-by-department/?department_id={self.department.id}"
        res = self.client.get(url)
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.data), 1)

    # ------------------------------------------------------
    # 8. Professor assigned subjects list
    # ------------------------------------------------------
    def test_professor_subjects(self):
        SubjectAssignment.objects.create(
            subject=self.subject1,
            faculty=self.faculty,
            academic_year=self.ay,
            department=self.department,
            semester=self.sem1
        )

        url = f"/subjects/professor/subjects/?faculty_id={self.faculty.id}"
        res = self.client.get(url)
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data[0]["subject_code"], "CS101")

    # ------------------------------------------------------
    # 9. Professor with no subjects
    # ------------------------------------------------------
    def test_professor_no_subjects(self):
        url = f"/subjects/professor/subjects/?faculty_id={self.faculty2.id}"
        res = self.client.get(url)
        self.assertEqual(res.status_code, 404)

    # ------------------------------------------------------
    # 10. Missing department ID
    # ------------------------------------------------------
    def test_view_assigned_by_department_missing(self):
        url = "/subjects/view-assigned-by-department/"
        res = self.client.get(url)
        self.assertEqual(res.status_code, 400)

    # ------------------------------------------------------
    # 11. Missing faculty ID
    # ------------------------------------------------------
    def test_get_professor_missing_id(self):
        url = "/subjects/professor/subjects/"
        res = self.client.get(url)
        self.assertEqual(res.status_code, 400)

    # ------------------------------------------------------
    # 12. Add subject missing fields
    # ------------------------------------------------------
    def test_add_subject_missing_fields(self):
        url = "/subjects/addSubject/"
        res = self.client.post(url, {}, format="json")
        self.assertEqual(res.status_code, 400)
