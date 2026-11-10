import logging

import re

from rest_framework.views import APIView

from rest_framework.response import Response

from rest_framework import status, permissions

from rest_framework_simplejwt.tokens import RefreshToken

from .models import CustomUser, PasswordResetOTP, AccountInvitation, RegistrationOTP

from .serializers import UserSerializer

from .utils import generate_otp, get_user_by_identifier

from django.utils import timezone

from datetime import timedelta



logger = logging.getLogger(__name__)





def sync_user_associations(user):

    """

    Ensure CustomUser, Faculty, and HODAssignment associations stay in sync.

    Handles encrypted email edge cases and updates role/department.

    """

    if not user or not user.is_authenticated:

        return



    role_str = (user.role or "").upper()

    try:

        from hod_assignment.models import HODAssignment

        from faculty.models import Faculty



        # 1. Check if user is linked to an active HOD assignment

        active_assignment = None

        if hasattr(user, 'faculty_profile') and user.faculty_profile:

            active_assignment = HODAssignment.objects.filter(

                faculty=user.faculty_profile,

                end_date__isnull=True

            ).select_related('department').first()



        # If not found, check by user_id or email across faculty records

        if not active_assignment:

            fac = Faculty.objects.filter(user=user).first()

            if not fac and user.user_id:

                fac = Faculty.objects.filter(faculty_id=user.user_id).first()

            if not fac:

                for f in Faculty.objects.all():

                    try:

                        if f.email and f.email.lower() == (user.email or "").lower():

                            fac = f

                            break

                    except Exception:

                        pass



            if fac:

                if fac.user_id != user.id:

                    fac.user = user

                    fac.save(update_fields=['user'])

                active_assignment = HODAssignment.objects.filter(

                    faculty=fac,

                    end_date__isnull=True

                ).select_related('department').first()



        if active_assignment:

            changed = False

            if user.role != 'HOD':

                user.role = 'HOD'

                changed = True

            if active_assignment.department and user.department_id != active_assignment.department_id:

                user.department = active_assignment.department

                changed = True

            if changed:

                user.save(update_fields=['role', 'department'])

        elif role_str == 'HOD' and not user.department:

            if hasattr(user, 'faculty_profile') and user.faculty_profile and user.faculty_profile.department:

                user.department = user.faculty_profile.department

                user.save(update_fields=['department'])

    except Exception as e:

        logger.error(f"Error syncing user associations: {e}")





class DashboardView(APIView):

    permission_classes = [permissions.IsAuthenticated]



    def get(self, request):

        user = request.user

        sync_user_associations(user)

        user.refresh_from_db()



        cards = []

        extra_data = {}

        role_upper = (user.role or "").upper()



        try:

            if role_upper in ['HOD']:

                from students.models import Student

                from faculty.models import Faculty

                from subjects.models import Subject

                from timetable.views import _resolve_department_for_user

                dept = _resolve_department_for_user(user)



                dept_id = dept.id if dept else None

                stu_qs = Student.objects.filter(department_id=dept_id) if dept_id else Student.objects.none()

                fac_qs = Faculty.objects.filter(department_id=dept_id) if dept_id else Faculty.objects.none()

                sub_qs = Subject.objects.filter(department_id=dept_id) if dept_id else Subject.objects.none()



                cards = [

                    {

                        "title": "Dept Students",

                        "value": str(stu_qs.count()),

                        "icon": "people",

                        "color": "navy",

                        "route": "/admissions/list"

                    },

                    {

                        "title": "Pending Verification",

                        "value": str(stu_qs.filter(status__iexact='registered').count()),

                        "icon": "checklist",

                        "color": "orange",

                        "route": "/admissions/list"

                    },

                    {

                        "title": "Dept Faculty",

                        "value": str(fac_qs.count()),

                        "icon": "people",

                        "color": "teal",

                        "route": "/faculty"

                    },

                    {

                        "title": "Dept Subjects",

                        "value": str(sub_qs.count()),

                        "icon": "book",

                        "color": "blue",

                        "route": "/subjects/department"

                    },

                ]



                # Teaching & Timetable data for HOD (Faculty Access)

                from subjects.models import SubjectAssignment

                from timetable.models import TimeTableSlot

                from timetable.views import _resolve_faculty_for_user

                from attendance.models import AttendanceSession, AttendanceCorrectionRequest

                from ia_assessment.models import IATestSetup

                from announcements.models import Announcement



                fac = _resolve_faculty_for_user(user)

                assigned_assignments = SubjectAssignment.objects.filter(faculty=fac).select_related('subject', 'department', 'semester') if fac else SubjectAssignment.objects.none()

                assigned_count = assigned_assignments.count()



                dept_ids = set(assigned_assignments.values_list('department_id', flat=True))

                sem_ids = set(assigned_assignments.values_list('semester_id', flat=True))

                if fac and fac.department_id:

                    dept_ids.add(fac.department_id)

                elif dept_id:

                    dept_ids.add(dept_id)



                weekday_map = {0: "MON", 1: "TUE", 2: "WED", 3: "THU", 4: "FRI", 5: "SAT"}

                day_code = weekday_map.get(timezone.now().weekday())

                today = timezone.localdate()



                today_slots_qs = TimeTableSlot.objects.filter(

                    assignment__faculty=fac,

                    day=day_code,

                    timetable__is_active=True

                ).select_related('assignment__subject', 'assignment__department', 'assignment__semester').order_by('start_time') if (fac and day_code) else TimeTableSlot.objects.none()



                today_classes = []

                unmarked_classes = 0

                for slot in today_slots_qs:

                    is_marked = AttendanceSession.objects.filter(timetable_slot=slot, date=today).exists()

                    if not is_marked:

                        unmarked_classes += 1

                    sub = slot.assignment.subject

                    slot_dept = slot.assignment.department

                    slot_sem = slot.assignment.semester

                    today_classes.append({

                        "slot_id": slot.id,

                        "subject_name": sub.subject_name if sub else "Subject",

                        "subject_code": sub.subject_code if sub else "",

                        "start_time": slot.start_time.strftime("%I:%M %p") if slot.start_time else "",

                        "end_time": slot.end_time.strftime("%I:%M %p") if slot.end_time else "",

                        "department": slot_dept.name if slot_dept else "",

                        "semester": f"Sem {slot_sem.sem_number}" if slot_sem else "",

                        "is_attendance_marked": is_marked,

                    })



                pending_corrections = AttendanceCorrectionRequest.objects.filter(faculty=fac, status='PENDING').count() if fac else 0

                active_ia_tests = IATestSetup.objects.filter(

                    subject__in=assigned_assignments.values_list('subject_id', flat=True),

                    is_locked=False

                ).count() if assigned_assignments.exists() else 0



                ann_qs = Announcement.objects.filter(

                    Q(department__in=dept_ids) | Q(department__isnull=True)

                ).order_by('-created_at')[:5] if dept_ids else Announcement.objects.filter(department__isnull=True).order_by('-created_at')[:5]



                recent_announcements = [

                    {

                        "id": a.id,

                        "title": a.title,

                        "content": a.content[:160] + ('...' if len(a.content) > 160 else ''),

                        "category": a.category,

                        "priority": a.priority,

                        "created_at": a.created_at.strftime("%b %d, %Y") if a.created_at else "",

                    }

                    for a in ann_qs

                ]



                extra_data = {

                    "assigned_count": assigned_count,

                    "today_classes": today_classes,

                    "unmarked_classes_today": unmarked_classes,

                    "pending_corrections": pending_corrections,

                    "active_ia_tests": active_ia_tests,

                    "recent_announcements": recent_announcements,

                }

            elif role_upper in ['PRINCIPAL', 'SYSTEM', 'ADMIN']:

                from students.models import Student

                from faculty.models import Faculty

                from grievances.models import Grievance



                cards = [

                    {

                        "title": "Total Students",

                        "value": str(Student.objects.count()),

                        "icon": "people",

                        "color": "navy",

                        "route": "/admissions/list"

                    },

                    {

                        "title": "Pending Approvals",

                        "value": str(Student.objects.filter(status__iexact='verified').count()),

                        "icon": "pending",

                        "color": "orange",

                        "route": "/admissions/list"

                    },

                    {

                        "title": "Total Faculty",

                        "value": str(Faculty.objects.count()),

                        "icon": "people",

                        "color": "teal",

                        "route": "/faculty"

                    },

                    {

                        "title": "Grievances",

                        "value": str(Grievance.objects.count()),

                        "icon": "notifications",

                        "color": "blue",

                        "route": "/grievances"

                    },

                ]

            elif role_upper in ['PROFESSOR', 'FACULTY']:

                from subjects.models import SubjectAssignment

                from timetable.models import TimeTableSlot

                from timetable.views import _resolve_faculty_for_user

                from students.models import Student

                from attendance.models import AttendanceSession, AttendanceCorrectionRequest

                from ia_assessment.models import IATestSetup

                from announcements.models import Announcement



                fac = _resolve_faculty_for_user(user)

                assigned_assignments = SubjectAssignment.objects.filter(faculty=fac).select_related('subject', 'department', 'semester') if fac else SubjectAssignment.objects.none()

                assigned_count = assigned_assignments.count()



                dept_ids = set(assigned_assignments.values_list('department_id', flat=True))

                sem_ids = set(assigned_assignments.values_list('semester_id', flat=True))

                if fac and fac.department_id:

                    dept_ids.add(fac.department_id)



                total_students = Student.objects.filter(

                    department_id__in=dept_ids,

                    semester_id__in=sem_ids,

                    status__iexact='active'

                ).count() if (dept_ids and sem_ids) else 0



                weekday_map = {0: "MON", 1: "TUE", 2: "WED", 3: "THU", 4: "FRI", 5: "SAT"}

                day_code = weekday_map.get(timezone.now().weekday())

                today = timezone.localdate()



                today_slots_qs = TimeTableSlot.objects.filter(

                    assignment__faculty=fac,

                    day=day_code,

                    timetable__is_active=True

                ).select_related('assignment__subject', 'assignment__department', 'assignment__semester').order_by('start_time') if (fac and day_code) else TimeTableSlot.objects.none()



                today_classes = []

                unmarked_classes = 0

                for slot in today_slots_qs:

                    is_marked = AttendanceSession.objects.filter(timetable_slot=slot, date=today).exists()

                    if not is_marked:

                        unmarked_classes += 1

                    sub = slot.assignment.subject

                    dept = slot.assignment.department

                    sem = slot.assignment.semester

                    today_classes.append({

                        "slot_id": slot.id,

                        "subject_name": sub.subject_name if sub else "Subject",

                        "subject_code": sub.subject_code if sub else "",

                        "start_time": slot.start_time.strftime("%I:%M %p") if slot.start_time else "",

                        "end_time": slot.end_time.strftime("%I:%M %p") if slot.end_time else "",

                        "department": dept.name if dept else "",

                        "semester": f"Sem {sem.sem_number}" if sem else "",

                        "is_attendance_marked": is_marked,

                    })



                pending_corrections = AttendanceCorrectionRequest.objects.filter(faculty=fac, status='PENDING').count() if fac else 0

                active_ia_tests = IATestSetup.objects.filter(

                    subject__in=assigned_assignments.values_list('subject_id', flat=True),

                    is_locked=False

                ).count() if assigned_assignments.exists() else 0



                ann_qs = Announcement.objects.filter(

                    Q(department__in=dept_ids) | Q(department__isnull=True)

                ).order_by('-created_at')[:5] if dept_ids else Announcement.objects.filter(department__isnull=True).order_by('-created_at')[:5]



                recent_announcements = [

                    {

                        "id": a.id,

                        "title": a.title,

                        "content": a.content[:160] + ('...' if len(a.content) > 160 else ''),

                        "category": a.category,

                        "priority": a.priority,

                        "created_at": a.created_at.strftime("%b %d, %Y") if a.created_at else "",

                    }

                    for a in ann_qs

                ]



                cards = [

                    {

                        "title": "Assigned Subjects",

                        "value": str(assigned_count),

                        "icon": "book",

                        "color": "blue",

                        "route": "/subjects"

                    },

                    {

                        "title": "My Students",

                        "value": str(total_students),

                        "icon": "people",

                        "color": "navy",

                        "route": "/faculty/students"

                    },

                    {

                        "title": "Today's Schedule",

                        "value": f"{len(today_classes)} Classes",

                        "icon": "checklist",

                        "color": "teal",

                        "route": "/timetable/my-schedule"

                    },

                    {

                        "title": "Pending Tasks",

                        "value": f"{unmarked_classes + pending_corrections} Items",

                        "icon": "pending",

                        "color": "orange",

                        "route": "/attendance/faculty"

                    },

                    {

                        "title": "IA Assessments",

                        "value": f"{active_ia_tests} Active",

                        "icon": "grade",

                        "color": "purple",

                        "route": "/ia/faculty"

                    },

                    {

                        "title": "Academic Reports",

                        "value": "Analytics",

                        "icon": "analytics",

                        "color": "green",

                        "route": "/faculty/reports"

                    },

                ]



                extra_data = {

                    "assigned_count": assigned_count,

                    "total_students": total_students,

                    "today_classes": today_classes,

                    "unmarked_classes_today": unmarked_classes,

                    "pending_corrections": pending_corrections,

                    "active_ia_tests": active_ia_tests,

                    "recent_announcements": recent_announcements,

                }

            elif role_upper in ['STUDENT']:

                from fees.models import StudentFee

                stu = getattr(user, 'student', None)

                if not stu:

                    from students.models import Student

                    stu = Student.objects.filter(user=user).first()



                fee_count = StudentFee.objects.filter(student=stu, status__in=['pending', 'partial']).count() if stu else 0

                cards = [

                    {

                        "title": "Attendance",

                        "value": "View Stats",

                        "icon": "check",

                        "color": "green",

                        "route": "/attendance/my-stats"

                    },

                    {

                        "title": "Pending Fees",

                        "value": str(fee_count),

                        "icon": "monetization",

                        "color": "orange",

                        "route": "/fees/my-fees"

                    },

                    {

                        "title": "Library",

                        "value": "Catalog",

                        "icon": "book",

                        "color": "blue",

                        "route": "/library"

                    },

                ]

            elif role_upper in ['ACCOUNTS']:

                from fees.models import FeeStructure, FeePayment, StudentFee

                from django.db.models import Sum



                total_col = FeePayment.objects.filter(verified=True, is_reversed=False).aggregate(s=Sum("amount"))["s"] or 0

                pending_cnt = FeePayment.objects.filter(verified=False, is_reversed=False).count()

                active_structs = FeeStructure.objects.filter(is_active=True).count()

                pending_students = StudentFee.objects.filter(status__in=['pending', 'partial']).count()



                cards = [

                    {

                        "title": "Total Collected",

                        "value": f"₹{total_col:,.0f}",

                        "icon": "monetization",

                        "color": "green",

                        "route": "/fees/dashboard"

                    },

                    {

                        "title": "Pending Verification",

                        "value": str(pending_cnt),

                        "icon": "pending",

                        "color": "orange",

                        "route": "/fees/student-payments"

                    },

                    {

                        "title": "Students with Dues",

                        "value": str(pending_students),

                        "icon": "people",

                        "color": "navy",

                        "route": "/fees/students"

                    },

                    {

                        "title": "Active Structures",

                        "value": str(active_structs),

                        "icon": "checklist",

                        "color": "teal",

                        "route": "/fees"

                    },

                ]

            elif role_upper in ['ADMISSION']:

                from students.models import Student

                cards = [

                    {

                        "title": "Total Students",

                        "value": str(Student.objects.count()),

                        "icon": "people",

                        "color": "navy",

                        "route": "/admissions/list"

                    },

                    {

                        "title": "Pending Verification",

                        "value": str(Student.objects.filter(status__iexact='registered').count()),

                        "icon": "checklist",

                        "color": "orange",

                        "route": "/admissions/list"

                    },

                    {

                        "title": "New Registration",

                        "value": "Add Student",

                        "icon": "add",

                        "color": "teal",

                        "route": "/admissions/register"

                    },

                ]

            elif role_upper in ['PLACEMENT_OFFICER']:

                from placement.models import Company, PlacementDrive, PlacementApplication

                cards = [

                    {

                        "title": "Partner Companies",

                        "value": str(Company.objects.count()),

                        "icon": "business",

                        "color": "navy",

                        "route": "/placement/companies"

                    },

                    {

                        "title": "Active Drives",

                        "value": str(PlacementDrive.objects.filter(status='ACTIVE').count()),

                        "icon": "work",

                        "color": "teal",

                        "route": "/placement/drives"

                    },

                    {

                        "title": "Student Applications",

                        "value": str(PlacementApplication.objects.count()),

                        "icon": "checklist",

                        "color": "orange",

                        "route": "/placement/applications"

                    },

                ]

        except Exception as e:

            logger.error(f"Error generating dashboard cards: {e}")



        resolved_dept_id = None

        resolved_dept_name = None

        try:

            from timetable.views import _resolve_department_for_user

            res_dept = _resolve_department_for_user(user)

            if res_dept:

                resolved_dept_id = res_dept.id

                resolved_dept_name = res_dept.name

        except Exception:

            pass

        if not resolved_dept_name and user.department:

            resolved_dept_id = user.department.id

            resolved_dept_name = user.department.name



        resp_data = {

            "message": "Dashboard loaded successfully",

            "role": user.role,

            "user": {

                "email": user.email,

                "user_id": user.user_id,

                "role": user.role,

                "department": resolved_dept_id or (user.department_id if user.department else None),

                "department_id": resolved_dept_id or (user.department_id if user.department else None),

                "department_name": resolved_dept_name or (user.department.name if user.department else None),

            },

            "cards": cards,

        }

        resp_data.update(extra_data)

        return Response(resp_data, status=status.HTTP_200_OK)





class LoginView(APIView):

    permission_classes = [permissions.AllowAny]

    authentication_classes = []



    def post(self, request):

        identifier = request.data.get("identifier")

        password = request.data.get("password")

        if not identifier or not password:

            return Response({"error": "Identifier and password required"}, status=status.HTTP_400_BAD_REQUEST)



        user = get_user_by_identifier(identifier)

        if not user:

            logger.warning(f"Failed login attempt - user not found: {identifier}")

            return Response({"error": "Invalid credentials"}, status=status.HTTP_400_BAD_REQUEST)



        if not user.is_active:

            logger.warning(f"Inactive user login attempt: {identifier}")

            return Response({

                "error": "This account is not yet active. Please complete your password setup using the link sent to your registered email, or contact your department administrator."

            }, status=status.HTTP_403_FORBIDDEN)



        if not user.check_password(password):

            logger.warning(f"Failed login attempt - wrong password: {identifier}")

            return Response({"error": "Invalid credentials"}, status=status.HTTP_400_BAD_REQUEST)



        sync_user_associations(user)

        user.refresh_from_db()



        # If force_password_change is True, include that info so frontend can redirect

        refresh = RefreshToken.for_user(user)

        data = {

            "refresh": str(refresh),

            "access": str(refresh.access_token),

            "role": user.role,

            "force_password_change": user.force_password_change,

            "user": UserSerializer(user).data

        }

        return Response(data, status=status.HTTP_200_OK)







class PasswordChangeView(APIView):

    permission_classes = [permissions.IsAuthenticated]



    def post(self, request):

        old_password = request.data.get("old_password")

        new_password = request.data.get("new_password")

        user = request.user



        if not old_password or not new_password:

            return Response({"error": "Both old and new password required"}, status=status.HTTP_400_BAD_REQUEST)



        if not user.check_password(old_password):

            return Response({"error": "Old password is incorrect"}, status=status.HTTP_400_BAD_REQUEST)



        user.set_password(new_password)

        user.force_password_change = False  # clear flag on manual change

        user.save()
        try:
            from faculty.models import Faculty
            Faculty.objects.filter(user=user).update(temp_password=None, password_setup_completed_at=timezone.now())
        except Exception:
            pass

        logger.info(f"Password changed for user_id: {user.user_id or user.email}")

        return Response({"message": "Password changed successfully"}, status=status.HTTP_200_OK)





class PasswordResetDirectView(APIView):

    """

    Admin-only: reset any user's password directly (no OTP).

    """

    permission_classes = [permissions.IsAdminUser]



    def post(self, request):

        identifier = request.data.get("identifier")

        new_password = request.data.get("new_password")

        if not identifier or not new_password:

            return Response({"error": "Both identifier and new password required"}, status=status.HTTP_400_BAD_REQUEST)



        user = get_user_by_identifier(identifier)

        if not user:

            return Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)



        user.set_password(new_password)

        user.force_password_change = True  # force them to change on next login if you prefer

        user.save()

        logger.info(f"Admin reset password for {identifier}")

        return Response({"message": "Password reset successful"}, status=status.HTTP_200_OK)

    import re





EMAIL_REGEX = r"[^@]+@[^@]+\.[^@]+"  # basic email validation





class PasswordResetRequestView(APIView):
    """
    Public endpoint: Informs users that password resets are managed directly by HOD / System Admin.
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        return Response({
            "error": "Email delivery has been deactivated. Passwords are now managed directly through the SDMS interface. "
                     "Please contact your Head of Department or System Administrator to have your temporary password generated."
        }, status=status.HTTP_400_BAD_REQUEST)

class PasswordResetVerifyView(APIView):

    permission_classes = [permissions.AllowAny]



    def post(self, request):

        email = request.data.get("email")

        otp = request.data.get("otp")

        new_password = request.data.get("new_password")



        if not (email and otp and new_password):

            return Response({"error": "All fields are required"}, status=status.HTTP_400_BAD_REQUEST)



        user = CustomUser.objects.filter(email__iexact=email).first()

        if not user:

            return Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)



        otp_obj = PasswordResetOTP.objects.filter(user=user, otp=otp).first()

        if not otp_obj:

            return Response({"error": "Invalid OTP"}, status=status.HTTP_400_BAD_REQUEST)



        # Check if OTP expired (10 minutes)

        if timezone.now() > otp_obj.created_at + timedelta(minutes=10):

            otp_obj.delete()

            return Response({"error": "OTP expired"}, status=status.HTTP_400_BAD_REQUEST)



        # Reset password

        user.set_password(new_password)

        user.force_password_change = False

        user.save()
        try:
            from faculty.models import Faculty
            Faculty.objects.filter(user=user).update(temp_password=None, password_setup_completed_at=timezone.now())
        except Exception:
            pass

        otp_obj.delete()



        return Response({"message": "Password reset successful"}, status=status.HTTP_200_OK)





class PasswordSetupVerifyTokenView(APIView):

    """

    Public endpoint: verifies token validity when student/faculty opens the invitation link.

    Returns recipient metadata (Name, Email, Role, Department) so the UI can greet them.

    """

    permission_classes = [permissions.AllowAny]



    def post(self, request):

        token = request.data.get("token") or request.query_params.get("token")

        if not token:

            return Response({"valid": False, "detail": "Token parameter is missing."}, status=status.HTTP_400_BAD_REQUEST)



        is_valid, invitation, error_msg = AccountInvitation.verify_token(token)

        if not is_valid:

            return Response({"valid": False, "detail": error_msg}, status=status.HTTP_400_BAD_REQUEST)



        user = invitation.user

        return Response({

            "valid": True,

            "invitation_type": invitation.invitation_type,

            "expires_at": invitation.expires_at.isoformat(),

            "user": {

                "name": user.get_full_name(),

                "email": user.email,

                "role": user.role,

                "user_id": user.user_id,

                "usn": user.usn,

                "department": user.department.name if user.department else None,

            }

        }, status=status.HTTP_200_OK)





class PasswordSetupConfirmView(APIView):

    """

    Public endpoint: sets the user's permanent password using the verified one-time token.

    Enforces password complexity, activates user, clears force_password_change,

    marks invitation ACCEPTED, sends confirmation email, and returns JWT auth tokens.

    """

    permission_classes = [permissions.AllowAny]



    def post(self, request):

        token = request.data.get("token")

        password = request.data.get("password")

        confirm_password = request.data.get("confirm_password")



        if not token or not password:

            return Response({"error": "Token and new password are required."}, status=status.HTTP_400_BAD_REQUEST)



        if confirm_password and password != confirm_password:

            return Response({"error": "Passwords do not match."}, status=status.HTTP_400_BAD_REQUEST)



        # Validate password strength

        if len(password) < 8:

            return Response({"error": "Password must be at least 8 characters long."}, status=status.HTTP_400_BAD_REQUEST)

        if not re.search(r"[A-Z]", password):

            return Response({"error": "Password must contain at least one uppercase letter (A-Z)."}, status=status.HTTP_400_BAD_REQUEST)

        if not re.search(r"[a-z]", password):

            return Response({"error": "Password must contain at least one lowercase letter (a-z)."}, status=status.HTTP_400_BAD_REQUEST)

        if not re.search(r"\d", password):

            return Response({"error": "Password must contain at least one numeric digit (0-9)."}, status=status.HTTP_400_BAD_REQUEST)



        is_valid, invitation, error_msg = AccountInvitation.verify_token(token)

        if not is_valid:

            return Response({"error": error_msg}, status=status.HTTP_400_BAD_REQUEST)



        user = invitation.user

        invitation.accept(password)
        try:
            from faculty.models import Faculty
            Faculty.objects.filter(user=user).update(temp_password=None, password_setup_completed_at=timezone.now())
        except Exception:
            pass

        sync_user_associations(user)

        user.refresh_from_db()



        # Asynchronously send password update confirmation email

        send_password_changed_notification(user)



        # Generate JWT tokens so user is immediately logged in

        refresh = RefreshToken.for_user(user)

        return Response({

            "message": "Password setup successful! Your account is now active.",

            "refresh": str(refresh),

            "access": str(refresh.access_token),

            "role": user.role,

            "force_password_change": False,

            "user": UserSerializer(user).data

        }, status=status.HTTP_200_OK)





class ResendInvitationView(APIView):
    """
    Authorized endpoint: Allows HOD, Principal, or Admin to reset password and get a temporary password.
    HOD can only reset passwords for users within their department.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        caller = request.user
        caller_role = (getattr(caller, 'role', '') or '').upper()
        is_admin = caller.is_staff or caller_role in ['PRINCIPAL', 'SYSTEM']
        is_hod = caller_role == 'HOD'

        if not (is_admin or is_hod):
            return Response({"error": "Only HOD, Principal, or Administrators can reset passwords."}, status=status.HTTP_403_FORBIDDEN)

        user_target = None
        user_id_param = request.data.get("user_id")
        email_param = request.data.get("email")
        pk_param = request.data.get("id")

        if pk_param:
            user_target = CustomUser.objects.filter(id=pk_param).first()
        if not user_target and user_id_param:
            user_target = CustomUser.objects.filter(user_id__iexact=str(user_id_param).strip()).first()
        if not user_target and email_param:
            user_target = CustomUser.objects.filter(email__iexact=str(email_param).strip()).first()

        if not user_target:
            return Response({"error": "Target user account not found."}, status=status.HTTP_404_NOT_FOUND)

        if is_hod and not is_admin:
            from timetable.views import _resolve_department_for_user
            dept = _resolve_department_for_user(caller)
            if not dept or user_target.department != dept:
                return Response({
                    "error": f"Access Denied: As HOD of {getattr(dept, 'name', 'your department')}, you can only manage users within your own department."
                }, status=status.HTTP_403_FORBIDDEN)

        from userlogin.password_service import set_temporary_password_for_user
        from userlogin.models import PasswordAuditLog

        temp_password = set_temporary_password_for_user(
            user=user_target,
            actor=caller,
            action=PasswordAuditLog.ACTION_RESET,
            request=request
        )

        return Response({
            "message": f"Password for {user_target.get_full_name()} reset successfully.",
            "temporary_password": temp_password,
            "user_id": user_target.user_id,
            "email": user_target.email
        }, status=status.HTTP_200_OK)

class RegistrationSendOTPView(APIView):
    """
    Public endpoint: Email OTP sending deactivated. Directly marks verification as ready.
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        email = (request.data.get("email") or "").strip().lower()
        if not email:
            return Response({"error": "Email address is required."}, status=status.HTTP_400_BAD_REQUEST)

        if CustomUser.objects.filter(email__iexact=email).exists():
            return Response(
                {"error": "An account with this email address already exists. Please log in or contact your administrator."},
                status=status.HTTP_400_BAD_REQUEST
            )

        return Response({
            "message": "Email verification is optional with in-app password management. You may proceed with registration.",
            "is_verified": True
        }, status=status.HTTP_200_OK)


class RegistrationVerifyOTPView(APIView):
    """
    Public endpoint: Email OTP verification bypass.
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        return Response({
            "message": "Verification confirmed.",
            "is_verified": True
        }, status=status.HTTP_200_OK)
