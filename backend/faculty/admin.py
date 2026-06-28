from django.contrib import admin
from .models import Faculty

@admin.register(Faculty)
class FacultyAdmin(admin.ModelAdmin):
    list_display = (
        "faculty_id",
        "name",
        "department",
        "role",
        "status",
        "registration_date",
        "approved_date",
    )
    search_fields = ("faculty_id", "name", "email", "phone")
    ordering = ("-registration_date",)
