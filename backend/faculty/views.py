import logging

from rest_framework import viewsets, status, permissions

from rest_framework.decorators import action

from rest_framework.response import Response

from rest_framework.exceptions import PermissionDenied, ValidationError

from django.utils import timezone

from django.db import transaction, IntegrityError



from .models import Faculty

from .serializers import FacultySerializer

from userlogin.models import CustomUser, PasswordAuditLog
from userlogin.password_service import set_temporary_password_for_user





logger = logging.getLogger(__name__)





class IsStaffOrHODOrPrincipal(permissions.BasePermission):

    """

    Ensures only authorized personnel (Principal, HOD, Admin, System, Admission) can create, update, or delete faculty.

    """

    def has_permission(self, request, view):

        if not request.user or not request.user.is_authenticated:

            return False

        if request.method in permissions.SAFE_METHODS:

            return True

        role = (getattr(request.user, "role", "") or "").upper()

        return request.user.is_staff or role in ["PRINCIPAL", "HOD", "SYSTEM", "ADMISSION", "ADMIN"]





def generate_faculty_registration_id(designation_or_role: str = "", is_guest: bool = False) -> str:
    """
    Automatically generates unique, sequential faculty registration IDs:
    - If Designation = Guest Faculty: Prefix GUEST (e.g., GUEST001, GUEST002, ...)
    - If Designation = Professor: Prefix PROF (e.g., PROF001, PROF002, ...)
    Guarantees uniqueness across both Faculty.faculty_id and CustomUser.user_id.
    """
    import re
    from userlogin.models import CustomUser

    desig_lower = str(designation_or_role or "").strip().lower()
    if is_guest or "guest" in desig_lower or desig_lower in ["guest_faculty", "gst"]:
        prefix = "GUEST"
    else:
        prefix = "PROF"

    fac_ids = list(Faculty.objects.values_list('faculty_id', flat=True))
    user_ids = list(CustomUser.objects.values_list('user_id', flat=True))
    all_ids = set([str(x).strip() for x in (fac_ids + user_ids) if x])

    matched_nums = []
    for f_id in all_ids:
        if not f_id:
            continue
        m = re.match(rf'^{prefix}(\d+)$', f_id, re.IGNORECASE)
        if m:
            num = int(m.group(1))
            if num < 900:
                matched_nums.append(num)

    next_num = (max(matched_nums) + 1) if matched_nums else 1
    next_id = f"{prefix}{next_num:03d}"

    while (
        Faculty.objects.filter(faculty_id__iexact=next_id).exists()
        or CustomUser.objects.filter(user_id__iexact=next_id).exists()
    ):
        next_num += 1
        next_id = f"{prefix}{next_num:03d}"

    return next_id


class FacultyViewSet(viewsets.ModelViewSet):

    queryset = Faculty.objects.all()

    serializer_class = FacultySerializer

    permission_classes = [permissions.IsAuthenticated, IsStaffOrHODOrPrincipal]

    def paginate_queryset(self, queryset):
        if (
            self.request.query_params.get("for_assignment") == "true"
            or self.request.query_params.get("purpose") in ["assignment", "elective", "elective_assignment"]
            or self.request.query_params.get("no_page") == "true"
            or self.request.query_params.get("page_size") == "all"
        ):
            return None
        return super().paginate_queryset(queryset)



    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        user = request.user
        user_role = (getattr(user, "role", "") or "").upper()
        if user_role == "HOD":
            from timetable.views import _resolve_department_for_user
            dept = _resolve_department_for_user(user)
            if dept and instance.department_id != dept.id:
                raise PermissionDenied("You do not have permission to view faculty from another department.")
        serializer = self.get_serializer(instance)
        return Response(serializer.data)

    def get_queryset(self):
        from django.db.models import Q
        user = self.request.user
        user_role = (getattr(user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        qs = Faculty.objects.all().select_related("department", "user")

        dept_param = self.request.query_params.get("department_id") or self.request.query_params.get("department")
        purpose = self.request.query_params.get("purpose")
        for_assignment = (
            self.request.query_params.get("for_assignment") == "true" or
            purpose in ["assignment", "elective", "elective_assignment"]
        )

        if user_role == "HOD" and not for_assignment:
            from timetable.views import _resolve_department_for_user
            dept = _resolve_department_for_user(user)
            if not dept:
                return Faculty.objects.none()
            # Enforce HOD department isolation: HOD can ONLY see faculty of their own department
            qs = qs.filter(department=dept)
        else:
            dept_param = self.request.query_params.get("department_id") or self.request.query_params.get("department")
            if dept_param and str(dept_param).lower() != "all":
                if str(dept_param).isdigit():
                    qs = qs.filter(department_id=int(dept_param))
                else:
                    qs = qs.filter(
                        Q(department__name__iexact=dept_param) | Q(department__code__iexact=dept_param)
                    )

        fac_type = self.request.query_params.get("faculty_type") or self.request.query_params.get("employment_type")
        if fac_type:
            fac_type_upper = fac_type.upper()
            if fac_type_upper in ["GUEST", "GUEST_FACULTY"]:
                qs = qs.filter(Q(employment_type="GUEST") | Q(is_guest_faculty=True) | Q(designation__icontains="Guest"))
            elif fac_type_upper in ["PERMANENT", "REGULAR"]:
                qs = qs.filter(Q(employment_type="PERMANENT") & Q(is_guest_faculty=False)).exclude(designation__icontains="Guest")

        search_query = self.request.query_params.get("search")
        if search_query:
            qs = qs.filter(
                Q(name__icontains=search_query) |
                Q(faculty_id__icontains=search_query)
            )

        return qs



    @action(detail=False, methods=['get'], url_path='next-id')
    def next_id(self, request):
        """
        Returns the next available unique Registration ID based on Designation:
        - If Designation = Guest Faculty -> Prefix GUEST (e.g. GUEST001, GUEST002, ...)
        - If Designation = Professor / other -> Prefix PROF (e.g. PROF001, PROF002, ...)
        Guarantees uniqueness across both Faculty and CustomUser records.
        """
        desig = (
            request.query_params.get('designation') or
            request.query_params.get('role') or
            request.query_params.get('employment_type') or
            ''
        )
        is_guest = (
            request.query_params.get('guest', '').lower() in ['true', '1']
            or 'guest' in desig.lower()
            or request.query_params.get('employment_type', '').upper() == 'GUEST'
            or request.query_params.get('role', '').upper() in ['GUEST', 'GUEST_FACULTY']
        )
        next_id = generate_faculty_registration_id(designation_or_role=desig, is_guest=is_guest)
        return Response({"next_id": next_id})

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        response_data = dict(serializer.data)

        temp_password = getattr(serializer.instance, '_temporary_password', None)
        if not temp_password and serializer.instance.user:
            temp_password = set_temporary_password_for_user(
                user=serializer.instance.user,
                actor=request.user,
                action=PasswordAuditLog.ACTION_INITIAL_CREATION,
                request=request
            )
        response_data["temporary_password"] = temp_password
        response_data["message"] = f"Faculty account created successfully for {serializer.instance.name}."

        return Response(response_data, status=status.HTTP_201_CREATED, headers=headers)

    @transaction.atomic

    def perform_create(self, serializer):

        user = self.request.user

        user_role = (getattr(user, "role", "") or "").upper()



        save_kwargs = {

            "status": "approved",

            "approved_date": timezone.now(),

        }



        if user_role == "HOD":

            from timetable.views import _resolve_department_for_user

            dept = _resolve_department_for_user(user)

            if not dept:

                raise ValidationError({"department": ["Authenticated HOD has no assigned department."]})



            # Backend enforcement: HOD can only register Professor or Guest Faculty
            req_role = (self.request.data.get("role") or "").upper()
            if req_role in ["HOD", "PRINCIPAL", "ADMISSION", "ACCOUNTS", "SYSTEM", "EXAM", "LIBRARY"]:
                raise PermissionDenied("HOD is not authorized to register administrative or other HOD roles.")
            if req_role in ["GUEST", "GUEST_FACULTY"]:
                save_kwargs["role"] = "PROFESSOR"
                save_kwargs["is_guest_faculty"] = True
                save_kwargs["employment_type"] = "GUEST"
                if not self.request.data.get("designation"):
                    save_kwargs["designation"] = "Guest Faculty"

            # Backend enforcement: Reject unauthorized cross-department faculty creation attempts

            submitted_dept = self.request.data.get("department")

            if submitted_dept:

                try:

                    if int(submitted_dept) != dept.id:

                        raise PermissionDenied(

                            f"Access Denied: As HOD of {dept.name}, you are not authorized to register faculty for other departments."

                        )

                except (ValueError, TypeError):

                    pass



            save_kwargs["department"] = dept

        elif user.is_staff or user_role in ["PRINCIPAL", "SYSTEM", "ADMISSION", "ADMIN"]:

            pass

        else:

            raise PermissionDenied("Only Principal, HOD, Admission Officer, or System Administrators can register faculty members.")



        # Check and enforce unique Registration ID with proper prefix (GUEST vs PROF)
        req_desig = str(self.request.data.get("designation") or save_kwargs.get("designation") or "").strip()
        req_role = (self.request.data.get("role") or save_kwargs.get("role") or "").upper()
        req_emp = (self.request.data.get("employment_type") or save_kwargs.get("employment_type") or "").upper()
        is_guest_faculty = (
            save_kwargs.get("is_guest_faculty", False)
            or req_role in ["GUEST", "GUEST_FACULTY"]
            or "guest" in req_desig.lower()
            or req_emp == "GUEST"
            or self.request.data.get("is_guest_faculty") in [True, "true", "1", 1]
        )
        expected_prefix = "GUEST" if is_guest_faculty else "PROF"
        submitted_id = (serializer.validated_data.get("faculty_id") or self.request.data.get("faculty_id") or "").strip()

        from userlogin.models import CustomUser
        if (
            not submitted_id
            or not submitted_id.upper().startswith(expected_prefix)
            or Faculty.objects.filter(faculty_id__iexact=submitted_id).exists()
            or CustomUser.objects.filter(user_id__iexact=submitted_id).exists()
        ):
            save_kwargs["faculty_id"] = generate_faculty_registration_id(designation_or_role=req_desig, is_guest=is_guest_faculty)
        else:
            save_kwargs["faculty_id"] = submitted_id.upper()

        try:

            instance = serializer.save(**save_kwargs)
            instance.refresh_from_db()
            if instance.user:
                PasswordAuditLog.objects.filter(
                    target_user=instance.user,
                    action=PasswordAuditLog.ACTION_INITIAL_CREATION,
                    actor__isnull=True
                ).update(
                    actor=user,
                    actor_email=user.email or user.user_id or '',
                    actor_role=user_role or ''
                )

        except IntegrityError as e:

            err_str = str(e).lower()

            if "phone" in err_str:

                raise ValidationError({"phone": ["A user or faculty with this phone number already exists."]})

            elif "email" in err_str:

                raise ValidationError({"email": ["A user or faculty with this email address already exists."]})

            elif "faculty_id" in err_str or "user_id" in err_str:

                raise ValidationError({"faculty_id": ["A faculty member with this Registration ID already exists."]})

            else:

                raise ValidationError({"non_field_errors": [f"Database integrity error: {e}"]})



    @transaction.atomic

    def perform_update(self, serializer):

        user = self.request.user

        user_role = (getattr(user, "role", "") or "").upper()



        save_kwargs = {}

        if user_role == "HOD":

            from timetable.views import _resolve_department_for_user

            dept = _resolve_department_for_user(user)

            instance = serializer.instance

            if not dept or instance.department != dept:

                raise PermissionDenied("HOD can only update faculty in their own department.")



            # Prevent HOD from changing department of an existing faculty member

            submitted_dept = self.request.data.get("department")

            if submitted_dept:

                try:

                    if int(submitted_dept) != dept.id:

                        raise PermissionDenied("HOD cannot reassign a faculty member to another department.")

                except (ValueError, TypeError):

                    pass

            save_kwargs["department"] = dept



        try:

            serializer.save(**save_kwargs)

        except IntegrityError as e:

            err_str = str(e).lower()

            if "phone" in err_str:

                raise ValidationError({"phone": ["A user or faculty with this phone number already exists."]})

            elif "email" in err_str:

                raise ValidationError({"email": ["A user or faculty with this email address already exists."]})

            elif "faculty_id" in err_str or "user_id" in err_str:

                raise ValidationError({"faculty_id": ["A faculty member with this Registration ID already exists."]})

            else:

                raise ValidationError({"non_field_errors": [f"Database integrity error: {e}"]})



    def perform_destroy(self, instance):

        user = self.request.user

        user_role = (getattr(user, "role", "") or "").upper()

        if not (user.is_staff or user_role in ["PRINCIPAL", "SYSTEM"]):

            raise PermissionDenied("Only Principal or System Administrators can remove faculty records.")

        instance.delete()



    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def approve(self, request, pk=None):
        """
        Approves a faculty member and generates initial credentials if needed.
        """
        faculty = self.get_object()
        user = request.user
        user_role = (getattr(user, "role", "") or "").upper()

        is_admin = user.is_staff or user_role in ["PRINCIPAL", "SYSTEM"]
        is_hod = user_role == "HOD"

        if not (is_admin or is_hod):
            return Response({"error": "Unauthorized to approve faculty."}, status=status.HTTP_403_FORBIDDEN)

        if is_hod and not is_admin:
            from timetable.views import _resolve_department_for_user
            dept = _resolve_department_for_user(user)
            if not dept or faculty.department != dept:
                return Response({"error": "HOD can only approve faculty in their own department."}, status=status.HTTP_403_FORBIDDEN)

        faculty.status = "approved"
        faculty.approved_date = timezone.now()
        faculty.save()

        temp_password = getattr(faculty, '_temporary_password', None)
        if not temp_password and faculty.user and not faculty.user.has_usable_password():
            temp_password = set_temporary_password_for_user(
                user=faculty.user,
                actor=user,
                action=PasswordAuditLog.ACTION_INITIAL_CREATION,
                request=request
            )

        resp = {
            "message": f"Faculty {faculty.name} approved successfully.",
            "status": faculty.status,
            "faculty_id": faculty.faculty_id,
            "email": faculty.email
        }
        if temp_password:
            resp["temporary_password"] = temp_password
        return Response(resp, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated], url_path='reset-password')
    def reset_password(self, request, pk=None):
        """
        Generates a new secure temporary password for faculty member.
        Enforces strict HOD department validation and logs audit event without credentials.
        """
        faculty = self.get_object()
        user = request.user
        user_role = (getattr(user, "role", "") or "").upper()

        is_admin = user.is_staff or user_role in ["PRINCIPAL", "SYSTEM"]
        is_hod = user_role == "HOD"

        if not (is_admin or is_hod):
            raise PermissionDenied("Unauthorized to reset faculty password.")

        if is_hod and not is_admin:
            from timetable.views import _resolve_department_for_user
            dept = _resolve_department_for_user(user)
            if not dept or faculty.department != dept:
                raise PermissionDenied(
                    f"Access Denied: As HOD of {getattr(dept, 'name', 'your department')}, "
                    f"you can only manage faculty within your own department."
                )

        target_user = faculty.user
        if not target_user:
            return Response(
                {"error": "Faculty has no linked login account. Please approve the record first."},
                status=status.HTTP_400_BAD_REQUEST
            )

        temp_password = set_temporary_password_for_user(
            user=target_user,
            actor=user,
            action=PasswordAuditLog.ACTION_RESET,
            request=request
        )
        Faculty.objects.filter(id=faculty.id).update(temp_password=temp_password, password_setup_completed_at=None)
        faculty.temp_password = temp_password
        faculty.password_setup_completed_at = None

        return Response({
            "message": f"Password for {faculty.name} has been reset successfully.",
            "temporary_password": temp_password,
            "faculty_id": faculty.faculty_id,
            "faculty_name": faculty.name,
            "email": faculty.email
        }, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated], url_path='reset_password')
    def reset_password_underscore(self, request, pk=None):
        return self.reset_password(request, pk)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def resend_invitation(self, request, pk=None):
        """
        Backward compatibility alias: delegates directly to reset_password.
        """
        return self.reset_password(request, pk)
