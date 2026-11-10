from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from userlogin.models import CustomUser
from academics.models import Department, Semester, AcademicYear
from subjects.models import Subject, SubjectAssignment
from faculty.models import Faculty

class DuplicateSubjectAYTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.dept = Department.objects.create(name="Computer Science and Engineering")
        self.sem7 = Semester.objects.create(sem_number=7)
        self.ay1 = AcademicYear.objects.create(year_name="2025-2026")
        self.ay2 = AcademicYear.objects.create(year_name="2026-2027")

        self.user = CustomUser.objects.create_user(
            email="prof_tester@example.com",
            password="testpassword123",
            role="PROFESSOR",
            department=self.dept
        )
        self.fac = Faculty.objects.create(
            user=self.user,
            name="Dr. Tester",
            faculty_id="TEST001",
            department=self.dept,
            designation="Professor"
        )

        # Single master subject BCS702
        self.subject = Subject.objects.create(
            subject_name="Parallel Computing",
            subject_code="BCS702",
            department=self.dept,
            semester=self.sem7,
            credits=4,
            theory_hours=4
        )

        # Assigned in two academic years to the same faculty
        self.assign1 = SubjectAssignment.objects.create(
            subject=self.subject,
            faculty=self.fac,
            department=self.dept,
            semester=self.sem7,
            academic_year=self.ay1,
            is_active=True
        )
        self.assign2 = SubjectAssignment.objects.create(
            subject=self.subject,
            faculty=self.fac,
            department=self.dept,
            semester=self.sem7,
            academic_year=self.ay2,
            is_active=True
        )

    def test_professor_subjects_all_ay_returns_single_record(self):
        self.client.force_authenticate(user=self.user)
        # Query with no academic_year or academic_year=all
        response = self.client.get('/subjects/professor/subjects/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        bcs702_items = [s for s in data if s['subject_code'] == 'BCS702']
        self.assertEqual(len(bcs702_items), 1, "Under All AY, BCS702 should appear only once!")

    def test_professor_subjects_filtered_by_specific_ay(self):
        self.client.force_authenticate(user=self.user)
        # Query for 2025-2026
        res1 = self.client.get('/subjects/professor/subjects/', {'academic_year': '2025-2026'})
        self.assertEqual(res1.status_code, status.HTTP_200_OK)
        data1 = res1.json()
        self.assertEqual(len(data1), 1)
        self.assertEqual(data1[0]['academic_year'], '2025-2026')

        # Query for 2026-2027
        res2 = self.client.get('/subjects/professor/subjects/', {'academic_year': '2026-2027'})
        self.assertEqual(res2.status_code, status.HTTP_200_OK)
        data2 = res2.json()
        self.assertEqual(len(data2), 1)
        self.assertEqual(data2[0]['academic_year'], '2026-2027')
