from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from django.contrib.auth import get_user_model

from academics.models import Department, Semester, AcademicYear
from faculty.models import Faculty
from subjects.models import Subject, SubjectAssignment
from students.models import Student
from attendance.models import LabBatch, LabBatchStudent

User = get_user_model()


class LabBatchSharedArchitectureTests(TestCase):
    def setUp(self):
        self.dept_cse = Department.objects.create(name="Computer Science and Engineering")
        self.dept_ece = Department.objects.create(name="Electronics and Communication Engineering")
        self.sem5 = Semester.objects.create(sem_number=5)
        self.ay = AcademicYear.objects.create(year_name="2026-2027")

        # HOD CSE
        self.hod_user = User.objects.create_user(
            email="hod_cse@gecc.edu",
            user_id="hod_cse",
            password="password123",
            role="HOD",
            department=self.dept_cse,
            is_active=True
        )
        self.hod_faculty = Faculty.objects.create(
            user=self.hod_user,
            faculty_id="HOD001",
            name="Dr. CSE HOD",
            gender="male",
            dob="1975-01-01",
            phone="9876543210",
            email="hod_cse@gecc.edu",
            department=self.dept_cse,
            qualification="Ph.D",
            role="HOD",
            status="approved"
        )

        # Faculty CSE
        self.prof_user = User.objects.create_user(
            email="prof_cse@gecc.edu",
            user_id="prof_cse",
            password="password123",
            role="PROFESSOR",
            department=self.dept_cse,
            is_active=True
        )
        self.prof_faculty = Faculty.objects.create(
            user=self.prof_user,
            faculty_id="FAC101",
            name="Prof. Alice",
            gender="female",
            dob="1985-01-01",
            phone="9876543211",
            email="prof_cse@gecc.edu",
            department=self.dept_cse,
            qualification="M.Tech",
            role="PROFESSOR",
            status="approved"
        )

        # Two lab subjects in CSE 5th Semester
        self.dbms_lab = Subject.objects.create(
            subject_code="22CSL51",
            subject_name="DBMS Laboratory",
            department=self.dept_cse,
            semester=self.sem5,
            subject_type="LAB",
            has_lab=True,
            has_theory=False
        )
        self.cn_lab = Subject.objects.create(
            subject_code="22CSL52",
            subject_name="Computer Networks Laboratory",
            department=self.dept_cse,
            semester=self.sem5,
            subject_type="LAB",
            has_lab=True,
            has_theory=False
        )

        # Assign Faculty to DBMS Lab
        SubjectAssignment.objects.create(
            subject=self.dbms_lab,
            faculty=self.prof_faculty,
            academic_year=self.ay,
            department=self.dept_cse,
            semester=self.sem5
        )

        # Create students in CSE 5th sem
        self.student1 = Student.objects.create(
            usn="4GC22CS001",
            name="Student One",
            cet_no="CET001",
            dob="2004-01-01",
            religion="Hindu",
            city_type="Urban",
            mobile_no="9000000001",
            email="s1@gecc.edu",
            parent_occupation="Farmer",
            address="Address 1",
            permanent_address="Address 1",
            seat_type="general_merit",
            date_of_admission="2022-08-01",
            department=self.dept_cse,
            semester=self.sem5,
            academic_year=self.ay,
            status="active"
        )
        self.student2 = Student.objects.create(
            usn="4GC22CS002",
            name="Student Two",
            cet_no="CET002",
            dob="2004-02-02",
            religion="Hindu",
            city_type="Urban",
            mobile_no="9000000002",
            email="s2@gecc.edu",
            parent_occupation="Teacher",
            address="Address 2",
            permanent_address="Address 2",
            seat_type="general_merit",
            date_of_admission="2022-08-01",
            department=self.dept_cse,
            semester=self.sem5,
            academic_year=self.ay,
            status="active"
        )

        self.client_hod = APIClient()
        self.client_hod.force_authenticate(self.hod_user)

        self.client_prof = APIClient()
        self.client_prof.force_authenticate(self.prof_user)

    def test_hod_creates_shared_lab_batch(self):
        """HOD can create a lab batch and it's shared across all lab subjects in that department & semester."""
        payload = {
            "name": "Batch A",
            "department_id": self.dept_cse.id,
            "semester_id": self.sem5.id,
            "academic_year_id": self.ay.id,
            "faculty_id": self.prof_faculty.id
        }
        res = self.client_hod.post("/attendance/batches/", payload, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        batch_id = res.data["id"]
        self.assertEqual(res.data["name"], "Batch A")

        # Query batches for DBMS Lab
        res_dbms = self.client_prof.get(f"/attendance/batches/?subject_id={self.dbms_lab.id}")
        self.assertEqual(res_dbms.status_code, status.HTTP_200_OK)
        dbms_list = res_dbms.data["results"] if isinstance(res_dbms.data, dict) and "results" in res_dbms.data else res_dbms.data
        ids = [b["id"] for b in dbms_list]
        self.assertIn(batch_id, ids)

        # Query batches for CN Lab
        res_cn = self.client_hod.get(f"/attendance/batches/?subject_id={self.cn_lab.id}")
        self.assertEqual(res_cn.status_code, status.HTTP_200_OK)
        cn_list = res_cn.data["results"] if isinstance(res_cn.data, dict) and "results" in res_cn.data else res_cn.data
        cn_ids = [b["id"] for b in cn_list]
        self.assertIn(batch_id, cn_ids)

    def test_regular_faculty_cannot_create_or_delete_batch(self):
        """Faculty cannot create or delete batches (only HOD / Admin)."""
        payload = {
            "name": "Batch B",
            "department_id": self.dept_cse.id,
            "semester_id": self.sem5.id
        }
        res_create = self.client_prof.post("/attendance/batches/", payload, format="json")
        self.assertEqual(res_create.status_code, status.HTTP_403_FORBIDDEN)

        # Create batch as HOD
        batch = LabBatch.objects.create(
            name="Batch B",
            department=self.dept_cse,
            semester=self.sem5,
            academic_year=self.ay
        )

        res_delete = self.client_prof.delete(f"/attendance/batches/{batch.id}/")
        self.assertEqual(res_delete.status_code, status.HTTP_403_FORBIDDEN)

    def test_student_assignment_and_conflict_prevention(self):
        """Students can be assigned to a batch, but cannot be assigned to multiple batches in same sem."""
        batch1 = LabBatch.objects.create(
            name="Batch A",
            department=self.dept_cse,
            semester=self.sem5,
            academic_year=self.ay
        )
        batch2 = LabBatch.objects.create(
            name="Batch B",
            department=self.dept_cse,
            semester=self.sem5,
            academic_year=self.ay
        )

        # Assign student 1 to Batch A
        res1 = self.client_hod.post(
            f"/attendance/batches/{batch1.id}/assign_students/",
            {"student_ids": [self.student1.id]},
            format="json"
        )
        self.assertEqual(res1.status_code, status.HTTP_200_OK)

        # Attempt to also assign student 1 to Batch B (conflict!)
        res2 = self.client_hod.post(
            f"/attendance/batches/{batch2.id}/assign_students/",
            {"student_ids": [self.student1.id, self.student2.id]},
            format="json"
        )
        self.assertEqual(res2.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("multiple batches", res2.data["error"])
