import logging
import re
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from rest_framework_simplejwt.tokens import RefreshToken
from .models import CustomUser, PasswordResetOTP
from .serializers import UserSerializer
from .utils import generate_otp, get_user_by_identifier, send_otp_email
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
        role_upper = (user.role or "").upper()

        try:
            if role_upper in ['HOD']:
                from students.models import Student
                from faculty.models import Faculty
                from subjects.models import Subject
                dept = user.department
                if not dept and hasattr(user, 'faculty_profile') and user.faculty_profile:
                    dept = user.faculty_profile.department

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
                        "route": "/subjects"
                    },
                ]
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
                fac = _resolve_faculty_for_user(user)

                assigned_count = SubjectAssignment.objects.filter(faculty=fac).count() if fac else 0
                weekday_map = {0: "MON", 1: "TUE", 2: "WED", 3: "THU", 4: "FRI", 5: "SAT"}
                day_code = weekday_map.get(timezone.now().weekday())
                today_slots = TimeTableSlot.objects.filter(
                    assignment__faculty=fac,
                    day=day_code,
                    timetable__is_active=True
                ).count() if (fac and day_code) else 0

                cards = [
                    {
                        "title": "Assigned Subjects",
                        "value": str(assigned_count),
                        "icon": "book",
                        "color": "blue",
                        "route": "/subjects"
                    },
                    {
                        "title": "Today's Schedule",
                        "value": f"{today_slots} Classes",
                        "icon": "checklist",
                        "color": "teal",
                        "route": "/timetable"
                    },
                    {
                        "title": "Mark Attendance",
                        "value": "Today",
                        "icon": "check",
                        "color": "green",
                        "route": "/attendance"
                    },
                ]
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
                from fees.models import FeeStructure, Payment
                cards = [
                    {
                        "title": "Active Fee Structures",
                        "value": str(FeeStructure.objects.filter(status='active').count()),
                        "icon": "monetization",
                        "color": "green",
                        "route": "/fees"
                    },
                    {
                        "title": "Pending Payments",
                        "value": str(Payment.objects.filter(status='pending').count()),
                        "icon": "pending",
                        "color": "orange",
                        "route": "/fees/payments"
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
        except Exception as e:
            logger.error(f"Error generating dashboard cards: {e}")

        return Response({
            "message": "Dashboard loaded successfully",
            "role": user.role,
            "user": {
                "email": user.email,
                "user_id": user.user_id,
                "role": user.role,
                "department": user.department.name if user.department else None,
            },
            "cards": cards,
        }, status=status.HTTP_200_OK)


class LoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        identifier = request.data.get("identifier")
        password = request.data.get("password")
        if not identifier or not password:
            return Response({"error": "Identifier and password required"}, status=status.HTTP_400_BAD_REQUEST)

        user = get_user_by_identifier(identifier)
        if not user or not user.check_password(password):
            logger.warning(f"Failed login attempt: {identifier}")
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
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        email = request.data.get("email") or request.data.get("identifier")
        if not email:
            return Response({"error": "Email is required"}, status=status.HTTP_400_BAD_REQUEST)

        # Validate email format
        if not re.match(EMAIL_REGEX, email):
            return Response({"error": "Enter a valid email"}, status=status.HTTP_400_BAD_REQUEST)

        # Check if user exists
        users = CustomUser.objects.filter(email__iexact=email)
        if not users.exists():
            return Response({"error": "No user found with this email"}, status=status.HTTP_404_NOT_FOUND)
        if users.count() > 1:
            return Response({"error": "Duplicate email exists, cannot generate OTP"}, status=status.HTTP_400_BAD_REQUEST)

        user = users.first()

        # Generate OTP
        otp = generate_otp()
        PasswordResetOTP.objects.create(user=user, otp=otp)

        # Send OTP via email
        try:
            send_otp_email(user, otp)
        except Exception as e:
            return Response({"error": f"Failed to send OTP: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        return Response({"message": f"OTP sent successfully to {email}"}, status=status.HTTP_200_OK)
    
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
        otp_obj.delete()

        return Response({"message": "Password reset successful"}, status=status.HTTP_200_OK)