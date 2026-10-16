from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny,IsAdminUser
from .models import Student
from .serializers import StudentSerializer
from rest_framework import generics
from academics.models import Semester
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework import status
from academics.models import Semester ,AcademicYear
from .utils import send_approval_email   # or correct import path
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters


# Your existing Create, List, DetailUpdate views
class StudentCreateView(generics.CreateAPIView):
    queryset = Student.objects.all()
    serializer_class = StudentSerializer
    permission_classes = [AllowAny]

    def create(self, request, *args, **kwargs):
        response = super().create(request, *args, **kwargs)
        student = Student.objects.get(id=response.data['id'])

        # If created by authenticated staff (ADMISSION, PRINCIPAL, SYSTEM, HOD), auto-approve student
        user = request.user if request.user and request.user.is_authenticated else None
        role = (getattr(user, "role", "") or "").upper() if user else ""
        if user and (role in ["ADMISSION", "PRINCIPAL", "SYSTEM", "HOD"] or user.is_staff):
            student.registration_status = 'approved'
            student.status = 'active'
            student.save(update_fields=['registration_status', 'status'])

        # Dispatch password setup invitation email automatically to registered email
        try:
            send_approval_email(student, created_by=user)
        except Exception as e:
            print(f"[EMAIL WARNING] Could not dispatch student setup email: {e}")

        response.data['admission_id'] = student.admission_id
        response.data['registration_status'] = student.registration_status
        response.data['message'] = f"Registration successful. Your Admission ID is {student.admission_id}. Password setup invitation sent to {student.email}."
        return response

from rest_framework.exceptions import PermissionDenied
from django.db import transaction

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
            from timetable.views import _resolve_department_for_user
            dept = _resolve_department_for_user(user)
            if dept:
                # Enforce HOD department, ignore client param trying to see other departments
                queryset = queryset.filter(department=dept)
            else:
                return Student.objects.none()
        elif role in ["PROFESSOR", "FACULTY"]:
            from timetable.views import _resolve_faculty_for_user
            fac = _resolve_faculty_for_user(user)
            dept = fac.department if fac else getattr(user, "department", None)
            if dept:
                queryset = queryset.filter(department=dept)
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

            if student.user:
                # Account remains inactive until the student completes password setup via token
                student.user.is_active = False
                student.user.force_password_change = True
                student.user.save(update_fields=['is_active', 'force_password_change'])

            # Safely send password setup invitation asynchronously
            try:
                send_approval_email(student, created_by=user)
            except Exception as e:
                print(f"[EMAIL WARNING] Could not dispatch setup email: {e}")

            return Response(
                {
                    "status": "Student approved and password setup invitation dispatched",
                    "registration_status": "approved",
                    "email_sent_to": student.email
                },
                status=status.HTTP_200_OK
            )

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
def resend_student_invitation(request, id):
    user = request.user
    role = (getattr(user, "role", "") or "").upper()
    is_admin = user.is_staff or role in ["PRINCIPAL", "SYSTEM", "ADMISSION"]
    is_hod = role == "HOD"

    if not (is_admin or is_hod):
        return Response({"error": "Unauthorized to resend student invitations."}, status=status.HTTP_403_FORBIDDEN)

    try:
        student = Student.objects.select_related('user', 'department').get(id=id)
    except Student.DoesNotExist:
        return Response({"error": "Student not found."}, status=status.HTTP_404_NOT_FOUND)

    if is_hod and not is_admin:
        from timetable.views import _resolve_department_for_user
        dept = _resolve_department_for_user(user)
        if not dept or student.department != dept:
            return Response({"error": "HOD can only manage students within their department."}, status=status.HTTP_403_FORBIDDEN)

    if not student.user:
        return Response({"error": "Student has no linked login account."}, status=status.HTTP_400_BAD_REQUEST)

    send_approval_email(student, created_by=user)
    return Response({
        "message": f"Password setup invitation resent successfully to {student.email}."
    }, status=status.HTTP_200_OK)


# Student detail view for logged-in student to view their own data
class StudentDetailView(generics.RetrieveAPIView):
    queryset = Student.objects.all()
    serializer_class = StudentSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.queryset.get(user=self.request.user)
    

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
                if not dept or student.department_id != dept.id:
                    return Response({"error": "You can only promote students within your own department."},
                                    status=status.HTTP_403_FORBIDDEN)

            # Eligibility validation
            if student.status != "active":
                return Response({"error": "Only active students can be promoted."},
                                status=status.HTTP_400_BAD_REQUEST)
            if student.registration_status != "approved":
                return Response({"error": "Student registration must be approved by Principal before semester promotion."},
                                status=status.HTTP_400_BAD_REQUEST)

            if not student.semester:
                return Response({"error": "Student does not have a semester assigned"},
                                status=status.HTTP_400_BAD_REQUEST)

            current_sem = student.semester

            # Handle final semester (assuming 8 is final)
            if current_sem.sem_number >= 8:
                student.status = "inactive"
                student.save(update_fields=["status"])
                return Response({"message": "Student has completed final semester (graduated) and status set to inactive."},
                                status=status.HTTP_200_OK)

            # Promote to next semester
            next_sem = Semester.objects.filter(sem_number=current_sem.sem_number + 1).first()
            if not next_sem:
                return Response({"error": f"Next semester (Semester {current_sem.sem_number + 1}) not configured in system."},
                                status=status.HTTP_400_BAD_REQUEST)

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

            student.save()
            return Response({
                "message": f"Student promoted from semester {current_sem.sem_number} to {next_sem.sem_number}.",
                "new_semester": next_sem.sem_number,
                "academic_year": student.academic_year.year_name if student.academic_year else None
            }, status=status.HTTP_200_OK)

    except Student.DoesNotExist:
        return Response({"error": "Student not found"}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({"error": "Internal server error during promotion", "details": str(e)},
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR)
