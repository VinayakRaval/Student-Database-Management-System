from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from django.db import transaction
from .models import TimeTable, TimeTableSlot, TimeTableSlotBatch, TimeTableApprovalHistory
from .serializers import TimeTableSerializer, FacultyScheduleSerializer
from .permissions import IsHOD, IsPrincipal, IsPrincipalOrHOD
from subjects.models import SubjectAssignment

def time_overlap(a_start, a_end, b_start, b_end):
    s_a = str(a_start)[:5]
    e_a = str(a_end)[:5]
    s_b = str(b_start)[:5]
    e_b = str(b_end)[:5]
    return (s_a < e_b) and (e_a > s_b)


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
    queryset = TimeTable.objects.all().prefetch_related(
        "slots__batches__assignment__faculty",
        "slots__batches__assignment__subject",
        "slots__assignment__faculty",
        "slots__assignment__subject"
    )
    serializer_class = TimeTableSerializer

    def get_queryset(self):
        user = self.request.user
        if not user or not user.is_authenticated:
            return TimeTable.objects.none()

        user_role = (getattr(user, "role", "") or "").upper()
        prefetch_args = (
            "slots__batches__assignment__faculty",
            "slots__batches__assignment__subject",
            "slots__assignment__faculty",
            "slots__assignment__subject",
        )

        if user.is_superuser or user_role in ["SYSTEM", "PRINCIPAL"]:
            return TimeTable.objects.all().prefetch_related(*prefetch_args)

        if user_role in ["HOD", "HEAD OF DEPARTMENT"]:
            dept = _resolve_department_for_user(user)
            if dept:
                return TimeTable.objects.filter(department=dept).prefetch_related(*prefetch_args)
            return TimeTable.objects.none()

        if user_role == "PROFESSOR":
            fac = _resolve_faculty_for_user(user)
            if fac:
                from django.db.models import Q
                return TimeTable.objects.filter(
                    Q(slots__assignment__faculty=fac) | Q(slots__batches__assignment__faculty=fac),
                    is_active=True
                ).distinct().prefetch_related(*prefetch_args)
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
                return qs.prefetch_related(*prefetch_args)
            return TimeTable.objects.none()

        return TimeTable.objects.all().prefetch_related(*prefetch_args)

    def get_permissions(self):
        if self.action in ("create", "update", "partial_update", "destroy", "hod", "assignments"):
            return [IsAuthenticated(), IsHOD()]
        if self.action in ("approve", "pending"):
            return [IsAuthenticated(), IsPrincipalOrHOD()]
        return [IsAuthenticated()]

    # --- 1. Assignments Dropdown ---
    @action(detail=False, methods=["get"])
    def assignments(self, request):
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role in ["HOD", "HEAD OF DEPARTMENT"]:
            dept = _resolve_department_for_user(request.user)
            if not dept:
                return Response([])
            from django.db.models import Q
            qs = SubjectAssignment.objects.filter(Q(department=dept) | Q(subject__department=dept))
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
            "subject_department": getattr(getattr(getattr(a, "subject", None), "department", None), "name", ""),
            "student_department": getattr(getattr(a, "department", None), "name", ""),
            "faculty_id": getattr(getattr(a, "faculty", None), "id", None),
            "faculty_name": getattr(getattr(a, "faculty", None), "name", "No faculty assigned"),
            "faculty_employee_id": getattr(getattr(a, "faculty", None), "faculty_id", ""),
            "faculty_role": getattr(getattr(a, "faculty", None), "role", ""),
            "has_theory": getattr(getattr(a, "subject", None), "has_theory", True),
            "has_lab": getattr(getattr(a, "subject", None), "has_lab", False),
            "subject_type": getattr(getattr(a, "subject", None), "subject_type", "THEORY"),
            "credits": getattr(getattr(a, "subject", None), "credits", 4),
            "theory_hours": getattr(getattr(a, "subject", None), "theory_hours", 3),
            "tutorial_hours": getattr(getattr(a, "subject", None), "tutorial_hours", 0),
            "practical_hours": getattr(getattr(a, "subject", None), "practical_hours", 0),
            "practical_sessions": getattr(getattr(a, "subject", None), "practical_sessions", 0),
            "practical_duration_per_session": getattr(getattr(a, "subject", None), "practical_duration_per_session", 0),
            "practical_display": getattr(getattr(a, "subject", None), "practical_display", str(getattr(getattr(a, "subject", None), "practical_hours", 0))),
            "total_teaching_hours": getattr(getattr(a, "subject", None), "total_teaching_hours", 3),
            "semester": getattr(a.semester, "sem_number", None) or getattr(getattr(getattr(a, "subject", None), "semester", None), "sem_number", None),
            "academic_year": getattr(getattr(a, "academic_year", None), "year_name", None),
        } for a in qs.select_related("subject", "subject__department", "faculty", "department", "semester", "academic_year")]
        return Response(data)

    def perform_create(self, serializer):
        user = self.request.user
        user_role = (getattr(user, "role", "") or "").upper()
        if user_role in ["HOD", "HEAD OF DEPARTMENT"]:
            dept = _resolve_department_for_user(user)
            if dept:
                serializer.save(created_by=user, department=dept, status="Approved", is_active=True)
                return
        serializer.save(created_by=user, status="Approved", is_active=True)

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
            if not dept or tt.department_id != dept.id:
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
            if not dept or tt.department_id != dept.id:
                return Response(
                    {"error": "You cannot delete timetables from another department."},
                    status=status.HTTP_403_FORBIDDEN
                )
        return super().destroy(request, *args, **kwargs)

    # --- 2. Approval Logic (Validates conflicts including batch slots & co-teaching) ---
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
            if not dept or tt.department_id != dept.id:
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

        # Check conflicts across other active timetables
        conflicts = []
        target_sessions = []
        for s in tt.slots.all().prefetch_related("batches__assignment__faculty", "batches__assignment__subject", "assignment__faculty", "assignment__subject"):
            if s.is_batch_wise and s.batches.exists():
                for b in s.batches.all():
                    if b.assignment and b.assignment.faculty:
                        target_sessions.append({
                            "faculty": b.assignment.faculty,
                            "day": s.day,
                            "start_time": b.start_time or s.start_time,
                            "end_time": b.end_time or s.end_time,
                            "allow_co_teaching": b.allow_co_teaching or s.allow_co_teaching,
                            "subject": b.assignment.subject.subject_name if b.assignment.subject else "Lab",
                            "batch_name": b.batch_name,
                            "lab_room": b.lab_room,
                        })
            elif s.assignment and s.assignment.faculty:
                target_sessions.append({
                    "faculty": s.assignment.faculty,
                    "day": s.day,
                    "start_time": s.start_time,
                    "end_time": s.end_time,
                    "allow_co_teaching": s.allow_co_teaching,
                    "subject": s.assignment.subject.subject_name if s.assignment.subject else "Class",
                    "batch_name": s.batch_name or "",
                    "lab_room": s.lab_room,
                })

        other_active_timetables = TimeTable.objects.filter(
            academic_year=tt.academic_year,
            is_active=True
        ).exclude(pk=tt.pk).prefetch_related(
            "slots__batches__assignment__faculty",
            "slots__batches__assignment__subject",
            "slots__assignment__faculty",
            "slots__assignment__subject"
        )

        other_sessions = []
        for other_tt in other_active_timetables:
            for s in other_tt.slots.all():
                if s.is_batch_wise and s.batches.exists():
                    for b in s.batches.all():
                        if b.assignment and b.assignment.faculty:
                            other_sessions.append({
                                "timetable_id": other_tt.id,
                                "faculty": b.assignment.faculty,
                                "day": s.day,
                                "start_time": b.start_time or s.start_time,
                                "end_time": b.end_time or s.end_time,
                                "allow_co_teaching": b.allow_co_teaching or s.allow_co_teaching,
                                "subject": b.assignment.subject.subject_name if b.assignment.subject else "Lab",
                                "batch_name": b.batch_name,
                            })
                elif s.assignment and s.assignment.faculty:
                    other_sessions.append({
                        "timetable_id": other_tt.id,
                        "faculty": s.assignment.faculty,
                        "day": s.day,
                        "start_time": s.start_time,
                        "end_time": s.end_time,
                        "allow_co_teaching": s.allow_co_teaching,
                        "subject": s.assignment.subject.subject_name if s.assignment.subject else "Class",
                        "batch_name": s.batch_name or "",
                    })

        for ts in target_sessions:
            fac = ts["faculty"]
            for os in other_sessions:
                if os["faculty"].id == fac.id and os["day"] == ts["day"]:
                    if time_overlap(ts["start_time"], ts["end_time"], os["start_time"], os["end_time"]):
                        # Check co-teaching permission
                        if not (ts["allow_co_teaching"] and os["allow_co_teaching"]):
                            conflicts.append({
                                "type": "FacultyConflict",
                                "faculty_id": fac.id,
                                "faculty_name": fac.name,
                                "slot": {
                                    "timetable_id": os["timetable_id"],
                                    "day": os["day"],
                                    "start_time": str(os["start_time"]),
                                    "end_time": str(os["end_time"]),
                                    "subject": os["subject"],
                                    "batch_name": os.get("batch_name", ""),
                                },
                                "new_slot": {
                                    "day": ts["day"],
                                    "start_time": str(ts["start_time"]),
                                    "end_time": str(ts["end_time"]),
                                    "subject": ts["subject"],
                                    "batch_name": ts.get("batch_name", ""),
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
        # Use approved timetables as the source of truth, and include active ones
        active_tt_ids = set(TimeTable.objects.filter(Q(is_active=True) | Q(status="Approved")).exclude(status="Rejected").values_list("id", flat=True))

        all_non_rejected = TimeTable.objects.exclude(status="Rejected")
        distinct_semesters = all_non_rejected.values_list("department_id", "semester_id").distinct()
        for dept_id, sem_id in distinct_semesters:
            if not TimeTable.objects.filter(department_id=dept_id, semester_id=sem_id, is_active=True).exists():
                latest = TimeTable.objects.filter(department_id=dept_id, semester_id=sem_id).exclude(status="Rejected").order_by("-id").first()
                if latest:
                    active_tt_ids.add(latest.id)

        dept = _resolve_department_for_user(request.user)
        is_personal = (request.query_params.get("personal", "")).lower() in ["true", "1"]

        # 2. Get slots: personal shows only slots assigned to this faculty (direct or via batch)
        if user_role in ["HOD", "HEAD OF DEPARTMENT"] and dept and not is_personal:
            slots = TimeTableSlot.objects.filter(
                Q(timetable__department=dept) | Q(assignment__department=dept) | Q(assignment__faculty=faculty) | Q(batches__assignment__faculty=faculty),
                timetable_id__in=active_tt_ids
            ).distinct().select_related(
                "assignment__faculty",
                "assignment__subject",
                "assignment__subject__department",
                "timetable__department",
                "timetable__semester"
            ).prefetch_related(
                "batches__assignment__faculty",
                "batches__assignment__subject"
            ).order_by("day", "start_time")
        else:
            slots = TimeTableSlot.objects.filter(
                Q(assignment__faculty=faculty) | Q(batches__assignment__faculty=faculty),
                timetable_id__in=active_tt_ids
            ).distinct().select_related(
                "assignment__faculty",
                "assignment__subject",
                "assignment__subject__department",
                "timetable__department",
                "timetable__semester"
            ).prefetch_related(
                "batches__assignment__faculty",
                "batches__assignment__subject"
            ).order_by("day", "start_time")

        # 3. Optional filters: semester, search, and faculty
        sem_param = request.query_params.get("semester")
        if sem_param:
            # Enforce strict semester filtering on the timetable and slot level
            if str(sem_param).isdigit():
                sem_int = int(sem_param)
                slots = slots.filter(
                    Q(timetable__semester__sem_number=sem_int) |
                    Q(timetable__semester_id=sem_int)
                ).distinct()
            else:
                slots = slots.filter(
                    Q(timetable__semester__sem_number=sem_param) |
                    Q(timetable__semester_id=sem_param)
                ).distinct()

        ay_param = request.query_params.get("academic_year") or request.query_params.get("academic_year_id")
        if ay_param and str(ay_param).lower() != "all":
            if str(ay_param).isdigit():
                slots = slots.filter(
                    Q(timetable__academic_year_id=ay_param) |
                    Q(assignment__academic_year_id=ay_param) |
                    Q(batches__assignment__academic_year_id=ay_param)
                ).distinct()
            else:
                slots = slots.filter(
                    Q(timetable__academic_year__year_name__iexact=str(ay_param).strip()) |
                    Q(assignment__academic_year__year_name__iexact=str(ay_param).strip()) |
                    Q(batches__assignment__academic_year__year_name__iexact=str(ay_param).strip())
                ).distinct()

        fac_param = request.query_params.get("faculty") or request.query_params.get("faculty_id")
        if fac_param:
            slots = slots.filter(
                Q(assignment__faculty_id=fac_param) | Q(batches__assignment__faculty_id=fac_param)
            ).distinct()

        search_param = request.query_params.get("search")
        if search_param:
            slots = slots.filter(
                Q(assignment__subject__subject_name__icontains=search_param) |
                Q(assignment__subject__subject_code__icontains=search_param) |
                Q(assignment__faculty__name__icontains=search_param) |
                Q(batches__assignment__subject__subject_name__icontains=search_param) |
                Q(batches__assignment__subject__subject_code__icontains=search_param) |
                Q(batches__assignment__faculty__name__icontains=search_param) |
                Q(day__icontains=search_param) |
                Q(batch_name__icontains=search_param) |
                Q(batches__batch_name__icontains=search_param)
            ).distinct()

        target_context_faculty = faculty if (user_role != "HOD" or is_personal) else None
        serializer = FacultyScheduleSerializer(slots, many=True, context={"request": request, "faculty": target_context_faculty})
        slot_list = list(serializer.data)

        # 4. Fetch assigned subjects:
        if user_role in ["HOD", "HEAD OF DEPARTMENT"] and dept and not is_personal:
            assigned_qs = SubjectAssignment.objects.filter(
                Q(department=dept) | Q(subject__department=dept) | Q(faculty=faculty)
            ).select_related(
                "subject", "subject__department", "subject__semester", "semester", "academic_year", "faculty"
            )
        else:
            assigned_qs = SubjectAssignment.objects.filter(faculty=faculty).select_related(
                "subject", "subject__department", "subject__semester", "semester", "academic_year", "faculty"
            )

        if sem_param:
            if str(sem_param).isdigit():
                sem_int = int(sem_param)
                assigned_qs = assigned_qs.filter(
                    Q(semester_id=sem_int) |
                    Q(semester__sem_number=sem_int) |
                    Q(subject__semester_id=sem_int) |
                    Q(subject__semester__sem_number=sem_int)
                ).distinct()
            else:
                assigned_qs = assigned_qs.filter(
                    Q(semester_id=sem_param) |
                    Q(semester__sem_number=sem_param) |
                    Q(subject__semester_id=sem_param) |
                    Q(subject__semester__sem_number=sem_param)
                ).distinct()

        if ay_param and str(ay_param).lower() != "all":
            if str(ay_param).isdigit():
                assigned_qs = assigned_qs.filter(academic_year_id=ay_param)
            else:
                assigned_qs = assigned_qs.filter(academic_year__year_name__iexact=str(ay_param).strip())

        if fac_param:
            assigned_qs = assigned_qs.filter(faculty_id=fac_param)
        if search_param:
            assigned_qs = assigned_qs.filter(
                Q(subject__subject_name__icontains=search_param) |
                Q(subject__subject_code__icontains=search_param) |
                Q(faculty__name__icontains=search_param)
            )

        assigned_subjects = []
        for a in assigned_qs:
            sem_num = getattr(a.semester, "sem_number", None) or getattr(getattr(a.subject, "semester", None), "sem_number", None)
            sched_count = slots.filter(Q(assignment=a) | Q(batches__assignment=a)).distinct().count()
            assigned_subjects.append({
                "assignment_id": a.id,
                "subject_id": a.subject.id,
                "subject_code": a.subject.subject_code,
                "subject_name": a.subject.subject_name,
                "faculty_name": getattr(getattr(a, "faculty", None), "name", "Not Assigned"),
                "semester": sem_num,
                "department": getattr(a.department or a.subject.department, "name", ""),
                "academic_year": getattr(a.academic_year, "year_name", ""),
                "slots_count": sched_count,
                "is_elective": getattr(a.subject, "is_elective", False),
            })

        # 5. Resolve Class Teacher for this department, semester, and academic year
        class_teacher_name = None
        class_teacher_id = None
        if dept:
            from timetable.models import SemesterClassTeacher
            sct_qs = SemesterClassTeacher.objects.filter(department=dept).select_related("faculty", "semester", "academic_year")
            if sem_param:
                if str(sem_param).isdigit():
                    sct_qs = sct_qs.filter(Q(semester__sem_number=int(sem_param)) | Q(semester_id=int(sem_param)))
                else:
                    sct_qs = sct_qs.filter(Q(semester__sem_number=sem_param) | Q(semester_id=sem_param))
            if ay_param and str(ay_param).lower() != "all":
                if str(ay_param).isdigit():
                    sct_qs = sct_qs.filter(academic_year_id=ay_param)
                else:
                    sct_qs = sct_qs.filter(academic_year__year_name__iexact=str(ay_param).strip())
            sct = sct_qs.first()
            if sct and sct.faculty:
                class_teacher_name = sct.faculty.name
                class_teacher_id = getattr(sct.faculty, "faculty_id", None)

            if not class_teacher_name:
                tt_ct_qs = TimeTable.objects.filter(department=dept).exclude(class_teacher__isnull=True).select_related("class_teacher", "semester", "academic_year")
                if sem_param:
                    if str(sem_param).isdigit():
                        tt_ct_qs = tt_ct_qs.filter(Q(semester__sem_number=int(sem_param)) | Q(semester_id=int(sem_param)))
                    else:
                        tt_ct_qs = tt_ct_qs.filter(Q(semester__sem_number=sem_param) | Q(semester_id=sem_param))
                if ay_param and str(ay_param).lower() != "all":
                    if str(ay_param).isdigit():
                        tt_ct_qs = tt_ct_qs.filter(academic_year_id=ay_param)
                    else:
                        tt_ct_qs = tt_ct_qs.filter(academic_year__year_name__iexact=str(ay_param).strip())
                tt_ct = tt_ct_qs.order_by("-id").first()
                if tt_ct and tt_ct.class_teacher:
                    class_teacher_name = tt_ct.class_teacher.name
                    class_teacher_id = getattr(tt_ct.class_teacher, "faculty_id", None)

        return Response({
            "results": slot_list,
            "slots": slot_list,
            "assigned_subjects": assigned_subjects,
            "faculty_name": faculty.name if faculty else "HOD",
            "faculty_id": getattr(faculty, "faculty_id", ""),
            "department_name": dept.name if dept else "",
            "role": user_role,
            "class_teacher_name": class_teacher_name,
            "class_teacher_id": class_teacher_id,
        }, status=status.HTTP_200_OK)

    # --- 4. Role specific lists ---
    @action(detail=False, methods=["get"])
    def pending(self, request):
        user_role = (getattr(request.user, "role", "") or "").upper()
        pending_statuses = ["Pending", "Pending Reapproval", "PENDING_APPROVAL", "PENDING_REAPPROVAL"]
        if user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            qs = TimeTable.objects.filter(status__in=pending_statuses, department=dept) if dept else TimeTable.objects.none()
        elif user_role == "PRINCIPAL":
            # Department timetables are approved directly and do not require Principal approval
            qs = TimeTable.objects.none()
        else:
            qs = TimeTable.objects.filter(status__in=pending_statuses)
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=["get"])
    def faculty(self, request):
        faculty = _resolve_faculty_for_user(request.user)
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        from django.db.models import Q
        if not faculty:
            if user_role in ["SYSTEM", "PRINCIPAL"] or request.user.is_superuser:
                qs = TimeTable.objects.filter(is_active=True)
            else:
                return Response({"error": "Faculty profile not found for user."}, status=status.HTTP_404_NOT_FOUND)
        else:
            qs = TimeTable.objects.filter(
                Q(slots__assignment__faculty=faculty) | Q(slots__batches__assignment__faculty=faculty),
                is_active=True
            ).distinct()

        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=["get"])
    def student(self, request):
        """
        Automatic semester-based timetable display for authenticated students.
        Resolves current department, semester (promoted/active), and academic year.
        Strictly enforces approved timetable status and departmental isolation.
        """
        user = request.user
        student = getattr(user, "student", None)
        if not student:
            from students.models import Student
            student = Student.objects.filter(user=user).select_related("department", "semester", "academic_year").first()
            if not student and getattr(user, "user_id", None):
                student = Student.objects.filter(usn=user.user_id).select_related("department", "semester", "academic_year").first()

        if not student:
            return Response({"error": "Authenticated user is not registered as an active student."}, status=status.HTTP_403_FORBIDDEN)

        # Allow query parameters for historical semester navigation (if requested)
        sem_param = request.query_params.get("semester")
        ay_param = request.query_params.get("academic_year")

        target_dept = student.department
        target_sem = student.semester
        target_ay = student.academic_year

        if sem_param:
            from academics.models import Semester
            req_sem = Semester.objects.filter(sem_number=sem_param).first() or Semester.objects.filter(id=sem_param).first()
            if req_sem:
                target_sem = req_sem

        if ay_param:
            from academics.models import AcademicYear
            req_ay = AcademicYear.objects.filter(year_name=ay_param).first() or AcademicYear.objects.filter(id=ay_param).first()
            if req_ay:
                target_ay = req_ay

        # Query only the approved, active timetable for the student's department, semester, and academic year
        qs = TimeTable.objects.filter(
            department=target_dept,
            semester=target_sem,
            status__iexact="Approved",
            is_active=True
        ).select_related("department", "semester", "academic_year").prefetch_related(
            "slots__assignment__subject",
            "slots__assignment__faculty",
            "slots__batches__assignment__subject",
            "slots__batches__assignment__faculty",
        )

        if target_ay:
            qs = qs.filter(academic_year=target_ay)

        timetable_obj = qs.order_by("-version", "-created_at").first()

        # If no timetable matching specific academic year, try active approved timetable for that semester & department
        if not timetable_obj and target_sem:
            timetable_obj = TimeTable.objects.filter(
                department=target_dept,
                semester=target_sem,
                status__iexact="Approved",
                is_active=True
            ).order_by("-version", "-created_at").first()

        from .serializers import TimeTableSerializer
        serialized_tt = TimeTableSerializer(timetable_obj).data if timetable_obj else None

        # Build list of available semesters for the student
        from students.models import StudentAcademicHistory
        available_sems = list(StudentAcademicHistory.objects.filter(student=student).values_list("semester__sem_number", flat=True).distinct())
        if student.semester and student.semester.sem_number not in available_sems:
            available_sems.append(student.semester.sem_number)
        available_sems.sort()

        is_current_sem = (target_sem == student.semester)

        ct_obj = (timetable_obj.class_teacher if timetable_obj and timetable_obj.class_teacher else getattr(student, "class_teacher", None))
        ct_name = ct_obj.name if ct_obj else None
        ct_id = ct_obj.id if ct_obj else None

        resp_data = {
            "student": {
                "name": student.name,
                "usn": student.usn,
                "department_id": student.department_id,
                "department_name": student.department.name if student.department else "CSE",
                "current_semester": student.semester.sem_number if student.semester else None,
                "current_academic_year": student.academic_year.year_name if student.academic_year else "",
                "class_teacher_name": ct_name,
                "class_teacher_id": ct_id,
            },
            "selected_context": {
                "semester": target_sem.sem_number if target_sem else None,
                "academic_year": target_ay.year_name if target_ay else (timetable_obj.academic_year.year_name if timetable_obj else ""),
                "is_current": is_current_sem,
                "class_teacher_name": ct_name,
                "class_teacher_id": ct_id,
            },
            "available_semesters": available_sems,
            "has_approved_timetable": timetable_obj is not None,
            "message": "Approved timetable loaded successfully." if timetable_obj else "No approved timetable is available for your current semester yet.",
            "timetable": serialized_tt,
            "results": [serialized_tt] if serialized_tt else [],
        }

        # If frontend expects plain list:
        if request.query_params.get("format") == "list":
            return Response([serialized_tt] if serialized_tt else [])

        return Response(resp_data)

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

    @action(detail=False, methods=["get", "post"])
    def class_teacher(self, request):
        """
        GET: Returns assigned class teacher for ?department_id=&semester_id=&academic_year_id=
        POST: Explicitly assigns/updates class teacher for semester students.
        """
        from timetable.models import SemesterClassTeacher
        from faculty.models import Faculty
        from students.models import Student, StudentAcademicHistory

        if request.method == "GET":
            dept_id = request.query_params.get("department_id") or request.query_params.get("department")
            sem_id = request.query_params.get("semester_id") or request.query_params.get("semester")
            ay_id = request.query_params.get("academic_year_id") or request.query_params.get("academic_year")

            qs = SemesterClassTeacher.objects.select_related("faculty", "department", "semester", "academic_year")
            if dept_id:
                qs = qs.filter(department_id=dept_id)
            if sem_id:
                qs = qs.filter(semester_id=sem_id)
            if ay_id:
                qs = qs.filter(academic_year_id=ay_id)

            record = qs.first()
            if record:
                return Response({
                    "id": record.id,
                    "department_id": record.department_id,
                    "semester_id": record.semester_id,
                    "academic_year_id": record.academic_year_id,
                    "faculty_id": record.faculty.id,
                    "faculty_name": record.faculty.name,
                    "faculty_employee_id": record.faculty.faculty_id,
                    "designation": record.faculty.designation or "Professor",
                    "email": str(record.faculty.email) if record.faculty.email else "",
                })
            return Response({"class_teacher": None}, status=status.HTTP_200_OK)

        elif request.method == "POST":
            dept_id = request.data.get("department_id") or request.data.get("department")
            sem_id = request.data.get("semester_id") or request.data.get("semester")
            ay_id = request.data.get("academic_year_id") or request.data.get("academic_year")
            fac_id = request.data.get("faculty_id") or request.data.get("class_teacher")

            if not (dept_id and sem_id and fac_id):
                return Response({"error": "department_id, semester_id, and faculty_id are required."}, status=status.HTTP_400_BAD_REQUEST)

            faculty = Faculty.objects.filter(id=fac_id).first()
            if not faculty:
                return Response({"error": "Faculty not found."}, status=status.HTTP_404_NOT_FOUND)

            # Update Student records
            updated_count = Student.objects.filter(department_id=dept_id, semester_id=sem_id).update(class_teacher=faculty)
            if ay_id:
                StudentAcademicHistory.objects.filter(department_id=dept_id, semester_id=sem_id, academic_year_id=ay_id).update(class_teacher=faculty)

            # Update or create SemesterClassTeacher
            if ay_id:
                record, _ = SemesterClassTeacher.objects.update_or_create(
                    department_id=dept_id,
                    semester_id=sem_id,
                    academic_year_id=ay_id,
                    defaults={"faculty": faculty, "assigned_by": request.user if request.user.is_authenticated else None}
                )

            # Also update any active timetable for this cohort
            TimeTable.objects.filter(department_id=dept_id, semester_id=sem_id).update(class_teacher=faculty)

            return Response({
                "message": f"Successfully assigned {faculty.name} as Class Teacher for {updated_count} students.",
                "faculty_name": faculty.name,
                "students_updated": updated_count,
            })
