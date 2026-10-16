from rest_framework import viewsets, status, generics
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Count, Q
from django.shortcuts import get_object_or_404

from .models import AttendanceSession, AttendanceRecord, AttendanceCorrectionRequest
from .serializers import AttendanceSessionCreateSerializer, AttendanceSessionSerializer
from students.models import Student
from timetable.models import TimeTableSlot
from subjects.models import Subject, SubjectAssignment
from faculty.models import Faculty
from django.utils import timezone

# ==========================================
# ==========================================
#  CORE APP VIEWSET (Faculty & Student App)
# ==========================================
class AttendanceViewSet(viewsets.ModelViewSet):
    queryset = AttendanceSession.objects.all()

    def get_serializer_class(self):
        if self.action == 'create':
            return AttendanceSessionCreateSerializer
        return AttendanceSessionSerializer

    permission_classes = [IsAuthenticated]

    # --- 1. Faculty: Get Students for a specific TimeTable Slot ---
    @action(detail=False, methods=['get'])
    def fetch_students_for_slot(self, request):
        """
        API to get student list for a specific TimeTable Slot.
        Usage: /api/attendance/fetch_students_for_slot/?slot_id=5
        """
        slot_id = request.query_params.get('slot_id')
        if not slot_id:
            return Response({"error": "slot_id is required"}, status=400)

        from timetable.views import _resolve_faculty_for_user, _resolve_department_for_user
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        try:
            slot = TimeTableSlot.objects.select_related(
                'assignment__faculty',
                'assignment__subject__department', 
                'assignment__subject__semester',
                'assignment__academic_year',
                'assignment__department',
                'assignment__semester',
                'timetable__department'
            ).get(id=slot_id)

            # Ownership check:
            if user_role == "PROFESSOR":
                fac = _resolve_faculty_for_user(request.user)
                if not fac:
                    return Response({"error": "Faculty profile not found for user."}, status=status.HTTP_404_NOT_FOUND)
                if slot.assignment.faculty_id != fac.id:
                    return Response({"error": "You are not assigned to teach this timetable slot."}, status=status.HTTP_403_FORBIDDEN)

            elif user_role == "HOD":
                fac = _resolve_faculty_for_user(request.user)
                dept = _resolve_department_for_user(request.user)
                target_dept = slot.assignment.department or slot.assignment.subject.department or slot.timetable.department
                # Allow if HOD is the assigned faculty for this slot, or slot belongs to HOD's department
                if not (fac and slot.assignment.faculty_id == fac.id):
                    if dept and target_dept and dept.id != target_dept.id:
                        return Response({"error": "This slot does not belong to your department."}, status=status.HTTP_403_FORBIDDEN)

            # Fetch students belonging to the Subject's Dept, Semester & Academic Year
            target_dept = slot.assignment.department or (slot.assignment.subject.department if slot.assignment.subject else None) or (slot.timetable.department if slot.timetable else None)
            target_sem = slot.assignment.semester or (slot.assignment.subject.semester if slot.assignment.subject else None) or (slot.timetable.semester if slot.timetable else None)
            
            students_qs = Student.objects.filter(
                department=target_dept,
                semester=target_sem
            ).filter(
                Q(status__iexact='active') | Q(registration_status__iexact='verified')
            )
            if slot.assignment.academic_year:
                students_qs = students_qs.filter(academic_year=slot.assignment.academic_year)

            students = students_qs.order_by('usn')

            data = [
                {
                    "id": s.id,
                    "name": s.name,
                    "usn": getattr(s, 'usn', '') or '',
                    "is_selected": True
                } 
                for s in students
            ]
            
            return Response(data)

        except TimeTableSlot.DoesNotExist:
            return Response({"error": "Invalid Slot ID"}, status=404)

    # --- 2. Faculty: Mark Attendance (Bulk Create) ---
    def create(self, request, *args, **kwargs):
        """
        Override create to enforce faculty ownership and bind session to authenticated user.
        Payload: { "timetable_slot": 1, "date": "2023-10-27", "records": [...] }
        """
        from timetable.views import _resolve_faculty_for_user, _resolve_department_for_user
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        slot_id = request.data.get('timetable_slot')
        if not slot_id:
            return Response({"error": "timetable_slot is required."}, status=status.HTTP_400_BAD_REQUEST)

        slot = TimeTableSlot.objects.select_related('assignment__faculty', 'assignment__subject').filter(id=slot_id).first()
        if not slot:
            return Response({"error": "Invalid timetable slot."}, status=status.HTTP_404_NOT_FOUND)

        payload = request.data.copy()

        if user_role == "PROFESSOR":
            fac = _resolve_faculty_for_user(request.user)
            if not fac:
                return Response({"error": "Faculty profile not found for user."}, status=status.HTTP_404_NOT_FOUND)
            if slot.assignment.faculty_id != fac.id:
                return Response({"error": "You are not authorized to mark attendance for this slot."}, status=status.HTTP_403_FORBIDDEN)
            # Force authenticated faculty profile
            payload['faculty'] = fac.id
            payload['subject'] = slot.assignment.subject_id

        elif user_role == "HOD":
            fac = _resolve_faculty_for_user(request.user)
            dept = _resolve_department_for_user(request.user)
            target_dept = slot.assignment.department or (slot.assignment.subject.department if slot.assignment.subject else None) or (slot.timetable.department if slot.timetable else None)
            if not (fac and slot.assignment.faculty_id == fac.id):
                if dept and target_dept and dept.id != target_dept.id:
                    return Response({"error": "This slot does not belong to your department."}, status=status.HTTP_403_FORBIDDEN)
            if fac and slot.assignment.faculty_id == fac.id:
                payload['faculty'] = fac.id
            elif not payload.get('faculty'):
                payload['faculty'] = slot.assignment.faculty_id
            payload['subject'] = slot.assignment.subject_id

        else:
            if not payload.get('faculty'):
                payload['faculty'] = slot.assignment.faculty_id
            if not payload.get('subject'):
                payload['subject'] = slot.assignment.subject_id

        serializer = self.get_serializer(data=payload)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        return Response({"message": "Attendance marked successfully!"}, status=status.HTTP_201_CREATED)

    # --- 3. View Stats (Percentage per Subject for Student, Dept Stats for HOD, Assigned Stats for Faculty) ---
    @action(detail=False, methods=['get'])
    def my_stats(self, request):
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        if user_role == "HOD":
            from timetable.views import _resolve_department_for_user
            dept = _resolve_department_for_user(request.user)
            records = AttendanceRecord.objects.all()
            if dept:
                records = records.filter(session__subject__department=dept)

            stats = records.values(
                'session__subject__subject_name',
                'session__subject__subject_code'
            ).annotate(
                total_sessions=Count('id'),
                present_count=Count('id', filter=Q(status='Present'))
            )
            data = []
            for entry in stats:
                total = entry['total_sessions']
                present = entry['present_count']
                percentage = (present / total) * 100 if total > 0 else 0.0
                data.append({
                    "subject_name": entry['session__subject__subject_name'],
                    "subject_code": entry['session__subject__subject_code'],
                    "total_classes": total,
                    "attended_classes": present,
                    "percentage": round(percentage, 1)
                })
            return Response(data)

        elif user_role == "PROFESSOR":
            from timetable.views import _resolve_faculty_for_user
            fac = _resolve_faculty_for_user(request.user)
            records = AttendanceRecord.objects.filter(session__faculty=fac) if fac else AttendanceRecord.objects.none()
            stats = records.values(
                'session__subject__subject_name',
                'session__subject__subject_code'
            ).annotate(
                total_sessions=Count('id'),
                present_count=Count('id', filter=Q(status='Present'))
            )
            data = []
            for entry in stats:
                total = entry['total_sessions']
                present = entry['present_count']
                percentage = (present / total) * 100 if total > 0 else 0.0
                data.append({
                    "subject_name": entry['session__subject__subject_name'],
                    "subject_code": entry['session__subject__subject_code'],
                    "total_classes": total,
                    "attended_classes": present,
                    "percentage": round(percentage, 1)
                })
            return Response(data)

        student = getattr(request.user, "student", None)
        if not student:
            student = Student.objects.filter(user=request.user).first()
        if not student:
            return Response([], status=200)

        stats = AttendanceRecord.objects.filter(student=student).values(
            'session__subject__subject_name',
            'session__subject__subject_code'
        ).annotate(
            total_sessions=Count('id'),
            present_count=Count('id', filter=Q(status='Present'))
        )

        data = []
        for entry in stats:
            total = entry['total_sessions']
            present = entry['present_count']
            percentage = (present / total) * 100 if total > 0 else 0.0
            
            data.append({
                "subject_name": entry['session__subject__subject_name'],
                "subject_code": entry['session__subject__subject_code'],
                "total_classes": total,
                "attended_classes": present,
                "percentage": round(percentage, 1)
            })

        return Response(data)


# ==========================================
#  REPORTING VIEWS (For Admin / HOD / Web)
# ==========================================

# 1. Subject-wise Class Report
class AttendanceReportView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        subject_id = request.query_params.get("subject_id")
        if not subject_id:
            return Response({"error": "subject_id query param is required"}, status=400)

        subject = get_object_or_404(Subject, id=subject_id)

        from timetable.views import _resolve_faculty_for_user, _resolve_department_for_user
        from subjects.models import SubjectAssignment
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        if user_role == "PROFESSOR":
            fac = _resolve_faculty_for_user(request.user)
            if not fac or not SubjectAssignment.objects.filter(subject_id=subject.id, faculty=fac).exists():
                return Response({"error": "You are not assigned to teach this subject."}, status=status.HTTP_403_FORBIDDEN)

        elif user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            if dept and subject.department_id != dept.id:
                return Response({"error": "This subject does not belong to your department."}, status=status.HTTP_403_FORBIDDEN)

        elif user_role == "STUDENT":
            return Response({"error": "Students are not authorized to view class-wide reports. Use my_stats endpoint."}, status=status.HTTP_403_FORBIDDEN)

        records = (
            AttendanceRecord.objects
            .filter(session__subject_id=subject_id)
            .values("student__usn")
            .annotate(
                total=Count("id"),
                present=Count("id", filter=Q(status="Present"))
            )
            .order_by("student__usn")
        )

        report = [
            {
                "usn": r["student__usn"],
                "total": r["total"],
                "present": r["present"],
                "percentage": round((r["present"] / r["total"]) * 100, 2) if r["total"] > 0 else 0
            }
            for r in records
        ]

        return Response(report)

# 2. Detailed View for a Specific Student (Admin/HOD lookup)
class StudentAttendanceView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, student_id, *args, **kwargs):
        student = get_object_or_404(Student, id=student_id)

        from timetable.views import _resolve_faculty_for_user, _resolve_department_for_user
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        if user_role == "STUDENT":
            if getattr(student.user, "id", None) != request.user.id:
                return Response({"error": "You can only view your own attendance record."}, status=status.HTTP_403_FORBIDDEN)

        elif user_role == "PROFESSOR":
            fac = _resolve_faculty_for_user(request.user)
            if not fac:
                return Response({"error": "Faculty profile not found for user."}, status=status.HTTP_404_NOT_FOUND)

        elif user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            if dept and student.department_id != dept.id:
                return Response({"error": "Student does not belong to your department."}, status=status.HTTP_403_FORBIDDEN)

        records = AttendanceRecord.objects.filter(student=student).select_related('session', 'session__subject')

        if user_role == "PROFESSOR":
            fac = _resolve_faculty_for_user(request.user)
            records = records.filter(session__faculty=fac)

        total_sessions = records.count()
        present_count = records.filter(status="Present").count()
        absent_count = total_sessions - present_count
        attendance_percentage = round((present_count / total_sessions) * 100, 2) if total_sessions else 0

        session_data = [
            {
                "session_id": r.session.id,
                "subject_code": r.session.subject.subject_code,
                "subject_name": r.session.subject.subject_name,
                "date": r.session.date,
                "status": r.status
            }
            for r in records
        ]

        return Response({
            "student_usn": student.usn,
            "student_name": student.name,
            "total_sessions": total_sessions,
            "present": present_count,
            "absent": absent_count,
            "attendance_percentage": attendance_percentage,
            "sessions": session_data
        })


# ==========================================
# 3. HOD Attendance Monitoring View
# ==========================================
class AttendanceMonitoringSummaryView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        from timetable.views import _resolve_department_for_user
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
                from academics.models import Department
                dept = Department.objects.filter(id=dept_id).first()

        # 1. Overview KPIs
        students_qs = Student.objects.filter(status__iexact="active")
        faculty_qs = Faculty.objects.filter(status__iexact="active")
        subjects_qs = Subject.objects.all()
        sessions_qs = AttendanceSession.objects.all()
        records_qs = AttendanceRecord.objects.all()

        if dept:
            students_qs = students_qs.filter(department=dept)
            faculty_qs = faculty_qs.filter(department=dept)
            subjects_qs = subjects_qs.filter(
                Q(department=dept) |
                Q(subjectassignment__department=dept)
            ).distinct()
            sessions_qs = sessions_qs.filter(
                Q(subject__department=dept) |
                Q(faculty__department=dept)
            ).distinct()
            records_qs = records_qs.filter(
                Q(session__subject__department=dept) |
                Q(student__department=dept)
            ).distinct()

        total_students = students_qs.count()
        total_faculty = faculty_qs.count()
        total_records = records_qs.count()
        present_records = records_qs.filter(status="Present").count()
        avg_dept_attendance = round((present_records / total_records * 100), 1) if total_records > 0 else 0.0

        # 2. Subject & Semester-wise Attendance
        subject_stats = []
        for sub in subjects_qs:
            sub_records = records_qs.filter(session__subject=sub)
            sub_total = sub_records.count()
            sub_present = sub_records.filter(status="Present").count()
            sub_sessions = sessions_qs.filter(subject=sub).count()

            # Faculty assigned
            assignment = SubjectAssignment.objects.filter(subject=sub).first()
            has_faculty = assignment and assignment.faculty
            fac_name = assignment.faculty.name if has_faculty else "Unassigned"

            if sub_sessions == 0:
                sub_pct = None
                if not has_faculty:
                    st_code = "UNASSIGNED"
                    st_label = "Faculty unassigned"
                else:
                    st_code = "NO_SESSIONS"
                    st_label = "No sessions recorded"
            else:
                sub_pct = round((sub_present / sub_total * 100), 1) if sub_total > 0 else 0.0
                st_code = "HEALTHY" if sub_pct >= 75.0 else "CRITICAL"
                st_label = "Healthy" if sub_pct >= 75.0 else "Critical (<75%)"

            subject_stats.append({
                "subject_id": sub.id,
                "subject_code": sub.subject_code,
                "subject_name": sub.subject_name,
                "semester": sub.semester.sem_number if sub.semester else "N/A",
                "department": sub.department.name if sub.department else "N/A",
                "faculty_name": fac_name,
                "total_sessions": sub_sessions,
                "attendance_percentage": sub_pct,
                "status": st_code,
                "status_label": st_label,
                "is_elective": sub.is_elective,
            })

        # 3. Professor Submission Status (Recent sessions / timetable slots)
        from datetime import date
        today = date.today()
        recent_sessions = sessions_qs.select_related('subject', 'faculty').order_by('-date', '-created_at')[:20]
        submissions = [
            {
                "session_id": s.id,
                "subject_code": s.subject.subject_code,
                "subject_name": s.subject.subject_name,
                "faculty_name": s.faculty.name if s.faculty else "N/A",
                "date": s.date.strftime("%Y-%m-%d"),
                "session_count": s.session_count,
                "records_count": s.records.count(),
                "status": "SUBMITTED"
            }
            for s in recent_sessions
        ]

        # 4. Students Below Threshold (<75%)
        low_attendance_students = []
        for st in students_qs:
            st_records = records_qs.filter(student=st)
            st_total = st_records.count()
            if st_total > 0:
                st_present = st_records.filter(status="Present").count()
                pct = round((st_present / st_total * 100), 1)
                if pct < 75.0:
                    low_attendance_students.append({
                        "student_id": st.id,
                        "usn": st.usn,
                        "name": st.name,
                        "semester": st.semester.sem_number if st.semester else "N/A",
                        "department": st.department.name if st.department else "N/A",
                        "total_classes": st_total,
                        "attended_classes": st_present,
                        "percentage": pct,
                        "phone": getattr(st, 'mobile_number', getattr(st, 'phone', 'N/A'))
                    })
        # Sort lowest first
        low_attendance_students.sort(key=lambda x: x["percentage"])

        # 5. Review Correction Requests
        cr_qs = AttendanceCorrectionRequest.objects.all()
        if dept:
            cr_qs = cr_qs.filter(
                Q(student__department=dept) |
                Q(faculty__department=dept)
            )
        correction_requests = [
            {
                "id": cr.id,
                "student_usn": cr.student.usn,
                "student_name": cr.student.name,
                "faculty_name": cr.faculty.name if cr.faculty else "N/A",
                "requested_status": cr.requested_status,
                "reason": cr.reason,
                "remarks": cr.remarks,
                "status": cr.status,
                "created_at": cr.created_at.strftime("%Y-%m-%d %H:%M"),
                "reviewed_at": cr.reviewed_at.strftime("%Y-%m-%d %H:%M") if cr.reviewed_at else None,
            }
            for cr in cr_qs[:30]
        ]

        unassigned_count = sum(1 for s in subject_stats if s["status"] == "UNASSIGNED")

        return Response({
            "department_info": {
                "id": dept.id if dept else 0,
                "name": dept.name if dept else "All Departments (Campus-Wide)",
                "user_email": getattr(request.user, "email", "HOD"),
                "role": user_role,
            },
            "overview": {
                "total_students": total_students,
                "total_faculty": total_faculty,
                "avg_dept_attendance": avg_dept_attendance,
                "low_attendance_count": len(low_attendance_students),
                "pending_corrections": cr_qs.filter(status="PENDING").count(),
                "unassigned_subjects_count": unassigned_count,
                "total_subjects": len(subject_stats),
            },
            "subjects": subject_stats,
            "submissions": submissions,
            "low_attendance_students": low_attendance_students,
            "correction_requests": correction_requests,
        })


# ==========================================
# 4. Student-Level Attendance for a Subject
# ==========================================
class SubjectStudentAttendanceView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        subject_id = request.query_params.get("subject_id")
        if not subject_id:
            return Response({"error": "subject_id parameter is required"}, status=status.HTTP_400_BAD_REQUEST)

        subject = get_object_or_404(Subject, id=subject_id)
        sessions = AttendanceSession.objects.filter(subject=subject)
        total_sessions = sessions.count()

        # Find eligible students
        assignment = SubjectAssignment.objects.filter(subject=subject).first()
        target_dept = (assignment.department or subject.department) if assignment else subject.department
        target_sem = (assignment.semester or subject.semester) if assignment else subject.semester

        students = Student.objects.filter(status__iexact="active")
        if target_dept:
            students = students.filter(department=target_dept)
        if target_sem:
            students = students.filter(semester=target_sem)

        student_list = []
        for st in students.order_by("usn"):
            records = AttendanceRecord.objects.filter(session__subject=subject, student=st)
            attended = records.filter(status="Present").count()
            missed = total_sessions - attended if total_sessions >= attended else 0
            pct = round((attended / total_sessions * 100), 1) if total_sessions > 0 else None

            if total_sessions == 0:
                st_label = "No Sessions"
            elif pct is not None and pct >= 75.0:
                st_label = "Healthy"
            else:
                st_label = "Shortage (<75%)"

            student_list.append({
                "student_id": st.id,
                "usn": st.usn,
                "name": st.name,
                "total_classes": total_sessions,
                "attended_classes": attended,
                "missed_classes": missed,
                "percentage": pct,
                "status": st_label,
            })

        return Response({
            "subject_code": subject.subject_code,
            "subject_name": subject.subject_name,
            "total_sessions": total_sessions,
            "students": student_list,
        })


# ==========================================
# 5. Review Attendance Correction Request
# ==========================================
class AttendanceCorrectionReviewView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk, *args, **kwargs):
        cr = get_object_or_404(AttendanceCorrectionRequest, id=pk)
        action_type = (request.data.get("action") or "").upper()
        remarks = request.data.get("remarks", "")

        if action_type not in ["APPROVE", "REJECT"]:
            return Response({"error": "action must be APPROVE or REJECT"}, status=status.HTTP_400_BAD_REQUEST)

        cr.remarks = remarks
        cr.reviewed_by = request.user
        cr.reviewed_at = timezone.now()

        if action_type == "APPROVE":
            cr.status = "APPROVED"
            cr.save()

            if cr.record:
                cr.record.status = cr.requested_status
                cr.record.save(update_fields=["status"])
            elif cr.session:
                AttendanceRecord.objects.update_or_create(
                    session=cr.session,
                    student=cr.student,
                    defaults={"status": cr.requested_status}
                )
            return Response({"message": "Correction request approved and attendance record updated."})
        else:
            cr.status = "REJECTED"
            cr.save()
            return Response({"message": "Correction request rejected."})