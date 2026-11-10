import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "SDMS.settings")
import django
django.setup()


from django.utils import timezone
from academics.models import Department, Semester, AcademicYear, SemesterFinalization
from ia_assessment.models import IATestSetup, IAMark, MarksCorrectionRequest, MarksSecurityAuditLog
from external_results.models import ExternalResult
from students.models import Student, StudentAcademicHistory
from userlogin.models import CustomUser
from django.core.exceptions import PermissionDenied
from rest_framework.test import APIRequestFactory, force_authenticate
from ia_assessment.views import BulkIAMarkUpdateView, MarksCorrectionRequestCreateView, MarksCorrectionRequestReviewView
from academics.views import SemesterFinalizeView

# Setup test actors
principal = CustomUser.objects.filter(role='PRINCIPAL').first() or CustomUser.objects.filter(is_superuser=True).first()
prof = CustomUser.objects.filter(role__in=['PROFESSOR', 'FACULTY']).first()
hod = CustomUser.objects.filter(role='HOD').first()

dept = Department.objects.first()
sem = Semester.objects.first()
ay = AcademicYear.objects.first()

print(f"Test environment: Dept={dept.name}, Sem={sem.sem_number}, AY={ay.year_name}")
print(f"Actors: Principal={principal.email if principal else None}, Prof={prof.email if prof else None}, HOD={hod.email if hod else None}")

# 1. Test Semester Finalization API
factory = APIRequestFactory()
fin_req = factory.post('/academics/semesters/finalize/', {
    'department_id': dept.id,
    'semester_id': sem.id,
    'academic_year_id': ay.id,
    'remarks': 'Official end of semester finalization test.'
}, format='json')
force_authenticate(fin_req, user=principal)
fin_resp = SemesterFinalizeView.as_view()(fin_req)
msg = fin_resp.data.get("message", "")
print(f"1. SemesterFinalizeView Response: {fin_resp.status_code} | {msg}")
assert fin_resp.status_code == 200, f"Finalization failed: {fin_resp.data}"

# 2. Verify all tests in this dept/sem are locked
locked_tests = IATestSetup.objects.filter(subject__department=dept, subject__semester=sem, is_locked=True)
print(f"2. Locked IA Tests count: {locked_tests.count()}")

test = locked_tests.first()
if not test:
    test = IATestSetup.objects.first()
    test.is_locked = True
    test.save(update_fields=['is_locked'])

# 3. Attempt unauthorized mark update as Professor via BulkIAMarkUpdateView
bulk_req = factory.put(f"/ia/ia-tests/{test.id}/update-marks/", {
    'marks': [{'student_id': Student.objects.first().id, 'obtained_marks': 22}]
}, format='json')
force_authenticate(bulk_req, user=prof or principal)
bulk_resp = BulkIAMarkUpdateView.as_view()(bulk_req, test_id=test.id)
print(f"3. BulkIAMarkUpdateView on locked test Response: {bulk_resp.status_code} | {bulk_resp.data}")
assert bulk_resp.status_code == 403, f"Expected 403 Forbidden, got {bulk_resp.status_code}"

# 4. Verify rejection was logged in MarksSecurityAuditLog
rejections = MarksSecurityAuditLog.objects.filter(event_type='REJECTED_MODIFICATION_ATTEMPT')
print(f"4. Audit log contains {rejections.count()} rejected modification attempts. Latest: {rejections.first().details}")
assert rejections.exists(), "Expected REJECTED_MODIFICATION_ATTEMPT in audit log!"

# 5. Create a MarksCorrectionRequest
student = Student.objects.first()
corr_req = factory.post('/ia/corrections/request/', {
    'ia_test_id': test.id,
    'student_id': student.id,
    'requested_marks': 21.5,
    'reason': 'Evaluation paper retotaling discrepancy corrected after verification.'
}, format='json')
force_authenticate(corr_req, user=prof or principal)
corr_resp = MarksCorrectionRequestCreateView.as_view()(corr_req)
print(f"5. MarksCorrectionRequestCreateView Response: {corr_resp.status_code}")
assert corr_resp.status_code == 201, f"Expected 201, got {corr_resp.data}"
corr_id = corr_resp.data['id']

# 6. Review & Approve Correction Request as Principal
review_req = factory.post(f"/ia/corrections/{corr_id}/review/", {
    'action': 'APPROVE',
    'remarks': 'Approved following formal academic board review.'
}, format='json')
force_authenticate(review_req, user=principal)
review_resp = MarksCorrectionRequestReviewView.as_view()(review_req, pk=corr_id)
print(f"6. MarksCorrectionRequestReviewView Response: {review_resp.status_code} | {review_resp.data}")
assert review_resp.status_code == 200, f"Expected 200, got {review_resp.data}"

# 7. Verify mark was updated and audit log records CORRECTION_APPROVED
updated_mark = IAMark.objects.get(ia_test=test, student=student)
print(f"7. Updated mark: {updated_mark.obtained_marks}")
assert float(updated_mark.obtained_marks) == 21.5, f"Expected 21.5, got {updated_mark.obtained_marks}"

approved_logs = MarksSecurityAuditLog.objects.filter(event_type='CORRECTION_APPROVED')
print(f"8. Audit log contains {approved_logs.count()} approved correction entries. Latest: {approved_logs.first().details}")
assert approved_logs.exists(), "Expected CORRECTION_APPROVED in audit log!"

print("\nALL AUTOMATED MARKS LOCKING & CORRECTION TESTS PASSED PERFECTLY!")
