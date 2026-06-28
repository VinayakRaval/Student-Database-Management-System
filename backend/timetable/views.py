from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from django.db import transaction
from .models import TimeTable, TimeTableSlot, TimeTableApprovalHistory
from .serializers import TimeTableSerializer, FacultyScheduleSerializer
from .permissions import IsHOD, IsPrincipal
from subjects.models import SubjectAssignment

def time_overlap(a_start, a_end, b_start, b_end):
    return (a_start < b_end) and (a_end > b_start)

class TimeTableViewSet(viewsets.ModelViewSet):
    queryset = TimeTable.objects.all().prefetch_related("slots")
    serializer_class = TimeTableSerializer

    def get_permissions(self):
        if self.action in ("create", "hod", "assignments"):
            return [IsAuthenticated(), IsHOD()]
        if self.action in ("approve", "pending"):
            return [IsAuthenticated(), IsPrincipal()]
        return [IsAuthenticated()]

    # --- 1. Assignments Dropdown (Fix: Filter by academic_year_id) ---
    @action(detail=False, methods=["get"])
    def assignments(self, request):
        dept = getattr(request.user, "department", None)
        qs = SubjectAssignment.objects.all()
        if dept:
            qs = qs.filter(department=dept)
        
        semester = request.query_params.get("semester")
        ay = request.query_params.get("academic_year")
        
        if semester:
            qs = qs.filter(semester__id=semester)

        if ay:
            # FIX: Filter by ID, not label
            qs = qs.filter(academic_year_id=ay) 
            
        data = [{
            "id": a.id,
            "subject_code": a.subject.subject_code,
            "subject_name": a.subject.subject_name,
            "faculty_id": getattr(a.faculty, "id", None),
            "faculty_name": getattr(a.faculty, "name", ""), # Fix name
            "semester": getattr(a.semester, "sem_number", None),
            "academic_year": getattr(a.academic_year, "year_name", None),
        } for a in qs.select_related("subject", "faculty", "semester", "academic_year")]
        return Response(data)

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user, status="Pending")

    # --- 2. Approval Logic ---
    @action(detail=True, methods=["post"])
    @transaction.atomic
    def approve(self, request, pk=None):
        tt = self.get_object()
        action = request.data.get("action")
        remarks = request.data.get("remarks", "")
        override = request.data.get("override", False)

        if action not in ("Approved", "Rejected"):
            return Response({"error": "action must be 'Approved' or 'Rejected'."}, status=status.HTTP_400_BAD_REQUEST)

        if action == "Rejected":
            tt.status = "Rejected"
            tt.approved_by = request.user
            tt.approved_at = timezone.now()
            tt.remarks = remarks
            tt.is_active = False
            tt.save()
            TimeTableApprovalHistory.objects.create(timetable=tt, action="Rejected", remarks=remarks, action_by=request.user)
            return Response({"message": "Timetable rejected."})

        # Check conflicts
        conflicts = []
        target_slots = list(tt.slots.all().select_related("assignment__faculty"))
        other_active_slots = TimeTableSlot.objects.filter(
            timetable__academic_year=tt.academic_year,
            timetable__is_active=True
        ).exclude(timetable=tt).select_related("assignment__faculty", "timetable")

        for s in target_slots:
            fac = s.assignment.faculty
            overlapping = other_active_slots.filter(day=s.day, assignment__faculty=fac)
            for oslot in overlapping:
                if time_overlap(s.start_time, s.end_time, oslot.start_time, oslot.end_time):
                    conflicts.append({
                        "type": "FacultyConflict",
                        "faculty_id": fac.id,
                        "faculty_name": fac.name,
                        "slot": {
                            "timetable_id": oslot.timetable.id,
                            "day": oslot.day,
                            "start_time": oslot.start_time,
                            "end_time": oslot.end_time,
                            "subject": oslot.assignment.subject.subject_name
                        },
                        "new_slot": {
                            "day": s.day,
                            "start_time": s.start_time,
                            "end_time": s.end_time,
                            "subject": s.assignment.subject.subject_name
                        }
                    })

        if conflicts and not override:
            return Response({"error": "Conflicts found", "conflicts": conflicts}, status=status.HTTP_409_CONFLICT)

        # Deactivate previous active timetables for same Dept/Sem
        TimeTable.objects.filter(
            department=tt.department,
            semester=tt.semester,
            is_active=True
        ).exclude(pk=tt.pk).update(is_active=False, status="Rejected")

        tt.status = "Approved"
        tt.approved_by = request.user
        tt.approved_at = timezone.now()
        tt.remarks = remarks
        tt.is_active = True
        tt.save()

        TimeTableApprovalHistory.objects.create(timetable=tt, action="Approved", remarks=remarks, action_by=request.user)
        return Response({"message": "Timetable approved and activated."})

    # --- 3. My Schedule (NEW: Returns list of slots for logged-in Faculty) ---
    @action(detail=False, methods=["get"])
    def my_schedule(self, request):
        try:
            # Adjust 'faculty_profile' if your User model link name is different
            from faculty.models import Faculty
            faculty = Faculty.objects.get(email=request.user.email)
        except Faculty.DoesNotExist:
            return Response({"error": "Faculty profile not found."}, status=404)

        slots = TimeTableSlot.objects.filter(
            assignment__faculty=faculty,
            timetable__is_active=True
        ).select_related(
            "assignment__subject", 
            "assignment__subject__department"
        ).order_by("day", "start_time")

        serializer = FacultyScheduleSerializer(slots, many=True)
        return Response(serializer.data)

    # --- 4. Role specific lists ---
    @action(detail=False, methods=["get"])
    def pending(self, request):
        qs = TimeTable.objects.filter(status="Pending")
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=["get"])
    def faculty(self, request):
        # NOTE: This returns FULL timetables related to faculty, 
        # use 'my_schedule' for the slot list view.
        faculty = getattr(request.user, "faculty_profile", None)
        if not faculty or faculty.role != "Professor":
            return Response({"error": "User is not a professor"}, status=403)

        qs = TimeTable.objects.filter(
            slots__assignment__faculty=faculty,
            is_active=True
        ).distinct()

        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=["get"])
    def student(self, request):
        user = request.user
        student = getattr(user, "student", None)
        if not student:
            return Response({"error": "User not a student"}, status=status.HTTP_403_FORBIDDEN)
        qs = TimeTable.objects.filter(
            department=student.department,
            semester=student.semester,
            academic_year=student.academic_year,
            is_active=True
        )
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=["get"])
    def hod(self, request):
        dept = getattr(request.user, "department", None)
        if not dept:
            return Response({"error": "User is not HOD or has no department"}, status=403)

        qs = TimeTable.objects.filter(department=dept)

        semester = request.query_params.get("semester")
        academic_year = request.query_params.get("academic_year")

        if semester:
            qs = qs.filter(semester__id=semester)
        if academic_year:
            qs = qs.filter(academic_year_id=academic_year)

        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)