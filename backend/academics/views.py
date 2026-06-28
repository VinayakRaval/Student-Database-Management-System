from rest_framework import generics
from rest_framework.permissions import AllowAny, IsAuthenticated
from .models import Department, Semester, AcademicYear, Schema
from .serializers import (
    DepartmentSerializer, SemesterSerializer,
    AcademicYearSerializer, SchemaSerializer
)
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import generics, permissions


# ---------------- Department ---------------- #

class DepartmentListCreateView(generics.ListCreateAPIView):
    queryset = Department.objects.all()
    serializer_class = DepartmentSerializer

    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsAuthenticated()]

class DepartmentDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Department.objects.all()
    serializer_class = DepartmentSerializer
    permission_classes = [IsAuthenticated]


# ---------------- Semester ---------------- #

class SemesterListCreateView(generics.ListCreateAPIView):
    queryset = Semester.objects.all()
    serializer_class = SemesterSerializer

    def get_permissions(self):
        if self.request.method == "GET":
           return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]

class SemesterDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Semester.objects.all()
    serializer_class = SemesterSerializer
    
    def get_permissions(self):
     if self.request.method == "GET":
        return [permissions.AllowAny()]
     return [permissions.IsAdminUser()]


# ---------------- Academic Year ---------------- #

class AcademicYearListCreateView(generics.ListCreateAPIView):
    queryset = AcademicYear.objects.all()
    serializer_class = AcademicYearSerializer

    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsAuthenticated()]

class AcademicYearDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = AcademicYear.objects.all()
    serializer_class = AcademicYearSerializer

    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsAuthenticated()]


# ---------------- Schema ---------------- #

class SchemaListCreateView(generics.ListCreateAPIView):
    queryset = Schema.objects.all()
    serializer_class = SchemaSerializer
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ["department"]

    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsAuthenticated()]

class SchemaDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Schema.objects.all()
    serializer_class = SchemaSerializer
    permission_classes = [IsAuthenticated]