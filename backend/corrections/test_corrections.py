from django.test import TestCase
from django.utils import timezone
from userlogin.models import CustomUser
from academics.models import Department, Semester, AcademicYear
from students.models import Student
from corrections.models import CorrectionRequest, CorrectionRequestHistory, generate_correction_request_id
from corrections.routing import determine_initial_routing

class CorrectionsWorkflowTests(TestCase):
    def setUp(self):
        self.dept_cse = Department.objects.create(name="Computer Science and Engineering")
        self.dept_ece = Department.objects.create(name="Electronics and Communication Engineering")
        self.sem = Semester.objects.create(sem_number=5)
        self.ay = AcademicYear.objects.create(year_name="2026-2027")

        self.student_user = CustomUser.objects.create_user(
            email="student1@test.com",
            phone="9876543210",
            user_id="stu001",
            password="TestPassword123!",
            role="STUDENT",
            department=self.dept_cse,
        )

        self.student = Student.objects.create(
            user=self.student_user,
            name="Test Student",
            dob="2003-01-01",
            cet_no="CET001",
            mobile_no="9876543210",
            email="student1@test.com",
            address="Campus Hostel",
            permanent_address="Campus Hostel",
            date_of_admission="2022-08-01",
            seat_type="CET",
            department=self.dept_cse,
            semester=self.sem,
            academic_year=self.ay,
            usn="4GE22CS001",
            status="active",
            registration_status="approved",
        )

    def test_routing_logic(self):
        role, dept = determine_initial_routing('PERSONAL', self.student)
        self.assertEqual(role, 'ADMISSION')
        self.assertEqual(dept, self.dept_cse)

        role, dept = determine_initial_routing('ATTENDANCE', self.student)
        self.assertEqual(role, 'PROFESSOR')
        self.assertEqual(dept, self.dept_cse)

        role, dept = determine_initial_routing('FEES', self.student)
        self.assertEqual(role, 'ACCOUNTS')
        self.assertIsNone(dept)

        role, dept = determine_initial_routing('LIBRARY', self.student)
        self.assertEqual(role, 'LIBRARY')
        self.assertIsNone(dept)

    def test_request_id_generation(self):
        req_id1 = generate_correction_request_id()
        self.assertTrue(req_id1.startswith("CR-"))
        self.assertTrue(req_id1.endswith("0001"))

    def test_correction_lifecycle(self):
        req = CorrectionRequest.objects.create(
            student=self.student,
            category='ATTENDANCE',
            target_record_ref='CS501 2026-10-15',
            current_value='Absent',
            requested_value='Present',
            description='I attended class on 15th October but was marked absent.',
            reason='Medical certificate presented',
            status='SUBMITTED',
            assigned_department=self.dept_cse,
            assigned_role='PROFESSOR',
        )

        CorrectionRequestHistory.objects.create(
            request=req,
            actor=self.student_user,
            action='SUBMITTED',
            from_status='',
            to_status='SUBMITTED',
            comments='Request submitted',
        )

        self.assertEqual(req.status, 'SUBMITTED')
        self.assertEqual(req.history.count(), 1)

        # Reviewer approves
        req.status = 'APPROVED'
        req.reviewer_comments = 'Verified with attendance register.'
        req.save()

        CorrectionRequestHistory.objects.create(
            request=req,
            action='APPROVED',
            from_status='SUBMITTED',
            to_status='APPROVED',
            comments=req.reviewer_comments,
        )

        self.assertEqual(req.status, 'APPROVED')
        self.assertEqual(req.history.count(), 2)

        # Resolve
        req.status = 'COMPLETED'
        req.resolved_at = timezone.now()
        req.resolution_notes = 'Attendance record updated to Present.'
        req.save()

        self.assertEqual(req.status, 'COMPLETED')
        self.assertIsNotNone(req.resolved_at)
