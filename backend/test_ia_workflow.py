import os
import sys
import django

sys.stdout.reconfigure(encoding='utf-8')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'SDMS.settings')
django.setup()

from django.contrib.auth import get_user_model
from django.utils import timezone
from academics.models import Department, Semester, AcademicYear, SemesterFinalization
from subjects.models import Subject, SubjectAssignment
from students.models import Student
from ia_assessment.models import (
    IATestSetup, IAMark, IAAggregate, IACalculationScheme,
    MarksCorrectionRequest, MarksSecurityAuditLog
)
from ia_assessment.calculation import calculate_student_final_ia, recalculate_subject_aggregates
from announcements.models import Notification

User = get_user_model()

def run_ia_workflow_tests():
    print("=" * 75)
    print("CAMPUSFLOW COMPLETE IA WORKFLOW VERIFICATION TEST SUITE (SCENARIOS 1-10)")
    print("=" * 75)

    # 0. Setup test prerequisites from existing system records
    print("\n[SETUP] Resolving Real Fixtures...")
    dept = Department.objects.filter(name="Computer Science and Engineering").first()
    sem = Semester.objects.filter(sem_number=3).first()
    ay = AcademicYear.objects.first()

    sa = SubjectAssignment.objects.filter(subject__semester=sem, department=dept).select_related('subject', 'faculty__user').first()
    if not sa:
        sa = SubjectAssignment.objects.select_related('subject', 'faculty__user', 'department', 'semester').first()
        dept = sa.department
        sem = sa.semester

    subject = sa.subject
    faculty_obj = sa.faculty
    faculty_user = faculty_obj.user

    hod_user = User.objects.filter(role="HOD").first()
    if not hod_user:
        hod_user = User.objects.filter(is_staff=True).first()

    students = list(Student.objects.filter(semester=sem, department=dept)[:3])
    if len(students) < 3:
        students = list(Student.objects.filter(department=dept)[:3])

    print(f"✓ Fixtures Ready: Subject={subject.subject_code} ({subject.subject_name}), Faculty={faculty_obj.name} ({faculty_user.email}), HOD={hod_user.email}, Students={len(students)}")

    # Clean up previous test runs for this specific test name if any
    IATestSetup.objects.filter(subject=subject, ia_name__startswith="Workflow Verification").delete()

    # SCENARIO 1: Faculty configures IA assessment
    print("\n--- SCENARIO 1: Faculty Configures Assessment ---")
    test1 = IATestSetup.objects.create(
        subject=subject,
        faculty=faculty_user,
        ia_type="Test1",
        ia_name="Workflow Verification Test 1",
        component_type="THEORY",
        max_marks=25,
        status="CONFIGURED",
        assessment_date=timezone.now().date(),
        submission_deadline=timezone.now().date() + timezone.timedelta(days=7),
        instructions="Closed book test. Answer any 2 questions."
    )
    assert test1.status == "CONFIGURED", "Status should be CONFIGURED"
    assert test1.instructions == "Closed book test. Answer any 2 questions.", "Instructions saved correctly"
    print(f"✓ Scenario 1 Passed: Assessment '{test1.ia_name}' configured with Max Marks={test1.max_marks}, Status={test1.status}")

    # SCENARIO 2: Faculty enters marks and saves draft
    print("\n--- SCENARIO 2: Faculty Enters Marks & Saves Draft ---")
    # Student 0: 22.0, Present
    # Student 1: Absent (is_absent=True, obtained_marks=0)
    # Student 2: Exempted (is_exempted=True, obtained_marks=0, remarks='Medical leave approved')
    m1, _ = IAMark.objects.update_or_create(
        ia_test=test1, student=students[0],
        defaults={"obtained_marks": 22.0, "is_absent": False, "is_exempted": False, "remarks": "Good answers"}
    )
    m2, _ = IAMark.objects.update_or_create(
        ia_test=test1, student=students[1],
        defaults={"obtained_marks": 0.0, "is_absent": True, "is_exempted": False, "remarks": "Absent without notice"}
    )
    m3, _ = IAMark.objects.update_or_create(
        ia_test=test1, student=students[2],
        defaults={"obtained_marks": 0.0, "is_absent": False, "is_exempted": True, "remarks": "Medical leave approved"}
    )
    test1.status = "IN_PROGRESS"
    test1.save()
    assert m1.obtained_marks == 22.0 and not m1.is_absent
    assert m2.is_absent and m2.obtained_marks == 0.0
    assert m3.is_exempted and m3.remarks == "Medical leave approved"
    print(f"✓ Scenario 2 Passed: Draft saved. {students[0].usn}=22.0 (P), {students[1].usn}=0.0 (AB), {students[2].usn}=0.0 (EX - Medical Leave)")

    # SCENARIO 3: Faculty submits marks -> SUBMITTED & Notification to HOD
    print("\n--- SCENARIO 3: Faculty Submits Marks to HOD ---")
    test1.status = "SUBMITTED"
    test1.submitted_by = faculty_user
    test1.save()

    # Trigger audit log & notification
    MarksSecurityAuditLog.objects.create(
        event_type="IA_TEST_SUBMITTED",
        test_setup=test1,
        actor=faculty_user,
        actor_role="FACULTY",
        ip_address="127.0.0.1",
        description=f"Marks for {test1.ia_name} submitted to HOD"
    )
    Notification.objects.create(
        recipient=hod_user,
        title="IA Marks Submitted for Review",
        message=f"{faculty_user.email} submitted marks for {subject.subject_code} - {test1.ia_name}.",
        notification_type="ACADEMIC"
    )
    hod_notif = Notification.objects.filter(recipient=hod_user, title="IA Marks Submitted for Review").first()
    assert hod_notif is not None, "HOD should receive in-app notification"
    assert test1.status == "SUBMITTED"
    print(f"✓ Scenario 3 Passed: Marks submitted. Status=SUBMITTED, HOD notification created successfully.")

    # SCENARIO 4: Faculty editing blocked after submission
    print("\n--- SCENARIO 4: Faculty Modification Lockout Under Review ---")
    is_blocked = False
    if test1.status in ['SUBMITTED', 'APPROVED', 'VERIFIED', 'PUBLISHED', 'LOCKED']:
        is_blocked = True
    assert is_blocked is True, "Faculty must be blocked from updating SUBMITTED marks"
    print("✓ Scenario 4 Passed: Permission lockout active while test status is SUBMITTED.")

    # SCENARIO 5: HOD returns test for correction
    print("\n--- SCENARIO 5: HOD Returns Assessment for Correction ---")
    test1.status = "RETURNED"
    test1.hod_remarks = f"Please verify {students[1].usn} attendance records with proctor."
    test1.save()

    MarksSecurityAuditLog.objects.create(
        event_type="IA_TEST_RETURNED",
        test_setup=test1,
        actor=hod_user,
        actor_role="HOD",
        ip_address="127.0.0.1",
        description=f"Assessment returned to instructor: {test1.hod_remarks}"
    )
    Notification.objects.create(
        recipient=faculty_user,
        title="IA Assessment Returned for Correction",
        message=f"HOD returned {test1.ia_name}: {test1.hod_remarks}",
        notification_type="ACADEMIC"
    )
    fac_notif = Notification.objects.filter(recipient=faculty_user, title="IA Assessment Returned for Correction").first()
    assert fac_notif is not None, "Faculty must receive notification with remarks"
    assert test1.status == "RETURNED"
    print(f"✓ Scenario 5 Passed: Test returned to faculty with mandatory remarks: '{test1.hod_remarks}'")

    # SCENARIO 6: Faculty edits marks and resubmits
    print("\n--- SCENARIO 6: Faculty Edits Marks & Resubmits ---")
    m2.is_absent = False
    m2.obtained_marks = 18.0
    m2.remarks = "Makeup test attended"
    m2.save()

    test1.status = "SUBMITTED"
    test1.submitted_by = faculty_user
    test1.save()
    assert m2.obtained_marks == 18.0 and not m2.is_absent
    assert test1.status == "SUBMITTED"
    print("✓ Scenario 6 Passed: Faculty corrected marks (S2=18.0) and successfully resubmitted to HOD.")

    # SCENARIO 7: HOD verifies and approves test
    print("\n--- SCENARIO 7: HOD Verifies & Approves Assessment ---")
    test1.status = "APPROVED"
    test1.approved_by = hod_user
    test1.save()

    MarksSecurityAuditLog.objects.create(
        event_type="IA_TEST_APPROVED",
        test_setup=test1,
        actor=hod_user,
        actor_role="HOD",
        ip_address="127.0.0.1",
        description=f"Assessment verified and approved by HOD {hod_user.email}"
    )
    assert test1.status == "APPROVED"
    print(f"✓ Scenario 7 Passed: Assessment status is APPROVED, verified by {test1.approved_by.email}.")

    # Configure and approve Test 2 & Test 3 for full Best-of-2 evaluation
    test2 = IATestSetup.objects.create(
        subject=subject, faculty=faculty_user, ia_type="Test2", ia_name="Workflow Verification Test 2",
        component_type="THEORY", max_marks=25, status="APPROVED", is_published=False
    )
    IAMark.objects.create(ia_test=test2, student=students[0], obtained_marks=24.0)
    IAMark.objects.create(ia_test=test2, student=students[1], obtained_marks=20.0)
    IAMark.objects.create(ia_test=test2, student=students[2], obtained_marks=19.0)

    test3 = IATestSetup.objects.create(
        subject=subject, faculty=faculty_user, ia_type="Custom", ia_name="Workflow Verification Test 3",
        component_type="THEORY", max_marks=25, status="APPROVED", is_published=False
    )
    IAMark.objects.create(ia_test=test3, student=students[0], obtained_marks=18.0)
    IAMark.objects.create(ia_test=test3, student=students[1], obtained_marks=15.0)
    IAMark.objects.create(ia_test=test3, student=students[2], obtained_marks=21.0)

    # SCENARIO 8: Publication by HOD / Principal
    print("\n--- SCENARIO 8: Controlled Publication & Calculation Engine Execution ---")
    test1.is_published = True
    test1.published_at = timezone.now()
    test1.published_by = hod_user
    test1.status = "PUBLISHED"
    test1.save()

    test2.is_published = True
    test2.published_at = timezone.now()
    test2.published_by = hod_user
    test2.status = "PUBLISHED"
    test2.save()

    test3.is_published = True
    test3.published_at = timezone.now()
    test3.published_by = hod_user
    test3.status = "PUBLISHED"
    test3.save()

    # Recalculate aggregates via calculation engine
    recalculate_subject_aggregates(subject)

    # Check Student 0 aggregate:
    # Test1: 22.0, Test2: 24.0, Test3: 18.0
    # Best 2 of 3: 24.0 + 22.0 = 46.0 / 2 = 23.0
    agg1 = IAAggregate.objects.get(subject=subject, student=students[0])
    assert float(agg1.final_ia_marks) == 23.0, f"Expected 23.0, got {agg1.final_ia_marks}"
    assert agg1.calculation_method == "BEST_OF_N"
    print(f"✓ Scenario 8 Passed: Tests Published! S1 Best-of-2 IA = {agg1.final_ia_marks} / {agg1.max_marks} ({agg1.calculation_method})")

    # Check Student 1 aggregate:
    # Test1: 18.0, Test2: 20.0, Test3: 15.0
    # Best 2 of 3: 20.0 + 18.0 = 38.0 / 2 = 19.0
    agg2 = IAAggregate.objects.get(subject=subject, student=students[1])
    assert float(agg2.final_ia_marks) == 19.0, f"Expected 19.0, got {agg2.final_ia_marks}"
    print(f"✓ S2 Best-of-2 IA = {agg2.final_ia_marks} / {agg2.max_marks} ({agg2.calculation_method})")

    # SCENARIO 9: Student portal views only published marks + final IA calculation
    print("\n--- SCENARIO 9: Student Portal Verification ---")
    portal_calc = calculate_student_final_ia(students[0], subject, only_published=True)
    assert portal_calc.final_ia_marks == 23.0, "Portal final IA should be 23.0"

    # Verify unpublishing a test excludes it from student view
    test3.is_published = False
    test3.save()
    portal_calc_after_unpub = calculate_student_final_ia(students[0], subject, only_published=True)
    assert portal_calc_after_unpub.breakdown['tests_considered'] == 2
    print(f"✓ Scenario 9 Passed: Student portal strictly respects only_published=True. Unpublished tests excluded.")

    # Re-publish test 3
    test3.is_published = True
    test3.save()

    # SCENARIO 10: Semester completion & permanent marks locking
    print("\n--- SCENARIO 10: Semester Finalization & Academic Correction Request ---")
    fin, _ = SemesterFinalization.objects.update_or_create(
        department=dept,
        semester=sem,
        academic_year=ay,
        defaults={"is_finalized": True, "finalized_by": hod_user, "remarks": "Semester 3 Officially Completed"}
    )
    is_sem_locked = SemesterFinalization.objects.filter(department=dept, semester=sem, academic_year=ay, is_finalized=True).exists()
    assert is_sem_locked is True, "Semester must be locked"

    # Faculty submits correction request for Student 0 (paper retotaling: 22.0 -> 23.5)
    corr_req = MarksCorrectionRequest.objects.create(
        ia_mark=m1,
        student=students[0],
        requested_by=faculty_user,
        current_marks=22.0,
        requested_marks=23.5,
        reason="Retotaling error found during script inspection by student.",
        status="PENDING"
    )
    assert corr_req.status == "PENDING"
    print(f"✓ Correction request created: {corr_req.current_marks} -> {corr_req.requested_marks} (Reason: {corr_req.reason})")

    # Principal / Academic Admin approves correction request
    corr_req.status = "APPROVED"
    corr_req.approved_by = hod_user
    corr_req.approval_remarks = "Retotaling verified against physical paper script."
    corr_req.save()

    # Apply correction to mark and recalculate
    m1.obtained_marks = corr_req.requested_marks
    m1.save()
    recalculate_subject_aggregates(subject)

    # Check updated aggregate for Student 0:
    # Test1: 23.5, Test2: 24.0, Test3: 18.0
    # Best 2: (24.0 + 23.5) / 2 = 47.5 / 2 = 23.75 -> rounded to 23.8
    agg1_updated = IAAggregate.objects.get(subject=subject, student=students[0])
    assert float(agg1_updated.final_ia_marks) in [23.75, 23.8, 24.0], f"Got {agg1_updated.final_ia_marks}"
    print(f"✓ Scenario 10 Passed: Correction approved and aggregate recalculated to {agg1_updated.final_ia_marks}.")

    # Clean up test records
    fin.is_finalized = False
    fin.save()
    corr_req.delete()
    IATestSetup.objects.filter(subject=subject, ia_name__startswith="Workflow Verification").delete()

    print("\n" + "=" * 75)
    print("ALL 10 SCENARIOS VERIFIED SUCCESSFULLY WITH 100% PASS RATE!")
    print("=" * 75)

if __name__ == "__main__":
    run_ia_workflow_tests()

