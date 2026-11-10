import math
from decimal import Decimal, ROUND_HALF_UP
from django.db import transaction
from django.db.models import Avg, Sum
from .models import IATestSetup, IAMark, IAAggregate, IACalculationScheme


def get_active_scheme_for_subject(subject):
    """
    Finds the most specific active calculation scheme for a subject.
    Priority:
    1. Subject-specific
    2. Semester + Department specific
    3. Department-specific
    4. Global default scheme
    """
    scheme = IACalculationScheme.objects.filter(subject=subject, is_active=True).first()
    if scheme:
        return scheme

    if subject.department and subject.semester:
        scheme = IACalculationScheme.objects.filter(
            department=subject.department,
            semester=subject.semester,
            is_active=True
        ).first()
        if scheme:
            return scheme

    if subject.department:
        scheme = IACalculationScheme.objects.filter(
            department=subject.department,
            is_active=True
        ).first()
        if scheme:
            return scheme

    scheme = IACalculationScheme.objects.filter(is_active=True).first()
    if scheme:
        return scheme

    # Fallback in-memory default scheme
    return IACalculationScheme(
        name="VTU Standard Best 2 of 3",
        scheme_type="BEST_OF_N",
        best_n=2,
        max_final_ia=Decimal("30.0"),
        test_weightage=Decimal("100.0"),
        assignment_weightage=Decimal("0.0"),
        quiz_weightage=Decimal("0.0"),
        rounding_rule="ROUND_HALF_UP",
    )


def apply_rounding(value, rounding_rule):
    val_float = float(value)
    if rounding_rule == "CEIL":
        return Decimal(str(math.ceil(val_float)))
    elif rounding_rule == "ROUND_HALF_UP":
        dec = Decimal(str(round(val_float, 4)))
        return dec.quantize(Decimal("1"), rounding=ROUND_HALF_UP)
    else:  # EXACT
        return Decimal(str(round(val_float, 2)))


def calculate_student_final_ia(student, subject, only_published=False):
    """
    Calculates the final IA marks for a single student in a given subject,
    and updates/creates the IAAggregate record.
    """
    scheme = get_active_scheme_for_subject(subject)

    marks_qs = IAMark.objects.filter(
        student=student,
        ia_test__subject=subject
    ).select_related("ia_test")

    if only_published:
        marks_qs = marks_qs.filter(ia_test__is_published=True)

    test_entries = []
    total_obtained = 0.0
    for m in marks_qs:
        max_m = float(m.ia_test.max_marks) if m.ia_test.max_marks > 0 else 25.0
        obt_m = float(m.obtained_marks) if not m.is_absent else 0.0
        total_obtained += obt_m
        pct = (obt_m / max_m * 100.0) if max_m > 0 else 0.0
        normalized = (obt_m / max_m * float(scheme.max_final_ia)) if max_m > 0 else 0.0

        test_entries.append({
            "mark_id": m.id,
            "test_id": m.ia_test.id,
            "test_name": m.ia_test.ia_name,
            "ia_type": m.ia_test.ia_type,
            "component_type": m.ia_test.component_type,
            "max_marks": max_m,
            "obtained_marks": obt_m,
            "percentage": round(pct, 2),
            "normalized_score": round(normalized, 2),
            "is_absent": m.is_absent,
            "is_exempted": m.is_exempted,
            "status": m.status,
            "test_status": m.ia_test.status,
            "is_published": m.ia_test.is_published,
        })

    active_tests = [t for t in test_entries if not t["is_exempted"]]
    active_count = len(active_tests)
    raw_final = 0.0
    selected_tests = []

    if active_count > 0:
        if scheme.scheme_type == "BEST_OF_N":
            # Separate theory tests from assignments/quizzes if present
            tests_only = [t for t in active_tests if t["ia_type"] in ["Test1", "Test2", "LabTest1", "LabTest2", "Custom"]]
            pool = tests_only if tests_only else active_tests
            # Sort descending by normalized score
            pool_sorted = sorted(pool, key=lambda x: x["normalized_score"], reverse=True)
            n = min(scheme.best_n, len(pool_sorted))
            selected = pool_sorted[:n]
            selected_tests = [t["test_name"] for t in selected]
            if selected:
                raw_final = sum(t["normalized_score"] for t in selected) / len(selected)

        elif scheme.scheme_type == "AVERAGE_ALL":
            raw_final = sum(t["normalized_score"] for t in active_tests) / active_count
            selected_tests = [t["test_name"] for t in active_tests]

        elif scheme.scheme_type == "WEIGHTED":
            tests = [t for t in active_tests if t["ia_type"] in ["Test1", "Test2", "LabTest1", "LabTest2"]]
            assignments = [t for t in active_tests if t["ia_type"] == "Assignment"]
            quizzes = [t for t in active_tests if t["ia_type"] in ["Quiz", "Presentation"]]

            test_avg = (sum(t["percentage"] for t in tests) / len(tests)) if tests else 0.0
            asgn_avg = (sum(t["percentage"] for t in assignments) / len(assignments)) if assignments else 0.0
            quiz_avg = (sum(t["percentage"] for t in quizzes) / len(quizzes)) if quizzes else 0.0

            weighted_pct = (
                (test_avg * float(scheme.test_weightage) / 100.0) +
                (asgn_avg * float(scheme.assignment_weightage) / 100.0) +
                (quiz_avg * float(scheme.quiz_weightage) / 100.0)
            )
            raw_final = (weighted_pct / 100.0) * float(scheme.max_final_ia)
            selected_tests = [t["test_name"] for t in active_tests]

        elif scheme.scheme_type == "TOTAL":
            raw_final = sum(t["obtained_marks"] for t in active_tests)
            selected_tests = [t["test_name"] for t in active_tests]

    # Bound final mark between 0 and max_final_ia
    raw_final = max(0.0, min(raw_final, float(scheme.max_final_ia)))
    final_rounded = apply_rounding(raw_final, scheme.rounding_rule)
    avg_score = round(total_obtained / active_count, 2) if active_count > 0 else 0.0

    breakdown = {
        "scheme_name": scheme.name,
        "scheme_type": scheme.scheme_type,
        "best_n": scheme.best_n,
        "rounding_rule": scheme.rounding_rule,
        "selected_tests": selected_tests,
        "all_tests": test_entries,
        "raw_final_score": round(raw_final, 2),
    }

    aggregate, _ = IAAggregate.objects.update_or_create(
        student=student,
        subject=subject,
        defaults={
            "total_marks": round(Decimal(str(total_obtained)), 2),
            "average_marks": round(Decimal(str(avg_score)), 2),
            "final_ia_marks": final_rounded,
            "max_marks": scheme.max_final_ia,
            "calculation_method": f"{scheme.name} ({scheme.get_scheme_type_display()}, Max: {scheme.max_final_ia})",
            "breakdown": breakdown,
        }
    )
    return aggregate


def recalculate_subject_aggregates(subject, only_published=False):
    """
    Recalculates final IA aggregates for all students enrolled in or
    having marks for this subject.
    """
    from students.models import Student
    student_ids = set(IAMark.objects.filter(ia_test__subject=subject).values_list("student_id", flat=True))

    assignment = subject.subjectassignment_set.first()
    target_dept = (assignment.department or subject.department) if assignment else subject.department
    target_sem = (assignment.semester or subject.semester) if assignment else subject.semester
    if target_dept and target_sem:
        enrolled_ids = Student.objects.filter(
            department=target_dept,
            semester=target_sem,
            status__iexact="active"
        ).values_list("id", flat=True)
        student_ids.update(enrolled_ids)

    results = []
    with transaction.atomic():
        for s_id in student_ids:
            student = Student.objects.filter(id=s_id).first()
            if student:
                agg = calculate_student_final_ia(student, subject, only_published=only_published)
                results.append(agg)
    return results
