from django.contrib import admin
from .models import AttendanceSession, AttendanceRecord

@admin.register(AttendanceSession)
class AttendanceSessionAdmin(admin.ModelAdmin):
    list_display = ("id", "subject", "faculty", "date", "session_count")
    list_filter = ("subject", "faculty", "date")
    search_fields = ("subject__name", "faculty__name")
    ordering = ("-date",)


@admin.register(AttendanceRecord)
class AttendanceRecordAdmin(admin.ModelAdmin):
    list_display = ("id", "student", "session", "status")
    list_filter = ("status", "session__subject", "session__faculty")
    search_fields = ("student__usn", "student__name", "session__subject__name")
    ordering = ("session__date",)
