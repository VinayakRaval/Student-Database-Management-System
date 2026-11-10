from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from django.contrib.auth import get_user_model
from django.utils import timezone
from datetime import timedelta, date, time
from academics.models import Department, Semester, AcademicYear
from students.models import Student
from faculty.models import Faculty
from subjects.models import Subject, SubjectAssignment
from attendance.models import LabBatch, LabBatchStudent, AttendanceSession, AttendanceRecord, ExtraClassSession

User = get_user_model()


class LabBatchDistributionTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Department, Semester, AcademicYear
        self.dept = Department.objects.create(name="Computer Science & Engineering")
        self.sem = Semester.objects.create(sem_number=5)
        self.ay = AcademicYear.objects.create(year_name="2026-2027")

        # Users & Faculty
        self.hod_user = User.objects.create_user(
            email="cse_hod@gecc.edu",
            user_id="cse_hod",
            password="password123",
            role="HOD",
            department=self.dept,
            is_active=True
        )
        self.hod_faculty = Faculty.objects.create(
            name="Dr. HOD CSE",
            faculty_id="FAC_HOD_01",
            user=self.hod_user,
            department=self.dept,
            gender="male",
            dob="1975-01-01",
            phone="9876543210",
            email="cse_hod@gecc.edu",
            qualification="Ph.D",
            role="HOD",
            status="approved",
            
        )

        self.prof_user = User.objects.create_user(
            email="cse_prof@gecc.edu",
            user_id="cse_prof",
            password="password123",
            role="PROFESSOR",
            department=self.dept,
            is_active=True
        )
        self.prof_faculty = Faculty.objects.create(
            name="Prof. Alan Turing",
            faculty_id="FAC_CSE_02",
            user=self.prof_user,
            department=self.dept,
            gender="male",
            dob="1980-01-01",
            phone="9876543211",
            email="cse_prof@gecc.edu",
            qualification="M.Tech",
            role="PROFESSOR",
            status="approved"
        )

        # Create 62 students for testing distribution
        self.students = []
        for i in range(1, 63):
            usn = f"4MC24CS{i:03d}"
            s = Student.objects.create(
                name=f"Student {i}",
                usn=usn,
                cet_no=f"CET{i:03d}",
                dob="2004-01-01",
                religion="Hindu",
                city_type="Urban",
                mobile_no=f"900000{i:04d}",
                email=f"s{i}@gecc.edu",
                parent_occupation="Service",
                address=f"Address {i}",
                permanent_address=f"Address {i}",
                seat_type="general_merit",
                date_of_admission="2022-08-01",
                department=self.dept,
                semester=self.sem,
                academic_year=self.ay,
                status="active",
                registration_status="verified"
            )
            self.students.append(s)

        # Theory subject & Lab subject
        self.theory_sub = Subject.objects.create(
            department=self.dept,
            semester=self.sem,
            subject_name="Computer Networks",
            subject_code="21CS52",
            has_theory=True,
            has_lab=False,
            subject_group="CN_GROUP"
        )
        self.lab_sub = Subject.objects.create(
            department=self.dept,
            semester=self.sem,
            subject_name="Computer Networks Laboratory",
            subject_code="21CSL56",
            has_theory=False,
            has_lab=True,
            parent_subject=self.theory_sub,
            subject_group="CN_GROUP"
        )

    def test_eligible_students_count_endpoint(self):
        self.client.force_authenticate(user=self.hod_user)
        res = self.client.get('/attendance/batches/eligible_students_count/', {
            'department_id': self.dept.id,
            'semester_id': self.sem.id,
            'academic_year_id': self.ay.id,
        })
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['total_eligible_students'], 62)
        self.assertEqual(len(res.data['students']), 62)

    def test_auto_distribute_preview_60_students_3_batches(self):
        self.client.force_authenticate(user=self.hod_user)
        # Take first 60 students
        student_ids = [s.id for s in self.students[:60]]
        res = self.client.post('/attendance/batches/auto_distribute_preview/', {
            'department_id': self.dept.id,
            'semester_id': self.sem.id,
            'academic_year_id': self.ay.id,
            'num_batches': 3,
            'student_ids': student_ids,
            'sort_by': 'usn_asc'
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        batches = res.data['batches']
        self.assertEqual(len(batches), 3)
        self.assertEqual(batches[0]['name'], "Batch A")
        self.assertEqual(batches[0]['count'], 20)
        self.assertEqual(batches[1]['name'], "Batch B")
        self.assertEqual(batches[1]['count'], 20)
        self.assertEqual(batches[2]['name'], "Batch C")
        self.assertEqual(batches[2]['count'], 20)

    def test_auto_distribute_preview_62_students_3_batches_remainder_rule(self):
        self.client.force_authenticate(user=self.hod_user)
        # 62 students divided into 3 batches: 21, 21, 20
        res = self.client.post('/attendance/batches/auto_distribute_preview/', {
            'department_id': self.dept.id,
            'semester_id': self.sem.id,
            'academic_year_id': self.ay.id,
            'num_batches': 3,
            'sort_by': 'usn_asc'
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        batches = res.data['batches']
        self.assertEqual(len(batches), 3)
        self.assertEqual(batches[0]['name'], "Batch A")
        self.assertEqual(batches[0]['count'], 21)
        self.assertEqual(batches[1]['name'], "Batch B")
        self.assertEqual(batches[1]['count'], 21)
        self.assertEqual(batches[2]['name'], "Batch C")
        self.assertEqual(batches[2]['count'], 20)

    def test_create_shared_batches_atomic(self):
        self.client.force_authenticate(user=self.hod_user)
        # 62 students into 3 batches
        batch_a_ids = [s.id for s in self.students[:21]]
        batch_b_ids = [s.id for s in self.students[21:42]]
        batch_c_ids = [s.id for s in self.students[42:62]]

        payload = {
            'department_id': self.dept.id,
            'semester_id': self.sem.id,
            'academic_year_id': self.ay.id,
            'batches': [
                {'name': 'Batch A', 'student_ids': batch_a_ids},
                {'name': 'Batch B', 'student_ids': batch_b_ids},
                {'name': 'Batch C', 'student_ids': batch_c_ids},
            ]
        }
        res = self.client.post('/attendance/batches/create_shared_batches/', payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(len(res.data['batches']), 3)

        # Verify DB records
        created_batches = LabBatch.objects.filter(department=self.dept, semester=self.sem)
        self.assertEqual(created_batches.count(), 3)
        b_a = created_batches.get(name="Batch A")
        self.assertIsNone(b_a.subject) # Shared across all lab subjects in semester
        self.assertEqual(b_a.batch_students.count(), 21)

    def test_theory_lab_automatic_faculty_pairing(self):
        self.client.force_authenticate(user=self.hod_user)
        # Assign theory subject to prof_faculty
        assign_payload = {
            'department_id': self.dept.id,
            'assignments': [
                {
                    'subject_id': self.theory_sub.id,
                    'faculty_id': self.prof_faculty.id,
                    'semester': self.sem.id,
                    'academic_year': self.ay.id,
                }
            ]
        }
        res = self.client.post('/subjects/assign_subjects/', assign_payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        # Check that the paired lab subject was ALSO assigned to prof_faculty automatically!
        lab_assignment = SubjectAssignment.objects.filter(
            subject=self.lab_sub,
            academic_year=self.ay,
            department=self.dept,
            semester=self.sem
        ).first()
        self.assertIsNotNone(lab_assignment)
        self.assertEqual(lab_assignment.faculty, self.prof_faculty)

    def test_extra_class_immediately_enables_attendance(self):
        today = date.today()
        # Schedule extra class by prof_faculty
        extra = ExtraClassSession.objects.create(
            subject=self.theory_sub,
            faculty=self.prof_faculty,
            session_type="THEORY",
            date=today,
            start_time=time(16, 0),
            end_time=time(17, 0),
            status="APPROVED",
            created_by=self.prof_user
        )

        from attendance.views import check_faculty_session_scheduled_today
        is_sched, has_reg, has_extra, extra_obj = check_faculty_session_scheduled_today(
            faculty=self.prof_faculty,
            subject=self.theory_sub,
            date=today,
            session_type="THEORY"
        )
        self.assertTrue(is_sched)
        self.assertTrue(has_extra)
        self.assertEqual(extra_obj.id, extra.id)

    def test_prevent_batch_delete_when_attendance_recorded(self):
        self.client.force_authenticate(user=self.hod_user)
        batch = LabBatch.objects.create(
            department=self.dept,
            semester=self.sem,
            academic_year=self.ay,
            name="Batch Protected",
            created_by=self.hod_user
        )
        # Add attendance session for this batch
        AttendanceSession.objects.create(
            subject=self.lab_sub,
            faculty=self.prof_faculty,
            batch=batch,
            session_type="LAB",
            date=date.today()
        )

        # Try to delete the batch
        res = self.client.delete(f'/attendance/batches/{batch.id}/')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("historical attendance records exist", res.data['error'])
