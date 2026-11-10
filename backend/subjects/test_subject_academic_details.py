from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from datetime import time
from userlogin.models import CustomUser
from academics.models import Department, Semester, AcademicYear, Schema
from faculty.models import Faculty
from subjects.models import Subject, SubjectAssignment
from timetable.models import TimeTable, TimeTableSlot
from timetable.serializers import TimeTableSerializer

class SubjectAcademicDetailsTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.dept = Department.objects.create(name="Computer Science and Engineering")
        self.sem7 = Semester.objects.create(sem_number=7)
        self.ay1 = AcademicYear.objects.create(year_name="2025-2026")
        self.ay2 = AcademicYear.objects.create(year_name="2026-2027")
        self.schema = Schema.objects.create(name="2021 Scheme")

        self.admin = CustomUser.objects.create_user(
            email="admin@test.com",
            user_id="ADMIN001",
            password="adminpassword123",
            role="SYSTEM"
        )
        self.client.force_authenticate(user=self.admin)

        self.faculty1 = Faculty.objects.create(
            faculty_id="PROF001",
            name="Dr. Alan Turing",
            email="alan@sdms.edu",
            phone="9876543201",
            department=self.dept,
            designation="Professor"
        )
        self.faculty2 = Faculty.objects.create(
            faculty_id="PROF002",
            name="Dr. Grace Hopper",
            email="grace@sdms.edu",
            phone="9876543202",
            department=self.dept,
            designation="Professor"
        )

    def test_subject_model_calculation(self):
        # 1. Direct hours
        s1 = Subject.objects.create(
            department=self.dept,
            semester=self.sem7,
            subject_name="Cloud Computing",
            subject_code="21CS71",
            credits=4,
            theory_hours=3,
            tutorial_hours=1,
            practical_hours=0
        )
        self.assertEqual(s1.total_teaching_hours, 4)
        self.assertEqual(s1.practical_display, "0")

        # 2. Practical sessions x duration notation
        s2 = Subject.objects.create(
            department=self.dept,
            semester=self.sem7,
            subject_name="Cloud Computing Lab",
            subject_code="21CSL76",
            has_theory=False,
            has_lab=True,
            credits=2,
            theory_hours=0,
            tutorial_hours=0,
            practical_sessions=2,
            practical_duration_per_session=3
        )
        self.assertEqual(s2.practical_hours, 6)
        self.assertEqual(s2.practical_display, "2 × 3")
        self.assertEqual(s2.total_teaching_hours, 6)

    def test_add_subject_api_validation(self):
        # Negative hours
        res = self.client.post("/subjects/addSubject/", {
            "department": self.dept.id,
            "semester": self.sem7.id,
            "subject_name": "Invalid Subject",
            "subject_code": "21CS79",
            "theory_hours": -1,
            "credits": 4,
            "academic_year": self.ay1.id
        }, format="json")
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("Teaching hours and credits cannot be negative", res.data["error"])

        # Negative credits
        res = self.client.post("/subjects/addSubject/", {
            "department": self.dept.id,
            "semester": self.sem7.id,
            "subject_name": "Invalid Subject 2",
            "subject_code": "21CS79",
            "theory_hours": 3,
            "credits": -2,
            "academic_year": self.ay1.id
        }, format="json")
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("Teaching hours and credits cannot be negative", res.data["error"])

    def test_add_subject_api_and_academic_year_reuse(self):
        # 1. Create Cloud Computing in AY 2025-2026
        payload1 = {
            "department": self.dept.id,
            "semester": self.sem7.id,
            "subject_name": "Cloud Computing",
            "subject_code": "21CS71",
            "academic_year": self.ay1.id,
            "credits": 4,
            "theory_hours": 3,
            "tutorial_hours": 1,
            "practical_hours": 0,
            "has_theory": True,
            "has_lab": False,
        }
        res1 = self.client.post("/subjects/addSubject/", payload1, format="json")
        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Subject.objects.filter(subject_code="21CS71").count(), 1)
        self.assertEqual(SubjectAssignment.objects.filter(subject__subject_code="21CS71", academic_year=self.ay1).count(), 1)

        # 2. Re-offer Cloud Computing for AY 2026-2027
        payload2 = {
            "department": self.dept.id,
            "semester": self.sem7.id,
            "subject_name": "Cloud Computing",
            "subject_code": "21CS71",
            "academic_year": self.ay2.id,
            "credits": 4,
            "theory_hours": 3,
            "tutorial_hours": 1,
            "practical_hours": 0,
            "has_theory": True,
            "has_lab": False,
        }
        res2 = self.client.post("/subjects/addSubject/", payload2, format="json")
        self.assertEqual(res2.status_code, status.HTTP_201_CREATED)
        # Master Subject count remains 1!
        self.assertEqual(Subject.objects.filter(subject_code="21CS71").count(), 1)
        # Offerings now exist for both academic years
        self.assertEqual(SubjectAssignment.objects.filter(subject__subject_code="21CS71").count(), 2)
        self.assertEqual(SubjectAssignment.objects.filter(subject__subject_code="21CS71", academic_year=self.ay2).count(), 1)

        # 3. Duplicate offering for same academic year rejected
        res3 = self.client.post("/subjects/addSubject/", payload2, format="json")
        self.assertEqual(res3.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("already offered for 2026-2027", res3.data["error"])

    def test_faculty_assignments_across_academic_years(self):
        sub = Subject.objects.create(
            department=self.dept,
            semester=self.sem7,
            subject_name="Cloud Computing",
            subject_code="21CS71",
            credits=4,
            theory_hours=3,
            tutorial_hours=0,
            practical_hours=0
        )
        # AY1 assignment to Dr. Alan Turing
        assign_ay1 = SubjectAssignment.objects.create(
            subject=sub,
            academic_year=self.ay1,
            department=self.dept,
            semester=self.sem7,
            faculty=self.faculty1,
            is_active=True
        )

        # AY2 assignment to Dr. Grace Hopper
        assign_ay2 = SubjectAssignment.objects.create(
            subject=sub,
            academic_year=self.ay2,
            department=self.dept,
            semester=self.sem7,
            faculty=self.faculty2,
            is_active=True
        )

        self.assertEqual(assign_ay1.faculty, self.faculty1)
        self.assertEqual(assign_ay2.faculty, self.faculty2)
        self.assertNotEqual(assign_ay1.faculty, assign_ay2.faculty)

    def test_get_subjects_with_academic_year_filter(self):
        sub = Subject.objects.create(
            department=self.dept,
            semester=self.sem7,
            subject_name="Cloud Computing",
            subject_code="21CS71",
            credits=4,
            theory_hours=3,
            tutorial_hours=1,
            practical_hours=0
        )
        SubjectAssignment.objects.create(
            subject=sub,
            academic_year=self.ay2,
            department=self.dept,
            semester=self.sem7,
            faculty=self.faculty2,
            is_active=True
        )

        res = self.client.get(f"/subjects/getSubjects/?academic_year=2026-2027&semester={self.sem7.id}")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        item = next((x for x in res.data if x["code"] == "21CS71"), None)
        self.assertIsNotNone(item)
        self.assertEqual(item["credits"], 4)
        self.assertEqual(item["theory_hours"], 3)
        self.assertEqual(item["tutorial_hours"], 1)
        self.assertEqual(item["total_teaching_hours"], 4)
        self.assertTrue(item["is_assigned"])
        self.assertEqual(item["assigned_faculty_name"], "Dr. Grace Hopper")

    def test_timetable_subject_details_and_totals(self):
        sub1 = Subject.objects.create(
            department=self.dept,
            semester=self.sem7,
            subject_name="Cloud Computing",
            subject_code="21CS71",
            credits=4,
            theory_hours=3,
            tutorial_hours=1,
            practical_hours=0
        )
        sub2 = Subject.objects.create(
            department=self.dept,
            semester=self.sem7,
            subject_name="Machine Learning Lab",
            subject_code="21CSL76",
            credits=2,
            theory_hours=0,
            tutorial_hours=0,
            practical_sessions=1,
            practical_duration_per_session=3,
            practical_hours=3
        )

        assign1 = SubjectAssignment.objects.create(
            subject=sub1,
            academic_year=self.ay2,
            department=self.dept,
            semester=self.sem7,
            faculty=self.faculty1
        )
        assign2 = SubjectAssignment.objects.create(
            subject=sub2,
            academic_year=self.ay2,
            department=self.dept,
            semester=self.sem7,
            faculty=self.faculty2
        )

        tt = TimeTable.objects.create(
            department=self.dept,
            semester=self.sem7,
            academic_year=self.ay2,
            created_by=self.admin,
            status="Draft"
        )

        # Slot 1: Monday Cloud Computing
        TimeTableSlot.objects.create(
            timetable=tt,
            day="MON",
            start_time=time(9, 0),
            end_time=time(10, 0),
            assignment=assign1
        )
        # Slot 2: Wednesday Cloud Computing (same subject, different day)
        TimeTableSlot.objects.create(
            timetable=tt,
            day="WED",
            start_time=time(10, 0),
            end_time=time(11, 0),
            assignment=assign1
        )
        # Slot 3: Friday ML Lab
        TimeTableSlot.objects.create(
            timetable=tt,
            day="FRI",
            start_time=time(14, 0),
            end_time=time(17, 0),
            assignment=assign2
        )

        serializer = TimeTableSerializer(tt)
        data = serializer.data

        # Subject details must group distinct subjects (2 distinct subjects, not 3 slots)
        details = data["subject_details"]
        self.assertEqual(len(details), 2)

        d1 = next(x for x in details if x["subject_code"] == "21CS71")
        self.assertEqual(d1["theory_hours"], 3)
        self.assertEqual(d1["tutorial_hours"], 1)
        self.assertEqual(d1["practical_hours"], 0)
        self.assertEqual(d1["total_hours"], 4)
        self.assertEqual(d1["credits"], 4)
        self.assertEqual(d1["faculty_name"], "Dr. Alan Turing")

        d2 = next(x for x in details if x["subject_code"] == "21CSL76")
        self.assertEqual(d2["theory_hours"], 0)
        self.assertEqual(d2["tutorial_hours"], 0)
        self.assertEqual(d2["practical_hours"], 3)
        self.assertEqual(d2["practical_display"], "1 × 3")
        self.assertEqual(d2["total_hours"], 3)
        self.assertEqual(d2["credits"], 2)
        self.assertEqual(d2["faculty_name"], "Dr. Grace Hopper")

        # Summary totals must sum each distinct subject once
        summary = data["teaching_hours_summary"]
        self.assertEqual(summary["total_theory_hours"], 3)
        self.assertEqual(summary["total_tutorial_hours"], 1)
        self.assertEqual(summary["total_practical_hours"], 3)
        self.assertEqual(summary["total_teaching_hours"], 7)
        self.assertEqual(summary["total_credits"], 6)
