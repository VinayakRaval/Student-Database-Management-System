from rest_framework import viewsets, status, generics
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import PermissionDenied
from django.db.models import Count, Q
from django.shortcuts import get_object_or_404
from django.db import transaction
import datetime
import math

from .models import (
    AttendanceSession, AttendanceRecord, AttendanceCorrectionRequest,
    LabBatch, LabBatchStudent, AttendanceAuditLog, ExtraClassSession
)
from .serializers import (
    AttendanceSessionCreateSerializer, 
    AttendanceSessionSerializer,
    LabBatchSerializer,
    LabBatchStudentSerializer,
    AttendanceAuditLogSerializer,
    ExtraClassSessionSerializer,
)
from students.models import Student
from timetable.models import TimeTableSlot
from subjects.models import Subject, SubjectAssignment
from academics.models import Department, Semester, AcademicYear
from faculty.models import Faculty
from django.utils import timezone


def get_batch_aliases(name):
    if not name:
        return set()
    n = str(name).strip()
    aliases = {n.lower()}
    if n.lower().startswith('batch '):
        suffix = n[6:].strip()  # e.g. 'A', 'B', 'C'
        aliases.add(suffix.lower())
        aliases.add(f'b{suffix.lower()}')
        if len(suffix) == 1 and suffix.isalpha():
            char_idx = ord(suffix.upper()) - ord('A') + 1
            aliases.add(f'b{char_idx}')
            aliases.add(f'batch {char_idx}')
    elif n.upper().startswith('B') and len(n) > 1 and n[1:].isdigit():
        num = int(n[1:])
        char = chr(ord('A') + num - 1)
        aliases.add(f'batch {char.lower()}')
        aliases.add(char.lower())
        aliases.add(f'batch {num}')
    return aliases


def resolve_lab_batch_subject(batch, faculty=None, date=None):
    """
    Resolves the associated Subject for a given LabBatch.
    If multiple lab subjects exist in the department and semester, resolves the subject
    associated with the selected batch and scheduled lab session / faculty assignment.
    """
    if not batch:
        return None
    if getattr(batch, 'subject', None):
        return batch.subject

    from timetable.models import TimeTableSlotBatch, TimeTableSlot
    from subjects.models import SubjectAssignment, Subject

    batch_aliases = get_batch_aliases(getattr(batch, 'name', ''))
    dept = getattr(batch, 'department', None)
    sem = getattr(batch, 'semester', None)

    # 1. Check active timetable slot batches matching this batch and (optionally) faculty & date
    if sem:
        sbs_qs = TimeTableSlotBatch.objects.filter(
            slot__timetable__semester=sem,
            slot__timetable__is_active=True
        ).select_related('slot', 'assignment__subject', 'assignment__faculty')

        if dept:
            sbs_qs = sbs_qs.filter(slot__timetable__department=dept)

        if date:
            day_map = {0: 'MON', 1: 'TUE', 2: 'WED', 3: 'THU', 4: 'FRI', 5: 'SAT', 6: 'SUN'}
            day_code = day_map.get(date.weekday(), 'MON')
            sbs_qs = sbs_qs.filter(slot__day=day_code)

        sbs = list(sbs_qs)
        matched_sbs = [sb for sb in sbs if sb.batch_name.lower().strip() in batch_aliases]

        # Prioritize matching faculty if provided
        if faculty and matched_sbs:
            for sb in matched_sbs:
                if sb.assignment and sb.assignment.faculty_id == faculty.id and sb.assignment.subject:
                    return sb.assignment.subject

        if matched_sbs and matched_sbs[0].assignment and matched_sbs[0].assignment.subject:
            return matched_sbs[0].assignment.subject

        # Also check without date filter if not found for that specific day
        if date:
            all_sbs = TimeTableSlotBatch.objects.filter(
                slot__timetable__semester=sem,
                slot__timetable__is_active=True
            ).select_related('slot', 'assignment__subject', 'assignment__faculty')
            if dept:
                all_sbs = all_sbs.filter(slot__timetable__department=dept)
            all_matched = [sb for sb in all_sbs if sb.batch_name.lower().strip() in batch_aliases]
            if faculty and all_matched:
                for sb in all_matched:
                    if sb.assignment and sb.assignment.faculty_id == faculty.id and sb.assignment.subject:
                        return sb.assignment.subject
            if all_matched and all_matched[0].assignment and all_matched[0].assignment.subject:
                return all_matched[0].assignment.subject

    # 2. Check SubjectAssignment for the faculty in this department and semester
    if faculty and sem:
        sa_filter = Q(faculty=faculty, subject__semester=sem, subject__subject_type__in=['LAB', 'BOTH'])
        if dept:
            sa_filter &= Q(subject__department=dept)
        sa = SubjectAssignment.objects.filter(sa_filter).select_related('subject').first()
        if sa and sa.subject:
            return sa.subject

    # 3. Check batch.faculty
    if getattr(batch, 'faculty', None) and sem:
        sa_filter = Q(faculty=batch.faculty, subject__semester=sem, subject__subject_type__in=['LAB', 'BOTH'])
        if dept:
            sa_filter &= Q(subject__department=dept)
        sa = SubjectAssignment.objects.filter(sa_filter).select_related('subject').first()
        if sa and sa.subject:
            return sa.subject

    # 4. Fallback: department & semester lab subjects
    # Note: If batch is shared across semester subjects and no specific timetable/faculty slot matches,
    # return None so it remains a shared semester-wide batch rather than being partitioned arbitrarily.
    return None


def check_faculty_session_scheduled_today(faculty, subject, date, batch=None, session_type="THEORY"):
    """
    Checks if a theory subject or lab batch is scheduled for today in an active, approved timetable slot
    OR has an approved/scheduled ExtraClassSession for today.
    Returns (is_scheduled, has_regular_slot, has_approved_extra, extra_class_obj).
    """
    day_map = {0: 'MON', 1: 'TUE', 2: 'WED', 3: 'THU', 4: 'FRI', 5: 'SAT', 6: 'SUN'}
    day_code = day_map.get(date.weekday(), 'MON')

    if not subject and batch:
        subject = resolve_lab_batch_subject(batch, faculty=faculty, date=date)

    # 1. Regular timetable slot check
    has_regular = False
    from timetable.models import TimeTableSlotBatch

    if session_type == "LAB" and batch:
        batch_aliases = get_batch_aliases(batch.name)
        sb_filter = Q(
            slot__timetable__status="Approved",
            slot__timetable__is_active=True,
            slot__day=day_code
        )
        if subject:
            sb_filter &= Q(assignment__subject=subject)
        if faculty:
            sb_filter &= Q(assignment__faculty=faculty)

        sbs = TimeTableSlotBatch.objects.filter(sb_filter)
        for sb in sbs:
            if sb.batch_name.lower().strip() in batch_aliases:
                has_regular = True
                break

    if not has_regular and subject:
        slot_filter = Q(
            timetable__status="Approved",
            timetable__is_active=True,
            assignment__subject=subject,
            day=day_code
        )
        if faculty:
            slot_filter &= Q(assignment__faculty=faculty)
        if session_type == "LAB" and batch:
            batch_aliases = get_batch_aliases(batch.name)
            slots = TimeTableSlot.objects.filter(slot_filter)
            for s in slots:
                if s.batch_name and s.batch_name.lower().strip() in batch_aliases:
                    has_regular = True
                    break
                elif s.is_batch_wise:
                    has_regular = True
                    break
        else:
            has_regular = TimeTableSlot.objects.filter(slot_filter).exists()

    # 2. Extra Class Session check (Scheduled / Approved / Completed)
    extra_filter = Q(
        date=date,
        status__in=["APPROVED", "PENDING", "COMPLETED"]
    )
    if subject:
        extra_filter &= Q(subject=subject)
    if faculty:
        extra_filter &= Q(faculty=faculty)
    if session_type == "LAB":
        if batch:
            extra_filter &= (Q(batch=batch) | Q(batch__isnull=True))
        extra_filter &= Q(session_type="LAB")
    elif session_type == "THEORY":
        extra_filter &= Q(session_type="THEORY")

    extra_class_obj = ExtraClassSession.objects.filter(extra_filter).first()
    has_extra = extra_class_obj is not None

    is_scheduled = has_regular or has_extra
    return is_scheduled, has_regular, has_extra, extra_class_obj


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
                present_count=Count('id', filter=Q(status='Present')),
                theory_total=Count('id', filter=Q(session__session_type='THEORY')),
                theory_present=Count('id', filter=Q(session__session_type='THEORY', status='Present')),
                lab_total=Count('id', filter=Q(session__session_type='LAB')),
                lab_present=Count('id', filter=Q(session__session_type='LAB', status='Present')),
            )
            data = []
            for entry in stats:
                total = entry['total_sessions']
                present = entry['present_count']
                percentage = (present / total) * 100 if total > 0 else 0.0
                th_tot = entry['theory_total']
                th_pres = entry['theory_present']
                lb_tot = entry['lab_total']
                lb_pres = entry['lab_present']
                data.append({
                    "subject_name": entry['session__subject__subject_name'],
                    "subject_code": entry['session__subject__subject_code'],
                    "total_classes": total,
                    "attended_classes": present,
                    "percentage": round(percentage, 1),
                    "theory_classes": th_tot,
                    "theory_attended": th_pres,
                    "theory_percentage": round((th_pres / th_tot) * 100, 1) if th_tot > 0 else None,
                    "lab_classes": lb_tot,
                    "lab_attended": lb_pres,
                    "lab_percentage": round((lb_pres / lb_tot) * 100, 1) if lb_tot > 0 else None,
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
                present_count=Count('id', filter=Q(status='Present')),
                theory_total=Count('id', filter=Q(session__session_type='THEORY')),
                theory_present=Count('id', filter=Q(session__session_type='THEORY', status='Present')),
                lab_total=Count('id', filter=Q(session__session_type='LAB')),
                lab_present=Count('id', filter=Q(session__session_type='LAB', status='Present')),
            )
            data = []
            for entry in stats:
                total = entry['total_sessions']
                present = entry['present_count']
                percentage = (present / total) * 100 if total > 0 else 0.0
                th_tot = entry['theory_total']
                th_pres = entry['theory_present']
                lb_tot = entry['lab_total']
                lb_pres = entry['lab_present']
                data.append({
                    "subject_name": entry['session__subject__subject_name'],
                    "subject_code": entry['session__subject__subject_code'],
                    "total_classes": total,
                    "attended_classes": present,
                    "percentage": round(percentage, 1),
                    "theory_classes": th_tot,
                    "theory_attended": th_pres,
                    "theory_percentage": round((th_pres / th_tot) * 100, 1) if th_tot > 0 else None,
                    "lab_classes": lb_tot,
                    "lab_attended": lb_pres,
                    "lab_percentage": round((lb_pres / lb_tot) * 100, 1) if lb_tot > 0 else None,
                })
            return Response(data)

        student = getattr(request.user, "student", None)
        if not student:
            student = Student.objects.filter(user=request.user).first()
        if not student:
            return Response([], status=200)

        stats = AttendanceRecord.objects.filter(student=student).values(
            'session__subject_id',
            'session__subject__subject_name',
            'session__subject__subject_code'
        ).annotate(
            total_sessions=Count('id'),
            present_count=Count('id', filter=Q(status='Present')),
            theory_total=Count('id', filter=Q(session__session_type='THEORY')),
            theory_present=Count('id', filter=Q(session__session_type='THEORY', status='Present')),
            lab_total=Count('id', filter=Q(session__session_type='LAB')),
            lab_present=Count('id', filter=Q(session__session_type='LAB', status='Present')),
        )

        data = []
        for entry in stats:
            total = entry['total_sessions']
            present = entry['present_count']
            percentage = (present / total) * 100 if total > 0 else 0.0
            sub_id = entry['session__subject_id']
            th_tot = entry['theory_total']
            th_pres = entry['theory_present']
            lb_tot = entry['lab_total']
            lb_pres = entry['lab_present']

            subject_records = AttendanceRecord.objects.filter(
                student=student,
                session__subject_id=sub_id
            ).select_related('session', 'session__batch', 'session__extra_class').order_by('-session__date')

            day_map = {0: 'MON', 1: 'TUE', 2: 'WED', 3: 'THU', 4: 'FRI', 5: 'SAT', 6: 'SUN'}
            subject_slots = list(TimeTableSlot.objects.filter(
                timetable__status="Approved",
                timetable__is_active=True,
                assignment__subject_id=sub_id
            ))
            slot_timing_by_day = {s.day: (s.start_time, s.end_time) for s in subject_slots}

            sessions_list = []
            for rec in subject_records:
                sess = rec.session
                is_extra = sess.extra_class is not None
                st = sess.start_time
                et = sess.end_time
                if not st and is_extra:
                    st = sess.extra_class.start_time
                    et = sess.extra_class.end_time
                if not st:
                    d_code = day_map.get(sess.date.weekday(), 'MON')
                    if d_code in slot_timing_by_day:
                        st, et = slot_timing_by_day[d_code]
                    elif subject_slots:
                        st, et = subject_slots[0].start_time, subject_slots[0].end_time
                    else:
                        st = datetime.time(9, 0)
                        et = datetime.time(10, 0)

                timing_str = f"{st.strftime('%I:%M %p')} - {et.strftime('%I:%M %p')}" if (st and et) else "09:00 AM - 10:00 AM"

                sessions_list.append({
                    "date": sess.date.isoformat(),
                    "status": rec.status,
                    "session_count": sess.session_count,
                    "session_type": sess.session_type,
                    "batch_name": sess.batch.name if sess.batch else "",
                    "is_extra_class": is_extra,
                    "start_time": st.strftime("%I:%M %p") if st else "09:00 AM",
                    "end_time": et.strftime("%I:%M %p") if et else "10:00 AM",
                    "timing": timing_str,
                })

            data.append({
                "subject_id": sub_id,
                "subject_name": entry['session__subject__subject_name'],
                "subject_code": entry['session__subject__subject_code'],
                "total_classes": total,
                "attended_classes": present,
                "percentage": round(percentage, 1),
                "theory_classes": th_tot,
                "theory_attended": th_pres,
                "theory_percentage": round((th_pres / th_tot) * 100, 1) if th_tot > 0 else None,
                "lab_classes": lb_tot,
                "lab_attended": lb_pres,
                "lab_percentage": round((lb_pres / lb_tot) * 100, 1) if lb_tot > 0 else None,
                "status_label": "Safe (>=75%)" if percentage >= 75.0 else "Shortage Alert (<75%)",
                "sessions": sessions_list,
            })

        return Response(data)

    # --- 4. Faculty: Fetch Eligible Students for Subject & Date ---
    @action(detail=False, methods=['get'])
    def fetch_students_for_subject(self, request):
        """
        API to get eligible students for a specific subject and check if attendance was already recorded for a given date.
        Usage: /api/attendance/fetch_students_for_subject/?subject_id=1&date=2026-10-17
        """
        subject_id = request.query_params.get('subject_id')
        if not subject_id:
            return Response({"error": "subject_id is required."}, status=status.HTTP_400_BAD_REQUEST)

        date_str = request.query_params.get('date')
        if date_str:
            try:
                attendance_date = datetime.date.fromisoformat(str(date_str).strip())
            except ValueError:
                return Response({"error": "Invalid date format. Use YYYY-MM-DD."}, status=status.HTTP_400_BAD_REQUEST)
        else:
            attendance_date = timezone.localdate()

        # Rule 3: Do not allow future dates
        today = timezone.localdate()
        if attendance_date > today:
            return Response({
                "error": f"Attendance date cannot be in the future (today is {today})."
            }, status=status.HTTP_400_BAD_REQUEST)

        from timetable.views import _resolve_faculty_for_user, _resolve_department_for_user
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        subject = get_object_or_404(Subject, id=subject_id)
        fac = None

        # Rule 1: Subject Validation - professor must be assigned
        if user_role == "PROFESSOR":
            fac = _resolve_faculty_for_user(request.user)
            if not fac:
                return Response({"error": "Faculty profile not found for user."}, status=status.HTTP_404_NOT_FOUND)
            if not SubjectAssignment.objects.filter(subject=subject, faculty=fac).exists():
                return Response({"error": "You are not assigned to teach this subject."}, status=status.HTTP_403_FORBIDDEN)
        elif user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            fac = _resolve_faculty_for_user(request.user)
            if dept and subject.department_id != dept.id and not (fac and SubjectAssignment.objects.filter(subject=subject, faculty=fac).exists()):
                return Response({"error": "This subject does not belong to your department."}, status=status.HTTP_403_FORBIDDEN)

        # Rule 2: Student Eligibility
        assignment = None
        if fac:
            assignment = SubjectAssignment.objects.filter(subject=subject, faculty=fac).first()
        if not assignment:
            assignment = SubjectAssignment.objects.filter(subject=subject).first()

        target_dept = (assignment.department or assignment.subject.department) if assignment else subject.department
        target_sem = (assignment.semester or assignment.subject.semester) if assignment else subject.semester

        if getattr(subject, 'is_elective', False):
            from subjects.models import ElectiveSubjectEnrollment
            enrolled_ids = list(ElectiveSubjectEnrollment.objects.filter(
                subject=subject, is_active=True
            ).values_list('student_id', flat=True))
            students_qs = Student.objects.filter(id__in=enrolled_ids)
        else:
            students_qs = Student.objects.filter(
                department=target_dept,
                semester=target_sem
            ).filter(
                Q(status__iexact='active') | Q(registration_status__iexact='verified')
            )
            if assignment and assignment.academic_year:
                students_qs = students_qs.filter(academic_year=assignment.academic_year)

        students = students_qs.order_by('usn')

        # Check existing attendance session (Theory)
        session_qs = AttendanceSession.objects.filter(subject=subject, date=attendance_date, session_type='THEORY')
        if fac:
            session_qs = session_qs.filter(faculty=fac)
        session = session_qs.first()

        existing_records_map = {}
        if session:
            for rec in session.records.all():
                existing_records_map[rec.student_id] = rec.status

        # Timetable & Extra Class scheduling check for today
        is_scheduled_today = True
        has_regular_slot = False
        has_approved_extra = False
        extra_class_id = None
        not_scheduled_reason = ""

        if attendance_date == today:
            is_scheduled_today, has_regular_slot, has_approved_extra, extra_obj = check_faculty_session_scheduled_today(
                faculty=fac,
                subject=subject,
                date=attendance_date,
                session_type="THEORY"
            )
            if not is_scheduled_today:
                not_scheduled_reason = "No class or lab session is scheduled for today."
            elif extra_obj:
                extra_class_id = extra_obj.id

        is_already_recorded = session is not None and len(existing_records_map) > 0
        is_read_only = (attendance_date < today) or (attendance_date == today and not is_scheduled_today)

        data = {
            "subject": {
                "id": subject.id,
                "subject_code": subject.subject_code,
                "subject_name": subject.subject_name,
                "department_name": getattr(target_dept, 'name', '') if target_dept else '',
                "semester": getattr(target_sem, 'sem_number', str(target_sem)) if target_sem else '',
            },
            "date": attendance_date.isoformat(),
            "session_id": session.id if session else None,
            "session_count": session.session_count if session else 1,
            "is_already_recorded": is_already_recorded,
            "is_read_only": is_read_only,
            "is_scheduled_today": is_scheduled_today,
            "has_regular_slot": has_regular_slot,
            "has_approved_extra": has_approved_extra,
            "extra_class_id": extra_class_id,
            "not_scheduled_reason": not_scheduled_reason,
            "can_mark_attendance": is_scheduled_today and not (attendance_date < today),
            "message": f"Viewing past attendance records for {attendance_date} (Read-only)." if (attendance_date < today) else (not_scheduled_reason if not is_scheduled_today else ""),
            "total_eligible_students": students.count(),
            "students": [
                {
                    "id": s.id,
                    "usn": getattr(s, 'usn', '') or '',
                    "name": s.name,
                    "department_name": getattr(s.department, 'name', '') if s.department else '',
                    "semester": str(getattr(s.semester, 'sem_number', s.semester) if s.semester else ''),
                    "status": existing_records_map.get(s.id, "Present"),
                    "has_existing_record": s.id in existing_records_map
                }
                for s in students
            ]
        }
        return Response(data, status=status.HTTP_200_OK)

    # --- 5. Faculty: Save/Update Subject Attendance Atomically ---
    @action(detail=False, methods=['post'])
    def save_subject_attendance(self, request):
        """
        API to atomically save or update attendance for eligible students in a subject on a selected date.
        Prevents duplicate entries and ensures date & eligibility rules are enforced.
        """
        subject_id = request.data.get('subject_id')
        date_str = request.data.get('date')
        records = request.data.get('records', [])
        session_count = int(request.data.get('session_count', 1) or 1)

        if not subject_id:
            return Response({"error": "subject_id is required."}, status=status.HTTP_400_BAD_REQUEST)
        if not date_str:
            return Response({"error": "Attendance date is required."}, status=status.HTTP_400_BAD_REQUEST)
        if not records or not isinstance(records, list):
            return Response({"error": "Records list cannot be empty."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            attendance_date = datetime.date.fromisoformat(str(date_str).strip())
        except ValueError:
            return Response({"error": "Invalid date format. Use YYYY-MM-DD."}, status=status.HTTP_400_BAD_REQUEST)

        # Rule 3: Attendance Date Rules - future dates disallowed, past dates read-only
        today = timezone.localdate()
        if attendance_date > today:
            return Response({
                "error": f"Attendance date cannot be in the future (today is {today})."
            }, status=status.HTTP_400_BAD_REQUEST)
        if attendance_date < today:
            return Response({
                "error": "Previous day attendance cannot be modified or added. Past attendance is strictly read-only."
            }, status=status.HTTP_400_BAD_REQUEST)

        from timetable.views import _resolve_faculty_for_user, _resolve_department_for_user
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        subject = get_object_or_404(Subject, id=subject_id)
        fac = None

        # Rule 1: Subject Validation
        if user_role == "PROFESSOR":
            fac = _resolve_faculty_for_user(request.user)
            if not fac:
                return Response({"error": "Faculty profile not found for user."}, status=status.HTTP_404_NOT_FOUND)
            if not SubjectAssignment.objects.filter(subject=subject, faculty=fac).exists():
                return Response({"error": "You are not assigned to teach this subject."}, status=status.HTTP_403_FORBIDDEN)
        elif user_role == "HOD":
            fac = _resolve_faculty_for_user(request.user)
            dept = _resolve_department_for_user(request.user)
            if dept and subject.department_id != dept.id and not (fac and SubjectAssignment.objects.filter(subject=subject, faculty=fac).exists()):
                return Response({"error": "This subject does not belong to your department."}, status=status.HTTP_403_FORBIDDEN)
            if not fac:
                assignment = SubjectAssignment.objects.filter(subject=subject).first()
                fac = assignment.faculty if assignment else None
        else:
            assignment = SubjectAssignment.objects.filter(subject=subject).first()
            fac = assignment.faculty if assignment else None

        if not fac:
            return Response({"error": "No faculty assigned to this subject."}, status=status.HTTP_400_BAD_REQUEST)

        # Enforce timetable slot or approved extra class today
        extra_class = None
        if attendance_date == today:
            is_scheduled_today, has_regular_slot, has_approved_extra, extra_obj = check_faculty_session_scheduled_today(
                faculty=fac,
                subject=subject,
                date=attendance_date,
                session_type="THEORY"
            )
            extra_class_id = request.data.get('extra_class_id')
            if extra_class_id:
                extra_class = ExtraClassSession.objects.filter(
                    id=extra_class_id,
                    faculty=fac,
                    subject=subject,
                    date=attendance_date,
                    status__in=["APPROVED", "PENDING", "COMPLETED"]
                ).first()
                if not extra_class:
                    return Response({"error": "Invalid or unapproved extra class ID."}, status=status.HTTP_400_BAD_REQUEST)
            elif not is_scheduled_today:
                return Response({
                    "error": "No class or lab session is scheduled for today. Attendance cannot be recorded without an active timetable slot or an approved extra class."
                }, status=status.HTTP_400_BAD_REQUEST)
            elif has_approved_extra and not has_regular_slot:
                extra_class = extra_obj

        # Rule 2: Eligible Students Verification
        assignment = SubjectAssignment.objects.filter(subject=subject, faculty=fac).first() or SubjectAssignment.objects.filter(subject=subject).first()
        target_dept = (assignment.department or assignment.subject.department) if assignment else subject.department
        target_sem = (assignment.semester or assignment.subject.semester) if assignment else subject.semester

        eligible_qs = Student.objects.filter(
            department=target_dept,
            semester=target_sem
        ).filter(
            Q(status__iexact='active') | Q(registration_status__iexact='verified')
        )
        if assignment and assignment.academic_year:
            eligible_qs = eligible_qs.filter(academic_year=assignment.academic_year)

        eligible_map = {s.id: s for s in eligible_qs}

        # Rule 4: Attendance Status - Every eligible student must have a valid status: Present or Absent
        seen_student_ids = set()
        clean_records = []
        for r in records:
            s_id = r.get('student_id') or r.get('id')
            st_val = r.get('status')
            if not s_id or s_id not in eligible_map:
                return Response({"error": f"Student ID {s_id} is not eligible for subject {subject.subject_code}."}, status=status.HTTP_400_BAD_REQUEST)
            if st_val not in ["Present", "Absent"]:
                return Response({"error": f"Invalid status '{st_val}' for student {eligible_map[s_id].name}. Must be 'Present' or 'Absent'."}, status=status.HTTP_400_BAD_REQUEST)
            if s_id in seen_student_ids:
                return Response({"error": f"Duplicate student ID {s_id} found in payload."}, status=status.HTTP_400_BAD_REQUEST)
            seen_student_ids.add(s_id)
            clean_records.append((eligible_map[s_id], st_val))

        # Check if all eligible students are accounted for
        missing_students = set(eligible_map.keys()) - seen_student_ids
        if missing_students:
            missing_names = [eligible_map[sid].name for sid in list(missing_students)[:3]]
            return Response({
                "error": f"All eligible students must have attendance marked. Missing {len(missing_students)} students (e.g., {', '.join(missing_names)})."
            }, status=status.HTTP_400_BAD_REQUEST)

        # Rule 5: Atomic execution and duplicate prevention
        with transaction.atomic():
            if extra_class:
                session, _ = AttendanceSession.objects.select_for_update().get_or_create(
                    subject=subject,
                    faculty=fac,
                    date=attendance_date,
                    session_type='THEORY',
                    batch=None,
                    extra_class=extra_class,
                    defaults={'session_count': session_count}
                )
                extra_class.status = "COMPLETED"
                extra_class.save(update_fields=['status'])
            else:
                session, _ = AttendanceSession.objects.select_for_update().get_or_create(
                    subject=subject,
                    faculty=fac,
                    date=attendance_date,
                    session_type='THEORY',
                    batch=None,
                    extra_class=None,
                    defaults={'session_count': session_count}
                )

            if session.session_count != session_count:
                session.session_count = session_count
                session.save(update_fields=['session_count'])

            present_count = 0
            absent_count = 0
            for student, st_val in clean_records:
                AttendanceRecord.objects.update_or_create(
                    session=session,
                    student=student,
                    defaults={'status': st_val}
                )
                if st_val == "Present":
                    present_count += 1
                else:
                    absent_count += 1

        # Dispatch notification to each marked student's user account
        from announcements.models import Notification
        for student, st_val in clean_records:
            if getattr(student, "user", None):
                try:
                    Notification.objects.create(
                        recipient=student.user,
                        title=f"Attendance Recorded: {subject.subject_code}",
                        message=f"Attendance for {subject.subject_name} ({subject.subject_code}) on {attendance_date} has been recorded as '{st_val}'.",
                        notification_type="ATTENDANCE"
                    )
                except Exception:
                    pass

        return Response({
            "message": f"Attendance successfully saved for {attendance_date}!",
            "session_id": session.id,
            "subject_code": subject.subject_code,
            "date": attendance_date.isoformat(),
            "total_marked": len(clean_records),
            "present_count": present_count,
            "absent_count": absent_count,
        }, status=status.HTTP_200_OK)

    # --- 6. Faculty: Fetch Students for Lab Batch & Date ---
    @action(detail=False, methods=['get'])
    def fetch_students_for_lab_batch(self, request):
        """
        API to get assigned students for a specific lab batch and check if attendance was already recorded for a given date.
        Usage: /api/attendance/fetch_students_for_lab_batch/?batch_id=1&date=2026-10-17
        """
        batch_id = request.query_params.get('batch_id')
        if not batch_id:
            return Response({"error": "batch_id is required."}, status=status.HTTP_400_BAD_REQUEST)

        date_str = request.query_params.get('date')
        if date_str:
            try:
                attendance_date = datetime.date.fromisoformat(str(date_str).strip())
            except ValueError:
                return Response({"error": "Invalid date format. Use YYYY-MM-DD."}, status=status.HTTP_400_BAD_REQUEST)
        else:
            attendance_date = timezone.localdate()

        today = timezone.localdate()
        if attendance_date > today:
            return Response({"error": f"Attendance date cannot be in the future (today is {today})."}, status=status.HTTP_400_BAD_REQUEST)

        batch = get_object_or_404(
            LabBatch.objects.select_related('subject', 'department', 'semester', 'academic_year', 'faculty'), 
            id=batch_id
        )

        from timetable.views import _resolve_faculty_for_user, _resolve_department_for_user
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        fac = None
        if user_role == "PROFESSOR":
            fac = _resolve_faculty_for_user(request.user)
            if not fac:
                return Response({"error": "Faculty profile not found for user."}, status=status.HTTP_404_NOT_FOUND)
        elif user_role in ["HOD", "PRINCIPAL", "SYSTEM"]:
            fac = _resolve_faculty_for_user(request.user)

        subject_id = request.query_params.get('subject_id') or (batch.subject_id if batch.subject else None)
        subject = Subject.objects.filter(id=subject_id).first() if subject_id else (batch.subject or resolve_lab_batch_subject(batch, faculty=fac, date=attendance_date))

        batch_dept_id = batch.department_id or (subject.department_id if subject else None)
        batch_sem_id = batch.semester_id or (subject.semester_id if subject else None)

        if user_role == "PROFESSOR":
            is_assigned = False
            if subject and SubjectAssignment.objects.filter(subject=subject, faculty=fac).exists():
                is_assigned = True
            elif batch.faculty_id == fac.id:
                is_assigned = True
            elif batch_dept_id and batch_sem_id and SubjectAssignment.objects.filter(
                faculty=fac, subject__department_id=batch_dept_id, subject__semester_id=batch_sem_id
            ).exists():
                is_assigned = True
            if not is_assigned:
                return Response({"error": "You are not assigned to this lab batch or subject."}, status=status.HTTP_403_FORBIDDEN)
        elif user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            if dept and batch_dept_id and batch_dept_id != dept.id and not (fac and subject and SubjectAssignment.objects.filter(subject=subject, faculty=fac).exists()):
                return Response({"error": "This batch does not belong to your department."}, status=status.HTTP_403_FORBIDDEN)

        # Retrieve students assigned to this batch
        batch_students = [
            bs.student for bs in batch.batch_students.select_related('student', 'student__department', 'student__semester').order_by('student__usn')
        ]

        # Check existing attendance session for this lab batch
        session_filter = Q(batch=batch, date=attendance_date, session_type='LAB')
        if subject:
            session_filter &= Q(subject=subject)
        session = AttendanceSession.objects.filter(session_filter).first()

        existing_records_map = {}
        if session:
            for rec in session.records.all():
                existing_records_map[rec.student_id] = rec.status

        # Timetable & Extra Class scheduling check for today
        is_scheduled_today = True
        has_regular_slot = False
        has_approved_extra = False
        extra_class_id = None
        not_scheduled_reason = ""

        if attendance_date == today:
            is_scheduled_today, has_regular_slot, has_approved_extra, extra_obj = check_faculty_session_scheduled_today(
                faculty=fac,
                subject=subject or batch.subject,
                date=attendance_date,
                batch=batch,
                session_type="LAB"
            )
            if not is_scheduled_today:
                not_scheduled_reason = "No class or lab session is scheduled for today."
            elif extra_obj:
                extra_class_id = extra_obj.id

        is_already_recorded = session is not None and len(existing_records_map) > 0
        is_read_only = (attendance_date < today) or (attendance_date == today and not is_scheduled_today)

        eff_sub = subject or getattr(batch, 'subject', None) or resolve_lab_batch_subject(batch, faculty=fac, date=attendance_date)
        eff_fac = getattr(batch, 'faculty', None)
        if not eff_fac and eff_sub:
            sa = SubjectAssignment.objects.filter(subject=eff_sub).first()
            if sa and sa.faculty:
                eff_fac = sa.faculty
        if not eff_fac and fac:
            eff_fac = fac

        data = {
            "batch": {
                "id": batch.id,
                "name": batch.name,
                "subject_id": eff_sub.id if eff_sub else None,
                "subject_code": eff_sub.subject_code if eff_sub else "",
                "subject_name": eff_sub.subject_name if eff_sub else "",
                "department_name": getattr(batch.department, 'name', '') if batch.department else (getattr(eff_sub.department, 'name', '') if eff_sub and eff_sub.department else ''),
                "semester": getattr(batch.semester, 'sem_number', str(batch.semester)) if batch.semester else (getattr(eff_sub.semester, 'sem_number', '') if eff_sub and eff_sub.semester else ''),
                "faculty_name": eff_fac.name if eff_fac else "Unassigned",
            },
            "date": attendance_date.isoformat(),
            "session_id": session.id if session else None,
            "session_count": session.session_count if session else 1,
            "is_already_recorded": is_already_recorded,
            "is_read_only": is_read_only,
            "is_scheduled_today": is_scheduled_today,
            "has_regular_slot": has_regular_slot,
            "has_approved_extra": has_approved_extra,
            "extra_class_id": extra_class_id,
            "not_scheduled_reason": not_scheduled_reason,
            "can_mark_attendance": is_scheduled_today and not (attendance_date < today),
            "message": f"Viewing past lab attendance records for {attendance_date} (Read-only)." if (attendance_date < today) else (not_scheduled_reason if not is_scheduled_today else ""),
            "total_batch_students": len(batch_students),
            "students": [
                {
                    "id": s.id,
                    "usn": getattr(s, 'usn', '') or '',
                    "name": s.name,
                    "department_name": getattr(s.department, 'name', '') if s.department else '',
                    "semester": str(getattr(s.semester, 'sem_number', s.semester) if s.semester else ''),
                    "status": existing_records_map.get(s.id, "Present"),
                    "has_existing_record": s.id in existing_records_map
                }
                for s in batch_students
            ]
        }
        return Response(data, status=status.HTTP_200_OK)

    # --- 7. Faculty: Save/Update Lab Attendance Atomically ---
    @action(detail=False, methods=['post'])
    def save_lab_attendance(self, request):
        """
        API to atomically save or update lab attendance for students in a lab batch on a selected date.
        Prevents duplicate entries and ensures date, batch, and status rules are enforced.
        """
        batch_id = request.data.get('batch_id')
        date_str = request.data.get('date')
        records = request.data.get('records', [])
        session_count = int(request.data.get('session_count', 1) or 1)

        if not batch_id:
            return Response({"error": "batch_id is required."}, status=status.HTTP_400_BAD_REQUEST)
        if not date_str:
            return Response({"error": "Attendance date is required."}, status=status.HTTP_400_BAD_REQUEST)
        if not records or not isinstance(records, list):
            return Response({"error": "Records list cannot be empty."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            attendance_date = datetime.date.fromisoformat(str(date_str).strip())
        except ValueError:
            return Response({"error": "Invalid date format. Use YYYY-MM-DD."}, status=status.HTTP_400_BAD_REQUEST)

        today = timezone.localdate()
        if attendance_date > today:
            return Response({"error": f"Attendance date cannot be in the future (today is {today})."}, status=status.HTTP_400_BAD_REQUEST)
        if attendance_date < today:
            return Response({"error": "Previous day lab attendance cannot be modified or added. Past attendance is strictly read-only."}, status=status.HTTP_400_BAD_REQUEST)

        batch = get_object_or_404(LabBatch.objects.select_related('subject', 'department', 'semester', 'faculty'), id=batch_id)
        from timetable.views import _resolve_faculty_for_user, _resolve_department_for_user
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        fac = None
        if user_role == "PROFESSOR":
            fac = _resolve_faculty_for_user(request.user)
            if not fac:
                return Response({"error": "Faculty profile not found for user."}, status=status.HTTP_404_NOT_FOUND)
        elif user_role in ["HOD", "PRINCIPAL", "SYSTEM"]:
            fac = _resolve_faculty_for_user(request.user)

        subject_id = request.data.get('subject_id') or (batch.subject_id if batch.subject else None)
        subject = Subject.objects.filter(id=subject_id).first() if subject_id else (batch.subject or resolve_lab_batch_subject(batch, faculty=fac, date=attendance_date))
        if not subject:
            subject = resolve_lab_batch_subject(batch, faculty=fac, date=attendance_date)
        if not subject:
            return Response({"error": "subject_id is required for lab attendance recording."}, status=status.HTTP_400_BAD_REQUEST)

        batch_dept_id = batch.department_id or (subject.department_id if subject else None)
        batch_sem_id = batch.semester_id or (subject.semester_id if subject else None)

        if user_role == "PROFESSOR":
            is_assigned = False
            if SubjectAssignment.objects.filter(subject=subject, faculty=fac).exists():
                is_assigned = True
            elif batch.faculty_id == fac.id:
                is_assigned = True
            elif batch_dept_id and batch_sem_id and SubjectAssignment.objects.filter(
                faculty=fac, subject__department_id=batch_dept_id, subject__semester_id=batch_sem_id
            ).exists():
                is_assigned = True
            if not is_assigned:
                return Response({"error": "You are not authorized to mark attendance for this lab batch."}, status=status.HTTP_403_FORBIDDEN)
        elif user_role == "HOD":
            fac = _resolve_faculty_for_user(request.user)
            dept = _resolve_department_for_user(request.user)
            if dept and batch_dept_id and batch_dept_id != dept.id and not (fac and SubjectAssignment.objects.filter(subject=subject, faculty=fac).exists()):
                return Response({"error": "This batch or subject does not belong to your department."}, status=status.HTTP_403_FORBIDDEN)
            if not fac:
                fac = batch.faculty or (SubjectAssignment.objects.filter(subject=subject).first().faculty if SubjectAssignment.objects.filter(subject=subject).first() else None)
        else:
            fac = batch.faculty or (SubjectAssignment.objects.filter(subject=subject).first().faculty if SubjectAssignment.objects.filter(subject=subject).first() else None)

        if not fac:
            return Response({"error": "No faculty assigned to this lab batch or subject."}, status=status.HTTP_400_BAD_REQUEST)

        # Enforce timetable slot or approved extra class today
        extra_class = None
        if attendance_date == today:
            is_scheduled_today, has_regular_slot, has_approved_extra, extra_obj = check_faculty_session_scheduled_today(
                faculty=fac,
                subject=subject,
                date=attendance_date,
                batch=batch,
                session_type="LAB"
            )
            extra_class_id = request.data.get('extra_class_id')
            if extra_class_id:
                extra_class = ExtraClassSession.objects.filter(
                    id=extra_class_id,
                    faculty=fac,
                    subject=subject,
                    session_type="LAB",
                    date=attendance_date,
                    status__in=["APPROVED", "PENDING", "COMPLETED"]
                ).filter(Q(batch=batch) | Q(batch__isnull=True)).first()
                if not extra_class:
                    return Response({"error": "Invalid or unapproved extra class ID."}, status=status.HTTP_400_BAD_REQUEST)
            elif not is_scheduled_today:
                return Response({
                    "error": "No class or lab session is scheduled for today. Attendance cannot be recorded without an active timetable slot or an approved extra class."
                }, status=status.HTTP_400_BAD_REQUEST)
            elif has_approved_extra and not has_regular_slot:
                extra_class = extra_obj

        # Batch students verification
        batch_students_qs = Student.objects.filter(lab_batch_assignments__batch=batch)
        eligible_map = {s.id: s for s in batch_students_qs}

        if not eligible_map:
            return Response({"error": f"No students are assigned to {batch.name}. Please assign students to the batch first."}, status=status.HTTP_400_BAD_REQUEST)

        seen_student_ids = set()
        clean_records = []
        for r in records:
            s_id = r.get('student_id') or r.get('id')
            st_val = r.get('status')
            if not s_id or s_id not in eligible_map:
                return Response({"error": f"Student ID {s_id} is not assigned to {batch.name}."}, status=status.HTTP_400_BAD_REQUEST)
            if st_val not in ["Present", "Absent"]:
                return Response({"error": f"Invalid status '{st_val}' for student {eligible_map[s_id].name}. Must be 'Present' or 'Absent'."}, status=status.HTTP_400_BAD_REQUEST)
            if s_id in seen_student_ids:
                return Response({"error": f"Duplicate student ID {s_id} found in payload."}, status=status.HTTP_400_BAD_REQUEST)
            seen_student_ids.add(s_id)
            clean_records.append((eligible_map[s_id], st_val))

        missing_students = set(eligible_map.keys()) - seen_student_ids
        if missing_students:
            missing_names = [eligible_map[sid].name for sid in list(missing_students)[:3]]
            return Response({
                "error": f"All batch students must have attendance marked. Missing {len(missing_students)} students ({', '.join(missing_names)})."
            }, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            if extra_class:
                session, _ = AttendanceSession.objects.select_for_update().get_or_create(
                    subject=subject,
                    faculty=fac,
                    batch=batch,
                    session_type='LAB',
                    date=attendance_date,
                    extra_class=extra_class,
                    defaults={
                        'session_count': session_count,
                        'start_time': extra_class.start_time,
                        'end_time': extra_class.end_time,
                    }
                )
                if not session.start_time:
                    session.start_time = extra_class.start_time
                    session.end_time = extra_class.end_time
                    session.save(update_fields=['start_time', 'end_time'])
                extra_class.status = "COMPLETED"
                extra_class.save(update_fields=['status'])
            else:
                session, _ = AttendanceSession.objects.select_for_update().get_or_create(
                    subject=subject,
                    faculty=fac,
                    batch=batch,
                    session_type='LAB',
                    date=attendance_date,
                    extra_class=None,
                    defaults={'session_count': session_count}
                )

            if session.session_count != session_count:
                session.session_count = session_count
                session.save(update_fields=['session_count'])

            present_count = 0
            absent_count = 0
            for student, st_val in clean_records:
                AttendanceRecord.objects.update_or_create(
                    session=session,
                    student=student,
                    defaults={'status': st_val}
                )
                if st_val == "Present":
                    present_count += 1
                else:
                    absent_count += 1

        # Dispatch notifications
        from announcements.models import Notification
        for student, st_val in clean_records:
            if getattr(student, "user", None):
                try:
                    Notification.objects.create(
                        recipient=student.user,
                        title=f"Lab Attendance Recorded: {subject.subject_code} ({batch.name})",
                        message=f"Lab attendance for {subject.subject_name} ({batch.name}) on {attendance_date} has been recorded as '{st_val}'.",
                        notification_type="ATTENDANCE"
                    )
                except Exception:
                    pass

        return Response({
            "message": f"Lab attendance successfully saved for {batch.name} on {attendance_date}!",
            "session_id": session.id,
            "subject_code": subject.subject_code,
            "batch_name": batch.name,
            "date": attendance_date.isoformat(),
            "total_marked": len(clean_records),
            "present_count": present_count,
            "absent_count": absent_count,
        }, status=status.HTTP_200_OK)

    # --- Monthly Attendance Report Dispatcher (HOD & Students) ---
    @action(detail=False, methods=['get', 'post'])
    def dispatch_monthly_report(self, request):
        """
        API to automatically compute monthly attendance metrics and dispatch reports/alerts to HOD and Students.
        Usage: /api/attendance/dispatch_monthly_report/?month=10&year=2026
        """
        import calendar
        from announcements.models import Notification
        from hod_assignment.models import HODAssignment
        from academics.models import Department

        today = timezone.localdate()
        year = int(request.query_params.get('year', today.year) or today.year)
        month = int(request.query_params.get('month', today.month) or today.month)
        month_name = calendar.month_name[month]

        dept_id = request.query_params.get('department_id')
        dept_qs = Department.objects.all()
        if dept_id and str(dept_id).isdigit():
            dept_qs = dept_qs.filter(id=int(dept_id))

        student_count = 0
        hod_count = 0

        for dept in dept_qs:
            dept_students = Student.objects.filter(
                department=dept
            ).filter(
                Q(status__iexact='active') | Q(registration_status__iexact='verified')
            )

            dept_total_sessions = 0
            dept_present_sessions = 0
            low_attendance_students = 0

            for st in dept_students:
                st_records = AttendanceRecord.objects.filter(
                    student=st,
                    session__date__year=year,
                    session__date__month=month
                )
                tot = st_records.count()
                if tot > 0:
                    pres = st_records.filter(status='Present').count()
                    pct = round((pres / tot) * 100, 1)
                    dept_total_sessions += tot
                    dept_present_sessions += pres

                    if pct < 75.0:
                        low_attendance_students += 1

                    if getattr(st, 'user', None):
                        status_alert = "Shortage Alert: Below 75% attendance" if pct < 75.0 else "Satisfactory"
                        Notification.objects.create(
                            recipient=st.user,
                            title=f"Monthly Attendance Report: {month_name} {year}",
                            message=f"Dear {st.name}, your overall attendance for {month_name} {year} is {pct}% ({pres}/{tot} classes attended). Status: {status_alert}.",
                            notification_type="ATTENDANCE"
                        )
                        student_count += 1

            # Resolve HOD for department
            hod_user = None
            hod_assign = HODAssignment.objects.filter(department=dept, end_date__isnull=True).select_related('faculty__user').first()
            if hod_assign and hod_assign.faculty and hod_assign.faculty.user:
                hod_user = hod_assign.faculty.user
            else:
                from django.contrib.auth import get_user_model
                User = get_user_model()
                hod_user = User.objects.filter(role__iexact='HOD', department=dept).first()

            if hod_user:
                dept_avg = round((dept_present_sessions / dept_total_sessions) * 100, 1) if dept_total_sessions > 0 else 0.0
                Notification.objects.create(
                    recipient=hod_user,
                    title=f"Monthly Attendance Summary: {dept.name} ({month_name} {year})",
                    message=f"Monthly Attendance Report for {dept.name} ({month_name} {year}): Enrolled Students: {dept_students.count()}, Total Class Attendances Tracked: {dept_total_sessions}, Average Attendance: {dept_avg}%, Students Below 75% Threshold: {low_attendance_students}.",
                    notification_type="ATTENDANCE"
                )
                hod_count += 1

        return Response({
            "message": f"Monthly attendance report for {month_name} {year} dispatched successfully!",
            "month": month_name,
            "year": year,
            "students_notified": student_count,
            "hods_notified": hod_count
        }, status=status.HTTP_200_OK)


    # --- 6. Custom Attendance Shortage Component (<75% threshold) ---
    @action(detail=False, methods=['get'])
    def shortage_report(self, request):
        """
        API to fetch students with attendance below threshold (default 75%).
        Usage: /api/attendance/shortage_report/?threshold=75&subject_id=1&department_id=2&semester=3
        """
        threshold_param = request.query_params.get('threshold', '75')
        try:
            threshold = float(threshold_param)
        except ValueError:
            threshold = 75.0

        subject_id = request.query_params.get('subject_id')
        dept_id = request.query_params.get('department_id')
        semester = request.query_params.get('semester')

        from timetable.views import _resolve_faculty_for_user, _resolve_department_for_user
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        records_qs = AttendanceRecord.objects.select_related(
            'student', 'student__department', 'student__semester',
            'session', 'session__subject', 'session__faculty'
        ).all()

        if user_role == "PROFESSOR":
            fac = _resolve_faculty_for_user(request.user)
            if fac:
                assigned_subjects = SubjectAssignment.objects.filter(faculty=fac).values_list('subject_id', flat=True)
                records_qs = records_qs.filter(Q(session__faculty=fac) | Q(session__subject_id__in=assigned_subjects))
            else:
                return Response({"threshold": threshold, "total_shortage_students": 0, "shortage_list": []})
        elif user_role == "HOD":
            dept = _resolve_department_for_user(request.user)
            if dept:
                records_qs = records_qs.filter(session__subject__department=dept)

        if subject_id:
            records_qs = records_qs.filter(session__subject_id=subject_id)
        if dept_id:
            records_qs = records_qs.filter(student__department_id=dept_id)
        if semester:
            records_qs = records_qs.filter(student__semester=semester)

        # Aggregate by (student, subject)
        aggregated = records_qs.values(
            'student_id',
            'student__usn',
            'student__name',
            'student__department__name',
            'student__semester__sem_number',
            'session__subject_id',
            'session__subject__subject_code',
            'session__subject__subject_name',
        ).annotate(
            total_conducted=Count('id'),
            total_attended=Count('id', filter=Q(status='Present'))
        )

        shortage_list = []
        for row in aggregated:
            conducted = row['total_conducted']
            attended = row['total_attended']
            pct = (attended / conducted * 100.0) if conducted > 0 else 0.0

            if pct < threshold:
                diff = (threshold * conducted) - (100.0 * attended)
                denom = 100.0 - threshold
                classes_needed = 0
                if denom > 0 and diff > 0:
                    classes_needed = math.ceil(diff / denom)

                status_label = "Critical (<60%)" if pct < 60 else f"Shortage (<{int(threshold)}%)"

                sem_num = row.get('student__semester__sem_number')
                sem_str = f"Semester {sem_num}" if sem_num else ''

                shortage_list.append({
                    "student_id": row['student_id'],
                    "usn": row['student__usn'] or '',
                    "name": row['student__name'],
                    "department_name": row.get('student__department__name') or '',
                    "semester": sem_str,
                    "subject_id": row['session__subject_id'],
                    "subject_code": row['session__subject__subject_code'],
                    "subject_name": row['session__subject__subject_name'],
                    "conducted_classes": conducted,
                    "attended_classes": attended,
                    "attendance_percentage": round(pct, 1),
                    "shortage_status": status_label,
                    "classes_needed_for_threshold": classes_needed
                })

        shortage_list.sort(key=lambda x: x['attendance_percentage'])

        return Response({
            "threshold": threshold,
            "total_shortage_students": len(shortage_list),
            "shortage_list": shortage_list
        }, status=status.HTTP_200_OK)


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
        from timetable.views import _resolve_faculty_for_user
        fac = _resolve_faculty_for_user(request.user)

        cr_qs = AttendanceCorrectionRequest.objects.all()
        if dept:
            cr_qs = cr_qs.filter(
                Q(student__department=dept) |
                Q(faculty__department=dept)
            )
        correction_requests = [
            {
                "id": cr.id,
                "student_id": cr.student.id,
                "student_usn": cr.student.usn,
                "student_name": cr.student.name,
                "faculty_name": cr.faculty.name if cr.faculty else "N/A",
                "subject_code": cr.session.subject.subject_code if cr.session and cr.session.subject else "N/A",
                "subject_name": cr.session.subject.subject_name if cr.session and cr.session.subject else "N/A",
                "session_date": cr.session.date.strftime("%Y-%m-%d") if cr.session else "N/A",
                "session_type": cr.session.session_type if cr.session else "THEORY",
                "batch_name": cr.session.batch.name if cr.session and cr.session.batch else "",
                "current_status": cr.record.status if cr.record else ("Absent" if cr.requested_status == "Present" else "Present"),
                "requested_status": cr.requested_status,
                "reason": cr.reason,
                "remarks": cr.remarks,
                "status": cr.status,
                "is_own_request": (fac and cr.faculty_id == fac.id) or (hasattr(cr.faculty, 'user') and cr.faculty.user == request.user),
                "created_at": cr.created_at.strftime("%Y-%m-%d %H:%M"),
                "reviewed_at": cr.reviewed_at.strftime("%Y-%m-%d %H:%M") if cr.reviewed_at else None,
            }
            for cr in cr_qs[:30]
        ]

        # 6. Extra Class Requests
        extra_qs = ExtraClassSession.objects.all()
        if dept:
            extra_qs = extra_qs.filter(Q(subject__department=dept) | Q(faculty__department=dept))
        extra_requests = [
            {
                "id": ex.id,
                "subject_code": ex.subject.subject_code,
                "subject_name": ex.subject.subject_name,
                "faculty_name": ex.faculty.name if ex.faculty else "N/A",
                "professor_name": ex.faculty.name if ex.faculty else "N/A",
                "department_name": ex.subject.department.name if (ex.subject and ex.subject.department) else (ex.faculty.department.name if (ex.faculty and ex.faculty.department) else ""),
                "semester_no": getattr(ex.subject.semester, 'sem_number', '') if (ex.subject and ex.subject.semester) else "",
                "session_type": ex.session_type,
                "batch_name": ex.batch.name if ex.batch else "",
                "date": ex.date.strftime("%Y-%m-%d"),
                "start_time": ex.start_time.strftime("%H:%M"),
                "end_time": ex.end_time.strftime("%H:%M"),
                "duration_minutes": ex.duration_minutes,
                "room": ex.room,
                "reason": ex.reason,
                "status": ex.status,
                "remarks": ex.remarks or "",
                "is_own_request": (fac and ex.faculty_id == fac.id) or ex.created_by == request.user,
                "created_at": ex.created_at.strftime("%Y-%m-%d %H:%M"),
            }
            for ex in extra_qs.select_related('subject', 'faculty', 'batch', 'subject__department', 'subject__semester').order_by('-date', '-start_time')[:50]
        ]

        unassigned_count = sum(1 for s in subject_stats if s["status"] == "UNASSIGNED")

        from academics.models import AcademicYear
        academic_years_list = list(AcademicYear.objects.all().order_by('-year_name').values('id', 'year_name'))
        if not academic_years_list:
            academic_years_list = [
                {"id": 2, "year_name": "2026-2027"},
                {"id": 1, "year_name": "2025-2026"}
            ]

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
                "pending_extra_classes": extra_qs.filter(status="PENDING").count(),
                "conducted_extra_classes": extra_qs.filter(Q(attendance_sessions__isnull=False) | Q(status__in=["APPROVED", "COMPLETED"])).distinct().count(),
                "unassigned_subjects_count": unassigned_count,
                "total_subjects": len(subject_stats),
            },
            "academic_years": academic_years_list,
            "subjects": subject_stats,
            "submissions": submissions,
            "low_attendance_students": low_attendance_students,
            "correction_requests": correction_requests,
            "extra_class_requests": extra_requests,
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

        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        if user_role not in ["HOD", "PRINCIPAL", "SYSTEM"] and not request.user.is_superuser:
            return Response({"error": "Only HOD, Principal, or Admin can review attendance correction requests."}, status=status.HTTP_403_FORBIDDEN)

        if user_role == "HOD" and not (request.user.is_superuser or user_role in ["PRINCIPAL", "SYSTEM"]):
            from timetable.views import _resolve_department_for_user
            dept = _resolve_department_for_user(request.user)
            req_dept = cr.student.department if cr.student else (cr.session.subject.department if cr.session and cr.session.subject else None)
            if not dept or (req_dept and req_dept != dept):
                return Response({"error": "HOD can only review correction requests for their own department."}, status=status.HTTP_403_FORBIDDEN)

        from timetable.views import _resolve_faculty_for_user
        fac = _resolve_faculty_for_user(request.user)

        # Strictly prohibit self-approval:
        is_own_request = (
            (fac and cr.faculty_id == fac.id) or
            (hasattr(cr.faculty, 'user') and cr.faculty.user == request.user) or
            (cr.faculty and cr.faculty.email == request.user.email)
        )
        if is_own_request and user_role not in ["PRINCIPAL", "SYSTEM"] and not request.user.is_superuser:
            return Response({
                "error": "Self-approval is strictly prohibited. Faculty and HODs cannot approve their own attendance correction requests. As a teaching HOD, this request must be routed to and reviewed by the Principal or Administrator."
            }, status=status.HTTP_403_FORBIDDEN)

        cr.remarks = remarks
        cr.reviewed_by = request.user
        cr.reviewed_at = timezone.now()
        cr.is_self_approved = False

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

            AttendanceAuditLog.objects.create(
                user=request.user,
                action="SELF_APPROVE_ATTENDANCE" if is_self_approved else "APPROVE_ATTENDANCE",
                details=f"{'HOD Self-Approved' if is_self_approved else 'Approved'} attendance correction for student {cr.student.usn} ({cr.requested_status}). Reason: {cr.reason}."
            )

            msg = "Correction request self-approved and recorded in audit log." if is_self_approved else "Correction request approved and attendance record updated."
            return Response({"message": msg, "is_self_approved": is_self_approved})
        else:
            cr.status = "REJECTED"
            cr.save()

            AttendanceAuditLog.objects.create(
                user=request.user,
                action="REJECT_ATTENDANCE_CORRECTION",
                details=f"Rejected attendance correction for student {cr.student.usn}."
            )

            return Response({"message": "Correction request rejected."})


# ==========================================
# 6. Faculty Attendance Correction Submission & List
# ==========================================
class AttendanceCorrectionSubmitView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, *args, **kwargs):
        from timetable.views import _resolve_faculty_for_user
        fac = _resolve_faculty_for_user(request.user)
        if not fac:
            return Response({"error": "Faculty profile not found for user."}, status=status.HTTP_404_NOT_FOUND)

        student_id = request.data.get("student_id")
        session_id = request.data.get("session_id")
        record_id = request.data.get("record_id")
        requested_status = (request.data.get("requested_status") or "").capitalize()
        reason = (request.data.get("reason") or "").strip()

        if not student_id:
            return Response({"error": "student_id is required."}, status=status.HTTP_400_BAD_REQUEST)
        if requested_status not in ["Present", "Absent"]:
            return Response({"error": "requested_status must be 'Present' or 'Absent'."}, status=status.HTTP_400_BAD_REQUEST)
        if not reason:
            return Response({"error": "A valid reason is required for attendance correction."}, status=status.HTTP_400_BAD_REQUEST)

        student = get_object_or_404(Student, id=student_id)
        session = AttendanceSession.objects.filter(id=session_id).first() if session_id else None
        record = AttendanceRecord.objects.filter(id=record_id).first() if record_id else None
        if not session and record:
            session = record.session

        cr = AttendanceCorrectionRequest.objects.create(
            session=session,
            record=record,
            student=student,
            faculty=fac,
            requested_status=requested_status,
            reason=reason,
            status="PENDING"
        )

        return Response({
            "message": "Attendance correction request submitted to HOD successfully.",
            "request_id": cr.id,
            "status": cr.status,
            "created_at": cr.created_at.strftime("%Y-%m-%d %H:%M")
        }, status=status.HTTP_201_CREATED)


class FacultyCorrectionRequestsListView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        from timetable.views import _resolve_faculty_for_user
        fac = _resolve_faculty_for_user(request.user)
        if not fac:
            return Response({"error": "Faculty profile not found for user."}, status=status.HTTP_404_NOT_FOUND)

        requests = AttendanceCorrectionRequest.objects.filter(faculty=fac).select_related(
            'student', 'session', 'session__subject'
        ).order_by('-created_at')[:50]

        data = [
            {
                "id": r.id,
                "student_id": r.student.id,
                "student_name": r.student.name,
                "student_usn": getattr(r.student, "usn", "") or "",
                "subject_code": r.session.subject.subject_code if r.session and r.session.subject else "N/A",
                "subject_name": r.session.subject.subject_name if r.session and r.session.subject else "N/A",
                "session_date": r.session.date.strftime("%Y-%m-%d") if r.session else "N/A",
                "requested_status": r.requested_status,
                "reason": r.reason,
                "status": r.status,
                "is_self_approved": r.is_self_approved,
                "remarks": r.remarks or "",
                "created_at": r.created_at.strftime("%Y-%m-%d %H:%M"),
                "reviewed_at": r.reviewed_at.strftime("%Y-%m-%d %H:%M") if r.reviewed_at else None,
            }
            for r in requests
        ]
        return Response(data, status=status.HTTP_200_OK)


# ==========================================
# 7. Lab Batch Management ViewSet (HOD & Faculty)
# ==========================================
class LabBatchViewSet(viewsets.ModelViewSet):
    queryset = LabBatch.objects.all().select_related('subject', 'department', 'semester', 'academic_year', 'faculty')
    serializer_class = LabBatchSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        user_role = (getattr(user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        from timetable.views import _resolve_faculty_for_user, _resolve_department_for_user
        qs = LabBatch.objects.all().select_related('subject', 'department', 'semester', 'academic_year', 'faculty')

        subject_id = self.request.query_params.get('subject_id')
        semester_id = self.request.query_params.get('semester_id')
        department_id = self.request.query_params.get('department_id')

        # Lab Batches Shared Architecture:
        # A batch in a department & semester is shared across all lab subjects in that department & semester.
        if subject_id:
            sub = Subject.objects.filter(id=subject_id).first()
            if sub:
                qs = qs.filter(
                    Q(subject_id=subject_id) |
                    (Q(department=sub.department) & Q(semester=sub.semester))
                )
            else:
                qs = qs.filter(subject_id=subject_id)

        if semester_id:
            qs = qs.filter(Q(semester_id=semester_id) | Q(subject__semester_id=semester_id))
        semester_no = self.request.query_params.get('semester_no') or self.request.query_params.get('semester')
        if semester_no:
            qs = qs.filter(Q(semester__sem_number=semester_no) | Q(subject__semester__sem_number=semester_no))

        academic_year_id = self.request.query_params.get('academic_year_id') or self.request.query_params.get('academic_year')
        if academic_year_id:
            if str(academic_year_id).isdigit():
                qs = qs.filter(Q(academic_year_id=academic_year_id) | Q(academic_year__isnull=True))
            else:
                qs = qs.filter(Q(academic_year__year_name=academic_year_id) | Q(academic_year__isnull=True))

        if department_id:
            qs = qs.filter(Q(department_id=department_id) | Q(subject__department_id=department_id))

        assigned_only = self.request.query_params.get('assigned_only') == 'true'
        personal = self.request.query_params.get('personal') == 'true'
        if user_role == "PROFESSOR" or (user_role == "HOD" and personal):
            fac = _resolve_faculty_for_user(user)
            if fac:
                # Faculty can access batches if assigned to faculty directly, or assigned to a subject in that dept & sem
                assigned_subs = list(SubjectAssignment.objects.filter(faculty=fac).values_list(
                    'subject_id', 'subject__department_id', 'subject__semester_id'
                ))
                assigned_sub_ids = [s[0] for s in assigned_subs if s[0]]
                dept_sem_pairs = [(s[1], s[2]) for s in assigned_subs if s[1] and s[2]]

                dept_sem_q = Q()
                for d_id, s_id in dept_sem_pairs:
                    dept_sem_q |= (Q(department_id=d_id) & Q(semester_id=s_id))

                qs = qs.filter(
                    Q(faculty=fac) |
                    Q(subject_id__in=assigned_sub_ids) |
                    dept_sem_q
                )
            else:
                qs = qs.none()
        elif user_role == "HOD":
            dept = _resolve_department_for_user(user)
            if dept:
                qs = qs.filter(Q(department=dept) | Q(subject__department=dept))

        return qs.distinct().order_by('semester__sem_number', 'name')

    def _check_hod_permission(self, request):
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role not in ["HOD", "ADMIN", "PRINCIPAL", "SYSTEM"] and not request.user.is_superuser:
            raise PermissionDenied("Only HOD, Principal, or Admin can manage lab batches and student allocations.")

    def create(self, request, *args, **kwargs):
        self._check_hod_permission(request)
        name = (request.data.get('name') or "").strip()
        if not name:
            return Response({"error": "Batch name is required."}, status=status.HTTP_400_BAD_REQUEST)

        subject_id = request.data.get('subject_id') or request.data.get('subject')
        semester_id = request.data.get('semester_id') or request.data.get('semester')
        department_id = request.data.get('department_id') or request.data.get('department')
        faculty_id = request.data.get('faculty_id') or request.data.get('faculty')
        academic_year_id = request.data.get('academic_year_id') or request.data.get('academic_year')

        from timetable.views import _resolve_department_for_user
        hod_dept = _resolve_department_for_user(request.user) if (getattr(request.user, "role", "") or "").upper() == "HOD" else None

        subject = None
        if subject_id:
            subject = Subject.objects.filter(id=subject_id).first()

        department = None
        if department_id:
            department = Department.objects.filter(id=department_id).first()
        elif subject and subject.department:
            department = subject.department
        elif hod_dept:
            department = hod_dept

        if hod_dept and department and department.id != hod_dept.id:
            return Response({"error": f"You can only create lab batches for your department ({hod_dept.name})."}, status=status.HTTP_403_FORBIDDEN)

        semester = None
        if semester_id:
            semester = Semester.objects.filter(id=semester_id).first()
        elif subject and subject.semester:
            semester = subject.semester

        if not department or not semester:
            return Response({"error": "Department and Semester are required to create a lab batch."}, status=status.HTTP_400_BAD_REQUEST)

        # Shared Architecture: Check existing batch with same name in same department, semester, and academic year
        existing = LabBatch.objects.filter(
            department=department,
            semester=semester,
            name__iexact=name
        )
        if academic_year_id:
            existing = existing.filter(academic_year_id=academic_year_id)
        if existing.exists():
            return Response({
                "error": f"A batch named '{name}' already exists for {department.name} Semester {semester.sem_number}."
            }, status=status.HTTP_400_BAD_REQUEST)

        fac = Faculty.objects.filter(id=faculty_id).first() if faculty_id else None

        batch = LabBatch.objects.create(
            subject=subject,
            department=department,
            semester=semester,
            name=name,
            academic_year_id=academic_year_id,
            faculty=fac,
            created_by=request.user
        )

        AttendanceAuditLog.objects.create(
            user=request.user,
            action="CREATE_BATCH",
            details=f"Created shared lab batch '{name}' for {department.name} Semester {semester.sem_number}."
        )

        serializer = self.get_serializer(batch)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    def update(self, request, *args, **kwargs):
        self._check_hod_permission(request)
        batch = self.get_object()
        name = request.data.get('name')
        faculty_id = request.data.get('faculty_id') or request.data.get('faculty')

        if name:
            batch.name = name.strip()
        if faculty_id is not None:
            batch.faculty = Faculty.objects.filter(id=faculty_id).first() if faculty_id else None
        batch.save()

        sub_label = batch.subject.subject_code if batch.subject else f"{batch.department.name if batch.department else ''} Sem {batch.semester.sem_number if batch.semester else ''}"
        AttendanceAuditLog.objects.create(
            user=request.user,
            action="UPDATE_BATCH",
            details=f"Updated lab batch '{batch.name}' ({sub_label})."
        )

        serializer = self.get_serializer(batch)
        return Response(serializer.data)

    def destroy(self, request, *args, **kwargs):
        self._check_hod_permission(request)
        batch = self.get_object()
        batch_name = batch.name
        sub_label = batch.subject.subject_code if batch.subject else f"Sem {batch.semester.sem_number if batch.semester else ''}"
        if AttendanceSession.objects.filter(batch=batch).exists():
            return Response({
                "error": f"Cannot delete '{batch_name}' because historical attendance records exist for this batch. You can reassign students instead to preserve historical records."
            }, status=status.HTTP_400_BAD_REQUEST)
        batch.delete()

        AttendanceAuditLog.objects.create(
            user=request.user,
            action="DELETE_BATCH",
            details=f"Deleted lab batch '{batch_name}' from {sub_label}."
        )
        return Response({"message": f"Batch '{batch_name}' deleted successfully."}, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'])
    def assign_students(self, request, pk=None):
        self._check_hod_permission(request)
        batch = self.get_object()
        student_ids = request.data.get('student_ids', [])
        if not isinstance(student_ids, list):
            return Response({"error": "student_ids must be a list of integers."}, status=status.HTTP_400_BAD_REQUEST)

        # Validation Rule: Prevent a student from being assigned to multiple batches in the same department and semester
        dept = batch.department or (batch.subject.department if batch.subject else None)
        sem = batch.semester or (batch.subject.semester if batch.subject else None)

        conflicting_students = LabBatchStudent.objects.filter(
            batch__department=dept,
            batch__semester=sem,
            student_id__in=student_ids
        ).exclude(batch=batch)

        if batch.academic_year:
            conflicting_students = conflicting_students.filter(batch__academic_year=batch.academic_year)

        if conflicting_students.exists():
            conflict_names = [f"{cs.student.usn} ({cs.student.name}) in {cs.batch.name}" for cs in conflicting_students[:3]]
            return Response({
                "error": f"Students cannot be assigned to multiple batches in this semester: {', '.join(conflict_names)}."
            }, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            existing_assigned = set(batch.batch_students.values_list('student_id', flat=True))
            new_assigned = set(student_ids)

            to_remove = existing_assigned - new_assigned
            to_add = new_assigned - existing_assigned

            if to_remove:
                LabBatchStudent.objects.filter(batch=batch, student_id__in=to_remove).delete()

            for s_id in to_add:
                student = Student.objects.filter(id=s_id).first()
                if student:
                    LabBatchStudent.objects.create(batch=batch, student=student)

        AttendanceAuditLog.objects.create(
            user=request.user,
            action="ASSIGN_STUDENTS",
            details=f"Assigned {len(student_ids)} students to {batch.name}."
        )

        return Response({
            "message": f"Successfully updated students for {batch.name}.",
            "batch_id": batch.id,
            "total_assigned": len(student_ids)
        }, status=status.HTTP_200_OK)

    @action(detail=False, methods=['get'])
    def eligible_students_for_subject(self, request):
        subject_id = request.query_params.get('subject_id')
        batch_id = request.query_params.get('batch_id')
        department_id = request.query_params.get('department_id')
        semester_id = request.query_params.get('semester_id')

        dept = None
        sem = None

        if batch_id:
            batch = LabBatch.objects.filter(id=batch_id).first()
            if batch:
                dept = batch.department or (batch.subject.department if batch.subject else None)
                sem = batch.semester or (batch.subject.semester if batch.subject else None)

        if not dept and subject_id:
            subject = Subject.objects.filter(id=subject_id).first()
            if subject:
                dept = subject.department
                sem = subject.semester

        if not dept and department_id:
            dept = Department.objects.filter(id=department_id).first()
        if not sem and semester_id:
            sem = Semester.objects.filter(id=semester_id).first()

        if not dept or not sem:
            return Response({"error": "Unable to determine department and semester for eligible students."}, status=status.HTTP_400_BAD_REQUEST)

        students_qs = Student.objects.filter(
            department=dept,
            semester=sem
        ).filter(
            Q(status__iexact='active') | Q(registration_status__iexact='verified')
        ).order_by('usn')

        # Find batch assignments across this entire department & semester
        all_batch_assignments = LabBatchStudent.objects.filter(
            batch__department=dept,
            batch__semester=sem
        ).select_related('batch')

        student_batch_map = {ba.student_id: (ba.batch.id, ba.batch.name) for ba in all_batch_assignments}

        result = [
            {
                "id": s.id,
                "usn": s.usn,
                "name": s.name,
                "department": s.department.name if s.department else "",
                "semester": str(s.semester.sem_number) if s.semester else "",
                "assigned_batch_id": student_batch_map.get(s.id, (None, None))[0],
                "assigned_batch_name": student_batch_map.get(s.id, (None, None))[1],
            }
            for s in students_qs
        ]
        return Response(result, status=status.HTTP_200_OK)

    @action(detail=False, methods=['get'])
    def eligible_students_count(self, request):
        """
        API to get total eligible students count and student list with attendance percentages.
        Query params: department_id, semester_id, academic_year_id, sort_by (usn_asc, attendance_desc, attendance_asc)
        """
        self._check_hod_permission(request)
        department_id = request.query_params.get('department_id')
        semester_id = request.query_params.get('semester_id')
        academic_year_id = request.query_params.get('academic_year_id')
        sort_by = (request.query_params.get('sort_by') or 'usn_asc').lower()

        from timetable.views import _resolve_department_for_user
        user_role = (getattr(request.user, "role", "") or "").upper()
        hod_dept = _resolve_department_for_user(request.user) if user_role == "HOD" else None
        if hod_dept:
            department_id = hod_dept.id

        if not department_id or not semester_id:
            return Response({"error": "department_id and semester_id are required."}, status=status.HTTP_400_BAD_REQUEST)

        students_qs = Student.objects.filter(
            department_id=department_id,
            semester_id=semester_id
        ).filter(
            Q(status__iexact='active') | Q(registration_status__iexact='verified')
        )
        if academic_year_id:
            students_qs = students_qs.filter(academic_year_id=academic_year_id)

        students_list = list(students_qs)

        batch_student_map = {}
        for bs in LabBatchStudent.objects.filter(batch__department_id=department_id, batch__semester_id=semester_id).select_related('batch'):
            batch_student_map[bs.student_id] = (bs.batch_id, bs.batch.name)

        student_records_data = []
        for s in students_list:
            recs = AttendanceRecord.objects.filter(student=s, session__subject__semester_id=semester_id)
            if academic_year_id:
                recs = recs.filter(session__subject__subjectassignment__academic_year_id=academic_year_id)
            total = recs.count()
            pres = recs.filter(status__iexact='Present').count()
            pct = round((pres / total) * 100, 1) if total > 0 else None
            student_records_data.append({
                "id": s.id,
                "usn": getattr(s, 'usn', '') or '',
                "name": s.name,
                "total_classes": total,
                "attended_classes": pres,
                "attendance_percentage": pct,
                "attendance_display": f"{pct}%" if pct is not None else "No Records",
                "assigned_batch_id": batch_student_map.get(s.id, (None, None))[0],
                "assigned_batch_name": batch_student_map.get(s.id, (None, None))[1],
            })

        if sort_by == 'attendance_desc':
            student_records_data.sort(key=lambda x: (
                0 if x["attendance_percentage"] is not None else 1,
                -(x["attendance_percentage"] if x["attendance_percentage"] is not None else -1),
                x["usn"]
            ))
        elif sort_by == 'attendance_asc':
            student_records_data.sort(key=lambda x: (
                0 if x["attendance_percentage"] is not None else 1,
                (x["attendance_percentage"] if x["attendance_percentage"] is not None else 999),
                x["usn"]
            ))
        else:
            student_records_data.sort(key=lambda x: x["usn"])

        return Response({
            "total_eligible_students": len(students_list),
            "department_id": department_id,
            "semester_id": semester_id,
            "academic_year_id": academic_year_id,
            "sort_by": sort_by,
            "students": student_records_data,
        }, status=status.HTTP_200_OK)

    @action(detail=False, methods=['post'])
    def auto_distribute_preview(self, request):
        """
        API to preview student distribution into K batches before saving.
        Remainder distribution rule:
        If N students divided into K batches, q = N // K, r = N % K.
        First r batches get q + 1 students, next (K - r) batches get q students.
        """
        self._check_hod_permission(request)
        department_id = request.data.get('department_id')
        semester_id = request.data.get('semester_id')
        academic_year_id = request.data.get('academic_year_id')
        num_batches = int(request.data.get('num_batches', 0))
        sort_by = (request.data.get('sort_by') or 'usn_asc').lower()
        selected_student_ids = request.data.get('student_ids')

        from timetable.views import _resolve_department_for_user
        user_role = (getattr(request.user, "role", "") or "").upper()
        hod_dept = _resolve_department_for_user(request.user) if user_role == "HOD" else None
        if hod_dept:
            department_id = hod_dept.id

        if num_batches < 1:
            return Response({"error": "Number of batches must be at least 1."}, status=status.HTTP_400_BAD_REQUEST)
        if num_batches > 26:
            return Response({"error": "Number of batches cannot exceed 26."}, status=status.HTTP_400_BAD_REQUEST)

        students_qs = Student.objects.filter(
            department_id=department_id,
            semester_id=semester_id
        ).filter(
            Q(status__iexact='active') | Q(registration_status__iexact='verified')
        )
        if academic_year_id:
            students_qs = students_qs.filter(academic_year_id=academic_year_id)
        if selected_student_ids:
            students_qs = students_qs.filter(id__in=selected_student_ids)

        students_list = list(students_qs)
        N = len(students_list)
        if N == 0:
            return Response({"error": "No eligible students found to distribute into batches."}, status=status.HTTP_400_BAD_REQUEST)

        student_data = []
        for s in students_list:
            recs = AttendanceRecord.objects.filter(student=s, session__subject__semester_id=semester_id)
            total = recs.count()
            pres = recs.filter(status__iexact='Present').count()
            pct = round((pres / total) * 100, 1) if total > 0 else None
            student_data.append({
                "id": s.id,
                "usn": getattr(s, 'usn', '') or '',
                "name": s.name,
                "attendance_percentage": pct,
                "attendance_display": f"{pct}%" if pct is not None else "No Records",
            })

        if sort_by == 'attendance_desc':
            student_data.sort(key=lambda x: (
                0 if x["attendance_percentage"] is not None else 1,
                -(x["attendance_percentage"] if x["attendance_percentage"] is not None else -1),
                x["usn"]
            ))
        elif sort_by == 'attendance_asc':
            student_data.sort(key=lambda x: (
                0 if x["attendance_percentage"] is not None else 1,
                (x["attendance_percentage"] if x["attendance_percentage"] is not None else 999),
                x["usn"]
            ))
        else:
            student_data.sort(key=lambda x: x["usn"])

        q = N // num_batches
        r = N % num_batches

        batches_preview = []
        curr_idx = 0
        for i in range(num_batches):
            batch_char = chr(ord('A') + i)
            batch_name = f"Batch {batch_char}"
            count_for_batch = q + 1 if i < r else q
            batch_students = student_data[curr_idx : curr_idx + count_for_batch]
            curr_idx += count_for_batch

            batches_preview.append({
                "name": batch_name,
                "count": len(batch_students),
                "students": batch_students,
            })

        return Response({
            "total_students": N,
            "num_batches": num_batches,
            "sort_by": sort_by,
            "batches": batches_preview,
            "unassigned_students": [],
            "validation_errors": []
        }, status=status.HTTP_200_OK)

    @action(detail=False, methods=['post'])
    def create_shared_batches(self, request):
        """
        API to atomically create K shared batches and assign students.
        """
        self._check_hod_permission(request)
        department_id = request.data.get('department_id')
        semester_id = request.data.get('semester_id')
        academic_year_id = request.data.get('academic_year_id')
        batches_data = request.data.get('batches', [])
        replace_existing = request.data.get('replace_existing', False)

        from timetable.views import _resolve_department_for_user
        user_role = (getattr(request.user, "role", "") or "").upper()
        hod_dept = _resolve_department_for_user(request.user) if user_role == "HOD" else None
        if hod_dept:
            department_id = hod_dept.id

        if not department_id or not semester_id:
            return Response({"error": "department_id and semester_id are required."}, status=status.HTTP_400_BAD_REQUEST)

        if not batches_data or not isinstance(batches_data, list):
            return Response({"error": "batches list is required and cannot be empty."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            from academics.models import SemesterFinalization
            if SemesterFinalization.objects.filter(department_id=department_id, semester_id=semester_id, academic_year_id=academic_year_id, is_finalized=True).exists():
                return Response({"error": "This semester is finalized and locked. Lab batches cannot be modified."}, status=status.HTTP_400_BAD_REQUEST)
        except Exception:
            pass

        dept = Department.objects.filter(id=department_id).first()
        sem = Semester.objects.filter(id=semester_id).first()
        ay = AcademicYear.objects.filter(id=academic_year_id).first() if academic_year_id else None

        if not dept or not sem:
            return Response({"error": "Invalid department or semester."}, status=status.HTTP_400_BAD_REQUEST)

        seen_students = set()
        for b_entry in batches_data:
            s_ids = b_entry.get('student_ids', [])
            for sid in s_ids:
                if sid in seen_students:
                    return Response({"error": f"Student with ID {sid} is assigned to multiple batches in the request."}, status=status.HTTP_400_BAD_REQUEST)
                seen_students.add(sid)

        created_batches = []
        with transaction.atomic():
            for b_entry in batches_data:
                b_name = (b_entry.get('name') or "").strip()
                s_ids = b_entry.get('student_ids', [])
                if not b_name:
                    continue

                batch_obj, _ = LabBatch.objects.get_or_create(
                    department=dept,
                    semester=sem,
                    academic_year=ay,
                    name=b_name,
                    subject=None,
                    defaults={'created_by': request.user}
                )

                if replace_existing:
                    LabBatchStudent.objects.filter(batch=batch_obj).delete()

                new_mappings = [
                    LabBatchStudent(batch=batch_obj, student_id=sid)
                    for sid in s_ids
                ]
                LabBatchStudent.objects.bulk_create(new_mappings, ignore_conflicts=True)

                created_batches.append({
                    "id": batch_obj.id,
                    "name": batch_obj.name,
                    "identifier": getattr(batch_obj, "identifier", batch_obj.name),
                    "student_count": len(s_ids),
                    "department": dept.name,
                    "semester": sem.sem_number,
                })

            AttendanceAuditLog.objects.create(
                user=request.user,
                action="CREATE_SHARED_BATCHES",
                details=f"Created/Configured {len(created_batches)} shared lab batches for {dept.name} Sem {sem.sem_number}."
            )

        return Response({
            "message": f"Successfully created {len(created_batches)} shared lab batches!",
            "batches": created_batches,
            "total_assigned_students": len(seen_students),
        }, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'])
    def reassign_students(self, request):
        """
        API to reassign student(s) between batches safely preserving historical records.
        """
        self._check_hod_permission(request)
        target_batch_id = request.data.get('target_batch_id')
        student_ids = request.data.get('student_ids', [])

        if not target_batch_id or not student_ids:
            return Response({"error": "target_batch_id and student_ids are required."}, status=status.HTTP_400_BAD_REQUEST)

        target_batch = LabBatch.objects.filter(id=target_batch_id).first()
        if not target_batch:
            return Response({"error": "Target batch not found."}, status=status.HTTP_404_NOT_FOUND)

        dept = target_batch.department
        sem = target_batch.semester

        with transaction.atomic():
            LabBatchStudent.objects.filter(
                batch__department=dept,
                batch__semester=sem,
                student_id__in=student_ids
            ).delete()

            new_mappings = [
                LabBatchStudent(batch=target_batch, student_id=sid)
                for sid in student_ids
            ]
            LabBatchStudent.objects.bulk_create(new_mappings, ignore_conflicts=True)

            AttendanceAuditLog.objects.create(
                user=request.user,
                action="REASSIGN_STUDENTS",
                details=f"Reassigned {len(student_ids)} students to {target_batch.name} in {dept.name if dept else ''} Sem {sem.sem_number if sem else ''}."
            )

        return Response({
            "message": f"Successfully reassigned {len(student_ids)} students to {target_batch.name}."
        }, status=status.HTTP_200_OK)


# ==========================================
# 8. Attendance Audit Log View
# ==========================================
class AttendanceAuditLogListView(generics.ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = AttendanceAuditLogSerializer
    queryset = AttendanceAuditLog.objects.all().order_by('-timestamp')


# ==========================================
# 9. Extra Class Session Management ViewSet
# ==========================================
class ExtraClassSessionViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = ExtraClassSessionSerializer

    def get_queryset(self):
        user = self.request.user
        role = (getattr(user, "role", "") or "").upper()
        if role == "FACULTY":
            role = "PROFESSOR"

        qs = ExtraClassSession.objects.select_related('subject', 'faculty', 'batch', 'created_by', 'reviewed_by').all()

        if role == "PROFESSOR":
            from timetable.views import _resolve_faculty_for_user
            fac = _resolve_faculty_for_user(user)
            if fac:
                qs = qs.filter(faculty=fac)
            else:
                qs = qs.none()
        elif role == "HOD":
            from timetable.views import _resolve_department_for_user, _resolve_faculty_for_user
            dept = _resolve_department_for_user(user)
            fac = _resolve_faculty_for_user(user)
            dept_q = Q(subject__department=dept) if dept else Q()
            fac_q = Q(faculty=fac) if fac else Q()
            qs = qs.filter(dept_q | fac_q).distinct()

        # Role-based scoping for Principal / Admin:
        if role in ["PRINCIPAL", "SYSTEM"] or user.is_superuser:
            dept_id = self.request.query_params.get('department_id')
            if dept_id:
                qs = qs.filter(Q(subject__department_id=dept_id) | Q(faculty__department_id=dept_id))

        # Additional query filters
        status_param = self.request.query_params.get('status')
        if status_param:
            st = status_param.strip().upper()
            if st == "CONDUCTED":
                qs = qs.filter(Q(attendance_sessions__isnull=False) | Q(status="COMPLETED")).distinct()
            elif st == "SCHEDULED":
                qs = qs.filter(status__in=["APPROVED", "PENDING"], attendance_sessions__isnull=True)
            elif st == "CANCELLED":
                qs = qs.filter(status="CANCELLED")
            else:
                qs = qs.filter(status=st)

        effective_status = self.request.query_params.get('effective_status')
        if effective_status:
            est = effective_status.strip().upper()
            if est == "CONDUCTED":
                qs = qs.filter(Q(attendance_sessions__isnull=False) | Q(status="COMPLETED")).distinct()
            elif est == "SCHEDULED":
                qs = qs.filter(status__in=["APPROVED", "PENDING"], attendance_sessions__isnull=True)
            elif est == "CANCELLED":
                qs = qs.filter(status="CANCELLED")

        session_type = self.request.query_params.get('session_type') or self.request.query_params.get('class_type')
        if session_type and session_type.upper() in ["THEORY", "LAB"]:
            qs = qs.filter(session_type=session_type.upper())

        faculty_id = self.request.query_params.get('faculty_id')
        if faculty_id:
            qs = qs.filter(faculty_id=faculty_id)

        faculty_name = self.request.query_params.get('faculty_name')
        if faculty_name:
            qs = qs.filter(faculty__name__icontains=faculty_name)

        subject_id = self.request.query_params.get('subject_id')
        if subject_id:
            qs = qs.filter(subject_id=subject_id)

        academic_year = self.request.query_params.get('academic_year')
        if academic_year:
            if academic_year.isdigit():
                qs = qs.filter(subject__subjectassignment__academic_year_id=int(academic_year)).distinct()
            else:
                qs = qs.filter(subject__subjectassignment__academic_year__year_name=academic_year).distinct()

        date_param = self.request.query_params.get('date')
        if date_param:
            qs = qs.filter(date=date_param)

        date_from = self.request.query_params.get('date_from')
        if date_from:
            qs = qs.filter(date__gte=date_from)

        date_to = self.request.query_params.get('date_to')
        if date_to:
            qs = qs.filter(date__lte=date_to)

        search = self.request.query_params.get('search')
        if search:
            search_str = search.strip()
            qs = qs.filter(
                Q(faculty__name__icontains=search_str) |
                Q(faculty__faculty_id__icontains=search_str) |
                Q(subject__subject_code__icontains=search_str) |
                Q(subject__subject_name__icontains=search_str) |
                Q(reason__icontains=search_str) |
                Q(room__icontains=search_str)
            ).distinct()

        return qs.order_by('-date', '-start_time')

    @action(detail=False, methods=['get'])
    def stats(self, request):
        qs = self.get_queryset()
        total_classes = qs.count()
        conducted_classes = qs.filter(
            Q(attendance_sessions__isnull=False) | Q(status="COMPLETED")
        ).distinct().count()
        theory_classes = qs.filter(session_type="THEORY").count()
        lab_classes = qs.filter(session_type="LAB").count()
        cancelled_classes = qs.filter(status="CANCELLED").count()
        scheduled_classes = total_classes - conducted_classes - cancelled_classes

        return Response({
            "total_extra_classes": total_classes,
            "conducted_classes": conducted_classes,
            "theory_classes": theory_classes,
            "lab_classes": lab_classes,
            "scheduled_classes": max(0, scheduled_classes),
            "cancelled_classes": cancelled_classes,
        })

    def perform_create(self, serializer):
        from timetable.views import _resolve_faculty_for_user
        fac = _resolve_faculty_for_user(self.request.user)
        if not fac:
            raise PermissionDenied("Faculty profile not found for user.")

        subject = serializer.validated_data.get('subject')
        # Scoping check: verify professor/teaching HOD is assigned to this subject
        if not SubjectAssignment.objects.filter(subject=subject, faculty=fac).exists():
            user_role = (getattr(self.request.user, "role", "") or "").upper()
            if user_role != "HOD" or (subject.department and subject.department != getattr(fac, 'department', None)):
                raise PermissionDenied("You can only request extra classes for your officially assigned subjects.")

        date_val = serializer.validated_data.get('date')
        today = timezone.localdate()
        if date_val < today:
            from rest_framework.exceptions import ValidationError
            raise ValidationError("Extra classes cannot be scheduled for past dates.")

        extra = serializer.save(
            faculty=fac,
            created_by=self.request.user,
            status="APPROVED"
        )

        # Notify HOD(s) automatically with required details: professor name, subject, department, semester, and date
        dept = subject.department or getattr(fac, 'department', None)
        hod_users = set()
        if dept:
            from hod_assignment.models import HODAssignment
            for ha in HODAssignment.objects.filter(department=dept, end_date__isnull=True).select_related('faculty__user'):
                if ha.faculty and ha.faculty.user:
                    hod_users.add(ha.faculty.user)
            from django.contrib.auth import get_user_model
            User = get_user_model()
            for u in User.objects.filter(role__iexact='HOD', department=dept):
                hod_users.add(u)
            for u in User.objects.filter(role__iexact='HOD', faculty_profile__department=dept):
                hod_users.add(u)

        if not hod_users:
            from django.contrib.auth import get_user_model
            User = get_user_model()
            for u in User.objects.filter(role__iexact='HOD'):
                hod_users.add(u)

        sem_num = getattr(subject.semester, 'sem_number', None) if subject.semester else None
        sem_text = f"Semester {sem_num}" if sem_num else "N/A"
        dept_text = dept.name if dept else "N/A"

        from announcements.models import Notification
        notif_title = f"Extra Class Scheduled: {subject.subject_code} - Prof. {fac.name}"
        notif_message = (
            f"Professor: {fac.name}\n"
            f"Subject: {subject.subject_code} ({subject.subject_name})\n"
            f"Department: {dept_text}\n"
            f"Semester: {sem_text}\n"
            f"Date: {extra.date.strftime('%d-%m-%Y')} ({extra.start_time.strftime('%H:%M')} - {extra.end_time.strftime('%H:%M')})"
        )

        for hod_user in hod_users:
            try:
                Notification.objects.create(
                    recipient=hod_user,
                    title=notif_title,
                    message=notif_message,
                    notification_type="ATTENDANCE"
                )
            except Exception:
                pass

        AttendanceAuditLog.objects.create(
            user=self.request.user,
            action="CONDUCT_EXTRA_CLASS",
            details=f"Extra class conducted/scheduled by {fac.name} for {subject.subject_code} on {extra.date}. Auto-approved and HOD notified."
        )

    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        extra = self.get_object()
        from timetable.views import _resolve_faculty_for_user
        fac = _resolve_faculty_for_user(request.user)
        if (fac and extra.faculty_id != fac.id) and extra.created_by != request.user and not request.user.is_superuser:
            return Response({"error": "You can only cancel your own extra class requests."}, status=status.HTTP_403_FORBIDDEN)
        if extra.status in ["COMPLETED", "CANCELLED"]:
            return Response({"error": f"Cannot cancel an extra class with status '{extra.status}'."}, status=status.HTTP_400_BAD_REQUEST)

        extra.status = "CANCELLED"
        extra.save(update_fields=['status'])
        return Response({"message": "Extra class request cancelled successfully.", "status": "CANCELLED"})

    @action(detail=True, methods=['post'])
    def review(self, request, pk=None):
        extra = self.get_object()
        user_role = (getattr(request.user, "role", "") or "").upper()
        if user_role not in ["HOD", "PRINCIPAL", "SYSTEM"] and not request.user.is_superuser:
            return Response({"error": "Only HOD, Principal, or Administrator can review extra class requests."}, status=status.HTTP_403_FORBIDDEN)

        if user_role == "HOD" and not (request.user.is_superuser or user_role in ["PRINCIPAL", "SYSTEM"]):
            from timetable.views import _resolve_department_for_user
            dept = _resolve_department_for_user(request.user)
            req_dept = extra.subject.department if extra.subject else (extra.faculty.department if extra.faculty else None)
            if not dept or (req_dept and req_dept != dept):
                return Response({"error": "HOD can only review extra class requests within their own department."}, status=status.HTTP_403_FORBIDDEN)

        from timetable.views import _resolve_faculty_for_user
        fac = _resolve_faculty_for_user(request.user)

        # Strictly prevent self-approval:
        if (fac and extra.faculty_id == fac.id) or extra.created_by == request.user:
            if user_role not in ["PRINCIPAL", "SYSTEM"] and not request.user.is_superuser:
                return Response({
                    "error": "Self-approval is strictly prohibited. As the requesting faculty, your extra class request must be reviewed and approved by the Principal or Administrator."
                }, status=status.HTTP_403_FORBIDDEN)

        action_type = (request.data.get("action") or "").upper()
        remarks = request.data.get("remarks", "").strip()

        if action_type not in ["APPROVE", "REJECT"]:
            return Response({"error": "action must be APPROVE or REJECT."}, status=status.HTTP_400_BAD_REQUEST)

        if action_type == "APPROVE":
            # Timetable conflict check
            day_map = {0: 'MON', 1: 'TUE', 2: 'WED', 3: 'THU', 4: 'FRI', 5: 'SAT', 6: 'SUN'}
            day_code = day_map.get(extra.date.weekday(), 'MON')

            # 1. Faculty conflict with regular slots:
            faculty_slot_conflict = TimeTableSlot.objects.filter(
                timetable__status="Approved",
                timetable__is_active=True,
                assignment__faculty=extra.faculty,
                day=day_code,
                start_time__lt=extra.end_time,
                end_time__gt=extra.start_time
            ).first()

            # 2. Faculty conflict with other approved extra classes on same date:
            extra_conflict = ExtraClassSession.objects.filter(
                faculty=extra.faculty,
                date=extra.date,
                status="APPROVED",
                start_time__lt=extra.end_time,
                end_time__gt=extra.start_time
            ).exclude(pk=extra.pk).first()

            conflict_warning = None
            if faculty_slot_conflict:
                conflict_warning = f"Faculty has regular timetable slot ({faculty_slot_conflict.assignment.subject.subject_code} {faculty_slot_conflict.start_time}-{faculty_slot_conflict.end_time}) at this time."
            elif extra_conflict:
                conflict_warning = f"Faculty has another approved extra class ({extra_conflict.subject.subject_code} {extra_conflict.start_time}-{extra_conflict.end_time}) at this time."

            extra.status = "APPROVED"
            extra.reviewed_by = request.user
            extra.reviewed_at = timezone.now()
            extra.remarks = remarks
            extra.save()

            AttendanceAuditLog.objects.create(
                user=request.user,
                action="APPROVE_EXTRA_CLASS",
                details=f"Approved extra class for {extra.subject.subject_code} on {extra.date} ({extra.start_time}-{extra.end_time})." + (f" Warning: {conflict_warning}" if conflict_warning else "")
            )

            resp_data = {
                "message": "Extra class request approved successfully.",
                "status": "APPROVED",
                "conflict_warning": conflict_warning
            }
            return Response(resp_data, status=status.HTTP_200_OK)

        else:
            extra.status = "REJECTED"
            extra.reviewed_by = request.user
            extra.reviewed_at = timezone.now()
            extra.remarks = remarks
            extra.save()

            AttendanceAuditLog.objects.create(
                user=request.user,
                action="REJECT_EXTRA_CLASS",
                details=f"Rejected extra class for {extra.subject.subject_code} on {extra.date}. Remarks: {remarks}"
            )

            return Response({
                "message": "Extra class request rejected.",
                "status": "REJECTED"
            }, status=status.HTTP_200_OK)


# ==========================================
# 10. Today's Scheduled Sessions View (Regular + Approved Extra)
# ==========================================
class TodaySessionsView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        from timetable.views import _resolve_faculty_for_user
        fac = _resolve_faculty_for_user(request.user)
        if not fac:
            return Response({"error": "Faculty profile not found."}, status=status.HTTP_404_NOT_FOUND)

        today = timezone.localdate()
        day_map = {0: 'MON', 1: 'TUE', 2: 'WED', 3: 'THU', 4: 'FRI', 5: 'SAT', 6: 'SUN'}
        day_code = day_map.get(today.weekday(), 'MON')
        day_name = today.strftime("%A")

        # Regular active timetable slots for today
        slots = TimeTableSlot.objects.filter(
            timetable__status="Approved",
            timetable__is_active=True,
            assignment__faculty=fac,
            day=day_code
        ).select_related(
            'assignment__subject', 'assignment__department', 'assignment__semester', 'timetable'
        ).order_by('start_time')

        regular_data = [
            {
                "slot_id": s.id,
                "subject_id": s.assignment.subject.id,
                "subject_code": s.assignment.subject.subject_code,
                "subject_name": s.assignment.subject.subject_name,
                "semester": getattr(s.assignment.semester, 'sem_number', s.assignment.subject.semester_id),
                "department_name": getattr(s.assignment.department, 'name', ''),
                "start_time": s.start_time.strftime("%H:%M"),
                "end_time": s.end_time.strftime("%H:%M"),
                "session_type": "THEORY",
                "is_extra_class": False,
            }
            for s in slots
        ]

        # Approved extra classes for today
        extras = ExtraClassSession.objects.filter(
            faculty=fac,
            date=today,
            status__in=["APPROVED", "COMPLETED"]
        ).select_related('subject', 'batch').order_by('start_time')

        extra_data = [
            {
                "extra_class_id": e.id,
                "subject_id": e.subject.id,
                "subject_code": e.subject.subject_code,
                "subject_name": e.subject.subject_name,
                "session_type": e.session_type,
                "batch_id": e.batch.id if e.batch else None,
                "batch_name": e.batch.name if e.batch else "",
                "start_time": e.start_time.strftime("%H:%M"),
                "end_time": e.end_time.strftime("%H:%M"),
                "duration_minutes": e.duration_minutes,
                "room": e.room,
                "status": e.status,
                "is_extra_class": True,
            }
            for e in extras
        ]

        return Response({
            "date": today.isoformat(),
            "day_name": day_name,
            "day_code": day_code,
            "regular_slots": regular_data,
            "extra_classes": extra_data,
            "total_today_sessions": len(regular_data) + len(extra_data)
        }, status=status.HTTP_200_OK)


