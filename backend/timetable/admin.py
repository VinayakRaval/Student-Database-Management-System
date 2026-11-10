from django.contrib import admin
from .models import TimeTable, TimeTableSlot, TimeTableSlotBatch, TimeTableApprovalHistory

class TimeTableSlotBatchInline(admin.TabularInline):
    model = TimeTableSlotBatch
    extra = 1

class TimeTableSlotInline(admin.TabularInline):
    model = TimeTableSlot
    extra = 1
    readonly_fields = ("created_at",)
    fields = ("day", "start_time", "end_time", "assignment", "is_batch_wise", "batch_name", "lab_room", "allow_co_teaching")

@admin.register(TimeTable)
class TimeTableAdmin(admin.ModelAdmin):
    list_display = (
        "id", "department_name", "semester_number", "academic_year_label",
        "effective_date", "version", "status", "is_active", "created_by", "created_at",
        "approved_by", "approved_at"
    )
    list_filter = ("department", "semester",  "academic_year", "status", "is_active")
    readonly_fields = ("created_at", "approved_at",)
    search_fields = (
        "department__name",
        "semester__sem_number",
        "academic_year__year_name",
        "created_by__username"
    )
    inlines = [TimeTableSlotInline]

    def department_name(self, obj):
        return obj.department.name
    department_name.admin_order_field = "department"

    def semester_number(self, obj):
        return obj.semester.sem_number
    semester_number.admin_order_field = "semester"

    def academic_year_label(self, obj):
        return obj.academic_year.year_name
    academic_year_label.admin_order_field = "academic_year"

@admin.register(TimeTableSlot)
class TimeTableSlotAdmin(admin.ModelAdmin):
    list_display = ("timetable", "day", "start_time", "end_time", "assignment", "is_batch_wise", "batch_name", "lab_room")
    list_filter = ("day", "is_batch_wise")
    search_fields = (
        "assignment__subject__subject_code",
        "assignment__subject__subject_name",
        "assignment__faculty__name",
    )
    inlines = [TimeTableSlotBatchInline]

@admin.register(TimeTableSlotBatch)
class TimeTableSlotBatchAdmin(admin.ModelAdmin):
    list_display = ("slot", "batch_name", "assignment", "lab_room", "start_time", "end_time", "allow_co_teaching")
    list_filter = ("batch_name", "allow_co_teaching")
    search_fields = (
        "batch_name",
        "lab_room",
        "assignment__subject__subject_name",
        "assignment__faculty__name"
    )

@admin.register(TimeTableApprovalHistory)
class TimeTableApprovalHistoryAdmin(admin.ModelAdmin):
    list_display = ("timetable", "action", "action_by", "action_at")
    list_filter = ("action",)
    search_fields = ("timetable__department__name", "action_by__username")
