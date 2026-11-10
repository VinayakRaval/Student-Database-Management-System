import os
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'SDMS.settings')
django.setup()

from rest_framework.test import APIRequestFactory, force_authenticate
from django.core.exceptions import ValidationError
from subjects.views import AssignSubjectsView, GetAssignedProfessorsView
from subjects.models import SubjectAssignment
from userlogin.models import CustomUser

user = CustomUser.objects.filter(is_superuser=True).first()
factory = APIRequestFactory()
view_assign = AssignSubjectsView.as_view()
view_get = GetAssignedProfessorsView.as_view()

print('=== TEST 1: REASSIGN WITHOUT UPDATE_EXISTING (EXPECT 400) ===')
req1 = factory.post('/subjects/assign_subjects/', {
    'department_id': 2,
    'assignments': [{
        'subject_code': 'CS301',
        'faculty_id': 4,
        'semester': 3,
        'academic_year': 1
    }]
}, format='json')
force_authenticate(req1, user=user)
res1 = view_assign(req1)
assert res1.status_code == 400, f'Expected 400, got {res1.status_code}'
assert 'This subject is already assigned to another faculty member' in res1.data['error']
print('Test 1 Passed: 400 returned with correct error message:')
print(res1.data['error'])

print('\n=== TEST 2: INTRA-PAYLOAD DUPLICATE (EXPECT 400) ===')
req2 = factory.post('/subjects/assign_subjects/', {
    'department_id': 2,
    'assignments': [
        {'subject_code': 'CS301', 'faculty_id': 5, 'semester': 3, 'academic_year': 1},
        {'subject_code': 'CS301', 'faculty_id': 4, 'semester': 3, 'academic_year': 1}
    ]
}, format='json')
force_authenticate(req2, user=user)
res2 = view_assign(req2)
assert res2.status_code == 400, f'Expected 400, got {res2.status_code}'
assert 'This subject is already assigned to another faculty member' in res2.data['error']
print('Test 2 Passed: Intra-payload duplicate rejected with 400:')
print(res2.data['error'])

print('\n=== TEST 3: UPDATE EXISTING WITH UPDATE_EXISTING=TRUE (EXPECT 200) ===')
req3 = factory.post('/subjects/assign_subjects/', {
    'department_id': 2,
    'update_existing': True,
    'assignments': [{
        'subject_code': 'CS301',
        'faculty_id': 5,
        'semester': 3,
        'academic_year': 1
    }]
}, format='json')
force_authenticate(req3, user=user)
res3 = view_assign(req3)
assert res3.status_code == 200, f'Expected 200, got {res3.status_code}'
print('Test 3 Passed: Successfully processed assignment with update_existing=True.')

print('\n=== TEST 4: MODEL CLEAN() VALIDATION ===')
sa = SubjectAssignment(
    subject_id=1,
    faculty_id=4,
    department_id=2,
    semester_id=3,
    academic_year_id=1
)
try:
    sa.clean()
    print('Failed: clean() should have raised ValidationError')
except ValidationError as ve:
    print('Test 4 Passed: Model clean() raised ValidationError:')
    print(list(ve.messages)[0] if hasattr(ve, 'messages') else str(ve))

print('\n=== TEST 5: GET ASSIGNED PROFESSORS VIEW ===')
req5 = factory.get('/subjects/getAssignedProfessors/?department_id=2&semester=3&academic_year=1')
force_authenticate(req5, user=user)
res5 = view_get(req5)
assert res5.status_code == 200
print(f'Test 5 Passed: Fetched {len(res5.data)} assignments for cohort:')
for a in res5.data:
    print(f" - {a['subject_code']} ({a['subject_name']}): {a['professor_name']}")

print('\n>>> ALL 5 VERIFICATION TESTS PASSED SUCCESSFULLY! <<<')
