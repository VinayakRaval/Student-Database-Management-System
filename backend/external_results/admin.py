from django.contrib import admin
from .models import ExternalResult, ChangeLog

@admin.register(ExternalResult)
class ExternalResultAdmin(admin.ModelAdmin):
    list_display = ('student', 'semester', 'exam_type', 'uploaded_at')
    search_fields = ('student__email', 'student__usn', 'semester', 'exam_type')
    list_filter = ('semester', 'exam_type')
    readonly_fields = ('uploaded_at',)

@admin.register(ChangeLog)
class ChangeLogAdmin(admin.ModelAdmin):
    list_display = ('action', 'action_by', 'student', 'timestamp')
    search_fields = ('action_by__email', 'student__email', 'notes')
    list_filter = ('action',)
    readonly_fields = ('timestamp',)
