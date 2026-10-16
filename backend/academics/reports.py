from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from django.db.models import Q, Count
from timetable.views import _resolve_department_for_user
from academics.models import Department, Semester, AcademicYear
from students.models import Student
from faculty.models import Faculty
from subjects.models import Subject, SubjectAssignment
from timetable.models import TimeTableSlot
from attendance.models import AttendanceRecord, AttendanceSession
from ia_assessment.models import IAMark, IATestSetup


class DepartmentReportsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        dept = None
        if user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            if not dept:
                return Response({"error": "No department associated with HOD user."}, status=status.HTTP_404_NOT_FOUND)
        elif user_role in ["PRINCIPAL", "SYSTEM"] or request.user.is_superuser:
            dept_id = request.query_params.get("department_id")
            if dept_id:
                dept = Department.objects.filter(id=dept_id).first()

        report_type = (request.query_params.get("report_type") or "STUDENTS").upper()
        semester_id = request.query_params.get("semester_id")
        academic_year_id = request.query_params.get("academic_year_id")
        subject_id = request.query_params.get("subject_id")
        start_date = request.query_params.get("start_date")
        end_date = request.query_params.get("end_date")
        q = (request.query_params.get("q") or "").strip()

        dept_info = {
            "id": dept.id if dept else None,
            "name": dept.name if dept else ("All Departments" if user_role in ["PRINCIPAL", "SYSTEM"] else "General Department"),
            "code": getattr(dept, "code", dept.name if dept else "ALL"),
            "user_email": request.user.email or getattr(request.user, "user_id", "") or str(request.user),
            "user_role": user_role,
        }

        # 1. Department Student Report
        if report_type == "STUDENTS":
            qs = Student.objects.all()
            if dept:
                qs = qs.filter(department=dept)
            if semester_id:
                qs = qs.filter(semester_id=semester_id)
            if academic_year_id:
                qs = qs.filter(academic_year_id=academic_year_id)
            if q:
                qs = qs.filter(Q(usn__icontains=q) | Q(name__icontains=q) | Q(email__icontains=q))

            rows = [
                {
                    "usn": s.usn,
                    "name": s.name,
                    "semester": s.semester.sem_number if s.semester else "N/A",
                    "department": s.department.name if s.department else "N/A",
                    "status": s.status,
                    "gender": getattr(s, "gender", "N/A"),
                    "email": getattr(s, "email", "N/A"),
                    "phone": getattr(s, "mobile_number", getattr(s, "phone", "N/A")),
                }
                for s in qs.order_by("usn")
            ]
            columns = ["USN", "Name", "Semester", "Department", "Status", "Gender", "Email", "Phone"]
            return Response({
                "department_info": dept_info,
                "report_type": report_type,
                "title": "Department Student Report",
                "columns": columns,
                "rows": rows,
                "summary": {
                    "total_count": len(rows),
                    "card1_label": "Total Students",
                    "card1_value": len(rows),
                    "card2_label": "Active Students",
                    "card2_value": sum(1 for r in rows if (r.get("status") or "").lower() == "active"),
                    "card3_label": "Male Students",
                    "card3_value": sum(1 for r in rows if (r.get("gender") or "").lower() == "male"),
                    "card4_label": "Female Students",
                    "card4_value": sum(1 for r in rows if (r.get("gender") or "").lower() == "female"),
                }
            })

        # 2. Faculty Workload Report
        elif report_type == "FACULTY_WORKLOAD":
            fac_qs = Faculty.objects.all()
            if dept:
                fac_qs = fac_qs.filter(department=dept)
            if q:
                fac_qs = fac_qs.filter(Q(name__icontains=q) | Q(email__icontains=q))

            rows = []
            for fac in fac_qs:
                assignments = SubjectAssignment.objects.filter(faculty=fac)
                if semester_id:
                    assignments = assignments.filter(semester_id=semester_id)
                if academic_year_id:
                    assignments = assignments.filter(academic_year_id=academic_year_id)

                sub_names = [f"{a.subject.subject_code} ({a.subject.subject_name})" for a in assignments if a.subject]
                slots_count = TimeTableSlot.objects.filter(assignment__in=assignments).count()
                weekly_hours = slots_count * 1  # 1 hour per slot

                rows.append({
                    "faculty_id": fac.id,
                    "faculty_name": fac.name,
                    "designation": getattr(fac, "designation", "Faculty"),
                    "email": getattr(fac, "email", "N/A"),
                    "assigned_subjects_count": len(sub_names),
                    "weekly_slots_count": slots_count,
                    "weekly_hours": weekly_hours,
                    "subjects": ", ".join(sub_names) if sub_names else "None",
                })
            columns = ["Faculty Name", "Designation", "Assigned Subjects", "Weekly Slots", "Weekly Hours", "Subjects List"]
            total_slots = sum(r["weekly_slots_count"] for r in rows)
            avg_slots = round(total_slots / len(rows), 1) if rows else 0.0
            return Response({
                "department_info": dept_info,
                "report_type": report_type,
                "title": "Faculty Workload Report",
                "columns": columns,
                "rows": rows,
                "summary": {
                    "total_faculty": len(rows),
                    "total_assigned_slots": total_slots,
                    "card1_label": "Faculty Members",
                    "card1_value": len(rows),
                    "card2_label": "Weekly Teaching Slots",
                    "card2_value": total_slots,
                    "card3_label": "Avg Slots / Faculty",
                    "card3_value": avg_slots,
                    "card4_label": "Total Assigned Subjects",
                    "card4_value": sum(r["assigned_subjects_count"] for r in rows),
                }
            })

        # 3. Attendance Report
        elif report_type == "ATTENDANCE":
            records = AttendanceRecord.objects.all()
            if dept:
                records = records.filter(Q(session__subject__department=dept) | Q(student__department=dept))
            if semester_id:
                records = records.filter(student__semester_id=semester_id)
            if subject_id:
                records = records.filter(session__subject_id=subject_id)
            if start_date:
                records = records.filter(session__date__gte=start_date)
            if end_date:
                records = records.filter(session__date__lte=end_date)
            if q:
                records = records.filter(Q(student__usn__icontains=q) | Q(student__name__icontains=q) | Q(session__subject__subject_code__icontains=q) | Q(session__subject__subject_name__icontains=q))

            # Aggregate per student per subject
            student_stats = (
                records.values("student__usn", "student__name", "session__subject__subject_code", "session__subject__subject_name", "student__semester__sem_number")
                .annotate(
                    total=Count("id"),
                    present=Count("id", filter=Q(status="Present"))
                )
                .order_by("student__usn")
            )

            rows = []
            for st in student_stats:
                total = st["total"]
                present = st["present"]
                pct = round((present / total * 100), 1) if total > 0 else 0.0
                rows.append({
                    "usn": st["student__usn"],
                    "name": st["student__name"],
                    "semester": st["student__semester__sem_number"] or "N/A",
                    "subject": f"{st['session__subject__subject_code']} - {st['session__subject__subject_name']}",
                    "total_classes": total,
                    "attended_classes": present,
                    "percentage": pct,
                    "status": "Shortage (<75%)" if pct < 75.0 else "Eligible (>=75%)",
                })
            columns = ["USN", "Name", "Semester", "Subject", "Total Classes", "Attended", "Percentage", "Status"]
            total_rec = len(rows)
            shortage = sum(1 for r in rows if r["percentage"] < 75.0)
            eligible = total_rec - shortage
            avg_att = round(sum(r["percentage"] for r in rows) / total_rec, 1) if total_rec > 0 else 0.0
            return Response({
                "department_info": dept_info,
                "report_type": report_type,
                "title": "Department Attendance Report",
                "columns": columns,
                "rows": rows,
                "summary": {
                    "total_records": total_rec,
                    "shortage_count": shortage,
                    "card1_label": "Student-Subject Records",
                    "card1_value": total_rec,
                    "card2_label": "Average Attendance",
                    "card2_value": f"{avg_att}%",
                    "card3_label": "Eligible (>=75%)",
                    "card3_value": eligible,
                    "card4_label": "Shortage (<75%)",
                    "card4_value": shortage,
                }
            })

        # 4. IA Performance Report
        elif report_type == "IA_PERFORMANCE":
            marks = IAMark.objects.all().select_related("student", "ia_test", "ia_test__subject")
            if dept:
                marks = marks.filter(Q(ia_test__subject__department=dept) | Q(student__department=dept))
            if semester_id:
                marks = marks.filter(student__semester_id=semester_id)
            if subject_id:
                marks = marks.filter(ia_test__subject_id=subject_id)
            if q:
                marks = marks.filter(Q(student__usn__icontains=q) | Q(student__name__icontains=q) | Q(ia_test__subject__subject_code__icontains=q) | Q(ia_test__subject__subject_name__icontains=q))

            rows = []
            for m in marks.order_by("student__usn", "ia_test__subject__subject_code"):
                max_m = m.ia_test.max_marks or 1
                obtained = float(m.obtained_marks)
                pct = round((obtained / max_m * 100), 1)
                passed = pct >= 40.0
                rows.append({
                    "usn": m.student.usn,
                    "name": m.student.name,
                    "semester": m.student.semester.sem_number if m.student.semester else "N/A",
                    "subject_code": m.ia_test.subject.subject_code,
                    "subject_name": m.ia_test.subject.subject_name,
                    "test_name": m.ia_test.ia_name,
                    "obtained_marks": obtained,
                    "max_marks": max_m,
                    "percentage": pct,
                    "result": "Pass" if passed else "Needs Support (<40%)",
                })
            columns = ["USN", "Name", "Semester", "Subject Code", "Subject Name", "Test Name", "Obtained", "Max", "Percentage", "Result"]
            total_m = len(rows)
            passed_cnt = sum(1 for r in rows if r["percentage"] >= 40.0)
            support_cnt = total_m - passed_cnt
            pass_rate = round(passed_cnt / total_m * 100, 1) if total_m > 0 else 0.0
            return Response({
                "department_info": dept_info,
                "report_type": report_type,
                "title": "IA & Academic Performance Report",
                "columns": columns,
                "rows": rows,
                "summary": {
                    "total_marks": total_m,
                    "passed_count": passed_cnt,
                    "needs_support_count": support_cnt,
                    "card1_label": "Marks Recorded",
                    "card1_value": total_m,
                    "card2_label": "Overall Pass Rate",
                    "card2_value": f"{pass_rate}%",
                    "card3_label": "Passed (>=40%)",
                    "card3_value": passed_cnt,
                    "card4_label": "Needs Support (<40%)",
                    "card4_value": support_cnt,
                }
            })

        # 5. Subject and Timetable Report
        elif report_type == "TIMETABLE":
            assignments = SubjectAssignment.objects.all().select_related("subject", "faculty", "department", "semester")
            if dept:
                assignments = assignments.filter(Q(department=dept) | Q(subject__department=dept))
            if semester_id:
                assignments = assignments.filter(semester_id=semester_id)
            if academic_year_id:
                assignments = assignments.filter(academic_year_id=academic_year_id)
            if q:
                assignments = assignments.filter(Q(subject__subject_code__icontains=q) | Q(subject__subject_name__icontains=q) | Q(faculty__name__icontains=q))

            rows = []
            for a in assignments:
                slots = TimeTableSlot.objects.filter(assignment=a).order_by("day", "start_time")
                slots_str = ", ".join([f"{s.day} {s.start_time.strftime('%H:%M')}-{s.end_time.strftime('%H:%M')}" for s in slots]) if slots.exists() else "None scheduled"
                rows.append({
                    "subject_code": a.subject.subject_code,
                    "subject_name": a.subject.subject_name,
                    "semester": a.semester.sem_number if a.semester else (a.subject.semester.sem_number if a.subject.semester else "N/A"),
                    "department": a.department.name if a.department else "N/A",
                    "faculty_name": a.faculty.name if a.faculty else "Unassigned",
                    "is_elective": "Yes" if a.subject.is_elective else "No",
                    "weekly_slots_count": slots.count(),
                    "slots": slots_str,
                })
            columns = ["Subject Code", "Subject Name", "Semester", "Department", "Faculty", "Elective", "Slots Count", "Schedule Details"]
            total_sub = len(rows)
            total_sl = sum(r["weekly_slots_count"] for r in rows)
            elective_cnt = sum(1 for r in rows if r["is_elective"] == "Yes")
            staffed = sum(1 for r in rows if r["faculty_name"] != "Unassigned")
            return Response({
                "department_info": dept_info,
                "report_type": report_type,
                "title": "Subject and Timetable Report",
                "columns": columns,
                "rows": rows,
                "summary": {
                    "total_subjects": total_sub,
                    "card1_label": "Total Subjects",
                    "card1_value": total_sub,
                    "card2_label": "Total Weekly Slots",
                    "card2_value": total_sl,
                    "card3_label": "Elective Subjects",
                    "card3_value": elective_cnt,
                    "card4_label": "Staffed Faculty",
                    "card4_value": staffed,
                }
            })

        # 6. Semester Progression Report
        elif report_type == "PROGRESSION":
            qs = Student.objects.filter(status__iexact="active")
            if dept:
                qs = qs.filter(department=dept)
            if semester_id:
                qs = qs.filter(semester_id=semester_id)
            if q:
                qs = qs.filter(Q(usn__icontains=q) | Q(name__icontains=q))

            rows = []
            for s in qs.order_by("usn"):
                # Attendance check
                rec = AttendanceRecord.objects.filter(student=s)
                total_att = rec.count()
                pres_att = rec.filter(status="Present").count()
                att_pct = round((pres_att / total_att * 100), 1) if total_att > 0 else 100.0
                att_status = "Eligible" if att_pct >= 75.0 else "Shortage"

                # Academic check
                marks = IAMark.objects.filter(student=s)
                low_marks = 0
                for m in marks:
                    if (float(m.obtained_marks) / (m.ia_test.max_marks or 1)) < 0.40:
                        low_marks += 1
                acad_status = f"{low_marks} backlog(s)" if low_marks > 0 else "Cleared"
                progression = "Eligible for Promotion" if att_status == "Eligible" and low_marks == 0 else "Review Required"

                rows.append({
                    "usn": s.usn,
                    "name": s.name,
                    "current_semester": s.semester.sem_number if s.semester else "N/A",
                    "attendance_pct": f"{att_pct}%",
                    "attendance_status": att_status,
                    "academic_status": acad_status,
                    "progression_recommendation": progression,
                })
            columns = ["USN", "Name", "Current Semester", "Attendance %", "Attendance Status", "Academic Status", "Progression Recommendation"]
            tot = len(rows)
            promoted = sum(1 for r in rows if r["progression_recommendation"] == "Eligible for Promotion")
            review = tot - promoted
            backlog_cnt = sum(1 for r in rows if "backlog" in r["academic_status"].lower())
            return Response({
                "department_info": dept_info,
                "report_type": report_type,
                "title": "Semester Progression Report",
                "columns": columns,
                "rows": rows,
                "summary": {
                    "total_students": tot,
                    "eligible_count": promoted,
                    "review_needed_count": review,
                    "card1_label": "Total Evaluated",
                    "card1_value": tot,
                    "card2_label": "Eligible to Promote",
                    "card2_value": promoted,
                    "card3_label": "Review Required",
                    "card3_value": review,
                    "card4_label": "With Backlogs",
                    "card4_value": backlog_cnt,
                }
            })

        return Response({"error": f"Invalid report_type '{report_type}'"}, status=status.HTTP_400_BAD_REQUEST)
