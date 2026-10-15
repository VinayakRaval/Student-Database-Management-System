from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from django.db import transaction
from .models import TimeTable, TimeTableSlot, TimeTableApprovalHistory
from .serializers import TimeTableSerializer, FacultyScheduleSerializer
from .permissions import IsHOD, IsPrincipal, IsPrincipalOrHOD
from subjects.models import SubjectAssignment

def time_overlap(a_start, a_end, b_start, b_end):
    return (a_start < b_end) and (a_end > b_start)


def _resolve_faculty_for_user(user):
    if not user or not user.is_authenticated:
        return None
    from faculty.models import Faculty
    if hasattr(user, "faculty_profile") and user.faculty_profile:
        return user.faculty_profile
    fac = Faculty.objects.filter(user=user).first()
    if fac:
        return fac
    if getattr(user, "user_id", None):
        fac = Faculty.objects.filter(faculty_id=user.user_id).first()
        if fac:
            if not fac.user:
                fac.user = user
                fac.save(update_fields=["user"])
            return fac
    if getattr(user, "email", None):
        for f in Faculty.objects.all():
            if f.email and f.email.lower() == user.email.lower():
                if not f.user:
                    f.user = user
                    f.save(update_fields=["user"])
                return f
    return None


def _resolve_department_for_user(user):
    if not user or not user.is_authenticated:
        return None
    dept = getattr(user, "department", None)
    if dept:
        return dept
    from hod_assignment.models import HODAssignment
    hod_assign = HODAssignment.objects.filter(faculty__user=user, end_date__isnull=True).first()
    if not hod_assign:
        fac = _resolve_faculty_for_user(user)
        if fac:
            hod_assign = HODAssignment.objects.filter(faculty=fac, end_date__isnull=True).first()
    if hod_assign:
        user.department = hod_assign.department
        user.save(update_fields=["department"])
        return hod_assign.department
    fac = _resolve_faculty_for_user(user)
    if fac and fac.department:
        user.department = fac.department
        user.save(update_fields=["department"])
        return fac.department
    return None


class TimeTableViewSet(viewsets.ModelViewSet):
    queryset = TimeTable.objects.all().prefetch_related("slots")
    serializer_class = TimeTableSerializer

    def get_queryset(self):
        user = self.request.user
        if not user or not user.is_authenticated:
            return TimeTable.objects.none()

        user_role = (getattr(user, "role", "") or "").upper()
        if user.is_superuser or user_role in ["SYSTEM", "PRINCIPAL"]:
            return TimeTable.objects.all().prefetch_related("slots")

        if user_role in ["HOD", "HEAD OF DEPARTMENT"]:
            dept = _resolve_department_for_user(user)
            if dept:
                return TimeTable.objects.filter(department=dept).prefetch_related("slots")
            return TimeTable.objects.all().prefetch_related("slots")

        if user_role == "PROFESSOR":
            fac = _resolve_faculty_for_user(user)
            if fac:
                return TimeTable.objects.filter(slots__assignment__faculty=fac, is_active=True).distinct().prefetch_related("slots")
            return TimeTable.objects.none()

        if user_role == "STUDENT":
            student = getattr(user, "student", None)
            if not student:
                from students.models import Student
                student = Student.objects.filter(user=user).first()
            if student:
                qs = TimeTable.objects.filter(department=student.department, semester=student.semester, is_active=True)
                if student.academic_year:
                    qs = qs.filter(academic_year=student.academic_year)
                return qs.prefetch_related("slots")
            return TimeTable.objects.none()

        return TimeTable.objects.all().prefetch_related("slots")

    def get_permissions(self):
        if self.action in ("create", "update", "partial_update", "destroy", "hod", "assignments"):
            return [IsAuthenticated(), IsHOD()]
        if self.action in ("approve", "pending"):
            return [IsAuthenticated(), IsPrincipalOrHOD()]
        return [IsAuthenticated()]

    # --- 1. Assignments Dropdown (Fix: Filter by academic_year_id) ---
    @action(detail=False, methods=["get"])
    def assignments(self, request):
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role in ["HOD", "HEAD OF DEPARTMENT"]:
            dept = _resolve_department_for_user(request.user)
        else:
            dept_id = request.query_params.get("department_id") or request.query_params.get("department")
            dept = None
            if dept_id:
                try:
                    from academics.models import Department
                    dept = Department.objects.filter(pk=dept_id).first()
                except Exception:
                    dept = None
            if not dept:
                dept = _resolve_department_for_user(request.user)

        qs = SubjectAssignment.objects.all()
        if dept:
            from django.db.models import Q
            qs = qs.filter(Q(department=dept) | Q(subject__department=dept))

        semester = request.query_params.get("semester")
        ay = request.query_params.get("academic_year")

        if semester:
            from django.db.models import Q
            qs = qs.filter(
                Q(semester__id=semester) | Q(semester__sem_number=semester) |
                Q(subject__semester__id=semester) | Q(subject__semester__sem_number=semester)
            )

        if ay:
            from django.db.models import Q
            qs = qs.filter(Q(academic_year_id=ay) | Q(academic_year__year_name=ay))

        data = [{
            "id": a.id,
            "subject_code": getattr(getattr(a, "subject", None), "subject_code", ""),
            "subject_name": getattr(getattr(a, "subject", None), "subject_name", ""),
            "faculty_id": getattr(getattr(a, "faculty", None), "id", None),
            "faculty_name": getattr(getattr(a, "faculty", None), "name", ""),
            "semester": getattr(a.semester, "sem_number", None) or getattr(getattr(getattr(a, "subject", None), "semester", None), "sem_number", None),
            "academic_year": getattr(getattr(a, "academic_year", None), "year_name", None),
        } for a in qs.select_related("subject", "faculty", "semester", "academic_year")]
        return Response(data)

    def perform_create(self, serializer):
        user = self.request.user
        user_role = (getattr(user, "role", "") or "").upper()
        if user_role in ["HOD", "HEAD OF DEPARTMENT"]:
            dept = _resolve_department_for_user(user)
            if dept:
                serializer.save(created_by=user, department=dept, status="Pending")
                return
        serializer.save(created_by=user, status="Pending")

    def create(self, request, *args, **kwargs):
        user = request.user
        user_role = (getattr(user, "role", "") or "").upper()
        if user_role in ["HOD", "HEAD OF DEPARTMENT"]:
            dept = _resolve_department_for_user(user)
            if not dept:
                return Response(
                    {"error": "You do not have a department assigned to your HOD profile."},
                    status=status.HTTP_403_FORBIDDEN
                )
            dept_id = request.data.get("department")
            if dept_id and str(dept_id) != str(dept.id):
                return Response(
                    {"error": f"You are the HOD of {dept.name}. You cannot create a timetable for another department."},
                    status=status.HTTP_403_FORBIDDEN
                )
            payload = request.data.copy() if hasattr(request.data, 'copy') else dict(request.data)
            payload["department"] = dept.id
            serializer = self.get_serializer(data=payload)
            serializer.is_valid(raise_exception=True)
            self.perform_create(serializer)
            headers = self.get_success_headers(serializer.data)
            return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)
        return super().create(request, *args, **kwargs)

    def update(self, request, *args, **kwargs):
        user = request.user
        user_role = (getattr(user, "role", "") or "").upper()
        if user_role in ["HOD", "HEAD OF DEPARTMENT"]:
            tt = self.get_object()
            dept = _resolve_department_for_user(user)
            if dept and tt.department_id != dept.id:
                return Response(
                    {"error": f"You are the HOD of {dept.name}. You cannot modify timetables for another department."},
                    status=status.HTTP_403_FORBIDDEN
                )
            dept_id = request.data.get("department")
            if dept_id and str(dept_id) != str(dept.id):
                return Response(
                    {"error": "You cannot change the timetable department to another department."},
                    status=status.HTTP_403_FORBIDDEN
                )
        return super().update(request, *args, **kwargs)

    def destroy(self, request, *args, **kwargs):
        user = request.user
        user_role = (getattr(user, "role", "") or "").upper()
        if user_role in ["HOD", "HEAD OF DEPARTMENT"]:
            tt = self.get_object()
            dept = _resolve_department_for_user(user)
            if dept and tt.department_id != dept.id:
                return Response(
                    {"error": "You cannot delete timetables from another department."},
                    status=status.HTTP_403_FORBIDDEN
                )
        return super().destroy(request, *args, **kwargs)

    # --- 2. Approval Logic ---
    @action(detail=True, methods=["post"])
    @transaction.atomic
    def approve(self, request, pk=None):
        tt = self.get_object()
        action = request.data.get("action")
        remarks = request.data.get("remarks", "")
        override = request.data.get("override", False)

        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            if dept and tt.department_id != dept.id:
                return Response({"error": "You can only approve or reject timetables for your department."}, status=status.HTTP_403_FORBIDDEN)

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

    # --- 3. My Schedule (Returns list of slots for logged-in Faculty / HOD) ---
    @action(detail=False, methods=["get"])
    def my_schedule(self, request):
        faculty = _resolve_faculty_for_user(request.user)
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        if not faculty:
            return Response({"error": "Faculty profile not found for user."}, status=status.HTTP_404_NOT_FOUND)

        from django.db.models import Q

        # 1. Collect relevant timetables:
        # Active timetables
        active_tt_ids = set(TimeTable.objects.filter(is_active=True).values_list("id", flat=True))

        # Include latest non-rejected timetable for semesters with no active timetable yet
        all_non_rejected = TimeTable.objects.exclude(status="Rejected")
        distinct_semesters = all_non_rejected.values_list("department_id", "semester_id").distinct()
        for dept_id, sem_id in distinct_semesters:
            if not TimeTable.objects.filter(department_id=dept_id, semester_id=sem_id, is_active=True).exists():
                latest = TimeTable.objects.filter(department_id=dept_id, semester_id=sem_id).exclude(status="Rejected").order_by("-id").first()
                if latest:
                    active_tt_ids.add(latest.id)

        # 2. Get slots specifically assigned to THIS faculty profile
        slots = TimeTableSlot.objects.filter(
            assignment__faculty=faculty,
            timetable_id__in=active_tt_ids
        ).select_related(
            "assignment__faculty",
            "assignment__subject",
            "assignment__subject__department",
            "timetable__department",
            "timetable__semester"
        ).order_by("day", "start_time")

        # 3. Optional filters: semester and search
        sem_param = request.query_params.get("semester")
        if sem_param:
            slots = slots.filter(
                Q(timetable__semester_id=sem_param) |
                Q(timetable__semester__sem_number=sem_param) |
                Q(assignment__semester_id=sem_param) |
                Q(assignment__subject__semester_id=sem_param)
            )

        search_param = request.query_params.get("search")
        if search_param:
            slots = slots.filter(
                Q(assignment__subject__subject_name__icontains=search_param) |
                Q(assignment__subject__subject_code__icontains=search_param) |
                Q(day__icontains=search_param)
            )

        serializer = FacultyScheduleSerializer(slots, many=True)
        slot_list = list(serializer.data)

        # 4. Fetch all subjects assigned to this faculty member
        assigned_qs = SubjectAssignment.objects.filter(faculty=faculty).select_related(
            "subject", "subject__department", "subject__semester", "semester", "academic_year"
        )
        if sem_param:
            assigned_qs = assigned_qs.filter(
                Q(semester_id=sem_param) |
                Q(semester__sem_number=sem_param) |
                Q(subject__semester_id=sem_param)
            )
        if search_param:
            assigned_qs = assigned_qs.filter(
                Q(subject__subject_name__icontains=search_param) |
                Q(subject__subject_code__icontains=search_param)
            )

        assigned_subjects = []
        for a in assigned_qs:
            sem_num = getattr(a.semester, "sem_number", None) or getattr(getattr(a.subject, "semester", None), "sem_number", None)
            sched_count = slots.filter(assignment=a).count()
            assigned_subjects.append({
                "assignment_id": a.id,
                "subject_id": a.subject.id,
                "subject_code": a.subject.subject_code,
                "subject_name": a.subject.subject_name,
                "semester": sem_num,
                "department": getattr(a.department or a.subject.department, "name", ""),
                "academic_year": getattr(a.academic_year, "year_name", ""),
                "slots_count": sched_count,
            })

        return Response({
            "results": slot_list,
            "slots": slot_list,
            "assigned_subjects": assigned_subjects,
            "faculty_name": faculty.name,
            "faculty_id": faculty.faculty_id
        }, status=status.HTTP_200_OK)

    # --- 4. Role specific lists ---
    @action(detail=False, methods=["get"])
    def pending(self, request):
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            qs = TimeTable.objects.filter(status="Pending", department=dept) if dept else TimeTable.objects.none()
        else:
            qs = TimeTable.objects.filter(status="Pending")
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=["get"])
    def faculty(self, request):
        faculty = _resolve_faculty_for_user(request.user)
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        if not faculty:
            if user_role in ["SYSTEM", "PRINCIPAL"] or request.user.is_superuser:
                qs = TimeTable.objects.filter(is_active=True)
            else:
                return Response({"error": "Faculty profile not found for user."}, status=status.HTTP_404_NOT_FOUND)
        else:
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
            from students.models import Student
            student = Student.objects.filter(user=user).first()
        if not student:
            return Response({"error": "User not a student"}, status=status.HTTP_403_FORBIDDEN)
        qs = TimeTable.objects.filter(
            department=student.department,
            semester=student.semester,
            is_active=True
        )
        if student.academic_year:
            qs = qs.filter(academic_year=student.academic_year)
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=["get"])
    def hod(self, request):
        dept = _resolve_department_for_user(request.user)
        if not dept:
            user_role = (getattr(request.user, "role", "") or "").upper()
            if request.user.is_superuser or user_role in ["SYSTEM", "PRINCIPAL"]:
                qs = TimeTable.objects.all()
            else:
                return Response({"error": "User is not HOD or has no department assigned"}, status=403)
        else:
            qs = TimeTable.objects.filter(department=dept)

        semester = request.query_params.get("semester")
        academic_year = request.query_params.get("academic_year")

        if semester:
            from django.db.models import Q
            qs = qs.filter(Q(semester__id=semester) | Q(semester__sem_number=semester))
        if academic_year:
            from django.db.models import Q
            qs = qs.filter(Q(academic_year_id=academic_year) | Q(academic_year__year_name=academic_year))

        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)
