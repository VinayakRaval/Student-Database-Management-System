from rest_framework import generics, permissions, filters, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from .models import ExternalResult, ChangeLog
from .serializers import ExternalResultSerializer
from .permissions import IsOwnerOrHOD
from rest_framework.exceptions import PermissionDenied


class ExternalResultListCreateView(generics.ListCreateAPIView):
    """
    GET: student -> their results; HOD -> all results (staff)
    POST: students upload (validated), staff may also create/replace
    """
    serializer_class = ExternalResultSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrHOD]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['semester', 'exam_type', 'student__email', 'student__usn']
    ordering_fields = ['semester', 'uploaded_at']

    def get_queryset(self):
        user = self.request.user
        if user.is_staff:
            return ExternalResult.objects.select_related('student').all()
        return ExternalResult.objects.filter(student=user)
    
    # ✅ Add this method
    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

    def create(self, request, *args, **kwargs):
    # Block staff BEFORE serializer validation
     if request.user.role == "HOD":
        return Response(
            {"detail": "Only students can upload results."},
            status=status.HTTP_403_FORBIDDEN
        )

     return super().create(request, *args, **kwargs)


class ExternalResultRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    """
    Retrieve: owner or staff
    Update/Delete: staff only (HOD)
    """
    queryset = ExternalResult.objects.select_related('student').all()
    serializer_class = ExternalResultSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrHOD]

    def perform_update(self, serializer):
        # capture previous info for changelog
        obj = self.get_object()
        prev_summary = f"Previous file: {obj.pdf_file.name if obj.pdf_file else 'N/A'}; semester: {obj.semester}; exam_type: {obj.exam_type}; status: {obj.status}"
        
        user = self.request.user
        extra_kwargs = {}
        new_status = self.request.data.get('status')
        if new_status == 'VERIFIED':
            from django.utils import timezone
            extra_kwargs['verified_by'] = user
            extra_kwargs['verified_at'] = timezone.now()

        updated_obj = serializer.save(**extra_kwargs)

        # Update student academic progression if verified
        if updated_obj.status == 'VERIFIED':
            stu_profile = getattr(updated_obj.student, 'student', None)
            if stu_profile and int(updated_obj.backlogs_count or 0) == 0 and updated_obj.semester:
                from academics.models import Semester
                next_sem = Semester.objects.filter(sem_number=updated_obj.semester.sem_number + 1).first()
                if next_sem:
                    stu_profile.semester = next_sem
                    stu_profile.save(update_fields=['semester'])

        # record changelog only if action done by staff
        if user.is_staff or getattr(user, 'role', '') == 'HOD':
            ChangeLog.objects.create(
                result=updated_obj,
                student=updated_obj.student,
                action_by=user,
                action='updated',
                notes=self.request.data.get('notes') or prev_summary
            )

    def perform_destroy(self, instance):
        # store info for changelog before delete
        prev_summary = f"Deleted file: {instance.pdf_file.name if instance.pdf_file else 'N/A'}; semester: {instance.semester}; exam_type: {instance.exam_type}"
        actor = self.request.user
        student = instance.student
        # delete instance (this removes DB record; file removal depends on storage settings)
        instance.delete()
        # create changelog
        if actor.is_staff or getattr(actor, 'role', '') == 'HOD':
            ChangeLog.objects.create(
                result=None,
                student=student,
                action_by=actor,
                action='deleted',
                notes=prev_summary
            )


class VerifyExternalResultView(generics.GenericAPIView):
    """
    POST: HOD / Exam Coordinator verifies marksheet, updates SGPA/backlogs,
    advances student progression, and writes an audit changelog entry.
    """
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrHOD]
    serializer_class = ExternalResultSerializer

    def post(self, request, pk=None):
        result = get_object_or_404(ExternalResult, pk=pk)
        user = request.user
        if getattr(user, 'role', '') != 'HOD' and not user.is_staff:
            return Response(
                {"detail": "Only HOD or Exam Coordinator can verify semester marksheets."},
                status=status.HTTP_403_FORBIDDEN
            )

        status_val = request.data.get('status', 'VERIFIED')
        sgpa_val = request.data.get('sgpa', result.sgpa)
        remarks_val = request.data.get('remarks', result.remarks)
        credits_val = request.data.get('credits_cleared', result.credits_cleared)
        backlogs_val = request.data.get('backlogs_count', result.backlogs_count)

        prev_summary = f"Status changed from {result.status} to {status_val}; SGPA: {sgpa_val}; Backlogs: {backlogs_val}"

        result.status = status_val
        if sgpa_val is not None:
            result.sgpa = sgpa_val
        if remarks_val is not None:
            result.remarks = remarks_val
        if credits_val is not None:
            result.credits_cleared = credits_val
        if backlogs_val is not None:
            result.backlogs_count = backlogs_val

        from django.utils import timezone
        result.verified_by = user
        result.verified_at = timezone.now()
        result.save()

        # Update student progression
        stu_profile = getattr(result.student, 'student', None)
        if stu_profile and status_val == 'VERIFIED':
            if int(result.backlogs_count or 0) == 0 and result.semester:
                from academics.models import Semester
                next_sem = Semester.objects.filter(sem_number=result.semester.sem_number + 1).first()
                if next_sem:
                    stu_profile.semester = next_sem
                    stu_profile.save(update_fields=['semester'])

        # Audit log in ChangeLog
        ChangeLog.objects.create(
            result=result,
            student=result.student,
            action_by=user,
            action='updated',
            notes=request.data.get('notes') or prev_summary
        )

        serializer = ExternalResultSerializer(result, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)

