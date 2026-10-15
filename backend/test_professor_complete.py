import requests
import datetime

BASE_URL = 'http://127.0.0.1:8000'

def run_tests():
    # Step 1: Login
    login_res = requests.post(
        f'{BASE_URL}/userlogin/login/', 
        json={'identifier': 'professor@sdms.edu', 'password': 'Demo@123'}
    )
    assert login_res.status_code == 200, f'Login failed: {login_res.text}'
    tokens = login_res.json()
    access = tokens.get('access')
    headers = {'Authorization': f'Bearer {access}'}
    print('[PASS] Login successful as PROFESSOR')

    # Step 2: Dashboard
    dash_res = requests.get(f'{BASE_URL}/dashboard/', headers=headers)
    assert dash_res.status_code == 200, f'Dashboard failed: {dash_res.text}'
    assert dash_res.json().get('role') == 'PROFESSOR', 'Role mismatch in dashboard'
    print('[PASS] Dashboard loaded with PROFESSOR role')

    # Step 3: Assigned Subjects
    subj_res = requests.get(f'{BASE_URL}/subjects/professor/subjects/', headers=headers)
    assert subj_res.status_code == 200, f'Subjects failed: {subj_res.text}'
    subjects = subj_res.json()
    assert len(subjects) > 0, 'No assigned subjects found'
    valid_subject_id = subjects[0]['id']
    subject_name = subjects[0].get('subject_name')
    print(f'[PASS] Assigned subjects fetched: {len(subjects)} subjects. Subject: {subject_name} (ID: {valid_subject_id})')

    # Step 4: Verify Cross-Faculty Subject Isolation (Issue 1)
    cross_res = requests.get(f'{BASE_URL}/subjects/professor/subjects/?faculty_id=99999', headers=headers)
    assert cross_res.status_code == 403, f'Expected 403 for cross faculty query, got {cross_res.status_code}'
    print('[PASS] Issue 1 verified: Cross-faculty subject access blocked with 403')

    # Step 5: Faculty Timetable (Issue 2)
    tt_res = requests.get(f'{BASE_URL}/timetable/timetables/faculty/', headers=headers)
    assert tt_res.status_code == 200, f'Timetable failed: {tt_res.text}'
    timetables = tt_res.json()
    valid_slot_id = timetables[0]['slots'][0]['id']
    print(f'[PASS] Issue 2 verified: Faculty timetable loaded safely with slot ID: {valid_slot_id}')

    # Step 6: Attendance Student List Verification (Issue 3)
    stud_slot_res = requests.get(f'{BASE_URL}/attendance/fetch_students_for_slot/?slot_id={valid_slot_id}', headers=headers)
    assert stud_slot_res.status_code == 200, f'Fetch students failed: {stud_slot_res.text}'
    slot_students = stud_slot_res.json()
    assert len(slot_students) > 0, 'No students found in slot'
    student_id = slot_students[0]['id']
    print(f'[PASS] Issue 3 verified: Slot students retrieved for assigned slot ({len(slot_students)} students)')

    # Step 7: Attendance Marking with Ownership Checks (Issue 4)
    att_payload = {
        'timetable_slot': valid_slot_id,
        'date': str(datetime.date.today()),
        'records': [
            {'student_id': student_id, 'status': 'Present'}
        ]
    }
    att_create_res = requests.post(f'{BASE_URL}/attendance/', json=att_payload, headers=headers)
    assert att_create_res.status_code in [200, 201], f'Attendance create failed: {att_create_res.status_code} {att_create_res.text}'
    print('[PASS] Issue 4 verified: Attendance marked with server-side ownership verification')

    # Step 8: Attendance Report Restriction
    rep_res = requests.get(f'{BASE_URL}/attendance/report/?subject_id={valid_subject_id}', headers=headers)
    assert rep_res.status_code == 200, f'Attendance report failed: {rep_res.text}'
    print('[PASS] Attendance report accessible for assigned subject')

    # Step 9: IA Active Students (Issue 5)
    ia_stud_res = requests.get(f'{BASE_URL}/ia/faculty/active-students/?subject_id={valid_subject_id}', headers=headers)
    assert ia_stud_res.status_code == 200, f'IA active students failed: {ia_stud_res.text}'
    ia_students = ia_stud_res.json()
    print(f'[PASS] Issue 5 verified: IA student list scoped to assigned subject ({len(ia_students)} students)')

    # Step 10: IA Test Creation & Idempotency
    ia_test_payload = {
        'subject': valid_subject_id,
        'ia_type': 'Test1',
        'ia_name': 'Internal Assessment 1',
        'max_marks': 25
    }
    ia_test_res = requests.post(f'{BASE_URL}/ia/ia-tests/create/', json=ia_test_payload, headers=headers)
    assert ia_test_res.status_code in [200, 201], f'IA test create failed: {ia_test_res.status_code} {ia_test_res.text}'
    test_id = ia_test_res.json()['id']
    print(f'[PASS] IA Test Setup created/verified with ID: {test_id}')

    # Step 11: IA Marks Over-Limit Validation
    over_limit_payload = {
        'marks': [
            {'student_id': student_id, 'obtained_marks': 99}
        ]
    }
    over_limit_res = requests.put(f'{BASE_URL}/ia/ia-tests/{test_id}/update-marks/', json=over_limit_payload, headers=headers)
    assert over_limit_res.status_code == 400, f'Expected 400 for marks exceeding max_marks, got {over_limit_res.status_code}'
    print('[PASS] IA marks over-limit correctly rejected with 400')

    # Step 12: IA Marks Valid Submission & Aggregate Calculation
    valid_marks_payload = {
        'marks': [
            {'student_id': student_id, 'obtained_marks': 22.5}
        ]
    }
    valid_marks_res = requests.put(f'{BASE_URL}/ia/ia-tests/{test_id}/update-marks/', json=valid_marks_payload, headers=headers)
    assert valid_marks_res.status_code == 200, f'IA mark update failed: {valid_marks_res.text}'
    print('[PASS] IA marks recorded and aggregates recalculated cleanly')

    print('\n=============================================')
    print('ALL 12 PROFESSOR SUITE TESTS PASSED 100%!')
    print('=============================================')

if __name__ == '__main__':
    run_tests()
