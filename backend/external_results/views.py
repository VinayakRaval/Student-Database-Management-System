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
        prev_summary = f"Previous file: {obj.pdf_file.name if obj.pdf_file else 'N/A'}; semester: {obj.semester}; exam_type: {obj.exam_type}"
        updated_obj = serializer.save()
        # record changelog only if action done by staff
        user = self.request.user
        if user.is_staff:
            ChangeLog.objects.create(
                result=updated_obj,
                student=updated_obj.student,
                action_by=user,
                action='updated',
                notes=prev_summary
            )

    def perform_destroy(self, instance):
        # store info for changelog before delete
        prev_summary = f"Deleted file: {instance.pdf_file.name if instance.pdf_file else 'N/A'}; semester: {instance.semester}; exam_type: {instance.exam_type}"
        actor = self.request.user
        student = instance.student
        # delete instance (this removes DB record; file removal depends on storage settings)
        instance.delete()
        # create changelog
        if actor.is_staff:
            ChangeLog.objects.create(
                result=None,
                student=student,
                action_by=actor,
                action='deleted',
                notes=prev_summary
            )
