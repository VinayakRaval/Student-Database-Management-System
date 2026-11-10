from academics.models import Department

def determine_initial_routing(category, student):
    """
    Returns (assigned_role, assigned_department) tuple based on correction category.
    Enforces department-level assignment where applicable.
    """
    student_dept = student.department if student else None

    routing_map = {
        'PERSONAL': ('ADMISSION', student_dept),
        'ADMISSION_USN': ('ADMISSION', student_dept),
        'DOCUMENTS': ('ADMISSION', student_dept),
        'ATTENDANCE': ('PROFESSOR', student_dept),
        'IA_MARKS': ('PROFESSOR', student_dept),
        'EXAM_RESULTS': ('EXAM', student_dept),
        'FEES': ('ACCOUNTS', None),
        'LIBRARY': ('LIBRARY', None),
        'ACADEMIC': ('HOD', student_dept),
        'ACCOUNT': ('SYSTEM', None),
        'OTHER': ('HOD', student_dept),
    }

    return routing_map.get(category, ('HOD', student_dept))
