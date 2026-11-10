from django.contrib import admin
from .models import CorrectionRequest, CorrectionRequestHistory

class CorrectionRequestHistoryInline(admin.TabularInline):
    model = CorrectionRequestHistory
    extra = 0
    readonly_fields = ('actor', 'action', 'from_status', 'to_status', 'comments', 'timestamp')
    can_delete = False

@admin.register(CorrectionRequest)
class CorrectionRequestAdmin(admin.ModelAdmin):
    list_display = ('request_id', 'student', 'category', 'status', 'assigned_role', 'assigned_department', 'created_at', 'resolved_at')
    list_filter = ('status', 'category', 'assigned_role', 'assigned_department')
    search_fields = ('request_id', 'student__usn', 'student__name', 'target_record_ref')
    readonly_fields = ('request_id', 'created_at', 'updated_at', 'resolved_at')
    inlines = [CorrectionRequestHistoryInline]

@admin.register(CorrectionRequestHistory)
class CorrectionRequestHistoryAdmin(admin.ModelAdmin):
    list_display = ('request', 'actor', 'action', 'from_status', 'to_status', 'timestamp')
    list_filter = ('action',)
    search_fields = ('request__request_id', 'actor__email')
    readonly_fields = ('request', 'actor', 'action', 'from_status', 'to_status', 'comments', 'timestamp')
