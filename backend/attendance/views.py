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
#  CORE APP VIEWSET (Faculty & Student App)
# ==========================================
class AttendanceViewSet(viewsets.ModelViewSet):
    queryset = AttendanceSession.objects.all()
    # Use the Bulk Create serializer for writes, standard for reads if needed
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

        try:
            slot = TimeTableSlot.objects.select_related(
                'assignment__subject__department', 
                'assignment__subject__semester',
                'assignment__subject__academic_year'
            ).get(id=slot_id)
            
            # Fetch students belonging to the Subject's Dept, Semester & Academic Year
            students = Student.objects.filter(
                department=slot.assignment.subject.department,
                semester=slot.assignment.subject.semester,
                # Assuming Student model has academic_year, otherwise remove this line
                academic_year=slot.assignment.subject.academic_year, 
                status__iexact='active' 
            ).order_by('usn')

            data = [
                {
                    "id": s.id,
                    "name": s.name,
                    "usn": getattr(s, 'usn', ''),
                    "is_selected": True # Default checkbox state for UI
                } 
                for s in students
            ]
            
            return Response(data)

        except TimeTableSlot.DoesNotExist:
            return Response({"error": "Invalid Slot ID"}, status=404)

    # --- 2. Faculty: Mark Attendance (Bulk Create) ---
    def create(self, request, *args, **kwargs):
        """
        Override create to use the Bulk Serializer.
        Payload: { "timetable_slot": 1, "date": "2023-10-27", "records": [...] }
        """
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        return Response({"message": "Attendance marked successfully!"}, status=status.HTTP_201_CREATED)

    # --- 3. Student: View My Stats (Percentage per Subject) ---
    @action(detail=False, methods=['get'])
    def my_stats(self, request):
        """
        Returns attendance percentage per subject for the logged-in student.
        """
        try:
            # Adjust based on how you link User -> Student
            student = request.user.student_profile 
        except AttributeError:
             return Response({"error": "User is not a student"}, status=403)

        # Aggregate data: Group by Subject
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
        records = AttendanceRecord.objects.filter(student=student).select_related('session', 'session__subject')

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