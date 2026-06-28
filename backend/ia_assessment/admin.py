from django.contrib import admin
from .models import IATestSetup, IAMark, IAAggregate

@admin.register(IATestSetup)
class IATestSetupAdmin(admin.ModelAdmin):
    list_display = ("subject", "ia_type", "ia_name", "max_marks", "faculty",)
    search_fields = ("ia_name", "subject__subject_name", "faculty__username",)
    list_filter = ("ia_type",)


@admin.register(IAMark)
class IAMarkAdmin(admin.ModelAdmin):
    list_display = ("student", "ia_test", "obtained_marks",)
    list_filter = ("ia_test__ia_type",)
    search_fields = ("student__usn", "student__name",)


@admin.register(IAAggregate)
class IAAggregateAdmin(admin.ModelAdmin):
    list_display = ("student", "subject", "total_marks", "average_marks")
    search_fields = ("student__usn", "subject__subject_name")
