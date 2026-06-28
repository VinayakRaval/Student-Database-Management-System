from django.contrib import admin
from .models import HODAssignment

@admin.register(HODAssignment)
class HODAssignmentAdmin(admin.ModelAdmin):
    # Columns to display in the list view
    list_display = ("faculty", "department", "assigned_date", "end_date", "is_current_hod")
    
    # Filters in the sidebar
    list_filter = ("department", "assigned_date", "end_date")
    
    # Searchable fields
    search_fields = ("faculty__name", "department__name")

    # Enable actions (delete by default is already included)
    actions = ["delete_selected"]

    # Readable boolean field
    def is_current_hod(self, obj):
        return obj.is_current()
    is_current_hod.boolean = True
    is_current_hod.short_description = "Current HOD"

    # Optional: Customize which fields are editable in the list vie
    list_editable = ("end_date",)
