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
        response.data['admission_id'] = student.admission_id
        response.data['message'] = f"Registration successful. Your Admission ID is {student.admission_id}."
        return response

class StudentListView(generics.ListAPIView):
    queryset = Student.objects.all()
    serializer_class = StudentSerializer
    permission_classes = [AllowAny]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ["registration_status"]

    def get_queryset(self):
        queryset = Student.objects.all()
        status_param = self.request.GET.get("registration_status")

        if status_param:
            queryset = queryset.filter(registration_status=status_param)

        return queryset

class StudentDetailUpdateView(generics.RetrieveUpdateAPIView):
    queryset = Student.objects.all()
    serializer_class = StudentSerializer
    lookup_field = 'id'
    permission_classes = [AllowAny]

class AssignUSNView(generics.UpdateAPIView):
    queryset = Student.objects.all()
    serializer_class = StudentSerializer
    lookup_field = 'id'
    permission_classes = [IsAuthenticated]

    def update(self, request, *args, **kwargs):
        student = self.get_object()
        usn = request.data.get('usn')
        if not usn:
            return Response({'error': 'USN required'}, status=status.HTTP_400_BAD_REQUEST)
        student.usn = usn
        student.save()
        return Response({'status': 'USN assigned'}, status=status.HTTP_200_OK)



# New Step 2: Department Verification (restricted to department staff)
class DepartmentVerificationView(generics.UpdateAPIView):
    queryset = Student.objects.filter(registration_status='pending')
    serializer_class = StudentSerializer
    permission_classes = [IsAuthenticated]  # Add role-based check for department here
    lookup_field = 'id'

    def update(self, request, *args, **kwargs):
        student = self.get_object()
        student.registration_status = 'verified'
        student.save()
        return Response({'status': 'Student registration verified by department'}, status=status.HTTP_200_OK)

# New Step 3: Principal Approval (restricted to principal role)

class PrincipalApprovalView(generics.UpdateAPIView):
    serializer_class = StudentSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = 'id'

    def get_queryset(self):
        return Student.objects.all()

    def update(self, request, *args, **kwargs):
        student = self.get_object()
        action = request.data.get('action')

        if student.registration_status != 'verified':
            return Response(
                {"error": "Student is not verified by department"},
                status=status.HTTP_400_BAD_REQUEST
            )

        if action == 'approve':
            student.registration_status = 'approved'
            student.status = 'active'
            student.admission_status = 'admitted'
            student.save()

            if student.user:
                student.user.is_active = True
                student.user.save()

            # 🚀 Now email will be sent
            send_approval_email(student)

            return Response(
                {"status": "Student approved and account activated"},
                status=status.HTTP_200_OK
            )

        elif action == 'reject':
            student.registration_status = 'rejected'
            student.save()
            return Response(
                {"status": "Student registration rejected by principal"},
                status=status.HTTP_200_OK
            )

        return Response(
            {"error": "Invalid action value. Use 'approve' or 'reject'"},
            status=status.HTTP_400_BAD_REQUEST
        )


# Student detail view for logged-in student to view their own data
class StudentDetailView(generics.RetrieveAPIView):
    queryset = Student.objects.all()
    serializer_class = StudentSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.queryset.get(user=self.request.user)
    

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def promote_student(request, id):
    try:
        student = Student.objects.get(id=id)

        if not student.semester:
            return Response({"error": "Student does not have a semester assigned"}, status=status.HTTP_400_BAD_REQUEST)

        current_sem = student.semester

        # Handle final semester (assuming 8 is final)
        if current_sem.sem_number == 8:
            student.status = "inactive"
            student.semester = None
            student.save()
            return Response({"message": "Student has graduated and set to inactive."}, status=status.HTTP_200_OK)

        # Promote to next semester
        try:
            next_sem = Semester.objects.get(sem_number=current_sem.sem_number + 1)
        except Semester.DoesNotExist:
            return Response({"error": "Next semester not found"}, status=status.HTTP_400_BAD_REQUEST)

        # Update semester
        student.semester = next_sem

        # Update academic year only for semesters 3,5,7,... (after first)
        if next_sem.sem_number % 2 == 1 and next_sem.sem_number != 1:
            if student.academic_year:
                start_year, end_year = map(int, student.academic_year.year_name.split('-'))
                start_year += 1
                end_year += 1
                new_year_name = f"{start_year}-{end_year}"
                new_ay, _ = AcademicYear.objects.get_or_create(year_name=new_year_name)
                student.academic_year = new_ay

        student.save()
        return Response({"message": f"Student promoted from semester {current_sem.sem_number} to {next_sem.sem_number}."}, status=status.HTTP_200_OK)

    except Student.DoesNotExist:
        return Response({"error": "Student not found"}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({"error": "Internal server error", "details": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
