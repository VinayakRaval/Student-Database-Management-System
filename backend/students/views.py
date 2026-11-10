from rest_framework import generics, status

from rest_framework.response import Response

from rest_framework.permissions import IsAuthenticated, AllowAny,IsAdminUser

from .models import Student, StudentAcademicHistory

from .serializers import StudentSerializer, StudentAcademicHistorySerializer

from rest_framework import generics

from academics.models import Semester, AcademicYear, Department

from django.utils import timezone

from rest_framework.decorators import api_view, permission_classes

from rest_framework import status

from .utils import send_approval_email

from django_filters.rest_framework import DjangoFilterBackend

from rest_framework import filters

from django.db import models as db_models, transaction

from attendance.models import AttendanceRecord, AttendanceSession

from ia_assessment.models import IAMark, IATestSetup

from external_results.models import ExternalResult

from fees.models import StudentFee, FeePayment

from library.models import IssueRecord, Fine

from subjects.models import Subject







# Your existing Create, List, DetailUpdate views

class StudentCreateView(generics.CreateAPIView):
    queryset = Student.objects.all()
    serializer_class = StudentSerializer
    permission_classes = [AllowAny]

    def create(self, request, *args, **kwargs):
        response = super().create(request, *args, **kwargs)
        student = Student.objects.select_related('user', 'department').get(id=response.data['id'])

        user = request.user if request.user and request.user.is_authenticated else None
        role = (getattr(user, "role", "") or "").upper() if user else ""
        if user and (role in ["ADMISSION", "PRINCIPAL", "SYSTEM", "HOD"] or user.is_staff):
            student.registration_status = 'approved'
            student.status = 'active'
            student.save(update_fields=['registration_status', 'status'])
            if student.user:
                student.user.is_active = True
                student.user.save(update_fields=['is_active'])

        temp_password = getattr(student, '_temporary_password', None)
        if not temp_password and student.user:
            from userlogin.password_service import set_temporary_password_for_user
            from userlogin.models import PasswordAuditLog
            temp_password = set_temporary_password_for_user(
                user=student.user,
                actor=user,
                action=PasswordAuditLog.ACTION_INITIAL_CREATION,
                request=request
            )

        response.data['admission_id'] = student.admission_id
        response.data['registration_status'] = student.registration_status
        response.data['status'] = student.status
        response.data['temporary_password'] = temp_password
        response.data['message'] = f"Student registration successful. Admission ID: {student.admission_id}"
        return response

class StudentListView(generics.ListAPIView):

    queryset = Student.objects.all()

    serializer_class = StudentSerializer

    permission_classes = [IsAuthenticated]

    filter_backends = [DjangoFilterBackend, filters.SearchFilter]

    filterset_fields = ["registration_status", "department", "semester"]

    search_fields = ["name", "usn", "email", "admission_id", "cet_no"]



    def get_queryset(self):

        user = self.request.user

        role = (getattr(user, "role", "") or "").upper()

        queryset = Student.objects.all().select_related("department", "semester", "academic_year").order_by("-id")



        if role == "STUDENT":

            # Students can only access their own student record

            return queryset.filter(user=user)



        if role == "HOD":

            # If requesting assigned/teaching students only (Faculty Access -> My Students):

            if self.request.GET.get("assigned_only") == "true" or self.request.GET.get("teaching_only") == "true":

                from timetable.views import _resolve_faculty_for_user

                from subjects.models import SubjectAssignment

                fac = _resolve_faculty_for_user(user)

                if not fac:

                    return Student.objects.none()



                assignments = SubjectAssignment.objects.filter(faculty=fac).select_related('subject', 'department', 'semester')

                if not assignments.exists():

                    return Student.objects.none()



                from django.db.models import Q

                q_filter = Q()

                for a in assignments:

                    d_id = a.department_id or (a.subject.department_id if a.subject else None)

                    s_id = a.semester_id or (a.subject.semester_id if a.subject else None)

                    if d_id and s_id:

                        q_filter |= Q(department_id=d_id, semester_id=s_id)

                    elif d_id:

                        q_filter |= Q(department_id=d_id)

                    elif s_id:

                        q_filter |= Q(semester_id=s_id)



                subject_param = self.request.GET.get("subject_id")

                if subject_param and str(subject_param).isdigit():

                    assign = assignments.filter(subject_id=int(subject_param)).first()

                    if assign:

                        sub_dept = assign.department_id or (assign.subject.department_id if assign.subject else None)

                        sub_sem = assign.semester_id or (assign.subject.semester_id if assign.subject else None)

                        if sub_dept:

                            queryset = queryset.filter(department_id=sub_dept)

                        if sub_sem:

                            queryset = queryset.filter(semester_id=sub_sem)

                    else:

                        return Student.objects.none()

                elif q_filter:

                    queryset = queryset.filter(q_filter)

                else:

                    return Student.objects.none()

            else:

                from timetable.views import _resolve_department_for_user

                dept = _resolve_department_for_user(user)

                if dept:

                    # Enforce HOD department, ignore client param trying to see other departments

                    queryset = queryset.filter(department=dept)

                else:

                    return Student.objects.none()

        elif role in ["PROFESSOR", "FACULTY"]:

            from timetable.views import _resolve_faculty_for_user

            from subjects.models import SubjectAssignment

            fac = _resolve_faculty_for_user(user)

            if not fac:

                return Student.objects.none()



            assignments = SubjectAssignment.objects.filter(faculty=fac).select_related('subject')

            assigned_dept_ids = set()

            for a in assignments:

                d_id = a.department_id or (a.subject.department_id if a.subject else None)

                if d_id:

                    assigned_dept_ids.add(d_id)

            if fac.department_id:

                assigned_dept_ids.add(fac.department_id)



            subject_param = self.request.GET.get("subject_id")
            if subject_param and str(subject_param).isdigit():
                assign = assignments.filter(subject_id=int(subject_param)).first()
                if assign:
                    # Enforce elective student isolation
                    if getattr(assign.subject, 'is_elective', False):
                        from subjects.models import ElectiveSubjectEnrollment
                        enrolled_qs = ElectiveSubjectEnrollment.objects.filter(
                            subject=assign.subject, is_active=True
                        )
                        if assign.academic_year_id:
                            enrolled_qs = enrolled_qs.filter(academic_year_id=assign.academic_year_id)
                        student_ids = list(enrolled_qs.values_list('student_id', flat=True))
                        if not student_ids:
                            return Student.objects.none()
                        queryset = queryset.filter(id__in=student_ids)
                    else:
                        sub_dept = assign.department_id or (assign.subject.department_id if assign.subject else None)
                        sub_sem = assign.semester_id or (assign.subject.semester_id if assign.subject else None)
                        if sub_dept:
                            queryset = queryset.filter(department_id=sub_dept)
                        if sub_sem:
                            queryset = queryset.filter(semester_id=sub_sem)
                        if assign.academic_year_id:
                            queryset = queryset.filter(academic_year_id=assign.academic_year_id)
                else:
                    return Student.objects.none()

            elif assigned_dept_ids:

                dept_req = self.request.GET.get("department")

                if dept_req and str(dept_req).isdigit() and int(dept_req) in assigned_dept_ids:

                    queryset = queryset.filter(department_id=int(dept_req))

                else:

                    queryset = queryset.filter(department_id__in=assigned_dept_ids)

            else:

                return Student.objects.none()

        else:

            # PRINCIPAL, ADMISSION, ACCOUNTS, SYSTEM, superuser

            dept_param = self.request.GET.get("department")

            if dept_param:

                queryset = queryset.filter(department_id=dept_param)



        status_param = self.request.GET.get("registration_status")

        if status_param:

            queryset = queryset.filter(registration_status=status_param)



        sem_param = self.request.GET.get("semester")

        if sem_param:

            queryset = queryset.filter(semester_id=sem_param)



        return queryset



class StudentDetailUpdateView(generics.RetrieveUpdateDestroyAPIView):

    queryset = Student.objects.all()

    serializer_class = StudentSerializer

    lookup_field = 'id'

    permission_classes = [IsAuthenticated]



    def get_object(self):

        obj = super().get_object()

        user = self.request.user

        role = (getattr(user, "role", "") or "").upper()



        if role == "STUDENT":

            if obj.user_id != user.id:

                raise PermissionDenied("Students can only view or manage their own record.")

        elif role == "HOD":

            from timetable.views import _resolve_department_for_user

            dept = _resolve_department_for_user(user)

            if not dept or obj.department_id != dept.id:

                raise PermissionDenied("HOD can only view or manage students in their own department.")

        return obj



    def perform_update(self, serializer):

        user = self.request.user

        role = (getattr(user, "role", "") or "").upper()



        if role in ["PROFESSOR", "FACULTY"]:

            raise PermissionDenied("Faculty/Professors are not authorized to modify official student records.")



        if role == "STUDENT":

            # Prevent student from modifying sensitive fields

            forbidden_fields = ['department', 'department_id', 'semester', 'semester_id',

                               'academic_year', 'academic_year_id', 'registration_status',

                               'status', 'usn', 'admission_id', 'seat_type']

            for f in forbidden_fields:

                if f in self.request.data:

                    raise PermissionDenied(f"Students are not authorized to modify '{f}'.")



        serializer.save()



    def perform_destroy(self, instance):

        user = self.request.user

        role = (getattr(user, "role", "") or "").upper()



        if role not in ["PRINCIPAL", "ADMISSION", "SYSTEM"] and not user.is_superuser:

            raise PermissionDenied("Only Principal or Admission Office has permission to delete student records.")



        u = instance.user

        instance.delete()

        if u:

            u.delete()



class AssignUSNView(generics.UpdateAPIView):

    queryset = Student.objects.all()

    serializer_class = StudentSerializer

    lookup_field = 'id'

    permission_classes = [IsAuthenticated]



    def update(self, request, *args, **kwargs):

        student = self.get_object()

        usn = request.data.get('usn', '').strip()

        if not usn:

            return Response({'error': 'USN required'}, status=status.HTTP_400_BAD_REQUEST)

        student.usn = usn

        student.save(update_fields=['usn'])



        if student.user:

            student.user.usn = usn

            if not student.user.user_id or student.user.user_id.startswith('GECC'):

                student.user.user_id = usn

            student.user.save(update_fields=['usn', 'user_id'])



        return Response({'status': 'USN assigned', 'usn': usn}, status=status.HTTP_200_OK)



    def post(self, request, *args, **kwargs):

        return self.update(request, *args, **kwargs)







# Step 2: Department Verification (HOD and Admission roles)

class DepartmentVerificationView(generics.UpdateAPIView):

    queryset = Student.objects.all()

    serializer_class = StudentSerializer

    permission_classes = [IsAuthenticated]

    lookup_field = 'id'



    def update(self, request, *args, **kwargs):

        user = request.user

        role = (getattr(user, "role", "") or "").upper()

        is_hod = role == "HOD" or (hasattr(user, "faculty_profile") and getattr(user.faculty_profile, "role", "").upper() == "HOD")

        is_admission = role == "ADMISSION"

        if not (is_hod or is_admission or role == "PRINCIPAL" or user.is_staff or user.is_superuser):

            return Response({"error": "Only HOD, Admission Officer, or Admin can verify student registrations."}, status=status.HTTP_403_FORBIDDEN)



        student = self.get_object()

        if is_hod and not (user.is_staff or user.is_superuser or role in ["PRINCIPAL", "SYSTEM", "ADMISSION"]):

            from timetable.views import _resolve_department_for_user

            dept = _resolve_department_for_user(user)

            if not dept or student.department_id != dept.id:

                return Response({"error": "HOD can only verify students in their own department."}, status=status.HTTP_403_FORBIDDEN)



        student.registration_status = 'verified'

        student.save(update_fields=['registration_status'])

        return Response({

            'status': 'Student registration verified',

            'registration_status': 'verified'

        }, status=status.HTTP_200_OK)



    def post(self, request, *args, **kwargs):

        return self.update(request, *args, **kwargs)



# Step 3: Principal Approval (Principal role)

class PrincipalApprovalView(generics.UpdateAPIView):

    serializer_class = StudentSerializer

    permission_classes = [IsAuthenticated]

    lookup_field = 'id'



    def get_queryset(self):

        return Student.objects.all()



    def post(self, request, *args, **kwargs):

        return self.update(request, *args, **kwargs)



    def update(self, request, *args, **kwargs):

        user = request.user

        role = (getattr(user, "role", "") or "").upper()

        if not (role == "PRINCIPAL" or user.is_staff or user.is_superuser):

            return Response({"error": "Only Principal can approve student registrations."}, status=status.HTTP_403_FORBIDDEN)



        student = self.get_object()

        action = request.data.get('action')



        if student.registration_status != 'verified' and action == 'approve':

            # Allow principal override if needed or require verification

            student.registration_status = 'verified'



        if action == 'approve':
            student.registration_status = 'approved'
            student.status = 'active'
            student.save()

            temp_password = None
            if student.user:
                student.user.is_active = True
                student.user.force_password_change = True
                student.user.save(update_fields=['is_active', 'force_password_change'])

                if not student.user.has_usable_password():
                    from userlogin.password_service import set_temporary_password_for_user
                    from userlogin.models import PasswordAuditLog
                    temp_password = set_temporary_password_for_user(
                        user=student.user,
                        actor=user,
                        action=PasswordAuditLog.ACTION_INITIAL_CREATION,
                        request=request
                    )

            resp_data = {
                "message": f"Student {student.name} approved successfully.",
                "registration_status": student.registration_status,
                "status": student.status,
                "admission_id": student.admission_id,
            }
            if temp_password:
                resp_data["temporary_password"] = temp_password
            return Response(resp_data, status=status.HTTP_200_OK)



        elif action == 'reject':

            student.registration_status = 'rejected'

            student.save()

            return Response(

                {"status": "Student registration rejected by principal", "registration_status": "rejected"},

                status=status.HTTP_200_OK

            )



        return Response(

            {"error": "Invalid action value. Use 'approve' or 'reject'"},

            status=status.HTTP_400_BAD_REQUEST

        )





@api_view(['POST'])
@permission_classes([IsAuthenticated])
def reset_student_password(request, id):
    """
    Generates a new secure temporary password for a student.
    Enforces role permissions, strict HOD department isolation, and logs audit events without secrets.
    """
    user = request.user
    role = (getattr(user, "role", "") or "").upper()
    is_admin = user.is_staff or role in ["PRINCIPAL", "SYSTEM", "ADMISSION"]
    is_hod = role == "HOD"

    if not (is_admin or is_hod):
        return Response({"error": "Unauthorized to reset student passwords."}, status=status.HTTP_403_FORBIDDEN)

    try:
        student = Student.objects.select_related('user', 'department').get(id=id)
    except Student.DoesNotExist:
        return Response({"error": "Student not found."}, status=status.HTTP_404_NOT_FOUND)

    if is_hod and not is_admin:
        from timetable.views import _resolve_department_for_user
        dept = _resolve_department_for_user(user)
        if not dept or student.department != dept:
            return Response(
                {"error": f"Access Denied: As HOD of {getattr(dept, 'name', 'your department')}, you can only manage students within your department."},
                status=status.HTTP_403_FORBIDDEN
            )

    if not student.user:
        return Response({"error": "Student has no linked login account."}, status=status.HTTP_400_BAD_REQUEST)

    from userlogin.password_service import set_temporary_password_for_user
    from userlogin.models import PasswordAuditLog

    temp_password = set_temporary_password_for_user(
        user=student.user,
        actor=user,
        action=PasswordAuditLog.ACTION_RESET,
        request=request
    )

    return Response({
        "message": f"Password for {student.name} has been reset successfully.",
        "temporary_password": temp_password,
        "usn": student.usn,
        "admission_id": student.admission_id,
        "student_name": student.name,
        "email": student.email
    }, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def resend_student_invitation(request, id):
    """
    Backward compatibility alias: delegates directly to reset_student_password.
    """
    return reset_student_password(request._request if hasattr(request, '_request') else request, id)

class StudentDetailView(generics.RetrieveAPIView):

    queryset = Student.objects.all()

    serializer_class = StudentSerializer

    permission_classes = [IsAuthenticated]



    def get_object(self):

        return self.queryset.get(user=self.request.user)

    



def sync_student_academic_history(student, current_user=None, remarks=None):

    """

    Idempotent helper to ensure all historical semesters for a student have

    corresponding StudentAcademicHistory records with aggregated stats.

    """

    if not student.semester:

        return []



    max_sem = student.semester.sem_number

    semesters = Semester.objects.filter(sem_number__lte=max_sem).order_by('sem_number')

    histories = []



    for sem in semesters:

        records = AttendanceRecord.objects.filter(student=student, session__subject__semester=sem)

        tot_att = records.count()

        att_cnt = records.filter(status__iexact='Present').count()

        att_pct = round((att_cnt / tot_att * 100), 2) if tot_att > 0 else None



        marks = IAMark.objects.filter(student=student, ia_test__subject__semester=sem)

        ia_obtained = None

        ia_total = None

        if marks.exists():

            ia_obtained = sum([float(m.obtained_marks or 0) for m in marks])

            ia_total = sum([float(m.ia_test.max_marks or 0) for m in marks])



        res = None

        if student.user:

            res = ExternalResult.objects.filter(student=student.user, semester=sem).first()

        sgpa = res.sgpa if res else None

        credits_earned = res.credits_cleared if res else 0

        backlogs = res.backlogs_count if res else 0



        status_at_time = 'enrolled'

        if sem.sem_number < max_sem:

            status_at_time = 'promoted'

        elif student.status in ['graduated', 'passed_out', 'alumni']:

            status_at_time = student.status



        ay = student.academic_year

        history, _ = StudentAcademicHistory.objects.update_or_create(

            student=student,

            semester=sem,

            academic_year=ay,

            defaults={

                'department': student.department,

                'status_at_time': status_at_time,

                'attendance_percentage': att_pct,

                'total_classes': tot_att,

                'attended_classes': att_cnt,

                'ia_marks_obtained': ia_obtained,

                'ia_marks_total': ia_total,

                'sgpa': sgpa,

                'credits_earned': credits_earned,

                'backlogs_count': backlogs,

                'promoted_by': current_user if current_user and current_user.is_authenticated else None,

                'remarks': remarks or f"Academic record for Semester {sem.sem_number}"

            }

        )

        histories.append(history)

    return histories





@api_view(['PUT', 'POST'])

@permission_classes([IsAuthenticated])

def promote_student(request, id):

    user = request.user

    role = (getattr(user, "role", "") or "").upper()



    if role not in ["HOD", "PRINCIPAL", "SYSTEM"] and not user.is_superuser:

        return Response({"error": "Only HOD or Principal can approve student semester promotions."},

                        status=status.HTTP_403_FORBIDDEN)



    try:

        with transaction.atomic():

            student = Student.objects.select_for_update().get(id=id)



            if role == "HOD":

                from timetable.views import _resolve_department_for_user

                dept = _resolve_department_for_user(user)

                if dept:

                    if student.department_id and student.department_id != dept.id:

                        return Response({"error": "You can only promote students within your own department."},

                                        status=status.HTTP_403_FORBIDDEN)

                    elif not student.department_id:

                        student.department = dept



            # Eligibility validation

            if student.status not in ["active", "promoted"]:

                return Response({"error": f"Student with status '{student.status}' cannot be promoted. Must be active."},

                                status=status.HTTP_400_BAD_REQUEST)

            if student.registration_status != "approved":

                return Response({"error": "Student registration must be approved by Principal before semester promotion."},

                                status=status.HTTP_400_BAD_REQUEST)



            if not student.semester:

                return Response({"error": "Student does not have a semester assigned"},

                                status=status.HTTP_400_BAD_REQUEST)



            current_sem = student.semester



            # Handle final semester graduation

            if current_sem.sem_number >= 8:

                new_status = request.data.get("status", "graduated")

                if new_status not in ["graduated", "passed_out", "alumni", "inactive"]:

                    new_status = "graduated"

                student.status = new_status

                student.save(update_fields=["status"])



                # Snapshot final semester

                sync_student_academic_history(student, current_user=user, remarks=f"Graduated after completing Semester {current_sem.sem_number}")

                StudentAcademicHistory.objects.filter(student=student, semester=current_sem).update(

                    status_at_time=new_status,

                    promoted_at=timezone.now(),

                    promoted_by=user,

                    remarks=f"Completed course / {new_status}"

                )



                if student.user and request.data.get("disable_login", False):

                    student.user.is_active = False

                    student.user.save(update_fields=["is_active"])



                return Response({

                    "message": f"Student {student.name} ({student.usn or student.admission_id}) has completed final semester. Status updated to {new_status}. All historical records preserved.",

                    "status": student.status,

                    "usn": student.usn,

                    "is_graduated": True

                }, status=status.HTTP_200_OK)



            # Promote to next semester

            next_sem = Semester.objects.filter(sem_number=current_sem.sem_number + 1).first()

            if not next_sem:

                return Response({"error": f"Next semester (Semester {current_sem.sem_number + 1}) not configured in system."},

                                status=status.HTTP_400_BAD_REQUEST)



            # Snapshot current semester before promotion

            sync_student_academic_history(student, current_user=user)

            StudentAcademicHistory.objects.filter(student=student, semester=current_sem).update(

                status_at_time='promoted',

                promoted_at=timezone.now(),

                promoted_by=user,

                remarks=request.data.get('remarks', f'Promoted from Semester {current_sem.sem_number} to {next_sem.sem_number}')

            )



            student.semester = next_sem



            # Update academic year safely when progressing from even to odd semester (Sem 2->3, 4->5, 6->7)

            if next_sem.sem_number % 2 == 1 and next_sem.sem_number != 1:

                if student.academic_year and student.academic_year.year_name:

                    import re

                    nums = re.findall(r'\d{4}', student.academic_year.year_name)

                    if len(nums) >= 2:

                        s_yr, e_yr = int(nums[0]) + 1, int(nums[1]) + 1

                        new_ay, _ = AcademicYear.objects.get_or_create(year_name=f"{s_yr}-{e_yr}")

                        student.academic_year = new_ay

                    elif len(nums) == 1:

                        s_yr = int(nums[0]) + 1

                        new_ay, _ = AcademicYear.objects.get_or_create(year_name=f"{s_yr}-{s_yr + 1}")

                        student.academic_year = new_ay



            student.status = 'active'

            student.save()

            # --- Lab Batch Allocation / Retention for New Semester ---
            from attendance.models import LabBatch, LabBatchStudent
            from attendance.views import get_batch_aliases

            next_batches_qs = LabBatch.objects.filter(department=student.department, semester=next_sem)
            if student.academic_year:
                ay_batches = next_batches_qs.filter(academic_year=student.academic_year)
                if ay_batches.exists():
                    next_batches_qs = ay_batches
            next_batches = list(next_batches_qs)

            allocated_batch = None
            if next_batches:
                # 1. Explicit batch ID provided in request
                target_batch_id = request.data.get('lab_batch_id')
                if target_batch_id:
                    allocated_batch = next((b for b in next_batches if b.id == int(target_batch_id)), None)

                # 2. Match previous batch name/alias from current_sem
                if not allocated_batch:
                    prev_batch_link = LabBatchStudent.objects.filter(
                        student=student,
                        batch__semester=current_sem
                    ).select_related('batch').first()

                    if prev_batch_link and prev_batch_link.batch:
                        prev_aliases = get_batch_aliases(prev_batch_link.batch.name)
                        for nb in next_batches:
                            if get_batch_aliases(nb.name).intersection(prev_aliases):
                                allocated_batch = nb
                                break

                # 3. If no matching batch name or new configuration, assign to batch with lowest enrollment
                if not allocated_batch:
                    allocated_batch = min(next_batches, key=lambda b: b.batch_students.count())

                if allocated_batch:
                    LabBatchStudent.objects.get_or_create(batch=allocated_batch, student=student)

            # Create history record for new semester

            sync_student_academic_history(student, current_user=user)



            return Response({

                "message": f"Student promoted from semester {current_sem.sem_number} to {next_sem.sem_number}.",

                "new_semester": next_sem.sem_number,

                "academic_year": student.academic_year.year_name if student.academic_year else None,

                "status": student.status,

                "lab_batch": allocated_batch.name if allocated_batch else None,

                "historical_records_count": student.academic_histories.count()

            }, status=status.HTTP_200_OK)



    except Student.DoesNotExist:

        return Response({"error": "Student not found"}, status=status.HTTP_404_NOT_FOUND)

    except Exception as e:

        return Response({"error": "Internal server error during promotion", "details": str(e)},

                        status=status.HTTP_500_INTERNAL_SERVER_ERROR)





@api_view(['POST'])

@permission_classes([IsAuthenticated])

def update_student_status(request, id):

    user = request.user

    role = (getattr(user, "role", "") or "").upper()

    if role not in ["HOD", "PRINCIPAL", "SYSTEM"] and not user.is_superuser:

        return Response({"error": "Unauthorized to change student academic status."}, status=status.HTTP_403_FORBIDDEN)



    try:

        student = Student.objects.get(id=id)

        new_status = request.data.get("status")

        remarks = request.data.get("remarks", "")

        if new_status not in ["active", "promoted", "graduated", "passed_out", "alumni", "left", "inactive"]:

            return Response({"error": f"Invalid status '{new_status}'."}, status=status.HTTP_400_BAD_REQUEST)



        student.status = new_status

        student.save(update_fields=["status"])



        if student.semester:

            StudentAcademicHistory.objects.filter(student=student, semester=student.semester).update(

                status_at_time=new_status,

                remarks=remarks or f"Status changed to {new_status}"

            )



        return Response({

            "message": f"Student {student.name} status updated to {new_status}. Historical records preserved.",

            "status": student.status,

            "usn": student.usn

        }, status=status.HTTP_200_OK)

    except Student.DoesNotExist:

        return Response({"error": "Student not found"}, status=status.HTTP_404_NOT_FOUND)





class StudentAcademicHistoryListView(generics.ListAPIView):

    permission_classes = [IsAuthenticated]



    def get_queryset(self):

        user = self.request.user

        role = (getattr(user, "role", "") or "").upper()

        queryset = Student.objects.all().select_related("department", "semester", "academic_year").order_by("-id")



        if role == "STUDENT":

            return queryset.filter(user=user)



        if role == "HOD":

            from timetable.views import _resolve_department_for_user

            dept = _resolve_department_for_user(user)

            if dept:

                queryset = queryset.filter(department=dept)

            else:

                return Student.objects.none()



        elif role in ["PROFESSOR", "FACULTY"]:

            from timetable.views import _resolve_faculty_for_user

            from subjects.models import SubjectAssignment

            fac = _resolve_faculty_for_user(user)

            if not fac:

                return Student.objects.none()



            assignments = SubjectAssignment.objects.filter(faculty=fac).select_related('subject')

            assigned_dept_ids = set()

            for a in assignments:

                d_id = a.department_id or (a.subject.department_id if a.subject else None)

                if d_id:

                    assigned_dept_ids.add(d_id)

            if fac.department_id:

                assigned_dept_ids.add(fac.department_id)



            search_param = self.request.GET.get("search") or self.request.GET.get("q")

            if not search_param and assigned_dept_ids:

                queryset = queryset.filter(department_id__in=assigned_dept_ids)



        ay_param = self.request.GET.get("academic_year")

        if ay_param:

            if str(ay_param).isdigit():

                queryset = queryset.filter(academic_year_id=int(ay_param))

            else:

                queryset = queryset.filter(academic_year__year_name=ay_param)



        sem_param = self.request.GET.get("semester")

        if sem_param:

            if str(sem_param).isdigit():

                queryset = queryset.filter(db_models.Q(semester_id=int(sem_param)) | db_models.Q(semester__sem_number=int(sem_param)))



        status_param = self.request.GET.get("status")

        if status_param and status_param.lower() != "all":

            queryset = queryset.filter(status__iexact=status_param)



        search_q = self.request.GET.get("search") or self.request.GET.get("q")

        if search_q:

            queryset = queryset.filter(

                db_models.Q(name__icontains=search_q) |

                db_models.Q(usn__icontains=search_q) |

                db_models.Q(admission_id__icontains=search_q) |

                db_models.Q(email__icontains=search_q)

            )



        return queryset



    def list(self, request, *args, **kwargs):

        queryset = self.get_queryset()



        data = []

        for s in queryset:

            if not s.academic_histories.exists():

                sync_student_academic_history(s)



            histories = s.academic_histories.select_related('semester', 'academic_year').order_by('semester__sem_number')

            sem_summaries = []

            for h in histories:

                sem_summaries.append({

                    "id": h.id,

                    "semester_number": h.semester.sem_number if h.semester else None,

                    "academic_year": h.academic_year.year_name if h.academic_year else None,

                    "status_at_time": h.status_at_time,

                    "attendance_percentage": float(h.attendance_percentage) if h.attendance_percentage is not None else None,

                    "total_classes": h.total_classes,

                    "attended_classes": h.attended_classes,

                    "ia_marks_obtained": float(h.ia_marks_obtained) if h.ia_marks_obtained is not None else None,

                    "ia_marks_total": float(h.ia_marks_total) if h.ia_marks_total is not None else None,

                    "sgpa": float(h.sgpa) if h.sgpa is not None else None,

                    "credits_earned": h.credits_earned,

                    "backlogs_count": h.backlogs_count,

                    "promoted_at": h.promoted_at,

                    "remarks": h.remarks,

                })



            data.append({

                "id": s.id,

                "name": s.name,

                "usn": s.usn,

                "admission_id": s.admission_id,

                "email": s.email,

                "department_id": s.department_id,

                "department_name": s.department.name if s.department else None,

                "current_semester_number": s.semester.sem_number if s.semester else None,

                "academic_year": s.academic_year.year_name if s.academic_year else None,

                "status": s.status or "active",

                "seat_type": s.seat_type,

                "date_of_admission": s.date_of_admission,

                "semesters_count": len(sem_summaries),

                "semester_history": sem_summaries

            })

        return Response(data, status=status.HTTP_200_OK)





class StudentAcademicHistoryDetailView(generics.GenericAPIView):

    permission_classes = [IsAuthenticated]



    def get(self, request, id):

        try:

            student = Student.objects.select_related('department', 'semester', 'academic_year', 'user').get(id=id)

        except Student.DoesNotExist:

            return Response({"error": "Student not found"}, status=status.HTTP_404_NOT_FOUND)



        user = request.user

        role = (getattr(user, "role", "") or "").upper()

        if role == "STUDENT" and student.user != user:

            return Response({"error": "Unauthorized to view other students' records"}, status=status.HTTP_403_FORBIDDEN)

        if role == "HOD" and not (user.is_staff or user.is_superuser or role in ["PRINCIPAL", "SYSTEM"]):

            from timetable.views import _resolve_department_for_user

            dept = _resolve_department_for_user(user)

            if not dept or student.department_id != dept.id:

                return Response({"error": "HOD can only view academic history of students in their own department."}, status=status.HTTP_403_FORBIDDEN)



        # Sync/update history snapshots

        sync_student_academic_history(student, current_user=user)



        histories = student.academic_histories.select_related('semester', 'academic_year', 'promoted_by').order_by('semester__sem_number')



        semesters_data = []

        overall_total_classes = 0

        overall_attended_classes = 0

        total_credits = 0

        total_backlogs = 0

        sgpa_list = []



        for h in histories:

            sem = h.semester

            ay = h.academic_year

            sem_num = sem.sem_number if sem else None



            # 1. Attendance for this semester

            att_records = AttendanceRecord.objects.filter(

                student=student,

                session__subject__semester=sem

            ).select_related('session__subject', 'session__batch', 'session__faculty')



            sem_total_att = att_records.count()

            sem_attended_att = att_records.filter(status__iexact='Present').count()

            sem_att_pct = round((sem_attended_att / sem_total_att * 100), 1) if sem_total_att > 0 else None



            overall_total_classes += sem_total_att

            overall_attended_classes += sem_attended_att



            # Subject-wise attendance

            subjects_in_sem = {}

            for r in att_records:

                sub = r.session.subject

                sub_id = sub.id

                if sub_id not in subjects_in_sem:

                    subjects_in_sem[sub_id] = {

                        "subject_id": sub.id,

                        "subject_code": sub.subject_code,

                        "subject_name": sub.subject_name,

                        "session_type": r.session.session_type,

                        "batch_name": r.session.batch.name if r.session.batch else None,

                        "total": 0,

                        "attended": 0,

                    }

                subjects_in_sem[sub_id]["total"] += 1

                if r.status.lower() == 'present':

                    subjects_in_sem[sub_id]["attended"] += 1



            subject_att_list = []

            for s_info in subjects_in_sem.values():

                pct = round((s_info["attended"] / s_info["total"] * 100), 1) if s_info["total"] > 0 else 0

                subject_att_list.append({

                    "subject_id": s_info["subject_id"],

                    "subject_code": s_info["subject_code"],

                    "subject_name": s_info["subject_name"],

                    "session_type": s_info["session_type"],

                    "batch_name": s_info["batch_name"],

                    "total": s_info["total"],

                    "attended": s_info["attended"],

                    "percentage": pct,

                    "status": "Eligible" if pct >= 75 else "Shortage"

                })



            # Attendance logs (recent 25)

            logs = []

            for r in att_records.order_by('-session__date')[:25]:

                logs.append({

                    "date": str(r.session.date),

                    "subject_code": r.session.subject.subject_code,

                    "subject_name": r.session.subject.subject_name,

                    "session_type": r.session.session_type,

                    "batch_name": r.session.batch.name if r.session.batch else None,

                    "status": r.status

                })



            # 2. IA Marks for this semester

            ia_marks_records = IAMark.objects.filter(

                student=student,

                ia_test__subject__semester=sem

            ).select_related('ia_test__subject', 'ia_test__batch')



            subject_ia_map = {}

            sem_ia_obtained = 0

            sem_ia_max = 0



            for m in ia_marks_records:

                sub = m.ia_test.subject

                sub_id = sub.id

                if sub_id not in subject_ia_map:

                    subject_ia_map[sub_id] = {

                        "subject_code": sub.subject_code,

                        "subject_name": sub.subject_name,

                        "tests": []

                    }

                obtained = float(m.obtained_marks or 0)

                max_m = float(m.ia_test.max_marks or 0)

                sem_ia_obtained += obtained

                sem_ia_max += max_m

                t_pct = round((obtained / max_m * 100), 1) if max_m > 0 else 0

                subject_ia_map[sub_id]["tests"].append({

                    "ia_type": m.ia_test.ia_type,

                    "ia_name": m.ia_test.ia_name,

                    "component_type": m.ia_test.component_type,

                    "batch_name": m.ia_test.batch.name if m.ia_test.batch else None,

                    "max_marks": max_m,

                    "obtained_marks": obtained,

                    "percentage": t_pct

                })



            # 3. External / VTU Exam Results

            res_data = None

            if student.user:

                ext_res = ExternalResult.objects.filter(student=student.user, semester=sem).first()

                if ext_res:

                    res_data = {

                        "exam_type": ext_res.exam_type,

                        "sgpa": float(ext_res.sgpa) if ext_res.sgpa else None,

                        "credits_cleared": ext_res.credits_cleared,

                        "backlogs_count": ext_res.backlogs_count,

                        "status": ext_res.status,

                        "pdf_file": request.build_absolute_uri(ext_res.pdf_file.url) if ext_res.pdf_file else None,

                        "remarks": ext_res.remarks,

                        "verified_at": ext_res.verified_at

                    }

                    if ext_res.sgpa:

                        sgpa_list.append(float(ext_res.sgpa))

                    total_credits += ext_res.credits_cleared

                    total_backlogs += ext_res.backlogs_count



            # 4. Fee Payments

            fee_payments_list = []

            fee_structures_info = []

            student_fees = StudentFee.objects.filter(student=student, fee_structure__semester=sem).select_related('fee_structure')

            for sf in student_fees:

                fee_structures_info.append({

                    "title": sf.fee_structure.title,

                    "total_amount": float(sf.total_amount),

                    "concession_amount": float(sf.concession_amount or 0),

                    "net_payable": float(sf.net_payable),

                    "paid_amount": float(sf.paid_amount),

                    "balance_amount": float(sf.balance_amount),

                    "status": sf.status

                })

                for p in sf.payments.all():

                    fee_payments_list.append({

                        "payment_id": p.id,

                        "amount": float(p.amount),

                        "mode": p.mode,

                        "paid_on": p.paid_on,

                        "reference_no": p.reference_no,

                        "upi_txn_id": p.upi_txn_id,

                        "bank_reference_no": p.bank_reference_no,

                        "verified": p.verified,

                        "remark": p.remark

                    })



            semesters_data.append({

                "semester_id": sem.id if sem else None,

                "semester_number": sem_num,

                "academic_year": ay.year_name if ay else (h.academic_year.year_name if h.academic_year else None),

                "status_at_time": h.status_at_time,

                "promoted_at": h.promoted_at,

                "promoted_by": h.promoted_by.get_full_name() if h.promoted_by else None,

                "remarks": h.remarks,

                "attendance": {

                    "total_classes": sem_total_att,

                    "attended_classes": sem_attended_att,

                    "percentage": sem_att_pct,

                    "subjects": subject_att_list,

                    "logs": logs

                },

                "ia_marks": {

                    "total_obtained": sem_ia_obtained,

                    "total_max": sem_ia_max,

                    "percentage": round((sem_ia_obtained / sem_ia_max * 100), 1) if sem_ia_max > 0 else 0,

                    "subjects": list(subject_ia_map.values())

                },

                "results": res_data,

                "fees": {

                    "structures": fee_structures_info,

                    "payments": fee_payments_list

                }

            })



        # 5. Library Records (All student issues)

        library_history = []

        if student.user:

            issues = IssueRecord.objects.filter(borrower=student.user).select_related('copy__book').order_by('-issued_at')

            for iss in issues:

                fines_total = iss.fines.aggregate(s=db_models.Sum('amount'))['s'] or 0

                library_history.append({

                    "issue_id": iss.issue_id,

                    "book_title": iss.copy.book.title if iss.copy and iss.copy.book else "Unknown",

                    "authors": iss.copy.book.authors if iss.copy and iss.copy.book else "",

                    "issued_at": iss.issued_at,

                    "due_date": str(iss.due_date) if iss.due_date else None,

                    "returned_at": iss.returned_at,

                    "status": iss.status,

                    "fine_amount": float(fines_total)

                })



        overall_att_pct = round((overall_attended_classes / overall_total_classes * 100), 1) if overall_total_classes > 0 else None

        cgpa = round(sum(sgpa_list) / len(sgpa_list), 2) if sgpa_list else None



        response_payload = {

            "student": {

                "id": student.id,

                "name": student.name,

                "usn": student.usn,

                "admission_id": student.admission_id,

                "email": student.email,

                "mobile_no": getattr(student, "mobile_no", ""),

                "department": {

                    "id": student.department.id if student.department else None,

                    "name": student.department.name if student.department else None,

                },

                "current_semester": {

                    "id": student.semester.id if student.semester else None,

                    "sem_number": student.semester.sem_number if student.semester else None,

                },

                "academic_year": {

                    "id": student.academic_year.id if student.academic_year else None,

                    "year_name": student.academic_year.year_name if student.academic_year else None,

                },

                "status": student.status or "active",

                "registration_status": student.registration_status,

                "seat_type": student.seat_type,

                "date_of_admission": student.date_of_admission,

                "father_name": getattr(student, "father_name", ""),

                "mother_name": getattr(student, "mother_name", ""),

            },

            "summary": {

                "total_semesters_completed": len(semesters_data),

                "overall_total_classes": overall_total_classes,

                "overall_attended_classes": overall_attended_classes,

                "overall_attendance_pct": overall_att_pct,

                "cgpa": cgpa,

                "total_credits_cleared": total_credits,

                "active_backlogs": total_backlogs,

                "library_books_borrowed": len(library_history)

            },

            "semesters": semesters_data,

            "library_history": library_history

        }



        return Response(response_payload, status=status.HTTP_200_OK)



