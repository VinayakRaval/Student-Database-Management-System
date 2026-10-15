from rest_framework import viewsets, status, generics
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Count, Q
from django.shortcuts import get_object_or_404

from .models import AttendanceSession, AttendanceRecord
from .serializers import AttendanceSessionCreateSerializer, AttendanceSessionSerializer
from students.models import Student
from timetable.models import TimeTableSlot
from subjects.models import Subject

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